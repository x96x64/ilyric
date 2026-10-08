"""Public synthetic timeline, raster determinism, and optional decoded-video audit."""
import json,subprocess,tempfile,sys
from pathlib import Path

def main():
 root=Path(__file__).resolve().parents[2];binary=root/'.build/release/LyricsScreenProbe'
 states=json.loads(subprocess.check_output([str(binary),'timeline']))
 assert len(states)==360
 changes=[i for i in range(1,360) if states[i]['visible']!=states[i-1]['visible']]
 assert changes==[120,240,300]
 assert abs(states[240]['scroll']-650)<.02 and abs(states[-1]['scroll']-650)<1e-9
 out=Path(tempfile.mkdtemp(prefix='inactive-check-',dir=root/'artifacts'));seen={}
 for i,(n,d) in enumerate([(0,1),(61,20),(3,1),(21,20),(0,1),(61,20)]):
  target=out/f'{i}.png';record=json.loads(subprocess.check_output([str(binary),'native-inactive',str(n),str(d),str(target)]))
  value=(record,target.read_bytes())
  if (n,d) in seen:assert seen[n,d]==value
  seen[n,d]=value
 result=dict(status='passed',frames=360,visibility_change_frames=changes,tail_scroll=[states[i]['scroll'] for i in [180,240,359]],repeated_pngs='byte-identical')
 if len(sys.argv)>1:
  import numpy as np
  video=Path(sys.argv[1]).resolve()
  if root/'artifacts' not in video.parents:raise ValueError('Synthetic video must be under artifacts')
  target=out/'decoded.raw'
  subprocess.run(['ffmpeg','-v','error','-i',str(video),'-vf','scale=540:960','-pix_fmt','gray','-f','rawvideo',str(target)],check=True)
  a=np.memmap(target,dtype='uint8',mode='r').reshape(-1,960,540);assert len(a)==360
  result['decoded_regions']={}
  for name,(x0,y0,x1,y1) in dict(transport=[200,1900,980,1990],bottom=[200,2310,990,2405],handle=[490,188,690,220],compact=[975,1480,1080,1580],expanded=[968,1350,1085,1590]).items():
   scale=960/2556;x0,x1=round(97.1831/2+x0*scale),round(97.1831/2+x1*scale);y0,y1=round(y0*scale),round(y1*scale)
   p=np.asarray(a[:,y0:y1,x0:x1],float);delta=np.mean(abs(np.diff(p,axis=0)),axis=(1,2))
   large=(np.where(delta>2)[0]+1).tolist()
   result['decoded_regions'][name]=dict(frames_above_2_levels=large,largest_changes=[dict(frame=int(i+1),mean_absolute_difference=float(delta[i])) for i in np.argsort(delta)[-5:][::-1]])
   assert set(large).issubset({120,240,300})
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()
