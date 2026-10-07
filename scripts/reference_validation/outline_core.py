"""Deterministic diagnostic fits; no native font or animation semantics are assumed."""
import math
from statistics import mean


def crossing(samples, level):
    """First upward crossing, bracketed by original PTS; absent support stays absent."""
    if not samples or any(b[0] <= a[0] for a,b in zip(samples,samples[1:])):
        raise ValueError('Strictly increasing nonempty observations required')
    if any(not math.isfinite(v) for _,v in samples):
        raise ValueError('Finite observations required')
    for before,after in zip(samples,samples[1:]):
        if before[1] < level <= after[1]:
            return dict(lower_pts=before[0],upper_pts=after[0])
    return None


def treatment(age, tau):
    """Bounded analytic diagnostic response to an explicitly supplied event age."""
    if not math.isfinite(age) or not math.isfinite(tau) or tau <= 0:
        raise ValueError('Finite age and positive time constant required')
    t=max(0,age)/tau
    return (1+t)*math.exp(-t)


def solve(matrix, vector):
    """Small normal-equation solver with an explicit singular-design failure."""
    n=len(vector);a=[list(row)+[v] for row,v in zip(matrix,vector)]
    for i in range(n):
        pivot=max(range(i,n),key=lambda j:abs(a[j][i]));a[i],a[pivot]=a[pivot],a[i]
        if abs(a[i][i])<1e-10:raise ValueError('Unidentifiable diagnostic fit')
        scale=a[i][i];a[i]=[v/scale for v in a[i]]
        for j in range(n):
            if i!=j:
                factor=a[j][i];a[j]=[v-factor*w for v,w in zip(a[j],a[i])]
    return [row[-1] for row in a]


def features(row, model, tau=None):
    values=[1,row['line']]
    if model=='appearance':values.append(max(0,min(1,(252-row['level'])/107)))
    elif model=='vertical':values.append(1 if row['age'] is None else treatment(row['age'],tau))
    elif model!='fixed':raise ValueError('Unknown diagnostic model')
    return values


def predict(row, fit):
    return sum(a*b for a,b in zip(features(row,fit['model'],fit['tau']),fit['coefficients']))


def residuals(rows, fit):
    if not rows:raise ValueError('Nonempty observations required')
    errors=[predict(r,fit)-r['dy'] for r in rows]
    return dict(rmse=math.sqrt(mean([v*v for v in errors])),maximum=max(map(abs,errors)),
                bias=mean(errors),count=len(rows))


def fit(rows, model, taus=tuple(.08+i*.01 for i in range(33))):
    """Shared origin, line-advance correction, and optional shared treatment.

    Fit targets are independently registered outline shifts, used diagnostically.
    Final mask scoring must use the shared prediction, never those local shifts.
    The appearance model is a brightness-linked geometric proxy, not proof that
    photometric changes move an outline. The fixed model is the geometry-null case.
    """
    if not rows:raise ValueError('Nonempty observations required')
    best=None
    for tau in (taus if model=='vertical' else [None]):
        x=[features(r,model,tau) for r in rows];n=len(x[0]);y=[r['dy'] for r in rows]
        coefficients=solve([[sum(v[i]*v[j] for v in x) for j in range(n)] for i in range(n)],
                           [sum(v[i]*w for v,w in zip(x,y)) for i in range(n)])
        if model=='vertical' and not 0<=coefficients[2]<=10:continue
        result=dict(model=model,tau=tau,coefficients=coefficients)
        result['training']=residuals(rows,result)
        if best is None or result['training']['rmse']<best['training']['rmse']:best=result
    if best is None:raise ValueError('No bounded model fits the observations')
    return best


def vertical_edges(reference, observed, limit=10):
    """Paired vertical contour crossings; reject changed or ambiguous support.

    Inputs contain matching columns of binary pixels. Counts and coverage expose
    selection bias: an absent result never means zero displacement.
    """
    if len(reference)!=len(observed) or not reference or limit<=0:
        raise ValueError('Matching columns and a positive bound required')
    differences=[];eligible=0;total=0
    for a,b in zip(reference,observed):
        if len(a)!=len(b):raise ValueError('Matching column heights required')
        edges=lambda c:[i for i in range(1,len(c)) if bool(c[i])!=bool(c[i-1])]
        ea,eb=edges(a),edges(b);total+=max(len(ea),len(eb))
        if not ea or len(ea)!=len(eb):continue
        delta=[y-x for x,y in zip(ea,eb)]
        if any(abs(v)>limit for v in delta):continue
        eligible+=1;differences.extend(delta)
    if not differences:return dict(status='unavailable',paired_edges=0,total_edges=total)
    return dict(status='measured',paired_edges=len(differences),total_edges=total,
                column_coverage=eligible/len(reference),mean_displacement=mean(differences),
                rms_displacement=math.sqrt(mean([v*v for v in differences])))
