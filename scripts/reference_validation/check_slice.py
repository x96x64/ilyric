"""Public integration checks for the experimental slice; NumPy/Pillow required."""
import json
from pathlib import Path
import subprocess
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'artifacts/slice-check'
OUT.mkdir(parents=True,exist_ok=True)
text='丸い窓に点を描く\n白い紙を横に置く'
events=[];index=0
for order,c in enumerate(text):
    if c!='\n':events.append(dict(start=index,length=1,begin=dict(numerator=order,denominator=4),end=dict(numerator=order+1,denominator=4),verticalEvent=dict(numerator=order,denominator=4)))
    index+=1
parameters=dict(size=103.25,width=987,originX=98,originY=686,lineAdvance=123,amplitude=0,tau=.195,dimOpacity=.42)
request=dict(text=text,canvasWidth=1179,breakEvidence='observed-structure-source-semantics-unknown',parameters=parameters,events=events)
(OUT/'input.json').write_text(json.dumps(request))
(OUT/'probe.json').write_text(json.dumps(dict(text=text,width=987,size=103.25,lineAdvance=123,font='system-bold')))
subprocess.run([str(ROOT/'.build/release/ReferenceProbe'),str(OUT/'probe.json'),str(OUT/'base')],check=True)
expected=None
for index,time in enumerate([(0,1),(7,4),(5,1),(7,4)]):
    dest=OUT/f'frame-{index}'
    subprocess.run([str(ROOT/'.build/release/LyricsSliceProbe'),str(OUT/'input.json'),*map(str,time),str(dest)],check=True)
    alpha=np.asarray(Image.open(dest/'coverage.png'))[:,:,3]
    if expected is None:expected=alpha
    else:assert np.array_equal(alpha,expected),'Appearance changed base support'
    if index==3:assert (dest/'appearance.png').read_bytes()==(OUT/'frame-1/appearance.png').read_bytes()
base=np.asarray(Image.open(OUT/'base/text.png'))[:,:,3]
assert np.array_equal(expected[686:686+base.shape[0],98:98+base.shape[1]],base),'Shaped-run recomposition differs from whole-paragraph Core Text raster'
# Private input cannot escape to the public synthetic output directory.
result=subprocess.run([str(ROOT/'.build/release/LyricsSliceProbe'),'reference-private/missing.json','0','1',str(OUT/'rejected')],capture_output=True)
assert result.returncode!=0
print('Slice integration: whole-paragraph raster identity, appearance independence, repeated-process equality, and private-path rejection passed')
