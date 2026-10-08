"""Verify selected appearance candidates in the actual experimental raster backend."""
import json
import subprocess
import numpy as np
from PIL import Image
from analyze import REPO, save
from glyph_outline import normalize


def run(root,out,inventory,prior,baseline,fits):
    results={}
    for train,test in [('V09','V10'),('V10','V09')]:
        fit=fits['comparisons'][train]['spatial']
        request=json.loads((root/f'analysis/lyrics-slice/current/{train}-vertical.json').read_text())
        request['appearance']=dict(intervalScale=fit['scale'],phaseOffset=fit['offset'],softness=fit['softness'],completedOpacity=fit['bright'])
        request['parameters']['dimOpacity']=fit['dim']
        path=out/f'{train}-soft.json';save(path,request)
        index={v['pts']:i for i,v in enumerate(inventory['observations'][test])};phases=[]
        for pts in prior['phase_pts'][test]:
            dest=out/f'{train}-{test}-soft-{pts}'
            subprocess.run([str(REPO/'.build/release/LyricsSliceProbe'),str(path),str(pts),'600',str(dest)],check=True)
            old=root/f'analysis/lyrics-slice/current/{train}-{test}-vertical-{pts}'
            coverage=np.asarray(Image.open(dest/'coverage.png'))[:,:,3]
            if not np.array_equal(coverage,np.asarray(Image.open(old/'coverage.png'))[:,:,3]):raise ValueError('Appearance changed geometry')
            alpha=np.asarray(Image.open(dest/'appearance.png'))[:,:,3]/255
            state=json.loads((dest/'state.json').read_text());oldstate=json.loads((old/'state.json').read_text())
            if state['lines']!=oldstate['lines']:raise ValueError('Appearance changed shaping')
            g=np.asarray(Image.open(root/'analysis/s09-state/current'/test/'frames'/f'{index[pts]+1:05d}.png')).mean(2)
            glyphs=[]
            for line,count in enumerate([8,7]):
                for cell in range(count):
                    x=96+cell*95;y=95+line*123;p=g[y:y+115,x:x+95]
                    mask=normalize(p)>.5;core=mask.copy()
                    for yy,xx in [(1,0),(-1,0),(0,1),(0,-1)]:core &= np.roll(mask,(yy,xx),(0,1))
                    shared=core&(coverage[y+600:y+715,x:x+95]>127)
                    bg=np.median(np.concatenate([p[:8],p[-8:]]),axis=0)
                    error=(bg+(255-bg)*alpha[y+600:y+715,x:x+95]-p)[shared]
                    glyphs.append(dict(line=line,cell=cell,shared_rms=float(np.sqrt(np.mean(error**2))),shared_bias=float(error.mean())))
            phases.append(dict(pts=pts,glyphs=glyphs))
        errors=[g['shared_rms'] for p in phases for g in p['glyphs']]
        results[train]=dict(held_out=test,coverage_byte_identical=True,line_metrics_identical=True,
            shared_rms=float(np.sqrt(np.mean(np.square(errors)))),maximum_glyph_rms=max(errors),phases=phases)
    save(out/'render-validation.json',results)
    return results
