"""Private V01–V03 appearance diagnostic with fixed archived common translation."""
import json,subprocess
from analyze import REPO,private_root,safe_path,save,probe
from state_typography import digest
from inactive_core import select,score

def main():
 root=private_root(REPO/'reference-private');folder=root/'analysis/latin-outline'
 required=[root/'analysis/manifest.json',root/'analysis/motion-composition/source-hashes.json',folder/'observations.json',folder/'results.json']+[root/f'analysis/{s}-frames.json' for s in ['V01','V02','V03']]
 if any(not p.is_file() for p in required):
  print(json.dumps(dict(status='unavailable',reason='Private outline measurements and original inventory required')));return
 ids=['V01','V02','V03'];m=json.loads(required[0].read_text())['recordings'];hashes=json.loads(required[1].read_text())
 if any(s not in m or s not in hashes for s in ids):
  print(json.dumps(dict(status='unavailable',reason='Incomplete private recording inventory')));return
 if any(not safe_path(root,root/m[s]['file']).is_file() or not (folder/(s+'-native.raw')).is_file() for s in ids):
  print(json.dumps(dict(status='unavailable',reason='Original recordings or native diagnostic frames absent')));return
 for s in ids:
  if digest(root/m[s]['file'])!=hashes[s]:raise ValueError('Original recording hash mismatch')
 out=safe_path(root,root/'analysis/inactive');out.mkdir(exist_ok=True)
 for s in ids:
  source=safe_path(root,root/m[s]['file'])
  current=probe(source,'-select_streams','v:0','-show_frames','-show_entries','frame=pts')['frames']
  archived=json.loads((root/f'analysis/{s}-frames.json').read_text())
  if [f['pts'] for f in current]!=[f['pts'] for f in archived]:raise ValueError('Original PTS mismatch')
  target=out/(s+'-verified.raw')
  vf='select=between(pts\\,1201\\,2999),colorspace=all=bt709:trc=srgb:range=pc,crop=1000:850:80:680'
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vf',vf,'-fps_mode','passthrough','-enc_time_base','1:600','-pix_fmt','rgb24','-f','rawvideo',str(target)],check=True)
  if digest(target)!=digest(folder/(s+'-native.raw')):raise ValueError('Archived color-managed raster mismatch')

 import numpy as np
 from PIL import Image,ImageFilter
 from latin_outline import normalize,WINDOWS
 rows=json.loads(required[2].read_text())['normalized'];res=json.loads(required[3].read_text())
 archived=json.loads((REPO/'docs/reference-data/v10/motion.json').read_text());archived.pop('evidence_status')
 if res!=archived:raise ValueError('Archived outline evidence mismatch')
 pts={s:sorted({r['pts'] for r in rows if r['source']==s}) for s in ids}
 raw={s:np.memmap(folder/(s+'-native.raw'),dtype='uint8',mode='r').reshape(-1,850,1000,3) for s in ids}
 template=raw['V01'][pts['V01'].index(res['template_pts'])].astype(float).mean(2)
 out=safe_path(root,root/'analysis/inactive');out.mkdir(exist_ok=True)
 results={};allrecords={}
 # Geometry-sensitive outer lines are excluded; three fixed middle-line windows.
 # Normalization variants expose template-support uncertainty without new alignment.
 for variant,column,pad in [('column',True,0),('global',False,0),('interior',True,8)]:
  refs=[]
  for line,x0,x1 in WINDOWS[3:6]:
   y=699+125*line-680;p=template[y:y+124,x0-80:x1-80]
   refs.append([np.asarray(Image.fromarray((normalize(p,column)*255).astype('uint8')).filter(ImageFilter.GaussianBlur(b))).astype(float)/255 for b in range(11)])
  records=[]
  for s in ids:
   onset=res['variants']['normalized']['motion'][s]['parameters']['onset']
   common={r['pts']:r['common'] for r in rows if r['source']==s}
   for i,pt in enumerate(pts[s]):
    if i%3:continue
    for cell,(line,x0,x1) in enumerate(WINDOWS[3:6]):
     y=699+125*line-680+round(common[pt]);p=raw[s][i,y:y+124,x0-80:x1-80].astype(float).mean(2)
     bg=np.median(np.concatenate([p[:8],p[-8:]]),axis=0);observed=p-bg
     terms=[]
     for a in refs[cell]:
      predicted=a*(255-bg)
      if pad:predicted=predicted[pad:-pad,pad:-pad];o=observed[pad:-pad,pad:-pad]
      else:o=observed
      terms.append([float(np.mean(predicted**2)),float(np.mean(predicted*o)),float(np.mean(o**2))])
     records.append(dict(source=s,pts=pt,elapsed=pt/600-onset,cell=cell,terms=terms))
  holdouts={}
  for s in ids:
   train=[r for r in records if r['source']!=s];test=[r for r in records if r['source']==s];models={}
   for model in ['existing','opacity','blur','interpolated']:
    fit=select(train,model)
    models[model]=dict(parameters=fit,training_rms=score(train,fit),held_out_rms=score(test,fit),phase_sensitivity={str(p):score(test,fit,p) for p in [-1/60,0,1/60]},inactive_rms=score([r for r in test if r['elapsed']<-.2],fit),transition_rms=score([r for r in test if -.05<=r['elapsed']<=.5],fit))
   holdouts[s]=models
  results[variant]=holdouts;allrecords[variant]=records
  if variant=='column':
   # Representative native support and blurred template; all source-bearing output private.
   sheet=Image.new('L',(450,372))
   for cell,a in enumerate(refs):
    for j,b in enumerate([0,7]):sheet.paste(Image.fromarray((a[b]*255).astype('uint8')),(j*150,cell*124))
   sheet.save(out/'template-support.png')
 result=dict(status='measured',evidence_status='fitted reconstruction and color-managed contrast diagnostics',sources=ids,hashes_verified=True,observations_per_recording=180,selected_frames_per_recording=60,pts_time_base='1/600',template_pts=res['template_pts'],variants=results,
 limitations=['Native-to-native sharp template, not a Core Text alpha mask','Three fixed middle-line regions, shared archived translation only','sRGB encoded-channel contrast after full-range Rec.709 interpretation; not physical luminance or measured alpha','Linear interpolation of precomputed blur-grid losses','Archived fitted onsets; phase shifts are sensitivity only','Background, glyph support, and progressive appearance remain confounded'])
 for s in ids:
  if digest(root/m[s]['file'])!=hashes[s]:raise ValueError('Original changed during analysis')
 save(out/'results.json',result);save(out/'observations.json',allrecords)
 print(json.dumps(result))
if __name__=='__main__':main()
