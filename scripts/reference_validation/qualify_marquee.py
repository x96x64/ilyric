"""Visual qualification of the title marquee (docs/reports/visual-qualification-plan.md).

Tracks the horizontal displacement of the header title in a held-out capture by cross-correlating its column profile
with the resting title, then compares the start delay, the cycle period, and the displacement curve with iLyrics's
TitleMarquee.measured for the measured scroll distance. Thresholds: delay and period within 5%, displacement RMS ≤ 2 px.
Usage: qualify_marquee.py CAPTURE PLAYBACK_START_S
"""
import json
import subprocess
import sys
from pathlib import Path
import numpy as np
from analyze import private_root

REPO = Path(__file__).resolve().parents[2]
SPEED, DELAY, PAUSE, GAP, CURVE = 104.3, 8.11, 4.42, 104.0, (0.296, 0.340, 0.567, 1.0)


def ease(u):
    if u <= 0: return 0.0
    if u >= 1: return 1.0
    bez = lambda a, b, s: 3*(1-s)*(1-s)*s*a+3*(1-s)*s*s*b+s**3
    lo, hi = 0.0, 1.0
    for _ in range(48):
        mid = (lo+hi)/2
        lo, hi = (mid, hi) if bez(CURVE[0], CURVE[2], mid) < u else (lo, mid)
    return bez(CURVE[1], CURVE[3], (lo+hi)/2)


def model(t, distance):
    if t <= DELAY: return 0.0
    duration = distance/SPEED; period = duration+PAUSE; phase = (t-DELAY) % period
    return distance*ease(phase/duration) if phase < duration else 0.0


def profiles(path, seconds=40, fps=30):
    cmd = ['ffmpeg', '-v', 'error', '-t', str(seconds), '-i', str(path), '-vf', f'fps={fps},crop=665:58:312:338,format=gray',
           '-f', 'rawvideo', '-']
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    f = np.frombuffer(raw, np.uint8).reshape(-1, 58, 665).astype(float)
    return f.mean(1), fps


def shifts(p, step=0.125, limit=8.0):
    """Cumulative leftward displacement from frame-to-frame shifts of the column profile (at most 8 px per frame,
    in 1/8-px steps by linear interpolation); the title rests, and the sum restarts, when consecutive frames agree."""
    x = np.arange(p.shape[1], dtype=float)
    total, out = 0.0, [0.0]
    for a, b in zip(p[:-1], p[1:]):
        if np.abs(b-a).mean() < 0.15:
            if total > 50:  # resting after a completed cycle
                total = 0.0
            out.append(total); continue
        best, err = 0.0, np.inf
        for s in np.arange(0, limit+step, step):
            shifted = np.interp(x+s, x, a)  # a moved left by s
            e = np.abs(shifted[40:-40]-b[40:-40]).mean()
            if e < err: best, err = s, e
        total += best; out.append(total)
    return np.array(out)


if __name__ == '__main__':
    root = private_root(REPO/'reference-private')
    capture, start = sys.argv[1], float(sys.argv[2])
    p, fps = profiles(root/'new-captures'/f'{capture}.MP4')
    s = shifts(p)
    t = np.arange(len(s))/fps-start
    moving = np.nonzero(s > 1)[0]
    first = moving[0]
    # Cycle ends where the displacement snaps back; the largest displacement before it is the scroll distance.
    end = next(i for i in range(first+1, len(s)) if s[i] < 0.2*s[i-1] and s[i-1] > 50)
    distance = float(s[first:end].max())
    second = next(i for i in range(end+1, len(s)) if s[i] > 1)
    measured_delay, measured_period = t[first], (second-first)/fps
    model_period = distance/SPEED+PAUSE
    m = np.array([model(x, distance) for x in t])
    # Displacement is compared over the first scroll, from its start to the snap back; the cumulative tracker holds
    # the final value during the following rest.
    window = (np.arange(len(s)) >= first) & (np.arange(len(s)) < end)
    # A full scroll distance looks identical to rest, so errors are taken modulo the distance.
    d = (s[window]-m[window]+distance/2) % distance-distance/2
    rms = float(np.sqrt(np.mean(d**2)))
    result = dict(distance_px=distance, delay_s=float(measured_delay), model_delay_s=DELAY, period_s=measured_period,
                  model_period_s=model_period, displacement_rms_px=rms,
                  passes=dict(delay=bool(abs(measured_delay-DELAY) <= 0.05*DELAY), period=bool(abs(measured_period-model_period) <= 0.05*model_period),
                              displacement=bool(rms <= 2)))
    (root/'analysis'/'visual-qualification'/f'marquee-{capture}.json').write_text(json.dumps(result, indent=1)+'\n')
    print(json.dumps(result))
