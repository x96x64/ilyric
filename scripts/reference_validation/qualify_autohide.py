"""Visual qualification of control auto-hide (docs/reports/visual-qualification-plan.md).

In each held-out capture, finds when playback starts (the transport symbol changes from play to pause) and when the
lower controls disappear (the transport region loses its ink), at 30 frames per second over the first 20 seconds.
iLyrics hides them 3.79 s after playback starts; threshold ±0.2 s. Prints numbers only. Usage: qualify_autohide.py N01 [...]
"""
import json
import subprocess
import sys
from pathlib import Path
import numpy as np
from analyze import private_root

REPO = Path(__file__).resolve().parents[2]
MODEL = 3.79


def series(path, seconds=20, fps=30):
    # Transport row around the play/pause symbol at native (590, 1948): crop 240x140 native pixels.
    cmd = ['ffmpeg', '-v', 'error', '-t', str(seconds), '-i', str(path), '-vf', f'fps={fps},crop=240:140:470:1878,format=gray',
           '-f', 'rawvideo', '-']
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    frames = np.frombuffer(raw, np.uint8).reshape(-1, 140, 240).astype(float)
    ink = np.array([(f > np.percentile(f, 20)+70) for f in frames])
    # Play is one centred triangle; pause is two bars with a gap at the centre column.
    centre = ink[:, 40:100, 112:128].sum(axis=(1, 2))
    total = ink.sum(axis=(1, 2))
    return centre, total, fps


def measure(path):
    centre, total, fps = series(path)
    present = total > 0.3*np.median(total[:int(fps)])
    # Playback start: the centre gap of the pause symbol appears while the transport is still shown.
    start = next(i for i in range(1, len(centre)) if present[i] and centre[i] < 0.3*centre[0])
    hide = next(i for i in range(start, len(total)) if not present[i])
    return dict(start_s=start/fps, hide_s=hide/fps, delay_s=(hide-start)/fps)


if __name__ == '__main__':
    root = private_root(REPO/'reference-private')
    result = {n: measure(root/'new-captures'/f'{n}.MP4') for n in sys.argv[1:]}
    errors = [r['delay_s']-MODEL for r in result.values()]
    summary = dict(per_capture=result, model_s=MODEL, max_abs_error_s=float(np.max(np.abs(errors))),
                   mean_error_s=float(np.mean(errors)), passes=bool(np.max(np.abs(errors)) <= 0.2))
    (root/'analysis'/'visual-qualification'/'autohide.json').write_text(json.dumps(summary, indent=1)+'\n')
    print(json.dumps({k: v for k, v in summary.items() if k != 'per_capture'}))
    for n, r in result.items():
        print(n, 'start %.2f s, hidden %.2f s, delay %.2f s' % (r['start_s'], r['hide_s'], r['delay_s']))
