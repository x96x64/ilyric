"""Localized appearance diagnostics for the inspected corpus, not a material model."""
import json
import subprocess
import numpy as np
from PIL import Image, ImageFilter


def measure(root, out, manifest, save, runs):
    ui={};material={}
    for sid,item in manifest['screenshots'].items():
        image=Image.open(root/item['file']).convert('RGB');gray=np.asarray(image).astype(float).mean(2)
        background=np.asarray(Image.fromarray(gray.astype('uint8')).filter(ImageFilter.GaussianBlur(25))).astype(float)
        contrast=gray-background;values={}
        for name,box,threshold in [('handle',[450,185,730,220],4),('title',[330,320,980,390],20),
                                   ('artist',[345,390,980,445],10),('progress',[80,1660,1100,1720],5),
                                   ('volume',[155,2160,995,2240],8)]:
            if sid in ('S02','S08') and name in ('progress','volume'):
                values[name]=None;continue
            x0,y0,x1,y1=box;ys,xs=np.nonzero(contrast[y0:y1,x0:x1]>threshold)
            values[name]=[int(xs.min()+x0),int(ys.min()+y0),int(xs.max()+x0+1),int(ys.max()+y0+1)] if len(xs) else None
        if sid in ('S01','S06'):
            mask=contrast[720:810,60:300]>(2 if sid=='S01' else 25)
            values['dot_x_spans']=[[int(r[0])+60,int(r[-1]+1)+60] for r in runs(mask.sum(0)>8,minimum=1)]
            values['dot_y_spans']=[[int(r[0])+720,int(r[-1]+1)+720] for r in runs(mask.sum(1)>20,minimum=1)]
        ui[sid]=values
    for sid,item in manifest['recordings'].items():
        frames=json.loads((out/(sid+'-frames.json')).read_text());times=np.array([f['pts']/600 for f in frames])
        raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(root/item['file']),
            '-vf','select=not(mod(n\\,120)),crop=40:1600:1120:550,scale=4:160:flags=area,format=rgb24',
            '-fps_mode','passthrough','-enc_time_base','1:600','-f','rawvideo','-'])
        data=np.frombuffer(raw,dtype='uint8').reshape(-1,160,4,3).astype(float)
        means=data.mean((1,2));gradient=data[:,:40].mean((1,2))-data[:,-40:].mean((1,2))
        material[sid]={'strip_mean_rgb_first':means[0].tolist(),'strip_mean_rgb_range':np.ptp(means,axis=0).tolist(),
            'strip_mean_rgb_temporal_sd':means.std(0).tolist(),
            'vertical_rgb_gradient_range':np.ptp(gradient,axis=0).tolist(),
            'sample_pts':[frames[i]['pts'] for i in range(0,len(frames),120)]}
        if sid not in ('V01','V02','V03'):continue
        data=np.memmap(out/(sid+'-gray.raw'),dtype='uint8',mode='r').reshape(-1,350,260)
        levels=[]
        for lo,hi in [(7,44),(50,110),(115,177)]:
            fg=np.percentile(data[:,54:73,lo:hi],90,axis=(1,2))
            bg=np.median(data[:,42:49,lo:hi],axis=(1,2));contrast=fg-bg
            selected=(times>.2)&(times<2.8);values=contrast[selected];t=times[selected]
            low,high=np.percentile(values,[10,90]);cross=np.flatnonzero(values>low+(high-low)*.5)
            observable=high-low>=15 and len(cross)>0
            levels.append({'x_range':[72+lo*4,72+hi*4],'contrast_p10_p90':[float(low),float(high)],
                'half_change_time':float(t[cross[0]]) if observable else None,
                'status':'contrast crossing' if observable else 'unavailable: insufficient contrast change'})
        material[sid]['first_line_contrast_groups']=levels
    save(out/'ui-results.json',ui);save(out/'material-highlight-results.json',material)
