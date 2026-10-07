"""Deterministic observation summaries; no native state or animation is assumed."""
from fractions import Fraction
import math
from statistics import mean, pstdev


def summarize(values):
    if not values or any(not math.isfinite(x) for x in values):
        raise ValueError('Finite nonempty observations are required')
    return dict(count=len(values), mean=mean(values), sd=pstdev(values),
                minimum=min(values), maximum=max(values), span=max(values)-min(values))


def stable_intervals(samples, time_base, tolerances, minimum_seconds=.5, maximum_gap_seconds=.04):
    """Greedy bounded-span runs of already identified, eligible observations.

    A run bounds every supplied geometry coordinate, not merely frame-to-frame
    drift. It establishes geometric stability only; activation and readability
    must be established separately. Endpoints are observed PTS, not extrapolated.
    """
    if not tolerances or any(t < 0 or not math.isfinite(t) for t in tolerances):
        raise ValueError('Finite nonnegative coordinate tolerances are required')
    base=Fraction(time_base)
    if base <= 0 or minimum_seconds <= 0 or maximum_gap_seconds <= 0:
        raise ValueError('Positive time parameters are required')
    if any(b['pts'] <= a['pts'] for a,b in zip(samples,samples[1:])):
        raise ValueError('Observations must have increasing PTS')
    result=[]; run=[]
    def finish():
        if run and float((run[-1]['pts']-run[0]['pts'])*base) >= minimum_seconds:
            result.append(dict(first_pts=run[0]['pts'],last_pts=run[-1]['pts'],count=len(run),
                               duration_seconds=float((run[-1]['pts']-run[0]['pts'])*base)))
    for sample in samples:
        vector=sample.get('geometry')
        if vector is None:
            finish();run=[];continue
        if len(vector)!=len(tolerances) or any(not math.isfinite(x) for x in vector):
            raise ValueError('Geometry dimensions must match finite tolerances')
        combined=run+[sample]
        exceeds=any(max(s['geometry'][i] for s in combined)-min(s['geometry'][i] for s in combined)>t
                    for i,t in enumerate(tolerances))
        gap=run and float((sample['pts']-run[-1]['pts'])*base)>maximum_gap_seconds
        if exceeds or gap:
            finish();run=[]
        run.append(sample)
    finish()
    return result


def affine_landmarks(reference, observed):
    """Fit spacing and translation of corresponding interior landmarks.

    This diagnoses relative geometry, not native font identity or an animation
    implementation. Landmark extraction and its sensitivity remain explicit.
    """
    if len(reference)!=len(observed) or len(reference)<3:
        raise ValueError('At least three paired landmarks are required')
    if any(not math.isfinite(x) for x in reference+observed):
        raise ValueError('Finite landmarks are required')
    x=mean(reference);y=mean(observed);den=sum((v-x)**2 for v in reference)
    if den<=0:raise ValueError('Degenerate landmarks')
    scale=sum((a-x)*(b-y) for a,b in zip(reference,observed))/den
    translation=y-scale*x
    residuals=[b-translation-scale*a for a,b in zip(reference,observed)]
    translation_only=[b-a-mean([d-c for c,d in zip(reference,observed)]) for a,b in zip(reference,observed)]
    rms=lambda values:math.sqrt(mean([v*v for v in values]))
    return dict(scale=scale,translation=translation,rmse=rms(residuals),
                translation_only_rmse=rms(translation_only),residuals=residuals)


def spacing_holdout(pairs):
    """Leave one recording out; only translation is registered on its landmarks."""
    if len(pairs)<2:raise ValueError('At least two recordings are required')
    scales={key:affine_landmarks(value['reference'],value['observed'])['scale'] for key,value in pairs.items()}
    result={}
    for key,pair in sorted(pairs.items()):
        others=sorted(k for k in pairs if k!=key)
        scale=mean([scales[k] for k in others])
        offset=mean([y-scale*x for x,y in zip(pair['reference'],pair['observed'])])
        residual=[y-offset-scale*x for x,y in zip(pair['reference'],pair['observed'])]
        result[key]=dict(training_recordings=others,scale=scale,fitted_translation=offset,
            rmse=math.sqrt(mean([x*x for x in residual])),maximum_error=max(map(abs,residual)))
    return result
