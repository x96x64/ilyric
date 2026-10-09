"""Optional pinned English CTC inference, bounded to 30-second overlapping windows."""
import contextlib
import importlib.metadata
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time
import wave
from fractions import Fraction
from .core import AlignmentError
from .worker import Unavailable, file_hash
from .full_song import GRID_US, artifact, path, proposals, text_targets, windows, owned_frames, vocal_activity_db, apply_vocal_rules, VOCAL_FRAME_US, VOCAL_ACTIVITY_DB, MINIMUM_US_PER_CHARACTER


def infer(audio, src, model, work, separator=None):
    started=time.perf_counter();_,tokens,owners=text_targets(src)
    if not audio.is_file() or audio.stat().st_size>256*1024*1024:
        raise AlignmentError('Supply local audio no larger than 256 MiB')
    if not model.is_dir():raise Unavailable('Pinned local English CTC model unavailable')
    for asset in json.loads((Path(__file__).resolve().parents[2]/'docs/alignment-data/v1/model-assets.json').read_text()):
        if not asset['asset'].startswith('wav2vec2/'):continue
        p=model/asset['asset'].split('/',1)[1]
        if not p.is_file():raise Unavailable('Pinned local English CTC asset unavailable')
        if p.stat().st_size!=asset['bytes'] or file_hash(p)!=asset['sha256']:
            raise AlignmentError('Pinned CTC asset identity differs')
    from .vocal_separation import require_separator, separate
    separation=require_separator(separator)
    os.environ.update(HF_HUB_OFFLINE='1',TRANSFORMERS_OFFLINE='1',TOKENIZERS_PARALLELISM='false')
    def deny(event,args):
        if event in ('socket.connect','socket.getaddrinfo'):raise Unavailable('Full-song inference forbids network access')
    sys.addaudithook(deny)
    try:
        import numpy as np
        import torch
        import soundfile as sf
        from scipy.signal import resample_poly
        from transformers import Wav2Vec2Processor,Wav2Vec2ForCTC
    except ImportError as e:raise Unavailable('Optional isolated acoustic dependencies unavailable') from e
    torch.set_num_threads(4);torch.manual_seed(0);torch.use_deterministic_algorithms(True)
    identity=file_hash(audio);t=time.perf_counter();decoded=work/'source.wav'
    try:
        subprocess.run(['ffmpeg','-v','error','-nostdin','-protocol_whitelist','file,pipe','-i',str(audio.resolve()),'-map','0:a:0','-vn','-ac','1','-ar','48000',
                        '-t','600.000021','-c:a','pcm_s16le','-n',str(decoded)],check=True,capture_output=True,timeout=120)
    except FileNotFoundError as e:raise Unavailable('FFmpeg unavailable') from e
    except subprocess.SubprocessError as e:raise AlignmentError('Bounded audio decode failed') from e
    with wave.open(str(decoded)) as w:source_samples=w.getnframes()
    if not 1200<=source_samples<=48000*600:raise AlignmentError('Complete audio must be 25 ms–600 seconds; input was not silently trimmed')
    duration=round(Fraction(source_samples*1000000,48000))
    signal,rate=sf.read(decoded,dtype='float32')
    signal=resample_poly(signal,1,3).astype(np.float32)
    if separation:
        # Separated vocals replace the mixture as the CTC input; source identity and timing remain the original's.
        signal,details=separate(audio,work,separator,len(signal),duration);separation.update(details)
    if ((len(signal)-400)//320+1)*(2*len(tokens)+1)>120000000:
        raise AlignmentError('Full-song CTC trace would exceed 120 MB; input remains unchanged')
    preprocessing=time.perf_counter()-t;t=time.perf_counter()
    with contextlib.redirect_stdout(sys.stderr):
        processor=Wav2Vec2Processor.from_pretrained(str(model),local_files_only=True)
        net=Wav2Vec2ForCTC.from_pretrained(str(model),local_files_only=True,use_safetensors=True).eval()
    initialization=time.perf_counter()-t;vocab=processor.tokenizer.get_vocab();blank=net.config.pad_token_id
    if any(c not in vocab for c in tokens):raise AlignmentError('Text cannot be represented by pinned model')
    plan=windows(len(signal));emissions=[];window_times=[];t=time.perf_counter()
    for row in plan:
        segment=signal[row['start_sample']:row['end_sample']];tick=time.perf_counter()
        with torch.inference_mode():
            values=processor(segment,sampling_rate=16000,return_tensors='pt').input_values
            scores=net(values).logits[0].log_softmax(-1).numpy()
        window_times.append(time.perf_counter()-tick)
        kept=owned_frames(row,len(scores),len(emissions))
        first=len(emissions)
        emissions.extend(scores[i].tolist() for i in kept)
        row['kept_frame_range']=[first,len(emissions)] if kept else None
    inference=time.perf_counter()-t;t=time.perf_counter()
    spans=path(emissions,[vocab[c] for c in tokens],blank)
    rows=proposals(src,duration,emissions,tokens,owners,spans,vocab,blank)
    if separation:
        level,reference=vocal_activity_db(signal);apply_vocal_rules(rows,level,reference)
    reconciliation=time.perf_counter()-t
    if file_hash(audio)!=identity:raise AlignmentError('Original audio changed during inference')
    engine=dict(id='windowed-english-ctc',method_version=1,proposal_rules=dict(minimum_mean_log_support=-3.0,minimum_greedy_similarity=.55,maximum_character_us=1500000,maximum_line_us=20000000),model='facebook/wav2vec2-base-960h',
                revision='22aad52d435eb6dbaf354bdad9b0da84ce7d6156',weights_sha256=file_hash(model/'model.safetensors'),
                model_grid_us=GRID_US,analysis_sample_rate=16000,decoded_sample_rate=48000,
                decoded_samples=source_samples,analysis_samples=len(signal),analyzed_frames=len(emissions),
                trailing_unanalyzed_us=duration-len(emissions)*GRID_US,device='cpu',threads=4,
                preprocessing='FFmpeg mono 48-kHz PCM16, scipy resample_poly 1/3, processor per-window normalization; 30 s windows, 4 s overlap, central ownership',
                dependencies={k:importlib.metadata.version(k) for k in ['torch','transformers','numpy','scipy','soundfile']},
                interpretation='Forced line-level proposals; shared-model greedy diagnostics are not independent lexical evidence; no vocal detector or automatic acceptance')
    if separation:engine.update(vocal_rules=dict(version=1,frame_us=VOCAL_FRAME_US,activity_db_below_p99=VOCAL_ACTIVITY_DB,minimum_us_per_character=MINIMUM_US_PER_CHARACTER),ctc_input='separated_vocals',separation={k:v for k,v in separation.items() if k!='measurements'})
    result=artifact(src,identity,duration,engine,plan,rows)
    result['measurements']=dict(preprocessing_seconds=preprocessing,initialization_seconds=initialization,
                               separation=separation['measurements'] if separation else None,inference_seconds=inference,reconciliation_seconds=reconciliation,
                               window_inference_seconds=window_times,total_seconds=time.perf_counter()-started,
                               peak_rss_bytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*(1 if sys.platform=='darwin' else 1024))
    return result
