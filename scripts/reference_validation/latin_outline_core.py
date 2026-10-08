"""Bounded outline diagnostics; local registration never becomes renderer state."""
import math
from statistics import mean,median


def decompose(rows):
    """One translation per observed frame; retain every local residual separately."""
    if not rows or any(not math.isfinite(r['shift']) for r in rows):raise ValueError('Finite supported observations required')
    center=median(r['shift'] for r in rows)
    residual=[r['shift']-center for r in rows]
    return dict(translation=center,rmse=math.sqrt(mean(x*x for x in residual)),maximum=max(map(abs,residual)),
                line_bias={str(line):mean(r['shift']-center for r in rows if r['line']==line) for line in sorted({r['line'] for r in rows})})


def relative_fit(rows):
    """Single bounded line-distance coefficient against explicit measured progress.

    Origin remains shared. This is a reconstruction diagnostic, not a native rule.
    """
    x=[(r['line']-1)*(1-r['progress']) for r in rows];y=[r['residual'] for r in rows]
    den=sum(v*v for v in x)
    if den<=1e-12:raise ValueError('Relative treatment is unidentifiable')
    return max(-10,min(10,sum(a*b for a,b in zip(x,y))/den))


def residual_score(rows,coefficient=0):
    e=[r['residual']-coefficient*(r['line']-1)*(1-r['progress']) for r in rows]
    if not e:raise ValueError('No supported residuals')
    return dict(rmse=math.sqrt(mean(v*v for v in e)),maximum=max(map(abs,e)),count=len(e))


def register_profile(template,search,limit):
    """Normalized row-profile correlation; boundaries and ambiguity are explicit."""
    import numpy as np
    a=np.asarray(template,float);b=np.asarray(search,float)
    if limit<1 or len(b)!=len(a)+2*limit or not np.isfinite(a).all() or not np.isfinite(b).all():raise ValueError('Invalid registration window')
    if np.linalg.norm(a)<1e-8:return dict(status='unavailable',reason='empty template')
    scores=[]
    for offset in range(2*limit+1):
        v=b[offset:offset+len(a)];den=np.linalg.norm(a)*np.linalg.norm(v)
        scores.append(float(a@v/den) if den>1e-8 else -1)
    best=max(range(len(scores)),key=lambda i:(scores[i],-abs(i-limit),-i))
    if scores[best]<.65 or best in [0,len(scores)-1]:return dict(status='unavailable',reason='unsupported or boundary optimum',score=scores[best])
    return dict(status='measured',shift=best-limit,score=scores[best])
