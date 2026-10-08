"""Analytic motion diagnostics; fitted capture anchors are not native baselines."""
import math
from core import response


def shape(t,onset,scale,model):
    if model in ('critical','hermite'):return response(t,onset,scale,model)
    if model!='quintic' or scale<=0:raise ValueError('Invalid motion candidate')
    u=min(1,max(0,(t-onset)/scale))
    return u*u*u*(10+u*(-15+6*u))


def crossing(samples):
    """Observed half-displacement phase; no inferred audio or input-event time."""
    if len(samples)<8:raise ValueError('Insufficient observations')
    early=[y for t,y in samples if t<samples[0][0]+.5]
    late=[y for t,y in samples if t>samples[-1][0]-.5]
    middle=(sum(early)/len(early)+sum(late)/len(late))/2
    for (a,x),(b,y) in zip(samples,samples[1:]):
        if x>=middle>y:return a+(middle-x)*(b-a)/(y-x)
    raise ValueError('No descending half crossing')


def score(samples,p,shift=0):
    residual=[y-p['offset']-p['amplitude']*shape(t,p['onset']+shift,p['scale'],p['model']) for t,y in samples]
    return dict(rmse=math.sqrt(sum(x*x for x in residual)/len(residual)),maximum=max(map(abs,residual)))


def fit_grid(samples,model,onsets,scales):
    import numpy as np
    t=np.array([x for x,y in samples]);y=np.array([y for x,y in samples]);best=None
    for scale in scales:
        for onset in onsets:
            x=np.array([shape(v,onset,scale,model) for v in t]);den=((x-x.mean())**2).sum()
            if den<1e-12:continue
            amplitude=float(((x-x.mean())*(y-y.mean())).sum()/den)
            p=dict(model=model,onset=float(onset),scale=float(scale),offset=float(y.mean()-amplitude*x.mean()),amplitude=amplitude)
            error=score(samples,p)
            if best is None or error['rmse']<best['training']['rmse']:best=dict(**p,training=error)
    if best is None:raise ValueError('Degenerate motion fit')
    return best
