"""Visual qualification of the background (docs/reports/visual-qualification-plan.md).

Compares each held-out capture with iLyrics's background for the same artwork, using the phase-independent block
statistics of background.py: mean CIELAB colour (CIEDE2000 difference, threshold 6) and spatial lightness spread sL
(relative difference, threshold 20%). Inputs and outputs stay under reference-private; prints numbers only.
Usage: qualify_background.py N01 [N02 ...]
"""
import json
import subprocess
import sys
from pathlib import Path
import numpy as np
from background import H, W, field, lab, stats
from analyze import private_root

REPO = Path(__file__).resolve().parents[2]


def capture_frames(path, fps=2):
    cmd = ['ffmpeg', '-v', 'error', '-i', str(path), '-vf', f'fps={fps},scale={W}:{H}:flags=area', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-']
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3).astype(np.float32)/255


def render_frames(artwork, out, seconds=60):
    raw = out.with_suffix('.raw')
    raw.unlink(missing_ok=True)
    subprocess.run([str(REPO/'.build'/'release'/'LyricsScreenProbe'), 'background-frames', str(artwork), str(seconds), str(raw)], check=True)
    return np.fromfile(raw, np.uint8).reshape(-1, H, W, 3).astype(np.float32)/255


def ciede2000(lab1, lab2):
    L1, a1, b1 = lab1; L2, a2, b2 = lab2
    C1, C2 = np.hypot(a1, b1), np.hypot(a2, b2); Cm = (C1+C2)/2
    G = 0.5*(1-np.sqrt(Cm**7/(Cm**7+25**7)))
    a1p, a2p = (1+G)*a1, (1+G)*a2
    C1p, C2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p, h2p = np.degrees(np.arctan2(b1, a1p)) % 360, np.degrees(np.arctan2(b2, a2p)) % 360
    dLp, dCp = L2-L1, C2p-C1p
    dh = h2p-h1p
    dh = dh-360 if dh > 180 else dh+360 if dh < -180 else dh
    dHp = 2*np.sqrt(C1p*C2p)*np.sin(np.radians(dh)/2)
    Lm, Cmp = (L1+L2)/2, (C1p+C2p)/2
    hm = (h1p+h2p)/2 if abs(h1p-h2p) <= 180 else (h1p+h2p+360)/2
    T = 1-0.17*np.cos(np.radians(hm-30))+0.24*np.cos(np.radians(2*hm))+0.32*np.cos(np.radians(3*hm+6))-0.20*np.cos(np.radians(4*hm-63))
    SL = 1+0.015*(Lm-50)**2/np.sqrt(20+(Lm-50)**2); SC = 1+0.045*Cmp; SH = 1+0.015*Cmp*T
    RT = -2*np.sqrt(Cmp**7/(Cmp**7+25**7))*np.sin(np.radians(60*np.exp(-((hm-275)/25)**2)))
    return float(np.sqrt((dLp/SL)**2+(dCp/SC)**2+(dHp/SH)**2+RT*(dCp/SC)*(dHp/SH)))


def main(names):
    root = private_root(REPO/'reference-private')
    out = root/'analysis'/'visual-qualification'
    result = {}
    for n in names:
        native = np.stack([field(f) for f in capture_frames(root/'new-captures'/f'{n}.MP4')])
        ours = np.stack([field(f) for f in render_frames(out/f'{n}-artwork.png', out/f'{n}-background')])
        sn, so = stats(native, 2), stats(ours, 5)
        mean_n = [sn['L'], sn['a'], sn['b']]; mean_o = [so['L'], so['a'], so['b']]
        result[n] = dict(delta_e00=ciede2000(mean_n, mean_o), sL_native=sn['sL'], sL_ours=so['sL'],
                         sL_relative=(so['sL']-sn['sL'])/sn['sL'], native=mean_n, ours=mean_o)
    pooled_de = float(np.mean([r['delta_e00'] for r in result.values()]))
    pooled_sl = float(np.mean([abs(r['sL_relative']) for r in result.values()]))
    summary = dict(per_song=result, mean_delta_e00=pooled_de, mean_abs_sL_relative=pooled_sl,
                   passes=dict(colour=pooled_de <= 6, spread=pooled_sl <= 0.2))
    (out/'background.json').write_text(json.dumps(summary, indent=1)+'\n')
    print(json.dumps({k: v for k, v in summary.items() if k != 'per_song'}, indent=1))
    for n, r in result.items():
        print(n, 'dE00 %.2f  sL native %.2f ours %.2f (%+.0f%%)' % (r['delta_e00'], r['sL_native'], r['sL_ours'], 100*r['sL_relative']))


if __name__ == '__main__':
    main(sys.argv[1:])
