"""Visual qualification of focus motion, word fill, the gap indicator, and inactive lines
(docs/reports/visual-qualification-plan.md), by comparing each held-out capture with iLyrics's rendering of the same
song (render_heldout.sh) on a common song clock.

The capture's song clock starts when its transport symbol changes from play to pause (qualify_autohide.py); the
rendering's starts at zero. iLyrics frames are mapped to the native canvas by removing the pillarbox and scaling.
All analysis runs on gray frames at 30 fps. Prints numbers only. Usage: qualify_paired.py N01 [...]
"""
import json
import subprocess
import sys
from pathlib import Path
import numpy as np
from analyze import private_root

REPO = Path(__file__).resolve().parents[2]
FPS = 30
# Pillarbox of the 1080x1920 rendering: the 1180x2556 native canvas scaled to 1920 rows.
OURS_FILTER = 'crop=886:1920:97:0,scale=1180:2556:flags=bicubic'
# Dot centres in the cropped column (native x minus 90); the dots pulse, so the disk is smaller than a dot.
DOTS_X, DOT_Y = (22, 84, 148), 760


def features(path, ours, start=0.0):
    """Streams gray frames of the lyric column (native x 90..1100, y 640..1700) and returns per-frame features:
    row profiles, the 40-px column-group means of the focused first-line band (y 640..790, x 100..1060), the gap
    indicator test, and a quarter-resolution copy of the rows below the focused paragraph (y 950..1500)."""
    x0, y0, x1, y1 = 90, 640, 1100, 1700
    w, h = x1-x0, y1-y0
    pre = OURS_FILTER+',' if ours else ''
    cmd = ['ffmpeg', '-v', 'error', '-ss', f'{start:.3f}', '-i', str(path), '-vf',
           f'{pre}fps={FPS},crop={w}:{h}:{x0}:{y0},format=gray', '-f', 'rawvideo', '-']
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    profile, groups, gap, below = [], [], [], []
    while True:
        raw = proc.stdout.read(w*h)
        if len(raw) < w*h:
            break
        f = np.frombuffer(raw, np.uint8).reshape(h, w).astype(np.float32)
        profile.append(f[60:].mean(1))
        groups.append(f[0:150, 10:970].reshape(150, 24, 40).mean((0, 2)))
        gap.append(gap_visible(f[60:][None])[0])
        below.append(f[310:860:4, ::4].astype(np.uint8))
    proc.wait()
    return np.array(profile), np.array(groups), np.array(gap), np.array(below)


def gap_visible(f):
    """Per frame: each of the three dots is brighter than the background directly above and below it, and no text
    lies to their right."""
    y = DOT_Y-700
    contrast = np.stack([f[:, y-6:y+7, x-6:x+7].mean((1, 2)) -
                         np.concatenate([f[:, y-34:y-24, x-6:x+7], f[:, y+24:y+34, x-6:x+7]], 1).mean((1, 2))
                         for x in DOTS_X], 1)
    right = f[:, y-25:y+25, 300:700]
    return (contrast.min(1) > 8) & (right.std((1, 2)) < 10)


def events_of(mask):
    """Rising and falling edges of a boolean series, in seconds, ignoring runs shorter than 0.3 s."""
    out, i = [], 0
    while i < len(mask):
        if mask[i]:
            j = i
            while j < len(mask) and mask[j]:
                j += 1
            if j-i >= 0.3*FPS:
                out.append((i/FPS, j/FPS))
            i = j
        else:
            i += 1
    return out


def vertical_shift(p):
    """Per-frame upward displacement of the lyric column by row-profile correlation (±40 px, integer)."""
    p = p-p.mean(1, keepdims=True)
    out = [0.0]
    for a, b in zip(p[:-1], p[1:]):
        best, err = 0, np.inf
        for s in range(-40, 41):
            e = np.abs(a[max(0, s):len(a)+min(0, s)]-b[max(0, -s):len(b)+min(0, -s)]).mean()
            if e < err:
                best, err = s, e
        out.append(float(best))
    return np.array(out)


def scrolls(shift):
    """Scroll events: runs of consecutive moving frames; onset, total displacement, and 50%/90% times."""
    moving = np.abs(shift) >= 1
    out = []
    for a, b in events_of(np.convolve(moving, np.ones(3), 'same') > 0):
        i, j = int(round(a*FPS)), int(round(b*FPS))
        cum = np.cumsum(shift[i:j])
        total = cum[-1]
        if abs(total) < 40:
            continue
        frac = cum/total
        t50 = next(k for k, v in enumerate(frac) if v >= 0.5)/FPS
        t90 = next(k for k, v in enumerate(frac) if v >= 0.9)/FPS
        out.append(dict(onset=a, t50=t50, t90=t90, distance=float(total)))
    return out


def fill_crossings(f, scroll_mask):
    """Rising brightness crossings of 40-px column groups in the focused-line band while nothing scrolls."""
    g = f
    out = []
    w = int(0.2*FPS)
    for k in range(g.shape[1]):
        s = g[:, k]
        for t in range(w, len(s)-w):
            if scroll_mask[t-w:t+w].any():
                continue
            lo, hi = s[t-w], s[t+w]
            mid = (lo+hi)/2
            if hi-lo > 12 and s[t-1] < mid <= s[t]:
                out.append((t/FPS, k))
    return out


def match(a, b, window):
    """Nearest-time pairs (b minus a) within `window` seconds, each b used once."""
    used, diffs = set(), []
    for t in a:
        cand = [(abs(u-t), i) for i, u in enumerate(b) if i not in used and abs(u-t) <= window]
        if cand:
            d, i = min(cand)
            used.add(i)
            diffs.append(b[i]-t)
    return diffs


def highpass_rms(a, b):
    from dev_pitch import gaussian_filter1d
    blur = lambda x: gaussian_filter1d(gaussian_filter1d(x, 10, 0), 10, 1)
    a, b = a.astype(np.float32), b.astype(np.float32)
    ha, hb = a-blur(a), b-blur(b)
    return float(np.sqrt(np.mean((ha-hb)**2)))


def first_crossing(cross, a, b):
    """Earliest crossing of the leftmost four column groups within [a, b) seconds: the first word's fill."""
    c = [t for t, k in cross if a <= t < b and k < 4]
    return min(c) if c else None


def measure(root, n, start):
    native, ours = root/'new-captures'/f'{n}.MP4', root/'analysis'/'visual-qualification'/f'{n}-ilyrics.mp4'
    def cached(path, ours_, start_):
        cache = root/'analysis'/'visual-qualification'/'cache'/f'{path.stem}-{start_:.3f}.npz'
        if cache.is_file() and cache.stat().st_mtime > path.stat().st_mtime:
            z = np.load(cache)
            return z['p'], z['g'], z['v'], z['b']
        cache.parent.mkdir(exist_ok=True)
        p, g, v, b = features(path, ours_, start_)
        np.savez(cache, p=p, g=g, v=v, b=b)
        return p, g, v, b
    pn, gn_, vn, bn = cached(native, False, start)
    po, go_, vo, bo = cached(ours, True, 0.0)
    T = min(len(pn), len(po))
    sn, so = vertical_shift(pn[:T]), vertical_shift(po[:T])
    en, eo = scrolls(sn), scrolls(so)
    cn, co = fill_crossings(gn_[:T], np.abs(sn) >= 1), fill_crossings(go_[:T], np.abs(so) >= 1)
    result = {}
    # Focus motion, per video: the delay from scroll onset to the first word's fill in the newly focused line, which
    # removes the synchronization difference between the two videos, and the 50% and 90% times after onset.
    def leads(events, cross):
        out = []
        for i, e in enumerate(events):
            end = events[i+1]['onset'] if i+1 < len(events) else T/FPS
            c = first_crossing(cross, e['onset'], end)
            out.append(None if c is None else c-e['onset'])
        return out
    ln, lo = leads(en, cn), leads(eo, co)
    result['focus'] = dict(native=len(en), ours=len(eo),
                           lead_native=[x for x in ln if x is not None], lead_ours=[x for x in lo if x is not None],
                           t50_native=[e['t50'] for e in en], t50_ours=[e['t50'] for e in eo],
                           t90_native=[e['t90'] for e in en], t90_ours=[e['t90'] for e in eo],
                           distance_native=[e['distance'] for e in en], distance_ours=[e['distance'] for e in eo],
                           onset_sync=match([e['onset'] for e in en], [e['onset'] for e in eo], 1.5))
    # Word fill: scroll events paired within 1.5 s; within each pair, crossings of each column group relative to the
    # line's first crossing, iLyrics minus native. The difference includes word timing of the automatic alignment.
    diffs = []
    for i, e in enumerate(en):
        cand = [j for j, f in enumerate(eo) if abs(f['onset']-e['onset']) <= 1.5]
        if not cand:
            continue
        j = min(cand, key=lambda j: abs(eo[j]['onset']-e['onset']))
        endn = en[i+1]['onset'] if i+1 < len(en) else T/FPS
        endo = eo[j+1]['onset'] if j+1 < len(eo) else T/FPS
        rn, ro = first_crossing(cn, e['onset'], endn), first_crossing(co, eo[j]['onset'], endo)
        if rn is None or ro is None:
            continue
        for k in range(24):
            a = [t-rn for t, g in cn if g == k and e['onset'] <= t < endn]
            b = [t-ro for t, g in co if g == k and eo[j]['onset'] <= t < endo]
            if a and b:
                diffs.append(min(b)-min(a))
    result['fill'] = dict(native=len(cn), ours=len(co), matched=len(diffs), diffs=diffs)
    # Gap indicator, per video: appearance relative to the scroll onset that brought the gap into focus, and exit
    # relative to the next scroll onset.
    def gap_times(mask, events):
        out = []
        onsets = [e['onset'] for e in events]
        mask = mask.copy()
        # Bridge dropouts shorter than 0.3 s while the dots pulse.
        i = 0
        while i < len(mask):
            if not mask[i]:
                j = i
                while j < len(mask) and not mask[j]:
                    j += 1
                if 0 < i and j < len(mask) and j-i < 0.3*FPS:
                    mask[i:j] = True
                i = j
            else:
                i += 1
        for a, b in events_of(mask):
            before = [o for o in onsets if a-2 <= o <= a+0.5]
            after = [o for o in onsets if b-1 <= o <= b+2]
            out.append(dict(start=a, end=b, appear=(a-max(before)) if before else None, exit=(b-min(after)) if after else None))
        return out
    gn, go = gap_times(vn[:T], en), gap_times(vo[:T], eo)
    result['gap'] = dict(native=gn, ours=go)
    # Inactive lines: once per second, a settled frame of ours (no scroll for 0.5 s) is paired with the native frame
    # within ±1.5 s whose lyric-column row profile agrees best; RMS of the difference of high-passed lightness in the
    # rows below the focused paragraph, and the ratio of their high-passed contrast.
    rms, contrast = [], []
    for t in range(int(0.5*FPS), T, FPS):
        if (np.abs(so[t-int(0.5*FPS):t+1]) >= 1).any():
            continue
        lo_, hi_ = max(0, t-int(1.5*FPS)), min(T, t+int(1.5*FPS))
        k = min(range(lo_, hi_), key=lambda i: float(np.abs(pn[i]-po[t]).mean()))
        if float(np.abs(pn[k]-po[t]).mean()) > 12:
            continue
        rms.append(highpass_rms(bn[k], bo[t]))
        contrast.append(highpass_rms(bo[t], np.zeros_like(bo[t]))/max(1e-6, highpass_rms(bn[k], np.zeros_like(bn[k]))))
    result['inactive'] = dict(frames=len(rms), rms=rms, contrast_ratio=contrast)
    return result


def summarize(per):
    def med(v):
        return float(np.median(v)) if len(v) else None
    pool = lambda key, side: [x for r in per.values() for x in r['focus'][f'{key}_{side}']]
    lead = med(pool('lead', 'ours')) - med(pool('lead', 'native'))
    t50 = med(pool('t50', 'ours')) - med(pool('t50', 'native'))
    t90 = med(pool('t90', 'ours')) - med(pool('t90', 'native'))
    fill = [d for r in per.values() for d in r['fill']['diffs']]
    gap = {}
    for kind in ('appear', 'exit'):
        a = [g[kind] for r in per.values() for g in r['gap']['native'] if g[kind] is not None]
        b = [g[kind] for r in per.values() for g in r['gap']['ours'] if g[kind] is not None]
        gap[kind] = dict(native=med(a), ours=med(b), n_native=len(a), n_ours=len(b),
                         difference=(med(b)-med(a)) if a and b else None)
    inactive = [d for r in per.values() for d in r['inactive']['rms']]
    ratio = [c for r in per.values() for c in r['inactive']['contrast_ratio']]
    return dict(
        focus=dict(events=(len(pool('t50', 'native')), len(pool('t50', 'ours'))),
                   lead_native=med(pool('lead', 'native')), lead_ours=med(pool('lead', 'ours')), lead_difference=lead,
                   t50_difference=t50, t90_difference=t90,
                   distance_native=med(pool('distance', 'native')), distance_ours=med(pool('distance', 'ours')),
                   passes=bool(abs(lead) <= 0.15 and abs(t50) <= 0.05 and abs(t90) <= 0.05)),
        fill=dict(matched=len(fill), median=med(fill), within_025=float(np.mean(np.abs(fill) <= 0.25)) if fill else None,
                  passes=bool(fill) and bool(abs(np.median(fill)) <= 0.10 and np.mean(np.abs(fill) <= 0.25) >= 0.9)),
        gap=dict(gap, passes=all(g['difference'] is not None and abs(g['difference']) <= 0.1 for g in gap.values())),
        inactive=dict(frames=len(inactive), median_rms=med(inactive), development_worst=7.398,
                      contrast_ratio_median=med(ratio), passes=bool(inactive) and bool(np.median(inactive) <= 7.398)))


if __name__ == '__main__':
    root = private_root(REPO/'reference-private')
    folder = root/'analysis'/'visual-qualification'
    starts = json.loads((folder/'autohide.json').read_text())['per_capture']
    path = folder/'paired.json'
    per = json.loads(path.read_text()) if path.is_file() and '--resume' in sys.argv else {}
    for n in [a for a in sys.argv[1:] if not a.startswith('--')]:
        per[n] = measure(root, n, starts[n]['start_s'])
        path.write_text(json.dumps(per, indent=1)+'\n')
    summary = summarize(per)
    summary['per_song'] = {n: summarize({n: r}) for n, r in per.items()}
    (folder/'paired-summary.json').write_text(json.dumps(summary, indent=1)+'\n')
    print(json.dumps({k: v for k, v in summary.items() if k != 'per_song'}, indent=1))
