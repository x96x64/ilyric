"""Visual qualification of control symbol positions (docs/reports/visual-qualification-plan.md).

Measures the ink-bounds centre of each plain control symbol in the held-out paused screenshots with the method of
docs/reports/control-symbols.md (a fixed window around the measured centre, thresholded 70 code values above its
20th-percentile luminance) and compares it with the centre that iLyrics aligns each symbol's ink bounds to.
Threshold: 3 native pixels. Prints numbers only. Usage: qualify_controls.py SCREENSHOT.PNG [...]
"""
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image

# Centres from Sources/LyricsSliceCore/ControlSymbols.swift (paused state: play symbol); disc symbols are excluded
# because their ink is cut out of or drawn over a translucent disc.
CENTRES = {'previous': (269.5, 1948), 'play': (595.5, 1949.5), 'next': (910, 1948), 'volumeLow': (114, 2203.5),
           'volumeHigh': (1048.5, 2203.5), 'bottomCenter': (590.5, 2358), 'bottomRight': (931.5, 2358.5)}
WINDOW = {'previous': 60, 'play': 60, 'next': 60, 'volumeLow': 30, 'volumeHigh': 40, 'bottomCenter': 45, 'bottomRight': 45}


def measure(path):
    L = np.asarray(Image.open(path).convert('RGB')).astype(float)@[0.2126, 0.7152, 0.0722]
    out = {}
    for name, (cx, cy) in CENTRES.items():
        w = WINDOW[name]
        x0, y0 = int(cx-w), int(cy-w)
        box = L[y0:int(cy+w), x0:int(cx+w)]
        mask = box > np.percentile(box, 20)+70
        ys, xs = np.nonzero(mask)
        if len(xs) == 0:
            out[name] = None
            continue
        mx, my = x0+(xs.min()+xs.max()+1)/2, y0+(ys.min()+ys.max()+1)/2
        out[name] = dict(dx=float(mx-cx), dy=float(my-cy), error=float(np.hypot(mx-cx, my-cy)))
    return out


if __name__ == '__main__':
    results = {Path(p).name: measure(p) for p in sys.argv[1:]}
    errors = [v['error'] for r in results.values() for v in r.values() if v]
    summary = dict(per_screenshot=results, max_error=max(errors), mean_error=float(np.mean(errors)),
                   within_3px=sum(e <= 3 for e in errors), measured=len(errors), passes=max(errors) <= 3)
    out = Path(sys.argv[1]).resolve().parents[2]/'analysis'/'visual-qualification'/'controls.json'
    out.write_text(json.dumps(summary, indent=1)+'\n')
    print(json.dumps({k: v for k, v in summary.items() if k != 'per_screenshot'}))
    for shot, r in results.items():
        print(shot, {k: (round(v['dx'], 1), round(v['dy'], 1)) if v else None for k, v in r.items()})
