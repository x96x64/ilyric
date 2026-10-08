"""Whole-mixture energy diagnostics. No claim of voice activity or automatic repair."""
import array
import math
import sys
import wave
from .core import AlignmentError


def rms_frames(path):
    with wave.open(str(path), 'rb') as f:
        if (f.getnchannels(), f.getsampwidth(), f.getframerate()) != (1, 2, 48000) or f.getnframes() > 60 * 48000:
            raise AlignmentError('Energy diagnostic requires at most 60 seconds of mono 48-kHz PCM16')
        samples = array.array('h', f.readframes(f.getnframes()))
    if sys.byteorder != 'little': samples.byteswap()
    return [math.sqrt(sum(x*x for x in samples[i:i+480]) / len(samples[i:i+480])) / 32768
            for i in range(0, len(samples), 480)]


def endpoint(energy, begin_us, end_us, relative_db=-30, minimum_low_ms=160, radius_ms=500):
    """Propose the nearest sustained energy decline; preserve unsupported results.

    Parameters must be chosen on development data. This is a diagnostic candidate,
    never a vocal classifier or a timestamp correction applied to an artifact.
    """
    if not energy or len(energy) > 6000 or any(not math.isfinite(x) or x < 0 for x in energy):
        raise AlignmentError('Invalid bounded energy series')
    if type(begin_us) is not int or type(end_us) is not int or not 0 <= begin_us < end_us <= len(energy)*10000 or relative_db not in [-20,-30,-40] or minimum_low_ms not in [80,160] or radius_ms not in [250,500,1000]:
        raise AlignmentError('Unsupported endpoint diagnostic settings')
    left=max(begin_us//10000, end_us//10000-radius_ms//10)
    right=min(len(energy), (end_us+9999)//10000+radius_ms//10)
    window=sorted(energy[left:right]); reference=window[min(len(window)-1,int(.9*(len(window)-1)))]
    if reference <= 1e-6:
        return {'candidate_us':None,'status':'no_local_energy_support','threshold':None,
                'end_at_capture_boundary':end_us>=len(energy)*10000-20000,'review_required':True}
    threshold=reference*10**(relative_db/20); candidates=[]; i=left
    while i < right:
        if energy[i]>threshold: i+=1;continue
        a=i
        while i<right and energy[i]<=threshold:i+=1
        # Require an observed decline, not the start/end of an excerpt/window.
        if a>left and i-a>=minimum_low_ms//10 and a*10000>begin_us:
            candidates.append(a*10000)
    candidate=min(candidates,key=lambda x:(abs(x-end_us),x)) if candidates else None
    return {'candidate_us':candidate,'status':'energy_decline' if candidate is not None else 'no_sustained_low_energy',
            'threshold':threshold,'end_at_capture_boundary':end_us>=len(energy)*10000-20000,
            'review_required':candidate is None or abs(candidate-end_us)>100000 or end_us>=len(energy)*10000-20000}


def quality_gate(value, threshold, unresolved=False):
    """Experimental review flag; a passed threshold is never verified acceptance."""
    if unresolved or value is None or not math.isfinite(value):return 'review_required'
    return 'review_required' if value < threshold else 'not_flagged'


def fit_review_threshold(examples):
    """Development-only separator with zero observed matched-case flags.

    Both matched and deliberately mismatched examples are required. This is not
    calibrated confidence and does not authorize automatic acceptance.
    """
    positives=[x['score'] for x in examples if x['matched'] and not x.get('unresolved') and x['score'] is not None]
    negatives=[x['score'] for x in examples if not x['matched'] and not x.get('unresolved') and x['score'] is not None]
    if not positives or not negatives or any(not math.isfinite(v) for v in positives+negatives):
        raise AlignmentError('Finite matched and mismatched development scores are required')
    limit=min(positives); below=[v for v in negatives if v<limit]
    # Place the boundary halfway above the highest separable negative. Higher
    # scoring mismatches cannot be rejected without observed false rejection.
    return (max(below)+limit)/2 if below else min(positives+negatives)-1


def confusion(examples, threshold):
    result=dict(matched=0,mismatched=0,false_acceptance=0,false_rejection=0,unresolved=0)
    for x in examples:
        flag=quality_gate(x['score'],threshold,x.get('unresolved',False))=='review_required'
        result['unresolved']+=bool(x.get('unresolved',False))
        if x['matched']:
            result['matched']+=1;result['false_rejection']+=flag
        else:
            result['mismatched']+=1;result['false_acceptance']+=not flag
    return result
