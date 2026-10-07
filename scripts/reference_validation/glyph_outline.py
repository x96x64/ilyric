"""Private common-origin outline experiment; only curated numbers may be public.

The protocol uses inspected S09 windows, never OCR. Whole-paragraph probe output
is partitioned spatially for diagnostics only; no text unit is reshaped. All
held-out masks use a shared origin and analytic treatment, not local registration.
"""
import json
from pathlib import Path
import subprocess
from analyze import REPO,private_root,safe_path,save,probe
from outline_core import crossing,fit,predict,residuals,vertical_edges
from state_typography import digest

TARGETS=[4803,4922,5200,5500,5790,6070,6240,6420,6600,6779]
VARIANTS={'baseline':(.5,'column',8,0), 'threshold-35':(.35,'column',8,0),
          'threshold-65':(.65,'column',8,0),'global-support':(.5,'global',8,0),
          'linear-light':(.5,'linear',8,0),'blur-1':(.5,'column',8,1),
          'border-4':(.5,'column',4,0),'border-12':(.5,'column',12,0)}


def normalize(p,method='column',border=8):
    import numpy as np
    if method=='linear':p=np.where(p<=.04045*255,p/255/12.92,((p/255+.055)/1.055)**2)*255
    background=np.median(np.concatenate([p[:border],p[-border:]]),axis=0)
    value=np.maximum(p-background,0)
    peak=np.percentile(value,95,axis=0 if method!='global' else None)
    return np.clip(value/np.maximum(peak,25 if method!='linear' else 8),0,1)


def interior_level(p):
    import numpy as np
    mask=normalize(p)>.5;inside=mask.copy()
    for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:inside &= np.roll(mask,(dy,dx),(0,1))
    if inside.sum()<20:raise ValueError('Incomplete glyph support')
    return float(p[inside].mean())


def counts(a,b):
    import numpy as np
    return [int(np.count_nonzero(a&b)),int(np.count_nonzero(a|b))]


def run(root,out,config,prior):
    import numpy as np
    from PIL import Image,ImageFilter
    from calibrate import render
    from analyze import foreground,ink_bounds
    from paragraph_core import common_registration
    cases=json.loads(safe_path(root,root/'typography-cases.json').read_text())
    metrics,_,_=render(root,out,'S09',cases['S09'],'base',dict(size=103.25,lineAdvance=128))
    alpha=np.asarray(Image.open(out/'probes/S09/base/text.png'))[:,:,3]/255
    padded=np.pad(alpha,20)
    sources={};observations={};reproduction={};crossings={};rows={key:[] for key in VARIANTS}
    curves={};native_pairs={};patch_cache={};source_hashes={};controls=[];window_checks=[]
    for sid in ['V09','V10']:
        record=config['recordings'][sid];source=safe_path(root,root/'recordings'/record['file'])
        expected=prior['metadata'][sid]['sha256'];source_hashes[sid]=digest(source)
        if source_hashes[sid]!=expected:raise ValueError('Original source hash mismatch')
        frames=probe(source,'-select_streams','v:0','-show_frames','-show_entries','frame=pts')['frames']
        selected=[f for f in frames if 4750<=f['pts']<=6820]
        sub=out/sid/'frames';sub.mkdir(parents=True,exist_ok=True)
        vf='select=between(pts\\,4750\\,6820),colorspace=all=bt709:trc=srgb:range=pc,crop=1180:750:0:600'
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vf',vf,'-fps_mode','passthrough',
                        '-enc_time_base','1:600',str(sub/'%05d.png')],check=True)
        paths=sorted(sub.glob('*.png'))
        if len(paths)!=len(selected):raise ValueError('Frame/PTS mismatch')
        by_pts={f['pts']:p for f,p in zip(selected,paths)}
        # Exact reproduction also verifies new source extraction against prior analysis.
        prior_index={r['pts']:i for i,r in enumerate(prior['observations'][sid])}
        for pts in [record['measurement']['phase_pts']['sharp_dim'],6240,6779]:
            old=root/'analysis/s09-state/current'/sid/'frames'/f'{prior_index[pts]+1:05d}.png'
            if not np.array_equal(np.asarray(Image.open(old)),np.asarray(Image.open(by_pts[pts]))):
                raise ValueError('Color-managed extraction differs from the historical baseline')
            original=prior['observations'][sid][prior_index[pts]]['measurements']['25-100']
            native=[v['bounds'] for v in original];mask=foreground(Image.open(by_pts[pts]),25,100)
            bounds=ink_bounds(alpha>.5);nx,ny,_,_=native[0];cx,cy,_,_=bounds[0];refs=[];cands=[]
            for n,c in zip(native,bounds):
                x,y,r,b=n;yy,xx=np.nonzero(mask[y-6:b+6,x-6:r+6]);refs.append(set(zip((xx+x-6-nx).tolist(),(yy+y-6-ny).tolist())))
                x,y,r,b=c;yy,xx=np.nonzero((alpha>.5)[max(0,y-6):b+6,max(0,x-6):r+6]);cands.append(set(zip((xx+max(0,x-6)-cx).tolist(),(yy+max(0,y-6)-cy).tolist())))
            reproduced=common_registration(refs,cands,5)
            label=next(k for k,v in record['measurement']['phase_pts'].items() if v==pts)
            previous=prior['phases']['recordings'][sid][label]['measurements']['25-100']['common_origin']
            if reproduced!=previous:raise ValueError('Prior common-origin result did not reproduce')
            reproduction.setdefault(sid,{})[label]=reproduced
        chosen=sorted({min(by_pts,key=lambda p:abs(p-t)) for t in TARGETS})
        observations[sid]=chosen;samples={(line,cell):[] for line,count in enumerate([8,7]) for cell in range(count)}
        for pts,path in by_pts.items():
            g=np.asarray(Image.open(path)).astype(float).mean(2)
            for (line,cell),series in samples.items():
                x=96+cell*95;y=95+line*123;p=g[y:y+115,x:x+95]
                series.append((pts,interior_level(p)))
                if pts in chosen:patch_cache[(sid,pts,line,cell)]=p
        crossings[sid]={}
        for key,series in samples.items():
            crossings[sid][str(key)]={str(level):crossing(series,level) for level in [180,195,210]}
        for pts in chosen:
            for line,count in enumerate([8,7]):
                for cell in range(count):
                    p=patch_cache[(sid,pts,line,cell)];x=96+cell*95;y=95+line*123
                    bracket=crossings[sid][str((line,cell))]['195']
                    # No crossing means upcoming throughout this interval, not an invented event.
                    age=(pts-bracket['upper_pts'])/600 if bracket else None
                    for name,(threshold,method,border,blur) in VARIANTS.items():
                        pp=np.asarray(Image.fromarray(p.astype('uint8')).filter(ImageFilter.GaussianBlur(blur))) if blur else p
                        norm=normalize(pp,method,border);mask=norm>threshold
                        scores={};best=None
                        for dy in range(-8,19):
                            ty=y-86+5*line-dy;tx=x-98;t=padded[ty+20:ty+135,tx+20:tx+115]>.5
                            intersection,union=counts(mask,t);score=intersection/union;scores[dy]=[intersection,union]
                            if best is None or score>best[0]:best=(score,dy)
                        if name=='baseline':
                            window_best={f'-8:{upper}':max((v[0]/v[1],-abs(k),-k,k) for k,v in scores.items() if -8<=k<=upper)[3] for upper in [8,12,18]}
                            window_checks.append(dict(recording=sid,pts=pts,line=line,cell=cell,shifts=window_best))
                            # A fixed-outline control with the observed column-wise contrast.
                            ty=y-86+5*line;tx=x-98;fixed=padded[ty+20:ty+135,tx+20:tx+115]
                            bg=np.median(np.concatenate([p[:8],p[-8:]]),axis=0)
                            gain=np.maximum(np.percentile(p-bg,95,axis=0),0)
                            for radius in [0,1]:
                                control=bg+fixed*gain
                                if radius:control=np.asarray(Image.fromarray(control.astype('uint8')).filter(ImageFilter.GaussianBlur(radius)))
                                cm=normalize(control)>.5;options=[]
                                for shift in range(-3,4):
                                    template=padded[ty+20-shift:ty+135-shift,tx+20:tx+115]>.5
                                    inter,union=counts(cm,template);options.append((inter/union,shift))
                                optimum=max(options)
                                controls.append(dict(recording=sid,pts=pts,line=line,cell=cell,blur=radius,
                                    dy=optimum[1],iou=optimum[0],centroid_shift=float(np.nonzero(cm)[0].mean()-np.nonzero(fixed>.5)[0].mean())))
                        row=dict(recording=sid,pts=pts,line=line,cell=cell,level=interior_level(p),age=age,dy=best[1],local_iou=best[0])
                        rows[name].append(row);curves[(name,sid,pts,line,cell)]=scores
                        if name=='baseline':native_pairs[(sid,pts,line,cell)]=mask
        sources[sid]=dict(source_hash_verified=True,decoded_frames=len(frames),analyzed_frames=len(selected),
                          time_base='1/600',first_pts=selected[0]['pts'],last_pts=selected[-1]['pts'])
    results={}
    for name,data in rows.items():
        results[name]={}
        for train in ['V09','V10']:
            training=[r for r in data if r['recording']==train];held=[r for r in data if r['recording']!=train]
            results[name][train]={}
            for model in ['fixed','appearance','vertical']:
                fitted=fit(training,model);fitted['held_out']=residuals(held,fitted)
                phase={};line_scores={};glyph_scores=[]
                for r in held:
                    shift=round(predict(r,fitted))
                    if shift not in curves[(name,r['recording'],r['pts'],r['line'],r['cell'])]:raise ValueError('Prediction outside registered support')
                    pair=curves[(name,r['recording'],r['pts'],r['line'],r['cell'])][shift]
                    phase.setdefault(str(r['pts']),[]).append(pair)
                    line_scores.setdefault(f"{r['pts']}-{r['line']}",[]).append(pair)
                    glyph_scores.append(pair[0]/pair[1])
                fitted['held_out_common_origin_iou']={pts:sum(p[0] for p in pairs)/sum(p[1] for p in pairs) for pts,pairs in phase.items()}
                fitted['held_out_line_iou']={key:sum(p[0] for p in pairs)/sum(p[1] for p in pairs) for key,pairs in line_scores.items()}
                fitted['held_out_glyph_iou']=dict(minimum=min(glyph_scores),mean=float(np.mean(glyph_scores)))
                results[name][train][model]=fitted
    # Brightness-crossing sensitivity changes measured input events, not fitted glyph offsets.
    timing={}
    for level in [180,210]:
        adjusted=[]
        for r in rows['baseline']:
            b=crossings[r['recording']][str((r['line'],r['cell']))][str(level)]
            adjusted.append(dict(r,age=(r['pts']-b['upper_pts'])/600 if b else None))
        timing[str(level)]={}
        for train in ['V09','V10']:
            f=fit([r for r in adjusted if r['recording']==train],'vertical')
            f['held_out']=residuals([r for r in adjusted if r['recording']!=train],f);timing[str(level)][train]=f
    boundary={}
    for first_pts in [5100,5400]:
        boundary[str(first_pts)]={}
        for train in ['V09','V10']:
            f=fit([r for r in rows['baseline'] if r['recording']==train and r['pts']>=first_pts],'vertical')
            f['held_out']=residuals([r for r in rows['baseline'] if r['recording']!=train],f)
            boundary[str(first_pts)][train]=f
    # Native-to-native masks isolate motion from the known probe outline mismatch.
    native_changes={}
    for sid in ['V09','V10']:
        native_changes[sid]=[]
        for line,count in enumerate([8,7]):
            for cell in range(count):
                a=native_pairs[(sid,6240,line,cell)];b=native_pairs[(sid,6779,line,cell)];options=[]
                for shift in range(-8,9):
                    moved=np.zeros_like(a)
                    if shift>=0:moved[shift:]=a[:a.shape[0]-shift] if shift else a
                    else:moved[:shift]=a[-shift:]
                    inter,union=counts(moved,b);options.append((inter/union,shift))
                best=max(options);inter,union=counts(a,b)
                native_changes[sid].append(dict(line=line,cell=cell,dy=best[1],registered_iou=best[0],fixed_iou=inter/union,edges=vertical_edges(a.T.tolist(),b.T.tolist())))
    for sid,record in config['recordings'].items():
        if sid in source_hashes and digest(root/'recordings'/record['file'])!=source_hashes[sid]:raise ValueError('Source changed')
    result=dict(status='measured',sources=sources,phase_pts=observations,reproduction=reproduction,
                measurements=rows,models=results,crossings=crossings,crossing_sensitivity=timing,native_outline_changes=native_changes,appearance_controls=controls,registration_windows=window_checks,boundary_sensitivity=boundary)
    save(out/'results.json',result)
    return dict(status='measured',baseline_models=results['baseline'])


def main():
    root=private_root(REPO/'reference-private');manifest=root/'s09-state-cases.json';prior_path=root/'analysis/s09-state/current/results.json'
    if not all(p.is_file() for p in [manifest,prior_path,root/'typography-cases.json',REPO/'.build/release/ReferenceProbe']):
        print(json.dumps(dict(status='unavailable',reason='Private S09 protocol, prior diagnostics, known text, or release probe absent')));return
    config=json.loads(safe_path(root,manifest).read_text());prior=json.loads(safe_path(root,prior_path).read_text())
    if not all(safe_path(root,root/'recordings'/config['recordings'][sid]['file']).is_file() for sid in ['V09','V10']):
        print(json.dumps(dict(status='unavailable',reason='Required V09/V10 originals absent')));return
    out=safe_path(root,root/'analysis/glyph-outline/current');out.mkdir(parents=True,exist_ok=True)
    print(json.dumps(run(root,out,config,prior),indent=2))

if __name__=='__main__':main()
