"""Case-balanced shared paragraph-origin fitting from diagnostic baseline proxies."""
import math


def fit_origin(cases):
    if not cases or any(not lines for lines in cases.values()):raise ValueError('Nonempty cases required')
    rows=[(r,1/len(lines)) for lines in cases.values() for r in lines]
    if any(not math.isfinite(v) for r,_ in rows for v in [r['line'],r['baseline_proxy'],r['origin_translation'][0]]):raise ValueError('Finite proxies required')
    w=sum(w for _,w in rows);x=sum(r['line']*v for r,v in rows);xx=sum(r['line']**2*v for r,v in rows)
    y=sum(r['baseline_proxy']*v for r,v in rows);xy=sum(r['line']*r['baseline_proxy']*v for r,v in rows)
    denominator=w*xx-x*x
    if denominator<=0:raise ValueError('Multiple line indices required')
    advance=(w*xy-x*y)/denominator
    return dict(origin_x=sum(r['origin_translation'][0]*v for r,v in rows)/w,first_baseline=(y-advance*x)/w,line_advance=advance)


def errors(lines,fit):
    values=[fit['first_baseline']+r['line']*fit['line_advance']-r['baseline_proxy'] for r in lines]
    return dict(baseline_proxy_errors=values,rmse=math.sqrt(sum(v*v for v in values)/len(values)),maximum=max(map(abs,values)))
