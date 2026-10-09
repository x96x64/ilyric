"""Optional pinned CPU Whisper observations; no lyric input or network during inference."""
import json
import re
from .core import AlignmentError
from .audio_anchors import FORMAT, validate
from .anchor_assets import SOURCE_REVISION, MODEL_SHA256

# Frozen before EN-F02/03. Word splits are heuristic anchors, not acoustic truth.
DECODING = ['-l','en','-t','4','-p','1','-ng','-mc','0','-bo','1','-bs','1',
            '-tp','0','-tpi','0','-nf','-ml','1','-sow','-ojf']
REFINEMENT_PADDING_US = 1000000


def convert(raw, window, duration_us):
    """Keep raw JSON externally; classify invalid intervals rather than clamp them."""
    if raw.get('result',{}).get('language') != 'en' or raw.get('params',{}).get('translate') is not False:
        raise AlignmentError('Whisper output language or translation differs')
    entries=raw.get('transcription')
    if not isinstance(entries,list) or len(entries)>10000:
        raise AlignmentError('Whisper transcription resource limit')
    output=[];rejected=[];start=window['start_sample']*1000000//16000
    end=min(duration_us,window['end_sample']*1000000//16000);prior=-1
    for i,row in enumerate(entries):
        identity=f"w{window['id']}-s{i}";reason=None
        try:
            a,b=row['offsets']['from'],row['offsets']['to'];text=row['text']
            if any(type(x) is not int or x%10 for x in [a,b]):raise ValueError()
            if not isinstance(text,str) or not text or len(text)>2000:raise ValueError()
            a=start+a*1000;b=start+b*1000
            if not start<=a<b<=end:reason='invalid_or_out_of_window_interval'
            if any(ord(c)<32 or 0xD800<=ord(c)<=0xDFFF for c in text):reason='unsupported_text_control'
        except (KeyError,TypeError,ValueError):
            rejected.append(dict(id=identity,reason='malformed_recognition',raw_index=i));continue
        if reason:
            rejected.append(dict(id=identity,reason=reason,raw_index=i));continue
        uncertainty=[]
        if re.search(r'\[[^]]*\]|\([^)]*\)|[♪♫]',text):uncertainty.append('nonlexical_event_or_annotation')
        if a<prior:uncertainty.append('nonchronological_recognition')
        prior=a
        output.append(dict(id=identity,window=window['id'],text=text,
                           begin_tick=a//10000,end_tick=b//10000,uncertainty=uncertainty))
    return output,rejected


def anchors(audio_hash,duration_us,observations):
    return validate(dict(format=FORMAT,audio=dict(sha256=audio_hash,duration_us=duration_us),language='en',
        timebase_hz=100,resolution_ticks=1,provenance=dict(producer='whisper.cpp-cpu',revision=SOURCE_REVISION,
        model='multilingual-small-ggml',weights_sha256=MODEL_SHA256,origin='audio_only',
        decoding=dict(lyric_prompt=False,previous_text_context=False,translation=False)),observations=observations))


def refinement_window(region,duration_us):
    a=max(0,region[0]-REFINEMENT_PADDING_US)//20000*20000
    b=min(duration_us,region[1]+REFINEMENT_PADDING_US)
    if not 0<=a<b<=duration_us or b-a>30000000:
        raise AlignmentError('Refinement exceeds existing 30-second model bound')
    return [a,b]


def apply_refinement(prepared, index, local, origin_us, end_us):
    """Preserve rejected proposals; estimates remain review-required and never overlap."""
    import copy
    row=prepared['lines'][index]
    row['quality']=copy.deepcopy(local['quality']);row['flags']=list(local['flags'])
    row['refinement_window_us']=[origin_us,end_us]
    for key in ['proposal','estimate']:
        row[key]=[origin_us+x for x in local[key]] if local[key] else None
    if row['proposal']:
        a,b=row['proposal'];region=row['correspondence']['region_us']
        if a-origin_us<20000 or end_us-b<20000:
            row['flags'].append('boundary_censored');row['estimate']=None
        if min(b,region[1])<=max(a,region[0]):
            row['flags'].append('refinement_outside_anchor');row['estimate']=None
    else:row['flags'].append('boundary_estimation_failure')
    row['flags'].append('audio_correspondence_requires_review')


def reject_overlaps(prepared):
    prior=None
    for row in prepared['lines']:
        if row['estimate'] is None:continue
        if prior is not None and row['estimate'][0]<prior['proposal'][1]:
            for bad in [prior,row]:
                bad['estimate']=None;bad['flags'].append('refinement_overlap')
        prior=row
