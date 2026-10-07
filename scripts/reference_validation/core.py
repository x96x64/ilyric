"""Small deterministic numerical primitives for the internal reference gate.

Coordinates and timestamps remain in the source capture space. No private media,
text, device font identity, or native animation implementation is encoded here.
"""
from fractions import Fraction
import math


def timing(pts, numerator=1, denominator=600):
    if not pts or any(b <= a for a, b in zip(pts, pts[1:])):
        raise ValueError('Presentation timestamps must be nonempty and increasing')
    intervals = [Fraction((b-a)*numerator, denominator) for a,b in zip(pts,pts[1:])]
    counts = {}
    for value in intervals:
        key = str(value)
        counts[key] = counts.get(key, 0)+1
    return {'decoded_frames': len(pts), 'first_pts': pts[0], 'last_pts': pts[-1],
            'time_base': str(Fraction(numerator,denominator)), 'interval_counts': counts}


def transform(native, output, mode):
    if min(*native,*output) <= 0 or mode not in ('contain','cover'):
        raise ValueError('Positive dimensions and an explicit uniform transform are required')
    scale = (min if mode == 'contain' else max)(output[0]/native[0], output[1]/native[1])
    return {'scale': scale, 'x': (output[0]-native[0]*scale)/2,
            'y': (output[1]-native[1]*scale)/2}


def response(time, onset, duration, model):
    if duration <= 0:
        raise ValueError('Positive response duration is required')
    u=max(0.0,(time-onset)/duration)
    if model == 'hermite':
        u=min(1.0,u)
        return u*u*(3-2*u)
    if model == 'critical':
        return 1-(1+u)*math.exp(-u)
    raise ValueError('Unknown model')


def evaluate(parameters, numerator, denominator):
    """Random-access fitted reconstruction, never Apple's implementation."""
    t=float(Fraction(numerator,denominator))
    return parameters['offset']+parameters['amplitude']*response(
        t,parameters['onset'],parameters['duration'],parameters['model'])


def fit(samples, model, onsets, durations):
    """Deterministic grid search; linear least squares for offset and amplitude.

    The grid bounds are part of the fitting protocol, not implicit motion priors.
    The caller must preserve observations and separately evaluate held-out data.
    """
    if len(samples)<4 or any(not math.isfinite(v) for pair in samples for v in pair):
        raise ValueError('At least four finite observations are required')
    best=None
    for onset in onsets:
        for duration in durations:
            xs=[response(t,onset,duration,model) for t,_ in samples]
            ys=[y for _,y in samples]
            mx=sum(xs)/len(xs); my=sum(ys)/len(ys)
            den=sum((x-mx)**2 for x in xs)
            if den<1e-12: continue
            amplitude=sum((x-mx)*(y-my) for x,y in zip(xs,ys))/den
            offset=my-amplitude*mx
            residual=[y-offset-amplitude*x for x,y in zip(xs,ys)]
            rmse=math.sqrt(sum(r*r for r in residual)/len(residual))
            if best is None or rmse<best['rmse']:
                best=dict(model=model,onset=onset,duration=duration,offset=offset,
                          amplitude=amplitude,rmse=rmse,max_error=max(map(abs,residual)))
    if best is None: raise ValueError('Degenerate fit')
    return best


def errors(samples, parameters):
    residual=[y-evaluate(parameters, Fraction(t).numerator, Fraction(t).denominator) for t,y in samples]
    if not residual: raise ValueError('No validation observations')
    return {'rmse':math.sqrt(sum(x*x for x in residual)/len(residual)),
            'max_error':max(map(abs,residual)), 'count':len(residual)}


def registered_mask(reference, candidate, max_shift=3):
    """Binary-mask IoU after bounded integer translation, with registration reported.

    Sets of (x,y) foreground pixels must describe the same localized text region.
    This metric does not infer baseline, font identity, scale, or opacity.
    """
    if not reference or not candidate: raise ValueError('Empty text mask')
    best=None
    for dy in range(-max_shift,max_shift+1):
        for dx in range(-max_shift,max_shift+1):
            shifted={(x+dx,y+dy) for x,y in candidate}
            overlap=len(reference & shifted)
            iou=overlap/(len(reference)+len(candidate)-overlap)
            if best is None or iou>best['iou']:
                best={'dx':dx,'dy':dy,'iou':iou}
    return best
