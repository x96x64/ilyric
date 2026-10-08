"""Original Latin fixtures: whole-paragraph raster and deterministic integration."""
import json
import subprocess
import numpy as np
from PIL import Image
from analyze import REPO

out=REPO/'artifacts/latin-check';out.mkdir(parents=True,exist_ok=True)
fixtures={
    'single':'AVATAR office.',
    'explicit':'A careful draft—\nwith room to revise.',
    'automatic':'An office proof pairs AV and To, then checks punctuation and spacing.',
    'clusters':'office, affinity; A\u0301VA — “quoted” punctuation.'}
for name,text in fixtures.items():
    # Integer advance isolates shaping/raster equality from the inherited placement quantization.
    p=dict(size=104.25,width=987,originX=96,originY=687,lineAdvance=128,amplitude=0,tau=.195,dimOpacity=1)
    request=dict(text=text,canvasWidth=1179,paragraphStyle='latinStatic',breakEvidence='observed-structure-source-semantics-unknown',parameters=p,events=[])
    path=out/f'{name}.json';path.write_text(json.dumps(request))
    reference=out/f'{name}-probe.json';reference.write_text(json.dumps(dict(text=text,font='system-bold',size=p['size'],width=p['width'],lineAdvance=p['lineAdvance'])))
    subprocess.run([str(REPO/'.build/release/ReferenceProbe'),str(reference),str(out/f'{name}-probe')],check=True)
    before=None
    for n,d in [(7,3),(0,1),(-1,1),(7,3)]:
        dest=out/f'{name}-{n}-{d}'
        subprocess.run([str(REPO/'.build/release/LyricsSliceProbe'),str(path),str(n),str(d),str(dest)],check=True)
        alpha=np.asarray(Image.open(dest/'coverage.png'))[:,:,3]
        probe=np.asarray(Image.open(out/f'{name}-probe/text.png'))[:,:,3]
        assert np.array_equal(alpha[687:687+probe.shape[0],96:96+probe.shape[1]],probe),name
        pixels=(dest/'appearance.png').read_bytes()
        if before is not None:assert pixels==before
        before=pixels
        state=json.loads((dest/'state.json').read_text());m=json.loads((out/f'{name}-probe/metrics.json').read_text())
        assert [(v['start'],v['length'],v['width']) for v in state['lines']]==[(v['start'],v['length'],v['width']) for v in m['lines']]
        if name=='automatic':assert state['lines'][0]['breakKind']=='automatic'
        if name=='explicit':assert state['lines'][0]['breakKind']=='observed-explicit'
print('Latin: whole-paragraph raster identity, source ranges, kerning/cluster fixtures, explicit/automatic breaks, and random-order equality passed')
