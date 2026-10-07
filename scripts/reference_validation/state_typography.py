"""Private state-controlled typography study; no automatic correspondence claim.

Read the inspected private state-typography-cases.json manifest. All source text,
frames, unfiltered metadata, and diagnostics remain under reference-private.
Public numerical evidence requires separate review. No source file is modified.
"""
import argparse
from fractions import Fraction
import hashlib
import io
import json
from pathlib import Path
import subprocess
from analyze import REPO, private_root, safe_path, save, probe, foreground, ink_bounds
from core import timing, registered_mask
from state_core import stable_intervals, summarize, affine_landmarks, spacing_holdout
from typography_core import line_strings, select, leave_one_out
from calibrate import render, compare


def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):h.update(block)
    return h.hexdigest()


def srgb_screenshot(path):
    from PIL import Image, ImageCms
    image=Image.open(path)
    profile=image.info.get('icc_profile')
    if not profile:raise ValueError('Screenshot ICC profile is required')
    return ImageCms.profileToProfile(image,ImageCms.ImageCmsProfile(io.BytesIO(profile)),
                                    ImageCms.createProfile('sRGB'),outputMode='RGB')


def landmarks(mask,bounds,cells):
    import numpy as np
    x,y,r,b=bounds;result=[]
    for lo,hi in zip(cells,cells[1:]):
        weights=mask[y:b,lo:hi].sum(0)
        if not weights.sum():raise ValueError('Insufficient landmark support')
        result.append(float(np.dot(weights,np.arange(lo,hi))/weights.sum()))
    return result


def line_measure(image, bounds, cells, threshold, floor, planes=None, mask=None):
    import numpy as np
    from PIL import Image, ImageFilter
    if mask is None: mask=foreground(image,threshold,floor)
    x,y,r,b=bounds
    if planes is None:
        gray=np.asarray(image.convert('RGB')).astype(float).mean(2)
        background=np.asarray(Image.fromarray(gray.astype('uint8')).filter(ImageFilter.GaussianBlur(18))).astype(float)
    else: gray,background=planes
    patch=gray[y:b,x:r];contrast=(gray-background)[y:b,x:r]
    return dict(landmarks=landmarks(mask,bounds,cells),
        contrast_p90=float(np.percentile(contrast,90)),
        normalized_edge_energy=float(abs(np.diff(patch,axis=1)).sum()/np.maximum(contrast,0).sum()),
        group_contrast_p90=[float(np.percentile(part,90)) for part in np.array_split(contrast,3,axis=1)])


def inventory(root,out,records):
    import numpy as np
    result={}
    for sid,record in sorted(records.items()):
        path=safe_path(root,root/'recordings'/record['file']);sub=out/sid;sub.mkdir(exist_ok=True)
        original=digest(path)
        metadata=probe(path,'-show_format','-show_streams');save(sub/'metadata.json',metadata)
        video=next(s for s in metadata['streams'] if s['codec_type']=='video')
        audio=next((s for s in metadata['streams'] if s['codec_type']=='audio'),None)
        frames=probe(path,'-select_streams','v:0','-show_frames','-show_entries','frame=pts,duration')['frames']
        packets=probe(path,'-select_streams','v:0','-show_packets','-show_entries','packet=pts,duration,flags')['packets']
        save(sub/'frames.json',frames);save(sub/'packets.json',packets)
        base=Fraction(video['time_base'])
        cadence=timing([f['pts'] for f in frames],base.numerator,base.denominator)
        raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-vf',
            'crop=1040:1400:72:500,scale=260:350:flags=area,format=gray',
            '-fps_mode','passthrough','-enc_time_base',video['time_base'],'-f','rawvideo','-'])
        reduced=np.frombuffer(raw,dtype='uint8').reshape(-1,350,260)
        if len(reduced)!=len(frames):raise ValueError('Frame/PTS count mismatch')
        changes=[float(abs(b.astype('int16')-a).mean()) for a,b in zip(reduced,reduced[1:])]
        result[sid]=dict(file=record['file'],sha256=original,format=metadata['format']['format_name'],
            video={k:video.get(k) for k in ['codec_name','profile','width','height','pix_fmt','color_range','color_space','color_transfer','color_primaries','r_frame_rate','avg_frame_rate','time_base','start_time','duration','nb_frames']},
            audio={k:audio.get(k) for k in ['codec_name','profile','sample_rate','channels','channel_layout','start_time','duration']} if audio else None,
            timing=cadence,discard_packets=sum('D' in p['flags'] for p in packets),
            duplicate_roi_pairs=sum(v==0 for v in changes),near_duplicate_roi_pairs=sum(v<.05 for v in changes),
            correspondence=record['correspondence'])
        if digest(path)!=original:raise ValueError('Source changed during analysis')
    return result


def run(root,out,config):
    import numpy as np
    from PIL import Image, ImageFilter
    metadata=inventory(root,out,config['recordings'])
    cases=json.loads(safe_path(root,root/'typography-cases.json').read_text())
    observations={};candidate_records={};comparisons={};screenshots={};stability={};sensitivity_records={};api_diagnostics={}
    for sid,record in sorted(config['recordings'].items()):
        if 'measurement' not in record:continue
        spec=record['measurement'];case=cases[spec['case']];sub=out/sid
        if len(case['observedLines'])!=1:raise ValueError('This inspected protocol requires a single target line')
        info=metadata[sid];video=info['video']
        if (video['color_space'],video['color_transfer'],video['color_primaries'],video['color_range'])!=('bt709','bt709','bt709','pc'):
            raise ValueError('This study requires inspected full-range Rec.709 inputs')
        frames=json.loads((sub/'frames.json').read_text());lo,hi=spec['pts_range']
        selected=[(i,f) for i,f in enumerate(frames) if lo<=f['pts']<=hi]
        if not selected:raise ValueError('Empty inspected interval')
        # Preserve decoded frame order and pair it with original integer PTS.
        destination=sub/'frames';destination.mkdir(exist_ok=True)
        x0,y0,x1,y1=spec['crop'];w=x1-x0;h=y1-y0
        vf=f"select=between(n\\,{selected[0][0]}\\,{selected[-1][0]}),colorspace=all=bt709:trc=srgb:range=pc,crop={w}:{h}:{x0}:{y0}"
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(root/'recordings'/record['file']),'-vf',vf,
            '-fps_mode','passthrough','-enc_time_base',video['time_base'],str(destination/'%05d.png')],check=True)
        files=sorted(destination.glob('*.png'))
        if len(files)!=len(selected):raise ValueError('Extracted frame/PTS count mismatch')
        image_by_pts={};values=[];cells=spec['landmark_cells_x']
        variants=[(t,floor) for t in [15,25,35] for floor in [100,145]]
        for path,(index,frame) in zip(files,selected):
            image=Image.open(path).convert('RGB');pts=frame['pts'];image_by_pts[pts]=path
            measures={}
            gray=np.asarray(image).astype(float).mean(2)
            background=np.asarray(Image.fromarray(gray.astype('uint8')).filter(ImageFilter.GaussianBlur(18))).astype(float)
            for threshold,floor in variants:
                mask=(gray-background>threshold)&(gray>floor)
                bx0,by0,bx1,by1=spec['search_roi']
                possible=ink_bounds(mask[by0:by1,bx0:bx1],bx0,by0)
                matches=[b for b in possible if spec['width_range'][0]<=b[2]-b[0]<=spec['width_range'][1]
                         and 60<=b[3]-b[1]<=120]
                if len(matches)!=1:continue
                bounds=matches[0]
                measures[f'{threshold}-{floor}']=dict(bounds=bounds,**line_measure(image,bounds,cells,threshold,floor,(gray,background),mask))
            baseline=measures.get('25-145')
            values.append(dict(pts=pts,index=index,measurements=measures,
                geometry=[baseline['bounds'][1],baseline['bounds'][2]-baseline['bounds'][0]] if baseline else None))
        observations[sid]=values
        intervals={str(t):stable_intervals(values,video['time_base'],[t,t],.5) for t in [1,2,3]}
        stability[sid]=intervals
        if not intervals['2']:raise ValueError('No sufficiently stable identified interval')
        stable=max(intervals['2'],key=lambda r:r['duration_seconds'])
        # Exclude 0.1 s at both observed stability boundaries to avoid transition-edge appearance.
        guard_ticks=int(Fraction(1,10)/Fraction(video['time_base']))
        settled=[v for v in values if stable['first_pts']+guard_ticks<=v['pts']<=stable['last_pts']-guard_ticks]
        if len(settled)<3:raise ValueError('Insufficient interior stable observations')
        stability[sid]['comparison_interval']={k:v for k,v in dict(first_pts=settled[0]['pts'],last_pts=settled[-1]['pts'],count=len(settled),duration_seconds=float((settled[-1]['pts']-settled[0]['pts'])*Fraction(video['time_base']))).items()}
        candidate_records[sid]={};candidate_data={}
        for size in [101+i*.25 for i in range(21)]:
            name=f'size-{size:g}'
            m,a,b=render(root,out,sid,case,name,dict(size=size))
            matches=line_strings(case['text'],m['lines'])==case['observedLines'] and len(b)==1
            candidate_data[name]=(m,a,b)
            candidate_records[sid][name]=dict(structure_matches=matches,
                width_error=[b[0][2]-b[0][0]-(v['measurements']['25-145']['bounds'][2]-v['measurements']['25-145']['bounds'][0]) for v in settled])
        for threshold,floor in variants:
            for cutoff in [96,127,160]:
                key=f'{threshold}-{floor}-alpha-{cutoff}'
                sensitivity_records.setdefault(key,{})[sid]={}
                for name,(m,_,_) in candidate_data.items():
                    pixels=np.asarray(Image.open(out/'probes'/sid/name/'text.png'))[:,:,-1]>cutoff
                    ink=ink_bounds(pixels)
                    measurements=[v['measurements'][f'{threshold}-{floor}']['bounds'] for v in settled]
                    sensitivity_records[key][sid][name]=dict(structure_matches=len(ink)==1,
                        width_error=[ink[0][2]-ink[0][0]-(b[2]-b[0]) for b in measurements])
        api_diagnostics[sid]={}
        for name,options in {'emphasized':dict(fontSelection='emphasized'),
            'language-ja':dict(language='ja'),'optical-none':dict(opticalSize='none'),
            'weight-0.3':dict(weight=.3),'weight-0.4':dict(weight=.4),'weight-0.5':dict(weight=.5)}.items():
            m,_,b=render(root,out,sid,case,name,dict(size=103.25,**options))
            api_diagnostics[sid][name]=dict(fonts=m['fonts'],lines=m['lines'],ink_bounds=b)
        # Original screenshot is an independent observation, not part of fitting.
        screenshot=srgb_screenshot(safe_path(root,root/'screenshots'/case['file']))
        sx,sy,sr,sb=case['roi'];shot_bounds=ink_bounds(foreground(screenshot)[sy:sb,sx:sr],sx,sy)
        screenshots[spec['case']]=dict(bounds=shot_bounds,landmarks=landmarks(foreground(screenshot),shot_bounds[0],[x+x0 for x in cells]))
        comparisons[sid]={};representative=settled[len(settled)//2]
        early=next(v for v in values if v['geometry'] is not None)
        screenshot_y=min((v for v in values if v['geometry'] is not None),
                         key=lambda v:abs(v['measurements']['25-145']['bounds'][1]+y0-shot_bounds[0][1]))
        for label,observation in [('first_detectable',early),('screenshot_y',screenshot_y),('settled',representative)]:
            image=Image.open(image_by_pts[observation['pts']]);measures=observation['measurements'];records={}
            for name,(m,a,b) in candidate_data.items():
                if name not in ['size-102','size-103','size-103.25','size-103.5','size-104']:continue
                records[name]=[]
                for threshold,floor in variants:
                    item=measures.get(f'{threshold}-{floor}')
                    if item:
                        result=compare(image,[item['bounds']],a,b,m,threshold,floor)
                        for line in result['lines']:
                            line['baseline_proxy']+=y0
                            line['origin_translation'][0]+=x0;line['origin_translation'][1]+=y0
                        # Keep native baseline proxies; avoid publishing the crop-local fit.
                        result.pop('baseline_fit')
                        records[name].append(result)
            comparisons[sid][label]=dict(pts=observation['pts'],candidates=records,
                landmarks_relative_to_screenshot={key:affine_landmarks(screenshots[spec['case']]['landmarks'],[x+x0 for x in value['landmarks']]) for key,value in measures.items()})
        summaries={}
        for threshold,floor in variants:
            key=f'{threshold}-{floor}';measurements=[v['measurements'][key] for v in settled if key in v['measurements']]
            summaries[key]=dict(width=summarize([v['bounds'][2]-v['bounds'][0] for v in measurements]),
                ink_top=summarize([v['bounds'][1]+y0 for v in measurements]),
                ink_left=summarize([v['bounds'][0]+x0 for v in measurements]),
                height=summarize([v['bounds'][3]-v['bounds'][1] for v in measurements]),
                contrast=summarize([v['contrast_p90'] for v in measurements]),
                edge_energy=summarize([v['normalized_edge_energy'] for v in measurements]))
        stability[sid]['selected']=stable;stability[sid]['summaries']=summaries
    ids=sorted(candidate_records)
    fit=select(candidate_records,ids) if ids else None
    holdout=leave_one_out(candidate_records,ids) if len(ids)>1 else None
    available={r['correspondence']['case'] for r in config['recordings'].values()}
    result=dict(status='measured_with_missing_correspondence' if set(config['required_cases'])-available else 'measured',
        missing_required_cases=sorted(set(config['required_cases'])-available),metadata=metadata,
        observations=observations,stability=stability,candidate_records=candidate_records,
        fit=fit,leave_one_recording_out=holdout,comparisons=comparisons,screenshots=screenshots,
        sensitivity={key:dict(fit=select(records,ids),leave_one_recording_out=leave_one_out(records,ids)) for key,records in sensitivity_records.items()},
        api_diagnostics=api_diagnostics)
    for sid,record in config['recordings'].items():
        if digest(root/'recordings'/record['file'])!=metadata[sid]['sha256']:raise ValueError('Source changed')
    result['supplement']=supplement(root,out,result)
    result['static_holdout']=static_holdout(root,out,cases,config['required_cases'],fit['candidate']) if fit else {}
    save(out/'results.json',result)
    return dict(status=result['status'],missing_required_cases=result['missing_required_cases'],
                recordings=len(metadata),fit=fit,leave_one_recording_out=holdout)



def supplement(root,out,result):
    """Additional localization and held-out spacing checks from saved observations."""
    import numpy as np
    from PIL import Image
    records={};windows={}
    for sid,comparisons in result['comparisons'].items():
        observations=result['observations'][sid]
        by_pts={v['pts']:v for v in observations}
        early=by_pts[comparisons['screenshot_y']['pts']]['measurements']['25-145']['landmarks']
        late=by_pts[comparisons['settled']['pts']]['measurements']['25-145']['landmarks']
        records[sid]=dict(reference=early,observed=late,fit=affine_landmarks(early,late))
        row=by_pts[comparisons['settled']['pts']]
        index=observations.index(row)
        image=Image.open(out/sid/'frames'/f'{index+1:05d}.png')
        nx,ny,nr,nb=row['measurements']['25-145']['bounds']
        reference=foreground(image)[ny-8:nb+8,nx-8:nr+8]
        yy,xx=np.nonzero(reference)
        reference_set=set(zip(xx.tolist(),yy.tolist()))
        alpha=np.asarray(Image.open(out/'probes'/sid/'size-103.25'/'text.png'))[:,:,-1]>127
        cx,cy,cr,cb=ink_bounds(alpha)[0]
        yy,xx=np.nonzero(alpha)
        candidate_set=set(zip((xx-cx+8).tolist(),(yy-cy+8).tolist()))
        windows[sid]={str(radius):registered_mask(reference_set,candidate_set,radius) for radius in [3,5,7]}
    holdout=spacing_holdout(records) if len(records)>1 else {}
    return dict(within_recording_spacing={sid:value['fit'] for sid,value in records.items()},
                held_out_spacing=holdout,registration_windows=windows)



def static_holdout(root,out,cases,ids,candidate):
    """Independent screenshot checks after recording-only parameter selection."""
    result={}
    size=float(candidate.removeprefix('size-'))
    for sid in ids:
        case=cases[sid]
        image=srgb_screenshot(safe_path(root,root/'screenshots'/case['file']))
        x,y,r,b=case['roi']
        metrics,alpha,ink=render(root,out,'static'+sid,case,candidate,dict(size=size))
        result[sid]={}
        for floor in [80,100,125,145]:
            bounds=ink_bounds(foreground(image,25,floor)[y:b,x:r],x,y)
            result[sid][str(floor)]=dict(bounds=bounds,comparison=compare(image,bounds,alpha,ink,metrics,25,floor))
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.parse_args()
    root=private_root(REPO/'reference-private');path=root/'state-typography-cases.json'
    if not path.exists():
        print(json.dumps(dict(status='unavailable',reason='Private state-typography-cases.json is absent')));return
    config=json.loads(safe_path(root,path).read_text())
    missing=[sid for sid,r in config['recordings'].items() if not safe_path(root,root/'recordings'/r['file']).is_file()]
    if missing:
        print(json.dumps(dict(status='unavailable',reason='Required recording files are absent',recording_ids=missing)));return
    if not (root/'typography-cases.json').is_file() or not (REPO/'.build/release/ReferenceProbe').is_file():
        print(json.dumps(dict(status='unavailable',reason='Private known text or release ReferenceProbe is absent')));return
    if any(not sid.isalnum() for sid in config['recordings']):raise ValueError('Invalid recording identifier')
    out=safe_path(root,root/'analysis/state-typography/current');out.mkdir(parents=True,exist_ok=True)
    print(json.dumps(run(root,out,config),indent=2))

if __name__=='__main__':main()
