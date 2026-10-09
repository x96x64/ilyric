"""Private physical-reference measurement and fitting for the artwork-derived background.

Requires ffmpeg, NumPy, Pillow, and SciPy. Inputs are the ignored reference-private
recordings and screenshot artwork crops; every output stays under reference-private/analysis.
The fitted model is an iLyric reconstruction matched to phase-independent statistics, not
Apple's implementation. Commands: targets | fit MODE EVALUATIONS | evaluate MODE
"""
import json
import subprocess
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
from analyze import private_root

W,H,B=295,639,8
LUM=np.array([.2126,.7152,.0722])
def field(f):
    h,w=(H//B)*B,(W//B)*B
    x=f[:h,:w].reshape(h//B,B,w//B,B,3).transpose(0,2,1,3,4).reshape(h//B,w//B,B*B,3)
    k=np.argsort(x@LUM,axis=2)[:,:,:B*B*3//10]
    return np.take_along_axis(x,k[...,None],axis=2).mean(2)[5:]
def lab(rgb):
    c=np.where(rgb<=0.04045,rgb/12.92,((rgb+0.055)/1.055)**2.4)
    M=np.array([[0.4124,0.3576,0.1805],[0.2126,0.7152,0.0722],[0.0193,0.1192,0.9505]])
    xyz=c@M.T/np.array([0.95047,1,1.08883]);f=np.where(xyz>0.008856,np.cbrt(xyz),7.787*xyz+16/116)
    return np.stack([116*f[...,1]-16,500*(f[...,0]-f[...,1]),200*(f[...,1]-f[...,2])],-1)
def smooth(a,k=2):
    from numpy.lib.stride_tricks import sliding_window_view as sw
    p=np.pad(a,k,mode='edge');return sw(p,(2*k+1,2*k+1)).mean((-1,-2))
def affine(a,b):
    gy,gx=np.gradient(a);dt=b-a
    Y,X=np.mgrid[0:a.shape[0],0:a.shape[1]].astype(float);Y-=Y.mean();X-=X.mean()
    J=np.stack([gx*X,gx*Y,gx,gy*X,gy*Y,gy],-1).reshape(-1,6)
    p,*_=np.linalg.lstsq(J,-dt.reshape(-1),rcond=None);return p
def stats(F,fps=10):
    """Phase-independent statistics of a T,Y,X,3 field sequence."""
    Lb=lab(np.clip(F,0,1));L=Lb[...,0]
    out=dict(L=float(L.mean()),a=float(Lb[...,1].mean()),b=float(Lb[...,2].mean()),
        C=float(np.hypot(Lb[...,1],Lb[...,2]).mean()),
        sL=float(L.std(axis=(1,2)).mean()),
        tb=float(L[:,:10].mean()-L[:,-10:].mean()))
    z=L-L.mean(0)
    for lag_s in [1,2,4]:
        lag=int(lag_s*fps)
        if lag<len(z):out[f'ac{lag_s}']=float((z[:-lag]*z[lag:]).sum()/np.sqrt((z[:-lag]**2).sum()*(z[lag:]**2).sum()))
    # spatial correlation at 4 cells (128 native px) horizontally and vertically
    zz=L-L.mean(axis=(1,2),keepdims=True);v=(zz**2).mean()
    out['rx']=float((zz[:,:,:-4]*zz[:,:,4:]).mean()/v);out['ry']=float((zz[:,:-8]*zz[:,8:]).mean()/v)
    Ls=np.stack([smooth(l,2) for l in L])[:,3:-3]
    rots=[];step=fps//2
    for i in range(0,len(Ls)-step,step):p=affine(Ls[i],Ls[i+step]);rots.append((p[3]-p[1])/2*fps/step)
    out['rot']=float(np.median(rots))
    return out

def render(art, t, p, w=W, h=H):
    """Deterministic candidate: rotating, orbiting enlarged artwork layers; blur; color transfer.
    p: s (layer side / canvas height), r (orbit radius / canvas height), nu (orbit rad/s),
       om (rotation rad/s), sig (blur, native px), sat, gain, grad."""
    src=Image.fromarray((art*255).astype(np.uint8))
    acc=np.zeros((h,w,3))
    for k,(ph,dirn) in enumerate([(0.0,1),(2.1,-1)]):
        side=max(8,int(p['s']*h));im=src.resize((side,side),Image.BILINEAR)
        im=im.rotate(np.degrees(dirn*p['om']*t+ph*1.7),resample=Image.BILINEAR,expand=False)
        cx=w/2+p['r']*h*np.cos(dirn*p['nu']*t+ph);cy=h/2+p['r']*h*np.sin(dirn*p['nu']*t+ph)
        canvas=Image.new('RGB',(w,h));canvas.paste(im,(int(cx-side/2),int(cy-side/2)))
        mask=Image.new('L',(w,h));mask.paste(255,(int(cx-side/2),int(cy-side/2),int(cx+side/2),int(cy+side/2)))
        acc+=np.asarray(canvas,float)/255*(np.asarray(mask,float)[...,None]/255)*(1 if k==0 else 1)
    base=acc/2
    img=Image.fromarray((np.clip(base,0,1)*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(float(p['sig'])/4))
    x=np.asarray(img,float)/255
    g=(x@LUM)[...,None];x=g+(x-g)*p['sat']
    x=x*p['gain']*(1-p['grad']*np.linspace(0,1,h)[:,None,None])
    return np.clip(x,0,1)


# Recording identifiers follow analyze.py's sorted inventory. Songs group repeated captures.
SONGS = {'A': ['V01', 'V02', 'V03'], 'B': ['V05', 'V06'], 'C': ['V07', 'V08', 'V09', 'V10']}
KEYS = ['L', 'C', 'sL', 'tb', 'ac1', 'ac2', 'ac4', 'rx', 'ry', 'rot']
# Tolerance floors used when repeated captures agree more closely than measurement noise.
FLOORS = np.array([1.5, 2, 1, 2, .05, .05, .08, .05, .08, .01])
NAMES = ['s', 'r', 'nu', 'om', 'sig', 'sat', 'gain', 'grad']
START = np.array([1.6, 0.18, 0.12, 0.03, 160, 1.2, 0.8, 0.35])


def frames(path, fps=10):
    cmd = ['ffmpeg', '-v', 'error', '-i', str(path), '-vf', f'fps={fps},scale={W}:{H}:flags=area',
           '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-']
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3).astype(np.float32)/255


def artwork(root, song):
    # The private background-cases.json maps neutral song labels to screenshots.
    # Header artwork bounds [96,276,312,492) with a 12-pixel inset exclude rounded corners.
    name = json.loads((root/'background-cases.json').read_text())[song]
    image = np.asarray(Image.open(root/'screenshots'/name).convert('RGB')).astype(float)/255
    return image[288:480, 108:300]


def targets(root, out):
    recordings = sorted((root/'recordings').glob('*.MP4'))
    result = {}
    for index, path in enumerate(recordings, 1):
        name = f'V{index:02}'
        if not any(name in v for v in SONGS.values()):
            continue
        result[name] = stats(np.stack([field(f) for f in frames(path)]))
    (out/'targets.json').write_text(json.dumps(result, indent=1)+'\n')
    return result


def objective(root, out):
    T = json.loads((out/'targets.json').read_text())
    tgt, tol, hue = {}, {}, {}
    for s, vs in SONGS.items():
        a = np.array([[T[v][k] for k in KEYS] for v in vs])
        tgt[s] = a.mean(0)
        tol[s] = np.maximum(a.std(0, ddof=1), FLOORS)
        hue[s] = np.degrees(np.arctan2(np.mean([T[v]['b'] for v in vs]), np.mean([T[v]['a'] for v in vs])))
    arts = {s: artwork(root, s) for s in SONGS}

    def song_loss(s, p, fps=5, dur=12):
        st = stats(np.stack([field(render(arts[s], i/fps, p)) for i in range(int(fps*dur))]), fps)
        e = (np.array([st[k] for k in KEYS])-tgt[s])/tol[s]
        dh = ((np.degrees(np.arctan2(st['b'], st['a']))-hue[s]+180) % 360-180)/5
        return float((e**2).sum()+dh**2), st
    return song_loss, tgt, tol


def fit(root, out, mode, evaluations):
    from scipy.optimize import minimize
    song_loss, tgt, tol = objective(root, out)
    train = [s for s in SONGS if s != mode] if mode in SONGS else list(SONGS)

    def loss(x):
        p = dict(zip(NAMES, x))
        if p['s'] < 0.5 or p['sig'] < 20 or p['sat'] < 0 or not 0 <= p['grad'] < 0.9 or p['gain'] <= 0:
            return 1e6
        return sum(song_loss(s, p)[0] for s in train)
    r = minimize(loss, START, method='Nelder-Mead', options=dict(maxfev=evaluations, xatol=1e-3, fatol=1e-2))
    p = dict(zip(NAMES, r.x.tolist()))
    result = dict(mode=mode, train=train, params=p, train_loss=r.fun,
                  per_song={s: dict(zip(['loss', 'stats'], song_loss(s, p))) for s in SONGS},
                  targets={s: dict(zip(KEYS, tgt[s].tolist())) for s in SONGS},
                  tolerance={s: dict(zip(KEYS, tol[s].tolist())) for s in SONGS})
    (out/f'fit-{mode}.json').write_text(json.dumps(result, indent=1, default=float)+'\n')
    return result


def main():
    root = private_root(Path(__file__).resolve().parents[2]/'reference-private')
    out = root/'analysis'/'background'
    out.mkdir(parents=True, exist_ok=True)
    command = sys.argv[1] if len(sys.argv) > 1 else ''
    if command == 'targets':
        print(json.dumps(targets(root, out), indent=1))
    elif command == 'fit' and len(sys.argv) == 4:
        r = fit(root, out, sys.argv[2], int(sys.argv[3]))
        print(json.dumps({k: r[k] for k in ['mode', 'params', 'train_loss']}, default=float))
    else:
        raise SystemExit('Usage: background.py targets | fit all|A|B|C EVALUATIONS')


if __name__ == '__main__':
    main()
