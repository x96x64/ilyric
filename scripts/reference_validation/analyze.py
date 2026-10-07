"""Internal physical-reference analysis. All outputs remain private.

Requires ffmpeg/ffprobe, NumPy, Pillow, and the release ReferenceProbe target.
The optional private cases.json contains manually transcribed text and ROIs.
No OCR, network access, source-media export, or public-profile write occurs here.
"""
import argparse
import json
from pathlib import Path
import subprocess
from core import timing, fit, errors

REPO = Path(__file__).resolve().parents[2]


def private_root(path):
    root = Path(path).resolve()
    expected = (REPO / 'reference-private').resolve()
    if root != expected or root.parent != REPO:
        raise ValueError('Analysis is restricted to the ignored reference-private directory')
    for candidate in (root/'input-sentinel', root/'analysis/result.json'):
        if subprocess.run(['git','check-ignore','-q',str(candidate)],cwd=REPO).returncode:
            raise ValueError('Private inputs and diagnostics must be ignored by Git')
    tracked = subprocess.check_output(['git','ls-files','reference-private'],cwd=REPO)
    if tracked.strip(): raise ValueError('Private material is tracked by Git')
    return root


def safe_path(root, path):
    root = root.resolve()
    resolved = path.resolve()
    if root not in resolved.parents: raise ValueError('Private path escapes its root')
    return resolved


def save(path, value):
    path.write_text(json.dumps(value,indent=2,ensure_ascii=False,allow_nan=False)+'\n')


def probe(path, *options):
    return json.loads(subprocess.check_output(['ffprobe','-v','error',*options,'-of','json',str(path)]))


def inventory(root, out):
    from PIL import Image, ImageCms
    import io
    result={'screenshots':{},'recordings':{}}
    for index,path in enumerate(sorted((root/'screenshots').glob('*.PNG')),1):
        path=safe_path(root,path)
        with Image.open(path) as image:
            icc=image.info.get('icc_profile')
            profile=ImageCms.getProfileName(ImageCms.ImageCmsProfile(io.BytesIO(icc))).strip() if icc else 'Unknown'
            result['screenshots'][f'S{index:02}']={'file':str(path.relative_to(root)),
                'size':list(image.size),'profile':profile,'mode':image.mode}
    for index,path in enumerate(sorted((root/'recordings').glob('*.MP4')),1):
        path=safe_path(root,path);sid=f'V{index:02}'
        metadata=probe(path,'-show_format','-show_streams');save(out/(sid+'-probe.json'),metadata)
        video=next(s for s in metadata['streams'] if s['codec_type']=='video')
        frames=probe(path,'-select_streams','v:0','-show_frames','-show_entries','frame=pts,pts_time,duration,duration_time')['frames']
        packets=probe(path,'-select_streams','v:0','-show_packets','-show_entries','packet=pts,dts,duration,flags')['packets']
        save(out/(sid+'-frames.json'),frames);save(out/(sid+'-packets.json'),packets)
        num,den=map(int,video['time_base'].split('/'))
        result['recordings'][sid]={'file':str(path.relative_to(root)),**timing([f['pts'] for f in frames],num,den),
            'discard_packets':sum('D' in p['flags'] for p in packets),
            'container_frames':int(video['nb_frames'])}
    save(out/'manifest.json',result)
    return result


def runs(values, gap=1, minimum=9):
    import numpy as np
    indices=np.flatnonzero(values)
    return [part for part in np.split(indices,np.where(np.diff(indices)>gap)[0]+1) if len(part)>=minimum]


def foreground(image, threshold=25, min_gray=145):
    import numpy as np
    from PIL import Image, ImageFilter
    gray=np.asarray(image.convert('RGB')).astype(float).mean(2)
    background=np.asarray(Image.fromarray(gray.astype('uint8')).filter(ImageFilter.GaussianBlur(18))).astype(float)
    return (gray-background>threshold)&(gray>min_gray)


def ink_bounds(mask, x=0, y=0):
    import numpy as np
    result=[]
    for row in runs(mask.sum(1)>12,gap=14,minimum=7):
        yy,xx=np.nonzero(mask[row[0]:row[-1]+1])
        result.append([int(xx.min())+x,int(row[0])+y,int(xx.max()+1)+x,int(row[-1]+1)+y])
    return result


def static(root, out, manifest):
    from PIL import Image
    results={}
    for sid,item in manifest['screenshots'].items():
        image=Image.open(root/item['file'])
        mask=foreground(image)
        results[sid]={'visible_ink_bounds':ink_bounds(mask[500:1480,85:1095],85,500),
                     'classification':'measured visible ink; not native baselines or layout boxes'}
    save(out/'static-results.json',results)


def typography(root, out):
    import numpy as np
    from PIL import Image
    config=root/'cases.json'
    if not config.exists(): return {'status':'unavailable','reason':'Private known-text cases.json is absent'}
    binary=REPO/'.build/release/ReferenceProbe'
    if not binary.exists(): return {'status':'unavailable','reason':'Build the release ReferenceProbe target'}
    cases=json.loads(config.read_text());results={};masks={}
    for sid,case in cases.items():
        if not sid.isalnum(): raise ValueError('Invalid private case identifier')
        image=Image.open(safe_path(root,root/'screenshots'/case['file'])).convert('RGB')
        x0,y0,x1,y1=case['roi'];native=ink_bounds(foreground(image)[y0:y1,x0:x1],x0,y0)
        results[sid]={'native_ink_bounds':native,'candidates':[]};masks[sid]={}
        for font,size in [('spike',81)]+[('system-bold',s) for s in [99,102,104,105,108]]:
            name=f'{font}-{size}';destination=out/'type'/f'{sid}-{name}';request=out/'type-input.json'
            save(request,dict(text=case['text'],width=987,size=size,lineAdvance=128,font=font,
                              alignment=case.get('alignment','left')))
            subprocess.run([str(binary),str(request),str(destination)],check=True)
            metrics=json.loads((destination/'metrics.json').read_text())
            alpha=np.asarray(Image.open(destination/'text.png'))[:,:,-1]>127
            bounds=ink_bounds(alpha);native_widths=[b[2]-b[0] for b in native]
            results[sid]['candidates'].append(dict(font=font,size=size,fonts=metrics['fonts'],
                line_lengths=[m['length'] for m in metrics['lines']],
                advances=[m['width'] for m in metrics['lines']],ink_bounds=bounds,
                width_error=[b[2]-b[0]-a for a,b in zip(native_widths,bounds)]))
            # Register the first known line only. No whole-screen image metric.
            nx,ny,nr,nb=native[0];cx,cy,cr,cb=bounds[0]
            yy,xx=np.nonzero(alpha[max(0,cy-6):cb+6,max(0,cx-6):cr+6])
            xx=xx+max(0,cx-6)-cx;yy=yy+max(0,cy-6)-cy;values=[]
            for threshold in [15,25,35]:
                ref=foreground(image,threshold)[ny-8:nb+8,nx-8:nr+8];best=(-1,None)
                for dy in range(-5,6):
                    for dx in range(-5,6):
                        x=xx+8+dx;y=yy+8+dy;valid=(x>=0)&(x<ref.shape[1])&(y>=0)&(y<ref.shape[0])
                        intersection=ref[y[valid],x[valid]].sum();iou=float(intersection/(ref.sum()+len(x)-intersection))
                        if iou>best[0]:best=(iou,[dx,dy])
                values.append(dict(threshold=threshold,iou=best[0],registration=best[1]))
            masks[sid][name]=values
    save(out/'typography-results.json',results);save(out/'mask-results.json',masks)
    return {'status':'measured','cases':len(cases)}


def dense(root, out, manifest):
    import numpy as np
    for sid,item in manifest['recordings'].items():
        target=out/(sid+'-gray.raw')
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(root/item['file']),'-map','0:v:0',
            '-vf','crop=1040:1400:72:500,scale=260:350:flags=area,format=gray',
            '-fps_mode','passthrough','-enc_time_base','1:600','-f','rawvideo',str(target)],check=True)
        data=np.memmap(target,dtype='uint8',mode='r').reshape(-1,350,260)
        if len(data)!=item['decoded_frames']: raise ValueError('Decoded frame/PTS count mismatch')
        rows=np.empty((len(data),350))
        for i,frame in enumerate(data): rows[i]=np.abs(np.diff(frame.astype('int16'),axis=1)).mean(1)
        np.save(out/(sid+'-rows.npy'),rows)


def trajectory(rows, frames, radius=13):
    import numpy as np
    # This study's first repeated English focus transition. The initial anchor
    # and time window were selected from inspected frames, not inferred by OCR.
    center=147.;samples=[]
    for i,frame in enumerate(frames):
        t=frame['pts']/600
        if not 2<t<5:continue
        lo=int(round(center))-radius;hi=int(round(center))+radius+1
        w=rows[i,lo:hi];w=np.maximum(0,w-np.percentile(w,10))
        if w.sum()<=0:raise ValueError('Lost text anchor')
        center=float(np.dot(w,np.arange(lo,hi))/w.sum());samples.append([frame['pts'],500+4*center])
    return np.asarray(samples)


def motion(out, manifest):
    import numpy as np
    results={};repeat={};tracks={};sensitivity_results={}
    for sid,item in manifest['recordings'].items():
        data=np.memmap(out/(sid+'-gray.raw'),dtype='uint8',mode='r').reshape(-1,350,260)
        changes=[float(np.abs(data[i].astype('int16')-data[i-1]).mean()) for i in range(1,len(data))]
        repeat[sid]={'exact_duplicate_roi_pairs':sum(d==0 for d in changes),
                     'roi_mad_below_0_05':sum(d<.05 for d in changes),
                     'minimum_roi_mad_8bit':min(changes)}
        if sid not in ('V01','V02','V03'):continue
        if item['time_base']!='1/600':raise ValueError('This study requires explicit 1/600 capture ticks')
        frames=json.loads((out/(sid+'-frames.json')).read_text());rows=np.load(out/(sid+'-rows.npy'))
        variants=[trajectory(rows,frames,r) for r in (11,13,15)];track=variants[1]
        np.savetxt(out/(sid+'-trajectory.csv'),track,delimiter=',',header='pts_ticks_1_over_600,edge_centroid_y_native_px',comments='')
        samples=[(t/600,y) for t,y in track];models={}
        for model in ('hermite','critical'):
            parameters=fit(samples[::2],model,[2+i*.01 for i in range(200)],[.04+i*.01 for i in range(78)])
            parameters['held_out']=errors(samples[1::2],parameters);models[model]=parameters
        results[sid]={'models':models}
        sensitivity=np.ptp(np.array(variants)[:,:,1],axis=0)
        settled=track[track[:,0]>2700,1]
        half=(np.median(track[track[:,0]<1500,1])+np.median(settled))/2
        crossing=np.flatnonzero(track[:,1]<half)[0];a,b=track[crossing-1:crossing+1]
        mid=float((a[0]+(half-a[1])*(b[0]-a[0])/(b[1]-a[1]))/600)
        repeat[sid].update(window_sensitivity_max_px=float(sensitivity.max()),
            window_sensitivity_median_px=float(np.median(sensitivity)),half_crossing_seconds=mid,
            settled_y_mean=float(settled.mean()),settled_y_sd=float(settled.std()))
        tracks[sid]=(samples,mid)
        glyph_rows=np.empty((len(data),350))
        for i,frame in enumerate(data):glyph_rows[i]=np.abs(np.diff(frame[:,7:48].astype('int16'),axis=1)).mean(1)
        glyph=trajectory(glyph_rows,frames);delta=glyph[:,1]-track[:,1];centered=delta-np.median(delta)
        sensitivity_results[sid]={'glyph_vs_line_proxy_median_offset':float(np.median(delta)),
            'centered_rms_difference':float(np.sqrt(np.mean(centered**2))),
            'centered_max_difference':float(np.max(abs(centered))),
            'fixed_0_8_hermite_fit':fit(samples,'hermite',[2.6+i*.01 for i in range(90)],[.8])}

    if 'V01' in results:
        base=results['V01']['models']['critical']
        for sid in ('V02','V03'):
            if sid not in tracks:continue
            samples,mid=tracks[sid];shift=mid-tracks['V01'][1];registered=dict(base);registered['onset']+=shift
            repeat[sid].update(registration_seconds=shift,capture_holdout_after_phase_registration=errors(samples,registered))
    save(out/'motion-results.json',results);save(out/'repeat-results.json',repeat)
    save(out/'anchor-sensitivity.json',sensitivity_results)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--metadata-only',action='store_true')
    args=parser.parse_args();root=private_root(REPO/'reference-private')
    if not root.is_dir() or not list((root/'screenshots').glob('*.PNG')) or not list((root/'recordings').glob('*.MP4')):
        print(json.dumps({'status':'unavailable','reason':'Private screenshots or recordings are absent'}));return
    try:import numpy;import PIL
    except ImportError:
        print(json.dumps({'status':'unavailable','reason':'NumPy and Pillow are required for private analysis'}));return
    out=safe_path(root,root/'analysis');out.mkdir(exist_ok=True)
    manifest=inventory(root,out);summary={'status':'measured','screenshots':len(manifest['screenshots']),'recordings':len(manifest['recordings'])}
    if not args.metadata_only:
        static(root,out,manifest);summary['typography']=typography(root,out)
        dense(root,out,manifest);motion(out,manifest)
        from appearance import measure
        measure(root,out,manifest,save,runs)
    save(out/'result.json',summary);print(json.dumps(summary))

if __name__=='__main__':main()
