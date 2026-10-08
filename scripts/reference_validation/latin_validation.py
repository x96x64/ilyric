"""Private Latin layout calibration; source structure remains an observed constraint."""
import io
import json
from analyze import REPO,private_root,safe_path,save
from state_typography import digest

IDS=['S02','S03','S04B','S05']


def run(root,out,cases):
    import numpy as np
    from PIL import Image,ImageCms
    from calibrate import render,compare
    from analyze import foreground,ink_bounds
    from typography_core import line_strings,select,leave_one_out
    archived=json.loads((REPO/'docs/reference-data/v2/typography.json').read_text())
    hashes={sid:digest(safe_path(root,root/'screenshots'/cases[sid]['file'])) for sid in IDS}
    inventory=out/'source-hashes.json'
    if inventory.exists() and json.loads(inventory.read_text())!=hashes:raise ValueError('Private screenshot integrity mismatch')
    save(inventory,hashes)
    records={mode:{} for mode in ['inherited','observed']};reproduction={};images={};native={};structures={};metadata={}
    for sid in IDS:
        case=cases[sid];original=Image.open(safe_path(root,root/'screenshots'/case['file']))
        if original.size!=(1179,2556) or not original.info.get('icc_profile'):raise ValueError('Reference geometry or ICC profile missing')
        metadata[sid]=dict(dimensions=list(original.size),format=original.format,profile=ImageCms.getProfileDescription(ImageCms.ImageCmsProfile(io.BytesIO(original.info['icc_profile']))).strip())
        x,y,r,b=case['roi'];encoded=original.convert('RGB')
        old_bounds=ink_bounds(foreground(encoded,25)[y:b,x:r],x,y)
        m,a,ink=render(root,out,sid,case,'reproduce',dict(size=104.5))
        errors=[c[2]-c[0]-(n[2]-n[0]) for n,c in zip(old_bounds,ink)]
        previous=archived['candidate_geometry'][sid]['size-104.5']
        current=compare(encoded,old_bounds,a,ink,m,25)
        old=next(v for v in archived['comparisons'][sid]['size-104.5'] if v['threshold']==25)
        if errors!=previous['width_error'] or current!=old:raise ValueError('Archived Latin comparison differs')
        reproduction[sid]=dict(status='reproduced',width_error=errors)
        image=ImageCms.profileToProfile(original,ImageCms.ImageCmsProfile(io.BytesIO(original.info['icc_profile'])),ImageCms.createProfile('sRGB'),outputMode='RGB')
        images[sid]=image
        native[sid]={str(floor):ink_bounds(foreground(image,25,floor)[y:b,x:r],x,y) for floor in [100,125,145]}
        if any(len(v)!=len(case['observedLines']) for v in native[sid].values()):raise ValueError('Inspect native paragraph support')
        joined=' '.join(case['observedLines'])
        structures[sid]=dict(observed_line_lengths=list(map(len,case['observedLines'])),source_semantics='unknown',
            transcription_matches_observed_words=joined==case['text'].replace('\n',' '),input_explicit_breaks=case['text'].count('\n'))
        if not structures[sid]['transcription_matches_observed_words']:raise ValueError('Known text differs from observed structure')
        for mode in records:
            records[mode][sid]={}
            for size in [103.5,103.75,104,104.25,104.5,104.75,105]:
                for width in [983,987,991]:
                    name=f'{mode}-{size:g}-{width}'
                    text='\n'.join(case['observedLines']) if mode=='observed' else case['text']
                    metrics,alpha,bounds=render(root,out,sid,case,name,dict(size=size,width=width),text)
                    records[mode][sid][name]=dict(parameters=dict(size=size,width=width),
                        structure_matches=line_strings(text,metrics['lines'])==case['observedLines'],
                        width_error=[c[2]-c[0]-(n[2]-n[0]) for n,c in zip(native[sid]['100'],bounds)],
                        ink_bounds=bounds,metrics=metrics)
        # Explicitly test the unbroken S04 constraint without forcing a narrower width.
        if case['structure']=='observed-breaks':
            structures[sid]['unbroken']={}
            for width in [983,987,991]:
                metrics,_,_=render(root,out,sid,case,f'unbroken-{width}',dict(size=104.25,width=width),joined)
                structures[sid]['unbroken'][str(width)]=dict(matches=line_strings(joined,metrics['lines'])==case['observedLines'],lengths=[v['length'] for v in metrics['lines']])
    fits={};sensitivity={}
    for mode,rs in records.items():
        fits[mode]=dict(joint=select(rs,IDS),exclusions=leave_one_out(rs,IDS),fixed_width={})
        for width in [983,987,991]:
            subset={s:{k:v for k,v in rs[s].items() if v['parameters']['width']==width} for s in IDS}
            fits[mode]['fixed_width'][str(width)]=dict(fit=select(subset,IDS),exclusions=leave_one_out(subset,IDS))
    # Width remains a prior, not identifiable when all visible breaks are supplied.
    chosen=fits['observed']['fixed_width']['987']['fit']['candidate'];comparisons={}
    for sid in IDS:
        record=records['observed'][sid][chosen];metrics=record['metrics']
        path=out/'probes'/sid/chosen/'text.png';alpha=np.asarray(Image.open(path))[:,:,3]>127
        comparisons[sid]={}
        for floor in [100,125,145]:
            comparisons[sid][str(floor)]=compare(images[sid],native[sid][str(floor)],alpha,record['ink_bounds'],metrics,25,floor)
    for threshold in [15,25,35]:
        for floor in [100,145]:
            for cut in [96,127,160]:
                variant={}
                for sid in IDS:
                    case=cases[sid];x,y,r,b=case['roi'];bounds=ink_bounds(foreground(images[sid],threshold,floor)[y:b,x:r],x,y);variant[sid]={}
                    for name,record in records['observed'][sid].items():
                        if record['parameters']['width']!=987:continue
                        alpha=np.asarray(Image.open(out/'probes'/sid/name/'text.png'))[:,:,3]>cut;ink=ink_bounds(alpha)
                        variant[sid][name]=dict(structure_matches=len(ink)==len(bounds) and record['structure_matches'],width_error=[c[2]-c[0]-(n[2]-n[0]) for n,c in zip(bounds,ink)])
                sensitivity[f'{threshold}-{floor}-{cut}']=dict(fit=select(variant,IDS),exclusions=leave_one_out(variant,IDS))
    if hashes!={sid:digest(root/'screenshots'/cases[sid]['file']) for sid in IDS}:raise ValueError('Original screenshots changed')
    value=dict(status='measured',metadata=metadata,reproduction=reproduction,structures=structures,native_bounds=native,
        fits=fits,sensitivity=sensitivity,comparisons=comparisons,
        candidates={mode:{sid:{k:{field:v for field,v in r.items() if field!='metrics'} for k,r in rs.items()} for sid,rs in group.items()} for mode,group in records.items()})
    save(out/'results.json',value)
    print(json.dumps(dict(status='measured',fits=fits)))


def main():
    root=private_root(REPO/'reference-private');path=root/'typography-cases.json'
    if not path.is_file() or not (REPO/'.build/release/ReferenceProbe').is_file():
        print(json.dumps(dict(status='unavailable',reason='Private Latin cases or release probe absent')));return
    cases=json.loads(safe_path(root,path).read_text())
    if not all(s in cases and safe_path(root,root/'screenshots'/cases[s]['file']).is_file() for s in IDS):
        print(json.dumps(dict(status='unavailable',reason='Required private Latin screenshots absent')));return
    out=safe_path(root,root/'analysis/latin/current');out.mkdir(parents=True,exist_ok=True)
    run(root,out,cases)

if __name__=='__main__':main()
