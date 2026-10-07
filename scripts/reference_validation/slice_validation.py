"""Private V09/V10 integration comparison; never publishes source content."""
import json
import subprocess
from analyze import REPO,private_root,safe_path,save,ink_bounds
from state_typography import digest
from glyph_outline import normalize
from outline_core import vertical_edges


def events_for(text,crossings):
    """Map this inspected simple CJK passage to explicit private event annotations."""
    events=[];index=0
    for line,string in enumerate(text.split('\n')):
        for cell,c in enumerate(string):
            if len(c.encode('utf-16-le'))!=2:raise ValueError('Inspected single-unit CJK protocol required')
            entry=crossings[str((line,cell))];a=entry['180'];b=entry['210'];v=entry['195']
            time=lambda tick:dict(numerator=tick,denominator=600)
            events.append(dict(start=index,length=1,begin=time(a['lower_pts']) if a and b else None,
                end=time(b['upper_pts']) if a and b else None,verticalEvent=time(v['upper_pts']) if v else None))
            index+=1
        index+=1
    return events


def run(root,out,config,prior):
    import numpy as np
    from PIL import Image
    cases=json.loads((root/'typography-cases.json').read_text());text=cases['S09']['text']
    if [len(s) for s in text.split('\n')]!=[8,7]:raise ValueError('Inspected paragraph structure changed')
    inventory=json.loads((root/'analysis/s09-state/current/results.json').read_text())
    results={};images={};background={};opacities={}
    for sid in ['V09','V10']:
        source=safe_path(root,root/'recordings'/config['recordings'][sid]['file'])
        if digest(source)!=inventory['metadata'][sid]['sha256']:raise ValueError('Original source changed')
        samples=[]
        index={v['pts']:i for i,v in enumerate(inventory['observations'][sid])}
        for pts in prior['phase_pts'][sid]:
            image=Image.open(root/'analysis/s09-state/current'/sid/'frames'/f'{index[pts]+1:05d}.png')
            gray=np.asarray(image).astype(float).mean(2);images[(sid,pts)]=gray
            for row in prior['measurements']['baseline']:
                if row['recording']!=sid or row['pts']!=pts:continue
                x=96+row['cell']*95;y=95+row['line']*123;p=gray[y:y+115,x:x+95]
                bg=np.median(np.concatenate([p[:8],p[-8:]]),axis=0);background[(sid,pts,row['line'],row['cell'])]=bg
                if row['level']<170:samples.append((row['level']-float(bg.mean()))/(255-float(bg.mean())))
        opacities[sid]=float(np.median(samples))
    for train,test in [('V09','V10'),('V10','V09')]:
        results[train]={};events=events_for(text,prior['crossings'][test])
        index={v['pts']:i for i,v in enumerate(inventory['observations'][test])}
        for model in ['fixed','vertical']:
            fit=prior['models']['baseline'][train][model];b,d,*amp=fit['coefficients']
            params=dict(size=103.25,width=987,originX=98,originY=686+b,lineAdvance=123+d,
                        amplitude=amp[0] if amp else 0,tau=fit['tau'] or .195,dimOpacity=opacities[train])
            request=dict(text=text,canvasWidth=1180,breakEvidence='observed-structure-source-semantics-unknown',parameters=params,events=events)
            path=out/f'{train}-{model}.json';save(path,request);phases=[]
            for pts in prior['phase_pts'][test]:
                dest=out/f'{train}-{test}-{model}-{pts}'
                subprocess.run([str(REPO/'.build/release/LyricsSliceProbe'),str(path),str(pts),'600',str(dest)],check=True)
                coverage=np.asarray(Image.open(dest/'coverage.png'))[:,:,3]/255
                appearance=np.asarray(Image.open(dest/'appearance.png'))[:,:,3]/255
                state=json.loads((dest/'state.json').read_text());gray=images[(test,pts)];glyphs=[];intersections=0;unions=0
                for line,count in enumerate([8,7]):
                    for cell in range(count):
                        x=96+cell*95;y=95+line*123;p=gray[y:y+115,x:x+95]
                        native=normalize(p)>.5;mask=coverage[y+600:y+715,x:x+95]>.5
                        inter=np.count_nonzero(native&mask);union=np.count_nonzero(native|mask);intersections+=inter;unions+=union
                        scores=[]
                        for dy in range(-8,9):
                            shifted=coverage[y+600-dy:y+715-dy,x:x+95]>.5
                            scores.append((np.count_nonzero(native&shifted)/np.count_nonzero(native|shifted),-abs(dy),dy))
                        best=max(scores);bg=background[(test,pts,line,cell)]
                        # Controlled white-over-local-background comparison, not a material reconstruction.
                        predicted=bg+(255-bg)*appearance[y+600:y+715,x:x+95]
                        core=native.copy()
                        for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:core &= np.roll(native,(dy,dx),(0,1))
                        error=(predicted-p)[core]
                        shared=core&mask;shared_error=(predicted-p)[shared]
                        glyphs.append(dict(line=line,cell=cell,iou=float(inter/union),residual_dy=best[2],
                            registration_at_limit=abs(best[2])==8,edges=vertical_edges(mask.T.tolist(),native.T.tolist()),
                            appearance_rmse=float(np.sqrt(np.mean(error**2))),appearance_bias=float(error.mean()),
                            shared_support_fraction=float(shared.sum()/core.sum()),
                            appearance_shared_rmse=float(np.sqrt(np.mean(shared_error**2))),appearance_shared_bias=float(shared_error.mean())))
                observed=inventory['observations'][test][index[pts]]['measurements']['25-100']
                ink=ink_bounds(coverage>.5)
                if len(ink)!=2:raise ValueError('Rendered paragraph support mismatch')
                phases.append(dict(pts=pts,common_origin_iou=float(intersections/unions),glyphs=glyphs,
                    width_errors=[b[2]-b[0]-(n['bounds'][2]-n['bounds'][0]) for b,n in zip(ink,observed)],
                    ink_bounds=ink,lines=state['lines'],fonts=state['fonts']))
            results[train][model]=dict(held_out=test,parameters=params,phases=phases)
    for sid in ['V09','V10']:
        if digest(root/'recordings'/config['recordings'][sid]['file'])!=inventory['metadata'][sid]['sha256']:raise ValueError('Source changed')
    value=dict(status='measured',parameter_provenance='Frozen v5 fits; no vertical refitting in this gate',
               dim_opacity_training=opacities,comparisons=results)
    save(out/'results.json',value)
    return dict(status='measured',directions=list(results))


def main():
    root=private_root(REPO/'reference-private');manifest=root/'s09-state-cases.json';prior=root/'analysis/glyph-outline/current/results.json'
    if not all(p.is_file() for p in [manifest,prior,root/'typography-cases.json',root/'analysis/s09-state/current/results.json',REPO/'.build/release/LyricsSliceProbe']):
        print(json.dumps(dict(status='unavailable',reason='Private S09 annotations, prior diagnostics, text, or release slice probe absent')));return
    config=json.loads(safe_path(root,manifest).read_text())
    if not all(safe_path(root,root/'recordings'/config['recordings'][s]['file']).is_file() for s in ['V09','V10']):
        print(json.dumps(dict(status='unavailable',reason='Private source recordings absent')));return
    out=safe_path(root,root/'analysis/lyrics-slice/current');out.mkdir(parents=True,exist_ok=True)
    print(json.dumps(run(root,out,config,json.loads(prior.read_text()))))

if __name__=='__main__':main()
