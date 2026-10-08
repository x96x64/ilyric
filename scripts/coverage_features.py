#!/usr/bin/env python3
"""Optional audio-only experiment. Features contain private acoustic-derived text.

Use ignored outputs. No acceptance, alignment, automatic acquisition, or rendering.
Pinned local English speech model; spectral activity is not a singing classifier.
"""
import argparse
import json
import os
from pathlib import Path
import resource
import sys
import tempfile
import time
from alignment.core import AlignmentError
from alignment.worker import Unavailable, decode, file_hash
from alignment.coverage import active_intervals


def extract(audio, model, work):
    manifest = Path(__file__).resolve().parents[1]/'docs/alignment-data/v1/model-assets.json'
    for asset in json.loads(manifest.read_text()):
        if not asset['asset'].startswith('wav2vec2/'):continue
        path = model/asset['asset'].split('/',1)[1]
        if not path.is_file():raise Unavailable('Pinned local CTC model unavailable')
        if path.stat().st_size != asset['bytes'] or file_hash(path) != asset['sha256']:
            raise AlignmentError('Unsupported local CTC asset revision')
    os.environ.update(HF_HUB_OFFLINE='1',TRANSFORMERS_OFFLINE='1',TOKENIZERS_PARALLELISM='false')
    def deny(event, args):
        if event in ('socket.connect','socket.getaddrinfo'):raise Unavailable('Acoustic diagnostic forbids network access')
    sys.addaudithook(deny)
    try:
        import numpy as np
        import torch
        import soundfile as sf
        from scipy.signal import resample_poly
        from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor
    except ImportError as e:raise Unavailable('Optional acoustic environment unavailable') from e
    torch.set_num_threads(4);torch.manual_seed(0);torch.use_deterministic_algorithms(True)
    if not audio.is_file() or audio.stat().st_size > 256*1024*1024:
        raise AlignmentError('Audio must be a readable local file no larger than 256 MiB')
    identity = file_hash(audio); t = time.perf_counter()
    duration = decode(audio,work/'analysis.wav')
    if duration < 25000:raise AlignmentError('CTC acoustic diagnostic requires at least 25 ms of audio')
    signal,rate=sf.read(work/'analysis.wav')
    signal = resample_poly(signal,1,3).astype(np.float32)
    preprocessing = time.perf_counter()-t; t = time.perf_counter()
    # Fixed whole-mixture spectral proxy: no reference or supplied text enters it.
    frames = np.lib.stride_tricks.sliding_window_view(np.pad(signal,(0,640)),640)[::160][:int(np.ceil(len(signal)/160))]
    power = abs(np.fft.rfft(frames*np.hanning(640),axis=1))**2
    flatness = np.exp(np.mean(np.log(power+1e-12),axis=1))/(np.mean(power,axis=1)+1e-12)
    rms = np.sqrt(np.mean(frames*frames,axis=1));reference = float(np.percentile(rms,90))
    mask = ((flatness < .3)&(rms>max(1e-6,reference*10**(-30/20)))).tolist()
    spectral = active_intervals(mask,10000,duration); spectral_seconds = time.perf_counter()-t
    t = time.perf_counter()
    processor=Wav2Vec2Processor.from_pretrained(str(model),local_files_only=True)
    net=Wav2Vec2ForCTC.from_pretrained(str(model),local_files_only=True).eval()
    initialization = time.perf_counter()-t; t=time.perf_counter()
    with torch.inference_mode():
        values=processor(signal,sampling_rate=16000,return_tensors='pt').input_values
        ids=net(values).logits[0].argmax(-1).tolist()
    inference = time.perf_counter()-t
    separator=processor.tokenizer.get_vocab()['|'];blank=net.config.pad_token_id
    excluded=set(processor.tokenizer.all_special_ids)|{blank,separator}
    activity=active_intervals([x not in excluded for x in ids],20000,duration)
    greedy=processor.decode(ids,skip_special_tokens=True)
    if file_hash(audio)!=identity:raise AlignmentError('Original audio changed during diagnostic')
    import importlib.metadata
    return dict(version=1,audio_sha256=identity,duration_us=duration,
                spectral_activity_us=spectral,ctc_activity_us=activity,greedy_text=greedy,
                provenance=dict(model='facebook/wav2vec2-base-960h',revision='22aad52d435eb6dbaf354bdad9b0da84ce7d6156',
                                weights_sha256=file_hash(model/'model.safetensors'),source_conditioning='audio only; no supplied text',
                                dependencies={x:importlib.metadata.version(x) for x in ['torch','transformers','numpy','scipy','soundfile']},
                                spectral_grid_us=10000,ctc_grid_us=20000,device='cpu',threads=4),
                measurements=dict(preprocessing_seconds=preprocessing,spectral_seconds=spectral_seconds,
                                  initialization_seconds=initialization,inference_seconds=inference,
                                  peak_rss_bytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*(1 if sys.platform=='darwin' else 1024)),
                limitations='Speech CTC is not singing VAD; English lexical evidence only. Spectral proxy includes instruments. Greedy text is diagnostic, never replacement lyrics.')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['audio','model','output']:p.add_argument('--'+name,type=Path,required=True)
    args=p.parse_args()
    try:
        if not args.audio.is_file() or not args.model.is_dir():raise Unavailable('Local audio or optional model unavailable')
        if args.output.exists():raise AlignmentError('Output already exists')
        if not args.output.parent.is_dir():raise AlignmentError('Create an ignored output directory first')
        with tempfile.TemporaryDirectory(dir=args.output.parent) as tmp:result=extract(args.audio,args.model,Path(tmp))
        with args.output.open('x',encoding='utf-8') as f:json.dump(result,f,ensure_ascii=False,indent=2)
        print(json.dumps(dict(status='diagnostic_only',automatic_acceptance=False)))
    except Unavailable as e:print(json.dumps(dict(status='unavailable',reason=str(e))));return 3
    except (AlignmentError,OSError,ValueError) as e:p.exit(2,'Acoustic diagnostic failed: '+str(e)+'\n')
    return 0

if __name__=='__main__':raise SystemExit(main())
