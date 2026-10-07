"""Private native-space typography calibration; writes only ignored diagnostics.

Inputs: reference-private/typography-cases.json, with known text, observedLines,
file, roi, group, structure, and optional alignment. Observed breaks constrain a
comparison; their source semantics remain unknown. Public output is curated
separately after a privacy review, never copied automatically by this command.
"""
import argparse
import json
from pathlib import Path
import subprocess
from analyze import REPO, private_root, safe_path, save, foreground, ink_bounds, typography
from typography_core import line_strings, select, leave_one_out, baseline_fit


def configurations():
    result = {f'size-{size:g}': dict(size=size) for size in [101+i*.25 for i in range(21)]}
    result.update({name: dict(size=104, **value) for name,value in {
        'emphasized': {'fontSelection':'emphasized'}, 'language-ja': {'language':'ja'},
        'language-en': {'language':'en'}, 'optical-none': {'opticalSize':'none'},
        'optical-auto': {'opticalSize':'auto'}, 'optical-34': {'opticalSize':'34'},
        'weight-0.3': {'weight':.3}, 'weight-0.4': {'weight':.4}, 'weight-0.5': {'weight':.5},
        'width-983': {'width':983}, 'width-991': {'width':991}}.items()})
    for width in [983,991]:
        for size in [104,104.25,104.5,104.75,105]:
            result[f'width-{width}-size-{size:g}'] = dict(size=size,width=width)
    return result


def render(root, out, sid, case, name, options, text=None):
    import numpy as np
    from PIL import Image
    destination = safe_path(root, out/'probes'/sid/name)
    request = safe_path(root, out/'request.json')
    value = dict(text=case['text'] if text is None else text, width=987, size=104,
                 lineAdvance=128, font='system-bold', alignment=case.get('alignment','left'))
    value.update(options)
    save(request,value)
    subprocess.run([str(REPO/'.build/release/ReferenceProbe'),str(request),str(destination)],check=True)
    metrics=json.loads((destination/'metrics.json').read_text())
    alpha=np.asarray(Image.open(destination/'text.png'))[:,:,-1]>127
    return metrics, alpha, ink_bounds(alpha)


def compare(image, native, alpha, candidate, metrics, threshold, min_gray=145):
    """Per-line ink-origin registration; geometry and shape are reported separately."""
    import numpy as np
    mask=foreground(image,threshold,min_gray); results=[]
    for index,(n,c,m) in enumerate(zip(native,candidate,metrics['lines'])):
        nx,ny,nr,nb=n; cx,cy,cr,cb=c
        yy,xx=np.nonzero(alpha[max(0,cy-6):cb+6,max(0,cx-6):cr+6])
        xx=xx+max(0,cx-6)-cx; yy=yy+max(0,cy-6)-cy
        ref=mask[ny-8:nb+8,nx-8:nr+8];best=(-1,None,None)
        for dy in range(-5,6):
            for dx in range(-5,6):
                x=xx+8+dx;y=yy+8+dy
                valid=(x>=0)&(x<ref.shape[1])&(y>=0)&(y<ref.shape[0])
                intersection=ref[y[valid],x[valid]].sum()
                iou=float(intersection/(ref.sum()+len(x)-intersection))
                if iou>best[0]:best=(iou,dx,dy)
        _,dx,dy=best
        results.append(dict(line=index,iou=best[0],registration=[dx,dy],registration_at_limit=abs(dx)==5 or abs(dy)==5,
            origin_translation=[nx-cx+dx,ny-cy+dy],
            baseline_proxy=m['baseline']+ny-cy+dy,
            width_error=(cr-cx)-(nr-nx),height_error=(cb-cy)-(nb-ny)))
    return dict(threshold=threshold,min_gray=min_gray,lines=results,
                baseline_fit=baseline_fit([r['baseline_proxy'] for r in results]))


def run(root, out):
    from PIL import Image
    cases=json.loads(safe_path(root,root/'typography-cases.json').read_text())
    if any(not sid.isalnum() for sid in cases): raise ValueError('Invalid case identifier')
    configs=configurations(); records={}; observations={}; comparisons={}; alternatives={}
    for sid,case in sorted(cases.items()):
        image=Image.open(safe_path(root,root/'screenshots'/case['file'])).convert('RGB')
        x0,y0,x1,y1=case['roi']
        bounds={str(t):ink_bounds(foreground(image,t)[y0:y1,x0:x1],x0,y0) for t in [15,25,35]}
        native=bounds['25']
        if len(native)!=len(case['observedLines']): raise ValueError(f'{sid}: inspect native line segmentation')
        observations[sid]=dict(group=case['group'],structure=case['structure'],source_break_semantics='unknown',
                               alignment=case.get('alignment','left'),ink_bounds_by_threshold=bounds)
        records[sid]={}
        for name,config in configs.items():
            metrics,alpha,ink=render(root,out,sid,case,name,config)
            matches=line_strings(case['text'],metrics['lines'])==case['observedLines'] and len(ink)==len(native)
            records[sid][name]=dict(parameters={'width':987,**config},
                structure_matches=matches,ink_bounds=ink,
                width_error=[(b[2]-b[0])-(a[2]-a[0]) for a,b in zip(native,ink)],metrics=metrics)
        alternatives[sid]={}
        if case['structure']=='observed-breaks':
            text=case['text'].replace('\n','' if case['group']=='japanese' else ' ')
            for width in [983,987,991]:
                m,_,ink=render(root,out,sid,case,f'unbroken-{width}',{'width':width},text)
                alternatives[sid][str(width)]=dict(structure_matches=line_strings(text,m['lines'])==case['observedLines'],
                    line_lengths=[r['length'] for r in m['lines']],ink_bounds=ink)
        if case.get('alternateTexts'):
            alternatives[sid]['transcription_variants']=[]
            for index,text in enumerate(case['alternateTexts']):
                m,a,b=render(root,out,sid,case,f'alternate-{index}',dict(size=102),text)
                alternatives[sid]['transcription_variants'].append(
                    dict(metrics=m,comparison=compare(image,native,a,b,m,25)))
    # Only the requested size varies in model fitting. API/width variants are diagnostics.
    grid={sid:{p:r for p,r in values.items() if p.startswith('size-')} for sid,values in records.items()}
    fits={}
    for group in ['latin','japanese','mixed']:
        ids=[s for s,c in cases.items() if c['group']==group]
        fits[group]=dict(fit=select(grid,ids),cases=ids)
        if len(ids)>1: fits[group]['leave_one_out']=leave_one_out(grid,ids)
    fits['shared']=dict(fit=select(grid,[s for s,c in cases.items() if c['group']!='sing-static']))
    sensitivity={}
    for threshold in [15,25,35]:
        for alpha_threshold in [96,127,160]:
            variant={}
            for sid,case in cases.items():
                native=observations[sid]['ink_bounds_by_threshold'][str(threshold)]
                variant[sid]={}
                for name,record in grid[sid].items():
                    import numpy as np
                    alpha=np.asarray(Image.open(out/'probes'/sid/name/'text.png'))[:,:,-1]>alpha_threshold
                    ink=ink_bounds(alpha)
                    variant[sid][name]=dict(structure_matches=record['structure_matches'] and len(ink)==len(native),
                        width_error=[(b[2]-b[0])-(a[2]-a[0]) for a,b in zip(native,ink)])
            key=f'foreground-{threshold}-alpha-{alpha_threshold}'
            sensitivity[key]={}
            for group in ['latin','japanese','mixed']:
                ids=fits[group]['cases']
                sensitivity[key][group]=dict(fit=select(variant,ids))
                if len(ids)>1:sensitivity[key][group]['leave_one_out']=leave_one_out(variant,ids)
    width_sensitivity={}
    for width in [983,987,991]:
        subset={sid:{name:r for name,r in values.items() if
            (name.startswith(f'width-{width}-size-') if width!=987 else name.startswith('size-'))}
            for sid,values in records.items()}
        width_sensitivity[str(width)]=dict(fit=select(subset,fits['latin']['cases']),
            leave_one_out=leave_one_out(subset,fits['latin']['cases']))
    joint={sid:{name:r for name,r in values.items() if name.startswith('size-') or '-size-' in name}
           for sid,values in records.items()}
    width_sensitivity['joint']=dict(fit=select(joint,fits['latin']['cases']),
        leave_one_out=leave_one_out(joint,fits['latin']['cases']))
    for sid,case in sorted(cases.items()):
        image=Image.open(safe_path(root,root/'screenshots'/case['file'])).convert('RGB')
        names={'size-102','size-103','size-104',fits['shared']['fit']['candidate'],
               fits.get(case['group'],fits['latin'])['fit']['candidate']}
        comparisons[sid]={}
        for name in sorted(names):
            record=records[sid][name]
            if not record['structure_matches']: continue
            metrics=record['metrics']
            import numpy as np
            alpha=np.asarray(Image.open(out/'probes'/sid/name/'text.png'))[:,:,-1]>127
            comparisons[sid][name]=[compare(image,observations[sid]['ink_bounds_by_threshold'][str(t)],
                                alpha,record['ink_bounds'],metrics,t) for t in [15,25,35]]
    floor_sensitivity={}
    for floor in [100,125,145]:
        variants={};selected={}
        for sid,case in cases.items():
            image=Image.open(safe_path(root,root/'screenshots'/case['file'])).convert('RGB')
            x0,y0,x1,y1=case['roi']
            native=ink_bounds(foreground(image,25,floor)[y0:y1,x0:x1],x0,y0)
            variants[sid]={}
            for name,record in grid[sid].items():
                ink=record['ink_bounds']
                variants[sid][name]=dict(structure_matches=record['structure_matches'] and len(native)==len(ink),
                    width_error=[(b[2]-b[0])-(a[2]-a[0]) for a,b in zip(native,ink)])
            name=fits.get(case['group'],fits['latin'])['fit']['candidate']
            record=records[sid][name]
            import numpy as np
            alpha=np.asarray(Image.open(out/'probes'/sid/name/'text.png'))[:,:,-1]>127
            selected[sid]=dict(candidate=name,native_ink_bounds=native,
                comparison=compare(image,native,alpha,record['ink_bounds'],record['metrics'],25,floor))
        floor_sensitivity[str(floor)]=dict(comparisons=selected,fits={
            group:select(variants,fits[group]['cases']) for group in ['latin','japanese','mixed']})
    result=dict(status='measured',version=1,coordinates='native screenshot pixels; top-left origin',
                observations=observations,candidates=records,fits=fits,comparisons=comparisons,alternatives=alternatives,
                sensitivity=sensitivity,width_sensitivity=width_sensitivity,
                floor_sensitivity=floor_sensitivity)
    save(out/'results.json',result)
    return dict(status='measured',cases=len(cases),fits=fits)


def reproduce(root, out):
    status=typography(root,out)
    if status['status']!='measured':return status
    current=json.loads((out/'typography-results.json').read_text())
    masks=json.loads((out/'mask-results.json').read_text())
    baseline=json.loads((REPO/'docs/reference-data/v1/results.json').read_text())['typography']
    differences=[]
    for sid,old in baseline.items():
        if current[sid]['native_ink_bounds']!=old['native_ink_bounds']:differences.append(sid+': bounds')
        for candidate in old['candidates']:
            match=next(c for c in current[sid]['candidates'] if
                       (c['font'],c['size'])==(candidate['font'],candidate['size']))
            if candidate!=match:differences.append(sid+': candidate')
        for name,values in old['first_line_mask_iou'].items():
            if masks[sid][name]!=values:differences.append(sid+': mask')
    result=dict(status='reproduced' if not differences else 'different',cases=len(baseline),differences=differences)
    save(out/'reproduction.json',result)
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',default=str(REPO/'reference-private'))
    parser.add_argument('--reproduce-baseline',action='store_true')
    args=parser.parse_args();root=private_root(args.root)
    config='cases.json' if args.reproduce_baseline else 'typography-cases.json'
    if not (root/config).exists():
        print(json.dumps(dict(status='unavailable',reason=f'Private {config} is absent')));return
    if not (REPO/'.build/release/ReferenceProbe').exists():
        print(json.dumps(dict(status='unavailable',reason='Build the release ReferenceProbe target')));return
    name='reproduction' if args.reproduce_baseline else 'current'
    out=safe_path(root,root/'analysis/typography-calibration'/name);out.mkdir(parents=True,exist_ok=True)
    result=reproduce(root,out) if args.reproduce_baseline else run(root,out)
    print(json.dumps(result,indent=2))
    if result['status']=='different':raise SystemExit(1)


if __name__=='__main__':main()
