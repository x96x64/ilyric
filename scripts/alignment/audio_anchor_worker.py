"""Isolated approved acoustic stage. Public tests do not import optional ML packages."""
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
from .core import AlignmentError, source
from .worker import Unavailable, file_hash
from .anchor_assets import require_assets
from .audio_anchors import match, review_artifact, fingerprint
from .full_song import windows, text_targets, path, proposals, artifact
from .whisper_anchors import DECODING, convert, anchors, refinement_window, apply_refinement, reject_overlaps


def save(file,value):
    with file.open('x') as f:json.dump(value,f,ensure_ascii=False,indent=2,allow_nan=False)


def infer(audio,lyrics,runtime,model,ctc,work,anchor_mode="word",separator=None):
    if anchor_mode not in ["word","segment"]:raise AlignmentError("Unsupported experimental anchor mode")
    from .segment_anchors import SEGMENT_DECODING, convert_segments, segment_evidence, project
    decoding=DECODING if anchor_mode=="word" else SEGMENT_DECODING
    segment_windows=[]
    started=time.perf_counter()
    if not audio.is_file() or not lyrics.is_file():raise Unavailable('Local audio or complete lyrics unavailable')
    if audio.stat().st_size>256*1024*1024 or lyrics.stat().st_size>65536:raise AlignmentError('Input resource limit')
    src=source(lyrics.read_bytes());text_targets(src)
    assets=require_assets(runtime,model)
    from .vocal_separation import require_separator, separate
    separation=require_separator(separator)
    if sys.platform!='darwin' or not Path('/usr/bin/sandbox-exec').is_file():
        raise Unavailable('This pinned CPU experiment requires macOS network isolation')
    if work.exists():raise AlignmentError('Use a new work directory; saved evidence is never overwritten')
    work.mkdir(parents=True)
    identity=file_hash(audio);tick=time.perf_counter()
    os.environ.update(HF_HUB_OFFLINE='1',TRANSFORMERS_OFFLINE='1',TOKENIZERS_PARALLELISM='false')
    def deny(event,args):
        if event in ('socket.connect','socket.getaddrinfo'):raise Unavailable('Acoustic inference forbids network access')
    sys.addaudithook(deny)
    try:
        import numpy as np
        import soundfile as sf
        from scipy.signal import resample_poly
    except ImportError as e:raise Unavailable('Existing isolated audio dependencies unavailable') from e
    decoded=work/'source.wav'
    try:
        subprocess.run(['ffmpeg','-v','error','-nostdin','-protocol_whitelist','file,pipe','-i',str(audio.resolve()),
            '-map','0:a:0','-vn','-ac','1','-ar','48000','-t','600.000021','-c:a','pcm_s16le','-n',str(decoded)],
            check=True,capture_output=True,timeout=120)
    except FileNotFoundError as e:raise Unavailable('FFmpeg unavailable') from e
    except subprocess.SubprocessError as e:raise AlignmentError('Bounded source decoding failed') from e
    signal,rate=sf.read(decoded,dtype='float32')
    if not 1200<=len(signal)<=48000*600:raise AlignmentError('Source exceeds 25 ms–600 seconds; no silent truncation')
    duration=round(Fraction(len(signal)*1000000,48000));signal=resample_poly(signal,1,3).astype(np.float32)
    plan=windows(len(signal));preprocessing=time.perf_counter()-tick;observed=[];rejected=[];times=[]
    # Separated vocals change only the recognition input; CTC refinement keeps the original mixture.
    recognition=signal
    if separation:
        recognition,details=separate(audio,work,separator,len(signal),duration);separation.update(details)
    # Each process resets Whisper context; words are never passed as prompts.
    for w in plan:
        name=f"window-{w['id']:02d}";wav=work/(name+'.wav');base=work/name
        sf.write(wav,recognition[w['start_sample']:w['end_sample']],16000,subtype='PCM_16')
        command=['/usr/bin/sandbox-exec','-p','(version 1)(allow default)(deny network*)',str(runtime.resolve()),
                 '-m',str(model.resolve()),'-f',str(wav.resolve()),'-of',str(base.resolve())]+decoding
        tick=time.perf_counter()
        with (work/(name+'.log')).open('x') as log:
            try:subprocess.run(command,stdout=log,stderr=log,check=True,timeout=300)
            except subprocess.SubprocessError as e:raise AlignmentError('Whisper window failed; inspect retained local log') from e
        times.append(time.perf_counter()-tick)
        output=work/(name+'.json')
        if not output.is_file() or output.stat().st_size>4*1024*1024:raise AlignmentError('Whisper output unavailable or oversized')
        raw=json.loads(output.read_text())
        if anchor_mode=='segment':segment_windows.append(convert_segments(raw,w,duration))
        else:
            items,failures=convert(raw,w,duration)
            observed.extend(items);rejected.extend(failures)
    if anchor_mode=='segment':
        evidence=segment_evidence(identity,duration,segment_windows)
        save(work/'segments.json',evidence)
        record,rejected=project(evidence)
    else:record=anchors(identity,duration,observed)
    save(work/'anchors.json',record)
    save(work/'recognition-rejections.json',rejected)
    tick=time.perf_counter();result=match(src,record);matching=time.perf_counter()-tick
    save(work/'correspondence.json',result)
    prepared=review_artifact(result);tick=time.perf_counter()
    # Existing verified speech model is used only after chronological correspondence.
    for item in json.loads((Path(__file__).resolve().parents[2]/'docs/alignment-data/v1/model-assets.json').read_text()):
        if not item['asset'].startswith('wav2vec2/'):continue
        f=ctc/item['asset'].split('/',1)[1]
        if not f.is_file():raise Unavailable('Pinned local CTC dependency unavailable')
        if f.stat().st_size!=item['bytes'] or file_hash(f)!=item['sha256']:raise AlignmentError('CTC identity differs')
    try:
        import torch
        from transformers import Wav2Vec2Processor,Wav2Vec2ForCTC
    except ImportError as e:raise Unavailable('Existing isolated CTC dependencies unavailable') from e
    torch.set_num_threads(4);torch.manual_seed(0);torch.use_deterministic_algorithms(True)
    with contextlib.redirect_stdout(sys.stderr):
        processor=Wav2Vec2Processor.from_pretrained(str(ctc),local_files_only=True)
        net=Wav2Vec2ForCTC.from_pretrained(str(ctc),local_files_only=True,use_safetensors=True).eval()
    initialization=time.perf_counter()-tick;vocab=processor.tokenizer.get_vocab();blank=net.config.pad_token_id
    refinements=[];tick=time.perf_counter()
    for i,d in enumerate(result['decisions']):
        if d['state']!='supported':continue
        a,b=refinement_window(d['region_us'],duration);t=time.perf_counter()
        local=source(prepared['lines'][i]['text'].encode());_,tokens,owners=text_targets(local)
        with torch.inference_mode():
            values=processor(signal[a*16000//1000000:(b*16000+999999)//1000000],sampling_rate=16000,return_tensors='pt').input_values
            emissions=net(values).logits[0].log_softmax(-1).numpy().tolist()
        spans=path(emissions,[vocab[c] for c in tokens],blank)
        proposal=proposals(local,b-a,emissions,tokens,owners,spans,vocab,blank)[0]
        apply_refinement(prepared,i,proposal,a,b)
        refinements.append(dict(occurrence=i,window_us=[a,b],seconds=time.perf_counter()-t))
    reject_overlaps(prepared);refinement=time.perf_counter()-tick
    engine=dict(prepared['engine'],id='whisper-anchors-bounded-ctc',analysis_samples=len(signal),
        assets=assets,decoding=decoding,ctc='facebook/wav2vec2-base-960h',
        ctc_revision='22aad52d435eb6dbaf354bdad9b0da84ce7d6156',ctc_weights_sha256=file_hash(ctc/'model.safetensors'),
        interpretation='Heuristic Whisper anchors plus speech CTC boundaries; review required; no calibrated confidence',
        dependencies={k:importlib.metadata.version(k) for k in ['torch','transformers','numpy','scipy','soundfile']})
    if anchor_mode=='segment':engine.update(anchor_granularity='segment',segment_evidence_sha256=fingerprint(evidence))
    if separation:engine.update(recognition_input='separated_vocals',separation={k:v for k,v in separation.items() if k!='measurements'})
    prepared=artifact(src,identity,duration,engine,plan,prepared['lines'])
    if file_hash(audio)!=identity or source(lyrics.read_bytes())!=src:raise AlignmentError('Original input changed')
    measurements=dict(preprocessing_seconds=preprocessing,whisper_window_seconds=times,whisper_total_seconds=sum(times),
        separation=separation['measurements'] if separation else None,matching_seconds=matching,ctc_initialization_seconds=initialization,refinement_seconds=refinement,
        refinement_windows=refinements,total_seconds=time.perf_counter()-started,
        parent_peak_rss_bytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        child_peak_rss_bytes=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
        memory_scope='macOS peak RSS: parent and maximum child separately; not simultaneous process-tree peak')
    prepared['measurements']=measurements;save(work/'prepared.json',prepared);save(work/'measurements.json',measurements)
    return dict(status='review_required',occurrences=len(prepared['lines']),
                estimates=sum(r['estimate'] is not None for r in prepared['lines']),automatic_acceptance=False)
