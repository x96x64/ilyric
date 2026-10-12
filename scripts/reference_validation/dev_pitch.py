"""Development measurement of paragraph pitch: in settled frames of the development recordings, the distances between
consecutive text-row centres below the focused paragraph. Within-paragraph distances cluster near the line advance;
distances between paragraphs form a second cluster. Prints numbers only. Usage: dev_pitch.py"""
import json
import subprocess
import numpy as np
from analyze import REPO, private_root


def gaussian_filter1d(a, sigma, axis=0):
    x = np.arange(-3*sigma, 3*sigma+1)
    k = np.exp(-x**2/(2*sigma**2))
    k /= k.sum()
    return np.apply_along_axis(lambda v: np.convolve(np.pad(v, len(x)//2, mode='edge'), k, 'valid'), axis, a)


def find_peaks(a, distance, prominence):
    """Local maxima at least `prominence` above the lower of the neighbouring minima within `distance`."""
    out = []
    for i in range(1, len(a)-1):
        lo, hi = max(0, i-distance), min(len(a), i+distance+1)
        if a[i] == a[lo:hi].max() and a[i]-max(a[lo:i+1].min(), a[i:hi].min()) >= prominence:
            out.append(i)
    return np.array(out, int), None


def profile(path, t):
    cmd = ['ffmpeg', '-v', 'error', '-ss', f'{t:.2f}', '-i', str(path), '-frames:v', '1', '-vf',
           'crop=900:1500:100:640,format=gray', '-f', 'rawvideo', '-']
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    if len(raw) < 900*1500:
        return None
    f = np.frombuffer(raw, np.uint8).reshape(1500, 900).astype(float)
    hp = f-gaussian_filter1d(gaussian_filter1d(f, 40, 0), 40, 1)
    return gaussian_filter1d(np.abs(hp).mean(1), 6)


if __name__ == '__main__':
    root = private_root(REPO/'reference-private')
    rec = json.loads((root/'analysis'/'manifest.json').read_text())['recordings']
    out = {}
    for name in sorted(root.glob('recordings/*.MP4')):
        d = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(name)],
                                 capture_output=True, text=True).stdout)
        dist = []
        for t in np.arange(3, d-1, 1.5):
            a, b = profile(name, t), profile(name, t+0.3)
            if a is None or b is None or np.abs(a-b).mean() > 0.05*a.mean():
                continue
            peaks, _ = find_peaks(a, distance=70, prominence=0.15*a.max())
            dist += list(np.diff(peaks))
        out[name.name[-24:-6]] = dist
    allv = np.array([v for d in out.values() for v in d])
    hist = np.histogram(allv, bins=np.arange(80, 320, 8))
    print(json.dumps(dict(n=int(len(allv)), histogram={int(e): int(c) for e, c in zip(hist[1], hist[0]) if c},
                          per_recording={k: dict(n=len(v), within=float(np.median([x for x in v if x < 160])) if any(x < 160 for x in v) else None,
                                                 between=float(np.median([x for x in v if x >= 160])) if any(x >= 160 for x in v) else None)
                                         for k, v in out.items()}), indent=1))
