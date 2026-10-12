"""Visual qualification of typography (docs/reports/visual-qualification-plan.md).

Samples each held-out capture once per second, recognizes the focused paragraph's lines with the macOS Vision text
recognizer (LyricsScreenProbe ocr), and compares their wrapping and ink widths with iLyrics's layout of the same
text (LyricsScreenProbe layout). A paragraph is kept when the same focused text appears at the same position in two
consecutive samples. A recognized line that begins with a capital letter other than the pronoun I is treated as an
explicit lyric line break. Thresholds: identical wrapping for every line; ink width within ±6 px. Prints numbers only.
Usage: qualify_typography.py N01 [...]
"""
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path
import numpy as np
from PIL import Image
from analyze import private_root

REPO = Path(__file__).resolve().parents[2]
PROBE = str(REPO/'.build'/'release'/'LyricsScreenProbe')


def focused(png):
    obs = json.loads(subprocess.run([PROBE, 'ocr', str(png)], capture_output=True, text=True, check=True).stdout)
    L = np.asarray(Image.open(png).convert('RGB')).astype(float)@[0.2126, 0.7152, 0.0722]
    lines = []
    for o in obs:
        x0, y0, x1, y1 = [int(round(v)) for v in o['box']]
        if not (560 <= y0 <= 1500) or y1-y0 < 60:
            continue
        band = L[max(0, y0):y1, :]
        if np.percentile(band[:, max(0, x0):x1], 99) < 235:  # focused ink is white; inactive ink is dim
            continue
        cols = np.nonzero((band > 225).any(0))[0]
        lines.append(dict(text=o['text'], top=y0, ink=[int(cols.min()), int(cols.max())+1]))
    lines.sort(key=lambda l: l['top'])
    # Keep the first run of lines spaced like one paragraph (line advance about 125 px).
    para = lines[:1]
    for l in lines[1:]:
        if l['top']-para[-1]['top'] <= 160:
            para.append(l)
        else:
            break
    return para


def explicit(text):
    first = text.split()[0] if text.split() else ''
    return bool(re.match(r'[A-Z]', first)) and not re.match(r"I('|’|$)", first)


def layout(lines):
    text = lines[0]['text']
    for l in lines[1:]:
        text += ('\n' if explicit(l['text']) else ' ')+l['text']
    return json.loads(subprocess.run([PROBE, 'layout', text], capture_output=True, text=True, check=True).stdout)


def measure(capture, step=1.0):
    duration = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(capture)],
                                    capture_output=True, text=True, check=True).stdout)
    seen, results, previous = set(), [], None
    with tempfile.TemporaryDirectory() as tmp:
        for i, t in enumerate(np.arange(5, duration-2, step)):
            png = Path(tmp)/f'{i}.png'
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{t:.2f}', '-i', str(capture), '-frames:v', '1', str(png)], check=True)
            para = focused(png)
            key = tuple(l['text'] for l in para), tuple(l['top'] for l in para)
            if para and previous and key[0] == previous[0] and all(abs(a-b) <= 3 for a, b in zip(key[1], previous[1])) and key[0] not in seen:
                seen.add(key[0])
                ours = layout(para)
                same = len(ours) == len(para) and all(len(o['text'].split()) == len(n['text'].split()) for o, n in zip(ours, para))
                widths = [(o['ink'][1]-o['ink'][0])-(n['ink'][1]-n['ink'][0]) for o, n in zip(ours, para)] if same else []
                results.append(dict(lines=len(para), ours=len(ours), wrap_identical=same, width_errors=widths))
            previous = key
    return results


if __name__ == '__main__':
    root = private_root(REPO/'reference-private')
    per = {n: measure(root/'new-captures'/f'{n}.MP4') for n in sys.argv[1:]}
    paragraphs = [r for v in per.values() for r in v]
    widths = [w for r in paragraphs for w in r['width_errors']]
    summary = dict(paragraphs=len(paragraphs), wrap_identical=sum(r['wrap_identical'] for r in paragraphs),
                   single_line=sum(r['lines'] == 1 for r in paragraphs),
                   multi_line=sum(r['lines'] > 1 for r in paragraphs),
                   multi_line_identical=sum(r['wrap_identical'] for r in paragraphs if r['lines'] > 1),
                   width_measured=len(widths), width_max_abs=max(map(abs, widths)) if widths else None,
                   width_within_6=sum(abs(w) <= 6 for w in widths), width_mean=float(np.mean(widths)) if widths else None)
    summary['passes'] = dict(wrapping=summary['wrap_identical'] == summary['paragraphs'],
                             width=bool(widths) and summary['width_within_6'] == len(widths))
    (root/'analysis'/'visual-qualification'/'typography.json').write_text(json.dumps(dict(summary=summary, per_capture=per), indent=1)+'\n')
    print(json.dumps(summary))
