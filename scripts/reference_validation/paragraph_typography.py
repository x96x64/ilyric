"""Private multiline state comparison, using an inspected correspondence protocol.

All generated content remains private. This command neither infers correspondence
nor publishes evidence. The unchanged ReferenceProbe shapes complete paragraphs.
"""
import json
from fractions import Fraction
from pathlib import Path
import subprocess
from analyze import REPO, private_root, safe_path, save, foreground, ink_bounds
from calibrate import render, compare
from typography_core import line_strings, select, leave_one_out
from state_core import stable_intervals, summarize, affine_landmarks, spacing_holdout
from state_typography import inventory, digest, line_measure, srgb_screenshot
from paragraph_core import match_paragraph, paragraph_geometry, registered_spacing

VARIANTS=[(threshold,floor) for threshold in [15,25,35] for floor in [80,100,125,145]]
BASELINE='25-100'


def extract(root,out,sid,record,metadata):
    spec=record['measurement'];video=metadata['video'];sub=out/sid
    if [video[k] for k in ['color_space','color_transfer','color_primaries','color_range']]!=['bt709','bt709','bt709','pc']:
        raise ValueError('Inspected full-range Rec.709 input required')
    frames=json.loads((sub/'frames.json').read_text());lo,hi=spec['pts_range']
    selected=[(i,f) for i,f in enumerate(frames) if lo<=f['pts']<=hi]
    if not selected:raise ValueError('Empty inspected interval')
    x,y,r,b=spec['crop'];destination=sub/'frames';destination.mkdir(exist_ok=True)
    # Remove only prior generated PNGs; never alter source media.
    for p in destination.glob('*.png'):p.unlink()
    vf=f"select=between(n\\,{selected[0][0]}\\,{selected[-1][0]}),colorspace=all=bt709:trc=srgb:range=pc,crop={r-x}:{b-y}:{x}:{y}"
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(safe_path(root,root/'recordings'/record['file'])),
        '-vf',vf,'-fps_mode','passthrough','-enc_time_base',video['time_base'],str(destination/'%05d.png')],check=True)
    files=sorted(destination.glob('*.png'))
    if len(files)!=len(selected):raise ValueError('Decoded frame/PTS count mismatch')
    return list(zip(files,selected))


def measure(files,spec):
    import numpy as np
    from PIL import Image,ImageFilter
    values=[]
    for path,(index,frame) in files:
        image=Image.open(path).convert('RGB');gray=np.asarray(image).astype(float).mean(2)
        background=np.asarray(Image.fromarray(gray.astype('uint8')).filter(ImageFilter.GaussianBlur(18))).astype(float)
        measures={};rejected={};x,y,r,b=spec['search_roi']
        for threshold,floor in VARIANTS:
            mask=(gray-background>threshold)&(gray>floor)
            bounds=match_paragraph(ink_bounds(mask[y:b,x:r],x,y),spec['width_ranges'],spec['advance_range'])
            if bounds is None:continue
            try:
                lines=[dict(bounds=bound,**line_measure(image,bound,cells,threshold,floor,(gray,background),mask))
                       for bound,cells in zip(bounds,spec['landmark_cells_x'])]
            except ValueError as error:
                if str(error)!='Insufficient landmark support':raise
                rejected[f'{threshold}-{floor}']='Incomplete landmark support';continue
            measures[f'{threshold}-{floor}']=lines
        baseline=measures.get(BASELINE)
        values.append(dict(pts=frame['pts'],index=index,measurements=measures,rejected=rejected,
            geometry=paragraph_geometry([v['bounds'] for v in baseline]) if baseline else None))
    return values


def stable_selection(values,base,line_count):
    runs={str(t):stable_intervals(values,base,[t]*(3*line_count),.5) for t in [1,2,3]}
    if not runs['2']:raise ValueError('No identified stable paragraph interval')
    selected=max(runs['2'],key=lambda r:r['duration_seconds']);guard=int(Fraction(1,10)/Fraction(base))
    interior=[v for v in values if selected['first_pts']+guard<=v['pts']<=selected['last_pts']-guard]
    if len(interior)<3:raise ValueError('Insufficient guarded observations')
    return dict(runs=runs,selected=selected,interior=dict(first_pts=interior[0]['pts'],last_pts=interior[-1]['pts'],
        count=len(interior),duration_seconds=float((interior[-1]['pts']-interior[0]['pts'])*Fraction(base)))),interior


def candidate_errors(candidate,observations,key,line_count):
    complete=[v['measurements'][key] for v in observations if key in v['measurements']]
    matches=len(candidate)==line_count and len(complete)==len(observations)
    errors=[c[2]-c[0]-(n['bounds'][2]-n['bounds'][0]) for lines in complete for c,n in zip(candidate,lines)]
    return dict(structure_matches=matches,width_error=errors)


def run(root,out,config):
    import numpy as np
    from PIL import Image
    metadata=inventory(root,out,config['recordings'])
    cases=json.loads(safe_path(root,root/'typography-cases.json').read_text())
    result=dict(status='measured',metadata=metadata,observations={},stability={},candidates={},comparisons={},spacing={},sensitivity={})
    spacing_pairs={}
    for sid,record in sorted(config['recordings'].items()):
        spec=record['measurement'];case=cases[spec['case']];count=len(case['observedLines'])
        if count!=len(spec['width_ranges']) or count!=len(spec['landmark_cells_x']):raise ValueError('Explicit line protocol mismatch')
        files=extract(root,out,sid,record,metadata[sid]);values=measure(files,spec)
        result['observations'][sid]=values;save(out/sid/'observations.json',values)
        stability,interior=stable_selection(values,metadata[sid]['video']['time_base'],count)
        stability['summaries']={}
        for threshold,floor in VARIANTS:
            key=f'{threshold}-{floor}';complete=[v['measurements'][key] for v in interior if key in v['measurements']]
            stability['summaries'][key]=dict(complete_frames=len(complete),lines=[])
            if not complete:continue
            for i in range(count):
                lines=[v[i] for v in complete]
                stability['summaries'][key]['lines'].append({k:summarize([fn(v) for v in lines]) for k,fn in {
                    'width':lambda v:v['bounds'][2]-v['bounds'][0],
                    'left':lambda v:v['bounds'][0]+spec['crop'][0],
                    'top':lambda v:v['bounds'][1]+spec['crop'][1],
                    'height':lambda v:v['bounds'][3]-v['bounds'][1],
                    'contrast':lambda v:v['contrast_p90'],'edge_energy':lambda v:v['normalized_edge_energy']}.items()})
            stability['summaries'][key]['ink_top_advance']=summarize([v[1]['bounds'][1]-v[0]['bounds'][1] for v in complete]) if count==2 else None
        result['stability'][sid]=stability
        candidates={};result['candidates'][sid]={}
        for size in [101+i*.25 for i in range(21)]:
            name=f'size-{size:g}';m,a,b=render(root,out,sid,case,name,dict(size=size))
            structure=line_strings(case['text'],m['lines'])==case['observedLines']
            candidates[name]=(m,a,b)
            result['candidates'][sid][name]=candidate_errors(b,interior,BASELINE,count)
            result['candidates'][sid][name]['structure_matches'] &= structure
            for threshold,floor in VARIANTS:
                for alpha in [96,127,160]:
                    key=f'{threshold}-{floor}-alpha-{alpha}'
                    ink=ink_bounds(np.asarray(Image.open(out/'probes'/sid/name/'text.png'))[:,:,-1]>alpha)
                    entry=candidate_errors(ink,interior,f'{threshold}-{floor}',count);entry['structure_matches'] &= structure
                    result['sensitivity'].setdefault(key,{}).setdefault(sid,{})[name]=entry
        # First fully supported observation remains qualified by appearance; not an activation event.
        eligible=[v for v in values if v['geometry'] is not None]
        early=eligible[0];late=interior[len(interior)//2]
        result['comparisons'][sid]={};result['spacing'][sid]={}
        by_pts={v['pts']:p for p,(_,v) in files}
        for label,row in [('early',early),('stable',late)]:
            image=Image.open(by_pts[row['pts']]);comparisons={}
            for name in ['size-102','size-103','size-103.25','size-103.5','size-104']:
                m,a,b=candidates[name];comparisons[name]={}
                for threshold,floor in VARIANTS:
                    key=f'{threshold}-{floor}'
                    if key not in row['measurements']:continue
                    comp=compare(image,[v['bounds'] for v in row['measurements'][key]],a,b,m,threshold,floor)
                    for line in comp['lines']:
                        line['baseline_proxy']+=spec['crop'][1]
                        line['origin_translation'][0]+=spec['crop'][0];line['origin_translation'][1]+=spec['crop'][1]
                    comp.pop('baseline_fit');comparisons[name][key]=comp
            result['comparisons'][sid][label]=dict(pts=row['pts'],candidates=comparisons)
        for key in early['measurements'].keys() & late['measurements'].keys():
            result['spacing'][sid][key]=[affine_landmarks(a['landmarks'],b['landmarks'])
                for a,b in zip(early['measurements'][key],late['measurements'][key])]
        for i in range(count):
            spacing_pairs.setdefault(str(i),{})[sid]=dict(reference=early['measurements'][BASELINE][i]['landmarks'],
                observed=late['measurements'][BASELINE][i]['landmarks'])
    ids=sorted(result['candidates'])
    result['fit']=select(result['candidates'],ids);result['leave_one_recording_out']=leave_one_out(result['candidates'],ids)
    result['sensitivity_fits']={}
    for key,records in result['sensitivity'].items():
        try:result['sensitivity_fits'][key]=dict(fit=select(records,ids),holdout=leave_one_out(records,ids))
        except ValueError:result['sensitivity_fits'][key]=dict(status='unavailable',reason='Incomplete paragraph foreground support')
    result['spacing_holdout']={line:spacing_holdout(pairs) for line,pairs in spacing_pairs.items()}
    # Existing S08 observations are external evidence, not reselected against S09.
    prior=json.loads((REPO/'docs/reference-data/v3/state-typography.json').read_text())
    # Published per-recording RMSE is a sufficient statistic for the equal-recording loss.
    # Its positive sign is not a signed width observation.
    historical={sid:{name:dict(structure_matches=r['structure_matches'],width_error=[r['width_rmse']])
        for name,r in candidates.items()} for sid,candidates in prior['candidate_geometry'].items()}
    joint={**historical,**result['candidates']}
    result['joint_fit']=select(joint,sorted(joint));result['joint_holdout']=leave_one_out(joint,sorted(joint))
    prior_scales=prior['spacing_and_registration']['within_recording_spacing']
    scale=sum(v['scale'] for v in prior_scales.values())/len(prior_scales)
    result['s08_spacing_prediction']={line:{sid:registered_spacing(p['reference'],p['observed'],scale)
        for sid,p in pairs.items()} for line,pairs in spacing_pairs.items()}
    for sid,record in config['recordings'].items():
        if digest(root/'recordings'/record['file'])!=metadata[sid]['sha256']:raise ValueError('Source changed')
    from paragraph_phases import run as phase_diagnostics
    result['phases']=phase_diagnostics(root,out,config,result,cases)
    save(out/'results.json',result)
    return dict(status=result['status'],recordings=ids,fit=result['fit'],holdout=result['leave_one_recording_out'],joint_fit=result['joint_fit'])


def main():
    root=private_root(REPO/'reference-private');path=root/'s09-state-cases.json'
    if not path.is_file():
        print(json.dumps(dict(status='unavailable',reason='Private s09-state-cases.json is absent')));return
    config=json.loads(safe_path(root,path).read_text())
    if any(not sid.isalnum() for sid in config['recordings']):raise ValueError('Invalid recording identifier')
    missing=[sid for sid,r in config['recordings'].items() if not safe_path(root,root/'recordings'/r['file']).is_file()]
    if missing or not (root/'typography-cases.json').is_file() or not (REPO/'.build/release/ReferenceProbe').is_file():
        print(json.dumps(dict(status='unavailable',reason='Private recordings, known text, or release probe absent',recording_ids=missing)));return
    out=safe_path(root,root/'analysis/s09-state/current');out.mkdir(parents=True,exist_ok=True)
    print(json.dumps(run(root,out,config),indent=2))

if __name__=='__main__':main()
