"""Private native-space appearance fitting with frozen shaped support.

Optional NumPy/Pillow dependencies are loaded only after input availability checks.
The column sums retain the exact pixel least-squares objective on shared interiors.
"""
import json
import math
import itertools
import subprocess
import numpy as np
from PIL import Image
from glyph_outline import normalize
from analyze import REPO, save

def dataset(root,out,inv,prior,base,train,sid,threshold=.5,border=8,phase_shift=0,registration=0):
    params=base['comparisons'][train]['vertical']['parameters'];oldpts=prior['phase_pts'][sid][0]
    # The earliest coverage contains the common upcoming displacement for every range.
    dest=root/f'analysis/lyrics-slice/current/{train}-{sid}-vertical-{oldpts}'
    if not dest.exists():
        # Training geometry uses the same frozen training fit, rendered on its own annotations.
        from slice_validation import events_for
        request=json.loads((root/f'analysis/lyrics-slice/current/{train}-vertical.json').read_text());request['events']=events_for(request['text'],prior['crossings'][sid]);path=out/f'{train}-{sid}.json';path.write_text(json.dumps(request))
        dest=out/f'{train}-{sid}-initial';subprocess.run(['.build/release/LyricsSliceProbe',str(path),str(oldpts),'600',str(dest)],check=True)
    cover=np.asarray(Image.open(dest/'coverage.png'))[:,:,3]/255
    state=json.loads((dest/'state.json').read_text());rows=[];arrays=[]
    for index,ob in enumerate(inv['observations'][sid]):
        pts=ob['pts']
        if not min(prior['phase_pts'][sid])<=pts<=max(prior['phase_pts'][sid]):continue
        gray=np.asarray(Image.open(root/'analysis/s09-state/current'/sid/'frames'/f'{index+1:05d}.png')).astype(float).mean(2)
        for line,count in enumerate([8,7]):
            advance=state['lines'][line]['width']/count
            for cell in range(count):
                x=96+cell*95;y=95+line*123;p=gray[y:y+115,x:x+95];entry=prior['crossings'][sid][str((line,cell))]
                a,b,v=entry['180'],entry['210'],entry['195'];q=-100 if not a or not b else (pts+phase_shift-(a['lower_pts']+b['upper_pts'])/2)/(b['upper_pts']-a['lower_pts'])
                age=0 if not v else max(0,(pts-v['upper_pts'])/600);u=age/params['tau'];displacement=params['amplitude']*(1+u)*math.exp(-u)
                dy=round(params['originY']+line*params['lineAdvance']+displacement)-round(params['originY']+line*params['lineAdvance']+params['amplitude'])+registration
                mask=np.roll(cover[y+600:y+715,x:x+95],dy,axis=0)
                native=normalize(p,border=border)>threshold;core=native.copy()
                for yy,xx in [(1,0),(-1,0),(0,1),(0,-1)]:core &= np.roll(native,(yy,xx),(0,1))
                shared=core&(mask>.5);bg=np.median(np.concatenate([p[:border],p[-border:]]),axis=0)
                k=(255-bg)*mask;target=p-bg
                arrays.append(np.stack([(shared*k*k).sum(0),(shared*k*target).sum(0),(shared*target*target).sum(0),shared.sum(0)]))
                rows.append([pts,line,cell,q,advance,x-params['originX']-cell*advance])
    return np.array(rows),np.array(arrays)

def profile(rows,model,scale=1,offset=0,softness=1):
    q=(rows[:,3:4]-offset)/scale;pos=(rows[:,5:6]+np.arange(95)+.5)/rows[:,4:5]
    if model=='baseline':return np.clip((q+.5-pos)*rows[:,4:5]+.5,0,1)
    z=.5+q if model=='temporal' else .5+(q+.5-pos)/softness
    v=np.clip(z,0,1);return np.broadcast_to(v*v*(3-2*v),(len(rows),95))

def endpoints(arr,g):
    a,b,c,n=arr.transpose(1,0,2);h=1-g
    mat=np.array([[(a*h*h).sum(),(a*h*g).sum()],[(a*h*g).sum(),(a*g*g).sum()]])
    rhs=np.array([(b*h).sum(),(b*g).sum()]);d,bright=np.linalg.solve(mat,rhs)
    return float(np.clip(d,.3,.6)),float(np.clip(bright,.9,1))

def score(arr,g,d,bright):
    a,b,c,n=arr.transpose(1,0,2);opacity=d+(bright-d)*g
    err=np.maximum(0,a*opacity*opacity-2*b*opacity+c)
    def rms(select):return float(np.sqrt(err[select].sum()/n[select].sum())) if n[select].sum() else None
    observed=(np.divide(b,a,out=np.zeros_like(b),where=a>0)-.44)/.54
    return dict(rms=rms(np.ones_like(g,dtype=bool)),boundary=rms((observed>.1)&(observed<.9)),upcoming=rms(observed<=.1),completed=rms(observed>=.9))


def select(rows,arrays,model,dim,grid=None):
    selected=(np.arange(len(rows))//15)%2==0
    if grid is None:
        grid=[(1,0,1)] if model=='baseline' else itertools.product(
            [1,1.5,2,3,4,6],[-.5,-.25,0,.25,.5,.75,1],
            [.25,.5,1,1.5,2,3] if model=='spatial' else [1])
    best=None
    for scale,offset,softness in grid:
        g=profile(rows[selected],model,scale,offset,softness)
        d,bright=(dim,1) if model=='baseline' else endpoints(arrays[selected],g)
        error=score(arrays[selected],g,d,bright)['rms']
        candidate=(error,scale,offset,softness,d,bright)
        if best is None or candidate<best:best=candidate
    error,scale,offset,softness,d,bright=best
    return dict(scale=scale,offset=offset,softness=softness,dim=d,bright=bright,training=error,
        phase_holdout=evaluate(rows[~selected],arrays[~selected],model,dict(scale=scale,offset=offset,softness=softness,dim=d,bright=bright)))


def evaluate(rows,arrays,model,fit):
    return score(arrays,profile(rows,model,fit['scale'],fit['offset'],fit['softness']),fit['dim'],fit['bright'])


def run(root,out,inv,prior,base):
    results={};sensitivity={};measurements={}
    from appearance_measure import summarize
    for train,test in [('V09','V10'),('V10','V09')]:
        r,a=dataset(root,out,inv,prior,base,train,train)
        rr,aa=dataset(root,out,inv,prior,base,train,test)
        measurements[train]=summarize(r,a)
        results[train]={}
        for model in ['baseline','spatial','temporal']:
            fit=select(r,a,model,base['dim_opacity_training'][train])
            fit['held_out']=evaluate(rr,aa,model,fit)
            results[train][model]=fit
        results[train]['sampling']=dict(training_frames=len(r)//15,held_out_frames=len(rr)//15,
            training_pts=[int(r[0,0]),int(r[-1,0])],held_out_pts=[int(rr[0,0]),int(rr[-1,0])])
        sensitivity[train]={}
        for label,options in [('threshold-35',dict(threshold=.35)),('threshold-65',dict(threshold=.65)),
            ('border-4',dict(border=4)),('border-12',dict(border=12)),
            ('phase-minus-10',dict(phase_shift=-10)),('phase-plus-10',dict(phase_shift=10)),
            ('registration-minus-1',dict(registration=-1)),('registration-plus-1',dict(registration=1))]:
            vr,va=dataset(root,out,inv,prior,base,train,test,**options)
            sensitivity[train][label]={m:evaluate(vr,va,m,results[train][m]) for m in ['baseline','spatial','temporal']}
        # Local parameter sensitivity on training data only; opposite recording stays held out.
        fit=select(r,a,'spatial',0,itertools.product([2.5,3,3.5],[-.125,0,.125],[.75,1,1.25]))
        fit['held_out']=evaluate(rr,aa,'spatial',fit)
        sensitivity[train]['local_grid']=fit
        print(json.dumps(dict(training=train,models=results[train])),flush=True)
    value=dict(status='measured',evidence_status='Fitted appearance reconstructions and measured conditional held-out errors',
        color_interpretation='Full-range Rec.709 converted to sRGB; nonlinear channel-average diagnostic code values',
        geometry='Frozen v5 parameters and v6 shaped support; no local registration',
        region_definition='Column-aggregated shared-interior contrast ratio, endpoints 0.44/0.98; boundary fraction 0.1 to 0.9',
        comparisons=results,sensitivity=sensitivity,measurements=measurements)
    save(out/'results.json',value)
    return value
