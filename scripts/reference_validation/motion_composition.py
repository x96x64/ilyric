"""Private V01–V03 anchor reproduction and motion holdouts; no source publication."""
import json,subprocess,csv
from analyze import REPO,private_root,safe_path,save,probe,trajectory
from state_typography import digest
from motion_core import fit_grid,crossing,score
from core import fit,errors,timing


def main():
 root=private_root(REPO/'reference-private');old=root/'analysis';manifest=old/'manifest.json'
 if not manifest.is_file():print(json.dumps(dict(status='unavailable',reason='Private original motion inventory absent')));return
 inventory=json.loads(manifest.read_text())['recordings'];ids=['V01','V02','V03']
 if any(s not in inventory or not safe_path(root,root/inventory[s]['file']).is_file() for s in ids):
  print(json.dumps(dict(status='unavailable',reason='Required original English recordings absent')));return
 import numpy as np
 out=safe_path(root,old/'motion-composition');out.mkdir(exist_ok=True)
 hashes={s:digest(root/inventory[s]['file']) for s in ids};hashfile=out/'source-hashes.json'
 if hashfile.exists() and json.loads(hashfile.read_text())!=hashes:raise ValueError('Source integrity mismatch')
 save(hashfile,hashes)
 archived=list(csv.DictReader((REPO/'docs/reference-data/v1/trajectories.csv').open()))
 tracks={};results={};observations=[]
 for sid in ids:
  source=root/inventory[sid]['file'];metadata=probe(source,'-show_streams');video=next(s for s in metadata['streams'] if s['codec_type']=='video')
  frames=probe(source,'-select_streams','v:0','-show_frames','-show_entries','frame=pts')['frames']
  if video['time_base']!='1/600' or (video['width'],video['height'])!=(1180,2556):raise ValueError('Unexpected native recording coordinates')
  if [f['pts'] for f in frames]!=[f['pts'] for f in json.loads((old/(sid+'-frames.json')).read_text())]:raise ValueError('Original PTS changed')
  target=out/(sid+'-gray.raw')
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-map','0:v:0','-vf','crop=1040:1400:72:500,scale=260:350:flags=area,format=gray','-fps_mode','passthrough','-enc_time_base','1:600','-f','rawvideo',str(target)],check=True)
  raw=np.memmap(target,dtype='uint8',mode='r').reshape(-1,350,260)
  if len(raw)!=len(frames):raise ValueError('Decoded count mismatch')
  rows=np.abs(np.diff(raw.astype('int16'),axis=2)).mean(2);track=trajectory(rows,frames)
  previous=np.array([[int(r['pts_ticks_1_over_600']),float(r['measured_edge_centroid_y_native_px'])] for r in archived if r['source']==sid])
  if not np.allclose(track,previous,rtol=0,atol=0.00000051):raise ValueError('Archived trajectory differs')
  tracks[sid]=[(t/600,y) for t,y in track]
  # A second tracked line tests rigid paragraph translation. Its different glyph
  # support prevents interpreting centroid separation as typographic line advance.
  center=179.;lower=[]
  for i,f in enumerate(frames):
   if not 1200<f['pts']<3000:continue
   lo=round(center)-13;hi=round(center)+14;w=rows[i,lo:hi];w=np.maximum(0,w-np.percentile(w,10))
   if w.sum()<=0:raise ValueError('Second-line support lost')
   center=float(w@np.arange(lo,hi)/w.sum());lower.append(500+4*center)
  lower=np.array(lower);separation=lower-track[:,1];t=track[:,0]/600
  leading=np.abs(np.diff(raw[:,:,7:48].astype('int16'),axis=2)).mean(2)
  glyph=trajectory(leading,frames);delta=glyph[:,1]-track[:,1];centered=delta-np.median(delta)
  windows=np.array([trajectory(rows,frames,r)[:,1] for r in [11,13,15]])
  models={}
  for model in ['critical','hermite']:
   p=fit(tracks[sid][::2],model,[2+i*.01 for i in range(200)],[.04+i*.01 for i in range(78)])
   models[model]=dict(parameters=p,held_out=errors(tracks[sid][1::2],p))
  archived_models=json.loads((old/'motion-results.json').read_text())[sid]['models']
  for model,value in models.items():
   previous=dict(archived_models[model]);held=previous.pop('held_out')
   if previous!=value['parameters'] or held!=value['held_out']:raise ValueError('Archived motion fit differs')
  results[sid]=dict(metadata=dict(codec=video['codec_name'],dimensions=[video['width'],video['height']],color=[video.get(k) for k in ['color_range','color_space','color_transfer','color_primaries']],**timing([f['pts'] for f in frames])),baseline=models,
   anchors=dict(leading_centered_rmse=float(np.sqrt(np.mean(centered**2))),leading_centered_max=float(abs(centered).max()),
    radius_sensitivity_max=float(np.ptp(windows,axis=0).max()),
    early_separation_mean=float(separation[t<2.5].mean()),late_separation_mean=float(separation[t>4.5].mean()),
    separation_range=[float(separation.min()),float(separation.max())],separation_sd=float(separation.std())),candidates={})
  observations.extend(dict(source=sid,pts=int(p),first_centroid=float(y),second_centroid=float(z)) for (p,y),z in zip(track,lower))
 for sid,track in tracks.items():
  mid=crossing(track)
  for model,scales in [('critical',[.065+i*.001 for i in range(31)]),('hermite',[.37+i*.002 for i in range(51)]),('quintic',[.45+i*.002 for i in range(76)])]:
   p=fit_grid(track[::2],model,[mid-.25+i*.001 for i in range(151)],scales)
   held={}
   for other,x in tracks.items():
    if other==sid:continue
    shift=crossing(x)-mid
    held[other]=dict(phase_shift=shift,errors=score(x,p,shift),timing_sensitivity={str(d):score(x,p,shift+d) for d in [-1/60,1/60]})
   results[sid]['candidates'][model]=dict(parameters=p,within=score(track[1::2],p),held_out=held)
 if hashes!={s:digest(root/inventory[s]['file']) for s in ids}:raise ValueError('Source changed during analysis')
 save(out/'results.json',dict(status='measured',trajectory_reproduction='all 540 observations within CSV rounding',sources=results))
 save(out/'observations.json',observations)
 print(json.dumps(dict(status='measured',sources=ids,observations=len(observations))))

if __name__=='__main__':main()
