"""Native segment support, separate from heuristic token timing and source lyrics."""
import copy
import json
import re
from collections import Counter
from .core import AlignmentError
from .audio_anchors import fields, sha, integer, fingerprint
from .whisper_anchors import DECODING, anchors
from .full_song import windows

FORMAT = 'ilyric-segment-evidence-1'
SEGMENT_DECODING = list(DECODING)
SEGMENT_DECODING[SEGMENT_DECODING.index('-ml')+1] = '0'


def support(offsets, window, duration_us):
    """Classify the supplied interval without rounding, repairing, or inferring it."""
    if not isinstance(offsets,dict) or 'from' not in offsets or 'to' not in offsets:
        return dict(status='missing',source_ticks=None)
    a,b=offsets['from'],offsets['to']
    if any(type(x) is not int or x%10 for x in [a,b]) or not 0<=a<b:
        return dict(status='invalid',source_ticks=None)
    start=window['start_sample']*1000000//16000
    if start+a*1000<start or start+b*1000>min(duration_us,window['end_sample']*1000000//16000):
        return dict(status='out_of_window',source_ticks=None)
    return dict(status='valid',source_ticks=[start//10000+a//10,start//10000+b//10])


def convert_segments(raw, window, duration_us):
    if raw.get('result',{}).get('language')!='en' or raw.get('params',{}).get('translate') is not False:
        raise AlignmentError('Segment output language or translation differs')
    values=raw.get('transcription')
    if not isinstance(values,list) or len(values)>10000:raise AlignmentError('Segment count exceeds resource limit')
    result=[];prior=-1
    for i,row in enumerate(values):
        if not isinstance(row,dict) or not isinstance(row.get('text'),str):
            raise AlignmentError('Segment must retain original recognized text')
        text=row['text']
        if len(text)>2000 or any(0xD800<=ord(c)<=0xDFFF for c in text):raise AlignmentError('Unsupported segment text resource or Unicode')
        bounds=copy.deepcopy(row.get('offsets'));timing=support(bounds,window,duration_us)
        if timing['status']=='valid':
            a,b=timing['source_ticks']
            if a<prior:timing['status']='ambiguous'
            prior=a
        # Subword tokens are not words. Scores and complete token text remain in raw JSON.
        counts=Counter();tokens=row.get('tokens',[])
        if not isinstance(tokens,list) or len(tokens)>10000:raise AlignmentError('Token diagnostic resource limit')
        for token in tokens:
            if not isinstance(token,dict):raise AlignmentError('Malformed token evidence')
            if str(token.get('text','')).startswith('[_'):continue
            t=support(token.get('offsets'),window,duration_us)
            if t['status']!='valid':counts[t['status']]+=1
            elif timing['source_ticks'] and not timing['source_ticks'][0]<=t['source_ticks'][0]<t['source_ticks'][1]<=timing['source_ticks'][1]:
                counts['outside_segment']+=1
        result.append(dict(id=f"w{window['id']}-s{i}",text=text,offsets_ms=bounds,support=timing,
                           token_count=len(tokens),token_timing_issues=dict(counts)))
    return dict(id=window['id'],raw_sha256=fingerprint(raw),segments=result)


def segment_evidence(audio_hash,duration_us,window_records):
    base=anchors(audio_hash,duration_us,[])
    record=dict(format=FORMAT,audio=base['audio'],language='en',timebase_hz=100,resolution_ticks=1,
                granularity='segment',provenance=base['provenance'],windows=copy.deepcopy(window_records))
    record['provenance']['producer']='whisper.cpp-cpu-native-segments'
    project(record) # Validate before preserving the record.
    return record


def project(record):
    """Reuse the frozen matcher; every lexical token retains the same parent support.

    This is not word timing. Native spans sharing multiple supplied lines can
    conflict in the unchanged chronological matcher; no hidden subdivision fixes it.
    """
    try:
        fields(record,'format audio language timebase_hz resolution_ticks granularity provenance windows')
        if (record['format'],record['language'],record['timebase_hz'],record['resolution_ticks'],record['granularity'])!=(FORMAT,'en',100,1,'segment'):
            raise AlignmentError('Unsupported segment evidence version or granularity')
        audio=record['audio'];base=anchors(audio['sha256'],audio['duration_us'],[])
        base['provenance']=copy.deepcopy(record['provenance'])
        plan=windows((audio['duration_us']*16000+999999)//1000000)
        if not isinstance(record['windows'],list) or len(record['windows'])!=len(plan):raise AlignmentError('Segment evidence must cover every automatic window')
        observations=[];rejected=[];chars=0;total=0
        for row,w in zip(record['windows'],plan):
            fields(row,'id raw_sha256 segments');sha(row['raw_sha256'])
            if type(row['id']) is not int or row['id']!=w['id'] or not isinstance(row['segments'],list):raise AlignmentError('Segment window order differs')
            prior=-1
            for i,seg in enumerate(row['segments']):
                fields(seg,'id text offsets_ms support token_count token_timing_issues')
                if seg['id']!=f"w{w['id']}-s{i}" or not isinstance(seg['text'],str) or len(seg['text'])>2000:raise AlignmentError('Segment identity or text differs')
                chars+=len(seg['text']);total+=1
                if chars>65536 or total>10000:raise AlignmentError('Segment resource limit')
                integer(seg['token_count'],0,10000)
                if not isinstance(seg['token_timing_issues'],dict) or set(seg['token_timing_issues'])-{'missing','invalid','out_of_window','outside_segment'}:raise AlignmentError('Invalid token diagnostics')
                for value in seg['token_timing_issues'].values():integer(value,0,seg['token_count'])
                timing=support(seg['offsets_ms'],w,audio['duration_us'])
                if timing['status']=='valid':
                    a,b=timing['source_ticks']
                    if a<prior:timing['status']='ambiguous'
                    prior=a
                if timing!=seg['support']:raise AlignmentError('Segment support was altered')
                reason=None
                if timing['status']!='valid':reason='segment_timing_'+timing['status']
                elif not seg['text']:reason='empty_recognition'
                elif any(ord(c)<32 or 0xD800<=ord(c)<=0xDFFF for c in seg['text']):reason='unsupported_text_control'
                if reason:
                    rejected.append(dict(id=seg['id'],reason=reason));continue
                a,b=timing['source_ticks'];uncertainty=[]
                if re.search(r'\[[^]]*\]|\([^)]*\)|[♪♫]',seg['text']):uncertainty.append('nonlexical_event_or_annotation')
                observations.append(dict(id=seg['id'],window=w['id'],text=seg['text'],begin_tick=a,end_tick=b,uncertainty=uncertainty))
        # The exact text, including invalid-timing segments, remains in record.
        base['observations']=observations
        from .audio_anchors import validate
        validate(base)
        if len(json.dumps(record,ensure_ascii=False,allow_nan=False).encode())>4*1024*1024:raise AlignmentError('Segment evidence exceeds 4 MiB')
        return base,rejected
    except (KeyError,TypeError,AttributeError,OverflowError) as e:raise AlignmentError('Malformed segment evidence') from e
