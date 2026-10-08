"""Original public fitting and cross-runtime composition checks; no private inputs."""
import json,subprocess,sys,hashlib
from pathlib import Path
from motion_core import shape,fit_grid,score

def main():
 root=Path(__file__).resolve().parents[2];out=root/'artifacts/motion-check';out.mkdir(exist_ok=True)
 samples=[(i/60,325*shape(i/60,1,.081,'critical')) for i in range(180)]
 p=fit_grid(samples[::2],'critical',[.99,1,1.01],[.08,.081,.082])
 assert p['scale']==.081 and p['onset']==1
 assert score(samples[1::2],p)['maximum']<1e-9
 hashes={}
 for i,n in enumerate([65,0,180,120,65,360,0]):
  path=out/f'frame-{i}.png';path.unlink(missing_ok=True)
  state=json.loads(subprocess.check_output([str(root/'.build/release/LyricsCompositionProbe'),'still',str(n),'60',str(path)],cwd=root))
  if n<=120:assert abs(state['scroll']-325*shape(n/60,1,.081,'critical'))<1e-8
  value=hashlib.sha256(path.read_bytes()).hexdigest()
  if n in hashes:assert hashes[n]==value
  hashes[n]=value
 assert len(set(hashes.values()))>3
 print(json.dumps(dict(status='passed',fitting='held-out synthetic response',cross_runtime='analytic positions',repeated_png='identical')))

if __name__=='__main__':main()
