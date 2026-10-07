"""Redistributable synthetic probe checks; no physical references are required."""
import json
from pathlib import Path
import subprocess
from core import evaluate

root=Path(__file__).resolve().parents[2]
out=root/'artifacts/reference-probe-test';out.mkdir(parents=True,exist_ok=True)
p=dict(model='critical',onset=.2,duration=.08,offset=1080,amplitude=-320)
expected={}
for i in [0,120,240,600,240,0,600,120]:
    request=dict(text='Original timing study\n静かな光と Sample',width=987,size=104,
                 lineAdvance=128,font='system-bold',numerator=i,denominator=600,
                 motion=p,anchorOffset=60)
    path=out/'input.json';path.write_text(json.dumps(request))
    subprocess.run([str(root/'.build/release/ReferenceProbe'),str(path),str(out/'frame')],check=True,cwd=root)
    result=json.loads((out/'frame/metrics.json').read_text())
    assert abs(result['fittedY']-evaluate(p,i,600))<1e-9
    image=(out/'frame/scene.png').read_bytes()
    if i in expected:assert image==expected[i]
    expected[i]=image
rejected=subprocess.run([str(root/'.build/release/ReferenceProbe'),str(path),str(root/'unsafe-probe-output')],cwd=root,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
assert rejected.returncode != 0
assert not (root/'unsafe-probe-output').exists()
print(json.dumps({'status':'passed','unique_timestamps':4,'evaluations':8,
                  'checks':['Swift/Python fitted position','random-order PNG equality','output path rejection']}))
