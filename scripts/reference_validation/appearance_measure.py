"""Appearance proxies measured on common-origin shared glyph support."""
import numpy as np
from outline_core import crossing


def summarize(rows,arrays):
    a,b,_,n=arrays.transpose(1,0,2)
    # This contrast ratio is not measured alpha or physical luminance.
    proxy=(np.divide(b,a,out=np.zeros_like(b),where=a>0)-.44)/.54
    widths=[];durations=[];missing=0
    for i,row in enumerate(rows):
        usable=n[i]>=5
        locations=[]
        for level in [.9,.1]:
            indices=np.flatnonzero(usable);crosses=[]
            for left,right in zip(indices,indices[1:]):
                if right-left<=4 and proxy[i,left]>=level>proxy[i,right]:
                    crosses.append((int(left),int(right)))
            locations.append(crosses[0] if len(crosses)==1 else None)
        if all(locations) and locations[1][0]>locations[0][1]:
            widths.append(dict(pts=int(row[0]),line=int(row[1]),cell=int(row[2]),
                lower=locations[1][0]-locations[0][1],upper=locations[1][1]-locations[0][0]))
    for line,count in enumerate([8,7]):
        for cell in range(count):
            selected=(rows[:,1]==line)&(rows[:,2]==cell)
            if not selected.any():
                missing+=1;continue
            fraction=(b[selected].sum(1)/a[selected].sum(1)-.44)/.54
            series=list(zip(rows[selected,0].astype(int).tolist(),fraction.tolist()))
            lo,hi=crossing(series,.1),crossing(series,.9)
            if lo and hi:
                durations.append(dict(line=line,cell=cell,lower_seconds=(hi['lower_pts']-lo['upper_pts'])/600,
                    upper_seconds=(hi['upper_pts']-lo['lower_pts'])/600))
            else:missing+=1
    def stats(values):
        return dict(count=len(values),minimum=float(min(values)),median=float(np.median(values)),maximum=float(max(values))) if values else dict(count=0)
    return dict(evidence_status='Measured shared-support contrast proxies with bracket uncertainty',
        width_midpoints=stats([(r['lower']+r['upper'])/2 for r in widths]),
        duration_midpoints=stats([(r['lower_seconds']+r['upper_seconds'])/2 for r in durations]),
        unavailable_durations=missing,spatial_brackets=widths,temporal_brackets=durations)
