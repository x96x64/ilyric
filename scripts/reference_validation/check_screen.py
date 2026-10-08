"""Separate-process synthetic full-screen determinism and component checks."""
import json,subprocess,tempfile
from pathlib import Path
from screen_core import compare_components

def main():
 root=Path(__file__).resolve().parents[2];binary=root/'.build/release/LyricsScreenProbe'
 out=Path(tempfile.mkdtemp(prefix='screen-check-',dir=root/'artifacts'));expected={}
 for index,(n,d) in enumerate([(0,1),(13,12),(3,2),(4,1),(5,1),(3,2),(0,1),(13,12)]):
  dest=out/f'{index}.png';value=json.loads(subprocess.check_output([str(binary),'native',str(n),str(d),str(dest)]))
  assert (value['width'],value['height'])==(1179,2556)
  key=(n,d);data=dest.read_bytes()
  if key in expected:assert expected[key]==(value,data)
  expected[key]=(value,data)
 profile=json.loads((root/'docs/reference-data/v1/profile.json').read_text())
 assert all(v['edge_errors']==[0,0,0,0] for v in compare_components(value['components'],profile).values())
 assert expected[(0,1)][1]!=expected[(13,12)][1]
 print(json.dumps(dict(status='passed',states=len(expected),repeated_pngs='byte-identical',geometry='archived bounds preserved')))
if __name__=='__main__':main()
