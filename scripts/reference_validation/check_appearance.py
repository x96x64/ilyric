"""Public synthetic cross-language appearance and raster checks; NumPy/Pillow required."""
import json
import subprocess
import numpy as np
from PIL import Image
from analyze import REPO
from appearance_core import progression
from appearance_fit import profile, select
from appearance_measure import summarize

# Exact synthetic column observations with distinct spatial and temporal structure.
rows=np.array([[i,0,0,(i-20)/10,95,0] for i in range(41)])
g=profile(rows,'spatial',3,0,1);a=np.full_like(g,10000.);target=.44+.54*g
arrays=np.stack([a,a*target,a*target**2,np.ones_like(g)],axis=1)
fit=select(rows,arrays,'spatial',.44)
assert (fit['scale'],fit['offset'],fit['softness'])==(3,0,1)
assert fit['phase_holdout']['rms']<1e-5
assert select(rows,arrays,'temporal',.44)['phase_holdout']['rms']>1
measured=arrays.copy();linear=.44+.54*np.arange(41)[:,None]/40
measured[:,1]=a*linear
measurement=summarize(rows,measured)
assert measurement['duration_midpoints']['count']==1
assert measurement['unavailable_durations']==14
bracket=measurement['temporal_brackets'][0]
assert bracket['lower_seconds']<=32/600<=bracket['upper_seconds']
for i in [0,7,20,31,40]:
    for x in [0,47,94]:assert abs(g[i,x]-progression((x+.5)/95,rows[i,3],'spatial',scale=3))<1e-12

out=REPO/'artifacts/appearance-check';out.mkdir(parents=True,exist_ok=True)
request=json.loads((REPO/'artifacts/slice-check/input.json').read_text())
request['appearance']=dict(intervalScale=3,phaseOffset=0,softness=1,completedOpacity=.981)
path=out/'input.json';path.write_text(json.dumps(request));seen={}
for tick in [0,7,20,7]:
    dest=out/f'frame-{tick}'
    subprocess.run([str(REPO/'.build/release/LyricsSliceProbe'),str(path),str(tick),'8',str(dest)],check=True)
    pixels=(dest/'appearance.png').read_bytes()
    if tick in seen:assert pixels==seen[tick]
    seen[tick]=pixels
    coverage=np.asarray(Image.open(dest/'coverage.png'))[:,:,3]
    actual=np.asarray(Image.open(dest/'appearance.png'))[:,:,3]
    state=json.loads((dest/'state.json').read_text());expected=np.zeros_like(actual,dtype=float)
    for line,detail in enumerate(state['lines']):
        count=len(request['text'].split('\n')[line]);advance=detail['width']/count
        for cell in range(count):
            event=next(e for e in state['spans'] if e['start']==detail['start']+cell)
            left=98+cell*advance;right=left+advance
            for x in range(int(np.ceil(left)),int(np.ceil(right))):
                f=progression((x+.5-left)/advance,event['phase'],'spatial',scale=3)
                y=686+line*123
                expected[y:y+123,x]=np.round(coverage[y:y+123,x]*(.42+(.981-.42)*f))
    # Japanese side bearings leave the range boundaries transparent in this original fixture.
    assert np.max(np.abs(actual.astype(float)-expected))<=1
print('Appearance: synthetic fitting holdout, spatial direction, Swift/Python raster agreement, and repeated output passed')
