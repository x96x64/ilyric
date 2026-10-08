"""Private common-origin Latin comparisons; source text and overlays remain ignored."""
import io
import json
import subprocess
from analyze import REPO,private_root,safe_path,save
from latin_validation import IDS
from latin_core import fit_origin,errors


def run(root,out,cases,prior):
    import numpy as np
    from PIL import Image,ImageCms
    from analyze import foreground,ink_bounds
    from typography_core import line_strings
    selection=prior['fits']['observed']['fixed_width']['987']
    if any(v['candidate']!='observed-104.25-987' for v in [selection['fit'],*selection['exclusions'].values()]):
        raise ValueError('Shared Latin candidate changed; reevaluate integration')
    rows={s:prior['comparisons'][s]['100']['lines'] for s in IDS}
    fitted=fit_origin(rows);results={}
    for omitted in [None,*IDS]:
        fit=fit_origin({s:r for s,r in rows.items() if s!=omitted});label=omitted or 'shared';results[label]={}
        for sid in ([omitted] if omitted else IDS):
            params=dict(size=104.25,width=987,originX=fit['origin_x'],originY=fit['first_baseline']-104.25,
                lineAdvance=fit['line_advance'],amplitude=0,tau=.195,dimOpacity=1)
            text='\n'.join(cases[sid]['observedLines'])
            value=dict(text=text,canvasWidth=1179,paragraphStyle='latinStatic',breakEvidence='observed-structure-source-semantics-unknown',parameters=params,events=[])
            path=out/f'{label}-{sid}.json';save(path,value);dest=out/f'{label}-{sid}'
            subprocess.run([str(REPO/'.build/release/LyricsSliceProbe'),str(path),'0','1',str(dest)],check=True)
            state=json.loads((dest/'state.json').read_text())
            if line_strings(text,state['lines'])!=cases[sid]['observedLines']:raise ValueError('Integrated paragraph structure mismatch')
            alpha=np.asarray(Image.open(dest/'coverage.png'))[:,:,3]>127
            original=Image.open(root/'screenshots'/cases[sid]['file'])
            image=ImageCms.profileToProfile(original,ImageCms.ImageCmsProfile(io.BytesIO(original.info['icc_profile'])),ImageCms.createProfile('sRGB'),outputMode='RGB')
            x,y,r,b=cases[sid]['roi'];mask=foreground(image,25,100)[y:b,x:r];candidate=alpha[y:b,x:r]
            score=lambda a,b:float((a&b).sum()/(a|b).sum())
            native=prior['native_bounds'][sid]['100'];ink=ink_bounds(candidate,x,y)
            line_iou=[]
            for i,n in enumerate(native):
                lo=y if i==0 else (native[i-1][3]+n[1])//2
                hi=b if i==len(native)-1 else (n[3]+native[i+1][1])//2
                line_iou.append(score(mask[lo-y:hi-y],candidate[lo-y:hi-y]))
            sensitivity={}
            for threshold in [15,25,35]:
                for floor in [100,125,145]:
                    m=foreground(image,threshold,floor)[y:b,x:r]
                    sensitivity[f'{threshold}-{floor}']=score(m,candidate)
            # Diagnostic common translation search is not used in the principal score.
            registrations={}
            for radius in [3,5,7]:
                ranked=[]
                for dy in range(-radius,radius+1):
                    for dx in range(-radius,radius+1):
                        c=alpha[y-dy:b-dy,x-dx:r-dx];ranked.append((score(mask,c),-abs(dx)-abs(dy),dx,dy))
                best=max(ranked);registrations[str(radius)]=dict(iou=best[0],dx=best[2],dy=best[3],at_limit=max(abs(best[2]),abs(best[3]))==radius)
            results[label][sid]=dict(parameters=params,fit=fit,proxy_errors=errors(rows[sid],fit),
                line_count=len(state['lines']),common_origin_iou=score(mask,candidate),line_iou=line_iou,
                width_errors=[c[2]-c[0]-(n[2]-n[0]) for c,n in zip(ink,native)],
                horizontal_errors=[c[0]-n[0] for c,n in zip(ink,native)],ink_bounds=ink,
                fonts=state['fonts'],lines=state['lines'],sensitivity=sensitivity,diagnostic_registration=registrations)
    value=dict(status='measured',shared_origin=fitted,comparisons=results)
    save(out/'integration.json',value);return value


def main():
    root=private_root(REPO/'reference-private');paths=[root/'typography-cases.json',root/'analysis/latin/current/results.json']
    if not all(p.is_file() for p in paths) or not (REPO/'.build/release/LyricsSliceProbe').is_file():
        print(json.dumps(dict(status='unavailable',reason='Private Latin calibration or release slice probe absent')));return
    cases,prior=[json.loads(safe_path(root,p).read_text()) for p in paths]
    if not all(safe_path(root,root/'screenshots'/cases[s]['file']).is_file() for s in IDS):
        print(json.dumps(dict(status='unavailable',reason='Private Latin screenshots absent')));return
    from state_typography import digest
    out=safe_path(root,root/'analysis/latin/current');hashes=json.loads((out/'source-hashes.json').read_text())
    def verify():
        if hashes!={s:digest(root/'screenshots'/cases[s]['file']) for s in IDS}:raise ValueError('Original screenshot changed')
    verify();value=run(root,out,cases,prior);verify()
    print(json.dumps(dict(status=value['status'],shared_origin=value['shared_origin'])))

if __name__=='__main__':main()
