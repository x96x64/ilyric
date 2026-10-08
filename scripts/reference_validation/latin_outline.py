"""Private native-resolution Latin outline experiment for the established V01–V03 passage."""
import json,subprocess
from pathlib import Path
from analyze import REPO,private_root,safe_path,save,probe
from state_typography import digest
from motion_core import crossing,fit_grid,score,shape
from latin_outline_core import decompose,relative_fit,residual_score,register_profile

# Inspected spatial windows, not text units or renderer constants. Known private
# correspondence is inherited from the previous gate; no OCR or new shaping.
WINDOWS=[(0,105,250),(0,400,530),(0,710,840),(1,105,250),(1,350,490),(1,600,720),(2,105,250),(2,300,420)]


def normalize(p,column=True):
 import numpy as np
 bg=np.median(np.concatenate([p[:8],p[-8:]]),axis=0)
 value=np.maximum(0,p-bg);peak=np.percentile(value,95,axis=0 if column else None)
 return np.clip(value/np.maximum(peak,20),0,1)


def main():
 root=private_root(REPO/'reference-private');old=root/'analysis/motion-composition';manifest=root/'analysis/manifest.json'
 if not manifest.is_file() or not (old/'source-hashes.json').is_file():
  print(json.dumps(dict(status='unavailable',reason='Private English motion inventory absent')));return
 m=json.loads(manifest.read_text())['recordings'];ids=['V01','V02','V03'];hashes=json.loads((old/'source-hashes.json').read_text())
 if any(s not in m or not safe_path(root,root/m[s]['file']).is_file() for s in ids):
  print(json.dumps(dict(status='unavailable',reason='Original English recordings absent')));return
 import numpy as np
 from PIL import Image,ImageFilter
 from outline_core import vertical_edges
 out=safe_path(root,root/'analysis/latin-outline');out.mkdir(exist_ok=True)
 prior=json.loads((old/'results.json').read_text());archived=json.loads((REPO/'docs/reference-data/v9/motion.json').read_text());archived.pop('evidence_status')
 if prior!=archived:raise ValueError('Reproduce archived motion evidence before extending it')
 oldrows=json.loads((old/'observations.json').read_text());ptssets={};data={};reproduced={}
 for sid in ids:
  source=safe_path(root,root/m[sid]['file'])
  if digest(source)!=hashes[sid]:raise ValueError('Original hash mismatch')
  frames=probe(source,'-select_streams','v:0','-show_frames','-show_entries','frame=pts')['frames']
  if [x['pts'] for x in frames]!=[x['pts'] for x in json.loads((root/f'analysis/{sid}-frames.json').read_text())]:raise ValueError('PTS mismatch')
  pts=[f['pts'] for f in frames if 1200<f['pts']<3000];ptssets[sid]=pts
  target=out/(sid+'-native.raw')
  vf='select=between(pts\\,1201\\,2999),colorspace=all=bt709:trc=srgb:range=pc,crop=1000:850:80:680'
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vf',vf,'-fps_mode','passthrough','-enc_time_base','1:600','-pix_fmt','rgb24','-f','rawvideo',str(target)],check=True)
  raw=np.memmap(target,dtype='uint8',mode='r').reshape(-1,850,1000,3)
  if len(raw)!=len(pts):raise ValueError('Native frames/PTS mismatch')
  data[sid]=raw;reproduced[sid]=dict(hash_verified=True,selected_frames=len(pts),first_pts=pts[0],last_pts=pts[-1])
 # One shared native template from a late inspected V01 observation. No per-file
 # origin or template reset is permitted. Static local-template constants are
 # measurement references, not fitted per-frame rendering offsets.
 template_index=min(range(len(ptssets['V01'])),key=lambda i:abs(ptssets['V01'][i]-2826))
 template=np.asarray(data['V01'][template_index],float).mean(2)
 base_anchor=next(r['first_centroid'] for r in oldrows if r['source']=='V01' and r['pts']==ptssets['V01'][template_index])
 results={};allrows={};controls=[]
 for variant,threshold,column in [('global',.5,False),('normalized',.5,True),('threshold35',.35,True),('threshold65',.65,True)]:
  rows=[]
  refs=[]
  for line,x0,x1 in WINDOWS:
   y=699+125*line-680;patch=template[y:y+124,x0-80:x1-80];norm=normalize(patch,column)
   refs.append((norm>threshold).mean(1))
  for sid in ids:
   track={r['pts']:r['first_centroid'] for r in oldrows if r['source']==sid}
   for index,pts in enumerate(ptssets[sid]):
    frame=np.asarray(data[sid][index],float).mean(2);guess=round(track[pts]-base_anchor);frame_rows=[]
    for cell,(line,x0,x1) in enumerate(WINDOWS):
     y=699+125*line-680;patch=frame[y+guess-14:y+guess+138,x0-80:x1-80]
     if patch.shape!=(152,x1-x0):raise ValueError('Outline window escaped crop')
     norm=normalize(patch,column);registered=register_profile(refs[cell],(norm>threshold).mean(1),14)
     if registered['status']!='measured':continue
     shift=guess+registered['shift'];record=dict(source=sid,pts=pts,line=line,cell=cell,shift=shift,correlation=registered['score'])
     if variant=='normalized':
      narrower=register_profile(refs[cell],(norm>threshold).mean(1)[4:-4],10)
      record['narrow_window']=narrower
     frame_rows.append(record);rows.append(record)
    if len(frame_rows)>=6:
     d=decompose(frame_rows)
     for row in frame_rows:
      row.update(common=d['translation'],residual=row['shift']-d['translation'])
      if variant=='normalized':
       line,x0,x1=WINDOWS[row['cell']];y=699+125*line-680;dy=round(d['translation'])
       reference=normalize(template[y:y+124,x0-80:x1-80])>.5
       observed=normalize(frame[y+dy:y+dy+124,x0-80:x1-80])>.5
       row['contours']=vertical_edges(reference.T.tolist(),observed.T.tolist(),limit=10)
  allrows[variant]=rows
  supported=[r for r in rows if 'common' in r];tracks={s:sorted({(r['pts']/600,r['common']) for r in supported if r['source']==s}) for s in ids}
  # Progress is an observed normalized common displacement, not native timing.
  for s in ids:
   values=tracks[s];a=float(np.median([y for t,y in values if t<2.5]));b=float(np.median([y for t,y in values if t>4.5]))
   for r in supported:
    if r['source']==s:r['progress']=float(np.clip((a-r['common'])/(a-b),0,1))
  fits={}
  for held in ids:
   train=[r for r in supported if r['source']!=held];test=[r for r in supported if r['source']==held];coefficient=relative_fit(train)
   fits[held]=dict(coefficient=coefficient,rigid=residual_score(test),relative=residual_score(test,coefficient))
  results[variant]=dict(accepted=len(rows),expected=len(ids)*180*len(WINDOWS),supported=len(supported),relative_holdouts=fits,
    line_residuals={s:{str(l):dict(early=float(np.mean([r['residual'] for r in supported if r['source']==s and r['line']==l and r['pts']<1500])),late=float(np.mean([r['residual'] for r in supported if r['source']==s and r['line']==l and r['pts']>2700]))) for l in range(3)} for s in ids})
  if variant in ['global','normalized']:
   fits_motion={}
   for s,track in tracks.items():
    mid=crossing(track);p=fit_grid(track[::2],'critical',[mid-.25+i*.001 for i in range(151)],[.081])
    fits_motion[s]=dict(parameters=p,held_out={h:dict(errors=score(v,p,crossing(v)-mid),phase=crossing(v)-mid,sensitivity={str(d):score(v,p,crossing(v)-mid+d) for d in [-1/60,1/60]}) for h,v in tracks.items() if h!=s})
   results[variant]['motion']=fits_motion
   combined={}
   for train in ids:
    coefficient=relative_fit([r for r in supported if r['source']==train])
    p=fits_motion[train]['parameters'];combined[train]={}
    for held in ids:
     if held==train:continue
     phase=crossing(tracks[held])-crossing(tracks[train]);errors={key:[] for key in ['rigid','relative']}
     overlaps={key:[0,0] for key in errors}
     for r in supported:
      if r['source']!=held:continue
      progress=shape(r['pts']/600,p['onset']+phase,p['scale'],'critical')
      common=p['offset']+p['amplitude']*progress
      line,x0,x1=WINDOWS[r['cell']];y=699+125*line-680
      index=ptssets[held].index(r['pts']);frame=data[held][index]
      reference=normalize(template[y:y+124,x0-80:x1-80],column)>threshold
      for model in errors:
       predicted=common+(coefficient*(line-1)*(1-progress) if model=='relative' else 0)
       errors[model].append(r['shift']-predicted)
       dy=round(predicted);patch=frame[y+dy:y+dy+124,x0-80:x1-80].astype(float).mean(2)
       mask=normalize(patch,column)>threshold
       overlaps[model][0]+=int(np.count_nonzero(mask&reference));overlaps[model][1]+=int(np.count_nonzero(mask|reference))
     combined[train][held]=dict(coefficient=coefficient,models={key:dict(rmse=float(np.sqrt(np.mean(np.array(e)**2))),maximum=max(map(abs,e)),common_origin_iou=overlaps[key][0]/overlaps[key][1]) for key,e in errors.items()})
   results[variant]['combined']=combined
 for threshold in [.35,.5,.65]:
  for cell,(line,x0,x1) in enumerate(WINDOWS):
   y=699+125*line-680;support=normalize(template[y:y+124,x0-80:x1-80]);reference=(support>threshold).mean(1)
   for blur in [0,2,4,6]:
    for appearance in ['uniform','rising','falling']:
     gain=np.ones(x1-x0)*.45 if appearance=='uniform' else np.linspace(.25,1,x1-x0)
     if appearance=='falling':gain=gain[::-1]
     alpha=np.asarray(Image.fromarray((np.pad(support,((14,14),(0,0)))*255).astype('uint8')).filter(ImageFilter.GaussianBlur(blur)))/255
     control=60+180*alpha*gain
     detected=register_profile(reference,(normalize(control)>threshold).mean(1),14)
     controls.append(dict(threshold=threshold,cell=cell,line=line,blur=blur,appearance=appearance,**detected))
 save(out/'controls.json',controls)
 save(out/'observations.json',allrows);save(out/'results.json',dict(status='measured',source_verification=reproduced,template_pts=ptssets['V01'][template_index],variants=results))
 if any(digest(root/m[s]['file'])!=hashes[s] for s in ids):raise ValueError('Original changed')
 print(json.dumps(dict(status='measured',variants={k:dict(accepted=v['accepted'],holdouts=v['relative_holdouts']) for k,v in results.items()})))

if __name__=='__main__':main()
