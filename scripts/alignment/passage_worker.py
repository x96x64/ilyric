"""Pinned local TIFA passage search. No renderer or inference download dependency."""
import contextlib
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time
from fractions import Fraction
from .core import AlignmentError, canonical
from .worker import Unavailable,file_hash
from .passage_search import POLICY,search_windows,reconcile,central_lines


def search(audio,src,model,vendor,work):
    audio,model,vendor,work=[p.resolve() for p in [audio,model,vendor,work]]
    previous=Path.cwd()
    try:
        os.chdir(work)
        return _search(audio,src,model,vendor,work)
    finally:
        os.chdir(previous)


def _search(audio,src,model,vendor,work):
    from .full_song import text_targets
    text_targets(src) # Preserve the existing English input restriction.
    started=time.perf_counter();model=model.resolve();vendor=vendor.resolve()
    manifest=Path(__file__).resolve().parents[2]/'docs/alignment-data/v1/model-assets.json'
    for asset in json.loads(manifest.read_text()):
        if not asset['asset'].startswith('TIFA-1.0-ST/'):continue
        p=model/asset['asset'].split('/',1)[1]
        if not p.is_file():raise Unavailable('Pinned local TIFA asset unavailable')
        if p.stat().st_size!=asset['bytes'] or file_hash(p)!=asset['sha256']:raise AlignmentError('Pinned TIFA identity differs')
    if not (vendor/'inference/api.py').is_file():raise Unavailable('Pinned TIFA source unavailable')
    files=sorted(vendor.rglob('*.py'));identity=hashlib.sha256()
    if len(files)>300 or sum(p.stat().st_size for p in files)>2000000:raise AlignmentError('TIFA source exceeds pinned bounds')
    for p in files:identity.update(p.relative_to(vendor).as_posix().encode()+b'\0'+p.read_bytes()+b'\0')
    if identity.hexdigest()!='e05742f6c2bf250537bb6582461467c7b39b2d13ef705d9505767c55fe1e9bd8':raise AlignmentError('TIFA source revision differs')
    if not audio.is_file():raise Unavailable('Local song unavailable')
    if audio.stat().st_size>256*1024*1024:raise AlignmentError('Audio exceeds 256 MiB')
    audio_hash=file_hash(audio);os.environ.update(HF_HUB_OFFLINE='1',TRANSFORMERS_OFFLINE='1',TOKENIZERS_PARALLELISM='false',
        MPLCONFIGDIR=str(work/'matplotlib'),NUMBA_CACHE_DIR=str(work/'numba'))
    def deny(event,args):
        if event in ('socket.connect','socket.getaddrinfo'):raise Unavailable('Passage inference forbids network access')
    sys.addaudithook(deny)
    try:
        import torch
        import soundfile as sf
        import onnxruntime
        import unidic_lite
    except ImportError as e:raise Unavailable('Optional isolated TIFA dependencies unavailable') from e
    onnxruntime.disable_telemetry_events();torch.set_num_threads(4);torch.manual_seed(0);torch.use_deterministic_algorithms(True)
    sys.path.insert(0,str(vendor))
    from inference.api import load_inference_model
    from lib.g2p import build_pipeline_from_config
    from lib.g2p_encoding import encode_paths
    from lib.path_traversal import materialize_paths
    tick=time.perf_counter()
    try:
        subprocess.run(['ffmpeg','-v','error','-nostdin','-protocol_whitelist','file,pipe','-i',str(audio.resolve()),'-map','0:a:0','-vn','-ac','1','-ar','48000','-t','600.000021','-c:a','pcm_s16le','-n',str(work/'audio.wav')],capture_output=True,check=True,timeout=120)
    except FileNotFoundError as e:raise Unavailable('FFmpeg unavailable') from e
    except subprocess.SubprocessError as e:raise AlignmentError('Bounded audio decode failed') from e
    signal,rate=sf.read(work/'audio.wav',dtype='float32')
    if not 1200<=len(signal)<=48000*600:raise AlignmentError('Song must be 25 ms–600 seconds; no silent trimming')
    duration=round(Fraction(len(signal)*1000000,48000));plan=search_windows(duration)
    contexts=[(max(0,i-1),min(len(src['paragraphs']),i+2),i) for i in range(len(src['paragraphs']))]
    unique=list(dict.fromkeys(('\n\n'.join(src['paragraphs'][a:b]), i-a) for a,b,i in contexts))
    if len(plan)*len(unique)>POLICY['max_evaluations']:raise AlignmentError('Search exceeds 2000 bounded TIFA evaluations')
    preprocessing=time.perf_counter()-tick;tick=time.perf_counter()
    with contextlib.redirect_stdout(sys.stderr):backend,vocabulary,config=load_inference_model(model/'model.pt',scope=1)
    if backend.sample_rate!=48000 or Fraction(str(backend.timestep))!=Fraction(1,100):raise AlignmentError('Unsupported TIFA sample/frame grid')
    for converter in config.g2p.converters:
        if converter.id=='japanese-mecab':converter.kwargs['unidic_dir']=unidic_lite.DICDIR
    g2p=build_pipeline_from_config(config.g2p,root_path=model)
    initialization=time.perf_counter()-tick;tick=time.perf_counter();encoded=[]
    for text,center in unique:
        if len(canonical(text)[0])>1500:raise AlignmentError('Context exceeds existing 1500-character inference limit')
        words=g2p.convert(text,languages=['en']);data,lexicon,texts=encode_paths(words,vocabulary,'raise',languages=['en'])
        if data['words'].size>3000 or data['paths'].size>100000:raise AlignmentError('Pronunciation lattice exceeds existing limits')
        encoded.append((text,center,{k:torch.from_numpy(v).unsqueeze(0) for k,v in data.items()},texts))
    g2p_seconds=time.perf_counter()-tick;records=[[] for _ in unique];tick=time.perf_counter();calls=0
    with torch.inference_mode():
        for region in plan:
            a=region['start_us']*48000//1000000;b=min(len(signal),(region['end_us']*48000+999999)//1000000)
            waveform=torch.from_numpy(signal[a:b]).unsqueeze(0)
            spec=backend.spectrogram(waveform,torch.tensor([(b-a)/48000],dtype=torch.float32))
            for p,(text,center,data,texts) in enumerate(encoded):
                scored=backend.score(spec,paths=data['paths'],words=data['words'],candidates=data['candidates'],unit='levenshtein')
                tokens,owners,groups=materialize_paths(data['paths'],data['words'],data['groups'],scored.choices)
                r=backend.align(spec,tokens=tokens,groups=groups,unit='frame',skip_penalty=.5)
                spans=r.spans[0].tolist();ids=owners[0].tolist();units=[]
                for word,word_text in enumerate(texts,1):
                    parts=[pair for pair,owner in zip(spans,ids) if owner==word]
                    units.append(dict(text=word_text,begin_us=parts[0][0]*10000 if parts and all(x<y for x,y in parts) else 0,
                                      end_us=parts[-1][1]*10000 if parts and all(x<y for x,y in parts) else 0))
                values,word_line,center_ids,unresolved=central_lines(text,center,units,region['end_us']-region['start_us'])
                valid=[r.similarity[0,x:y,i].mean() for i,((x,y),owner) in enumerate(zip(spans,ids)) if x<y and word_line.get(owner) in center_ids]
                similarity=float(torch.stack(valid).mean()) if valid else None
                record=dict(id=f'p{p}-w{region["id"]}',window=region['id'],agreement=float(r.agreement[0]),similarity=similarity,
                    lines=[[x+region['start_us'],y+region['start_us']] for x,y in values],unresolved=sorted(set(unresolved)),
                    context_skipped_word_units=sum(u['begin_us']>=u['end_us'] for j,u in enumerate(units,1) if word_line.get(j) not in center_ids),
                    window_bounds_us=[region['start_us'],region['end_us']])
                records[p].append(record);calls+=1
                if calls%50==0:print(json.dumps(dict(candidate_evaluations=calls)),file=sys.stderr,flush=True)
    inference=time.perf_counter()-tick;tick=time.perf_counter()
    groups_=[records[unique.index(('\n\n'.join(src['paragraphs'][a:b]),i-a))] for a,b,i in contexts]
    selection=reconcile(groups_,duration);reconciliation=time.perf_counter()-tick
    if file_hash(audio)!=audio_hash:raise AlignmentError('Original audio changed')
    return dict(format='ilyric-tifa-candidates-1',source=src,audio=dict(sha256=audio_hash,duration_us=duration),windows=plan,
        groups=groups_,selection=selection,provenance=dict(model='TIFA-1.0-ST',revision='614a277d2580efe5e4b84faf4c34753dbc5a062c',
        weights_sha256=file_hash(model/'model.pt'),config_sha256=file_hash(model/'config.yaml'),source_fingerprint=identity.hexdigest(),
        model_grid_us=10000,context_policy='one preceding and one following supplied paragraph; central timing only',source_samples_48000=len(signal),dependencies={k:importlib.metadata.version(k) for k in ['torch','numpy','lightning','g2pflow','onnxruntime']},
        preprocessing='FFmpeg mono 48-kHz PCM16; pinned TIFA spectrogram, pronunciation scoring and skip_penalty 0.5; fixed 30 s windows/15 s stride'),
        measurements=dict(total_seconds=time.perf_counter()-started,preprocessing_seconds=preprocessing,initialization_seconds=initialization,
        g2p_seconds=g2p_seconds,inference_seconds=inference,reconciliation_seconds=reconciliation,candidate_evaluations=calls,
        unique_passages=len(unique),peak_rss_bytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*(1 if sys.platform=='darwin' else 1024)))
