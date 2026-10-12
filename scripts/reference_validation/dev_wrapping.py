"""Development comparison of greedy and balanced automatic line breaks against a development capture.

Uses the focused-paragraph recognition of qualify_typography.py on a development recording (never a held-out
capture) and counts paragraphs whose line word counts match iLyrics's greedy layout and the balanced experiment.
Usage: dev_wrapping.py RECORDING_INDEX (1-based, sorted reference-private/recordings)
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path
import numpy as np
from qualify_typography import PROBE, REPO, explicit, focused
from analyze import private_root


def counts(text, mode):
    if mode == 'greedy':
        return [len(l['text'].split()) for l in json.loads(subprocess.run([PROBE, 'layout', text], capture_output=True, text=True, check=True).stdout)]
    out = subprocess.run([PROBE, 'layout-balanced', text], capture_output=True, text=True, check=True).stdout.rstrip('\n')
    return [len(l.split()) for l in out.split('\n')]


if __name__ == '__main__':
    root = private_root(REPO/'reference-private')
    path = sorted((root/'recordings').glob('*.MP4'))[int(sys.argv[1])-1]
    duration = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(path)], capture_output=True, text=True).stdout)
    seen, prev, tally = set(), None, dict(paragraphs=0, multi=0, greedy=0, balanced=0, greedy_multi=0, balanced_multi=0)
    with tempfile.TemporaryDirectory() as tmp:
        for i, t in enumerate(np.arange(5, duration-2, 1.0)):
            png = Path(tmp)/f'{i}.png'
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{t:.2f}', '-i', str(path), '-frames:v', '1', str(png)], check=True)
            para = focused(png)
            key = tuple(l['text'] for l in para), tuple(l['top'] for l in para)
            if para and prev and key[0] == prev[0] and key[0] not in seen:
                seen.add(key[0])
                native = [len(l['text'].split()) for l in para]
                text = para[0]['text']
                for l in para[1:]:
                    text += ('\n' if explicit(l['text']) else ' ')+l['text']
                g, b = counts(text, 'greedy') == native, counts(text, 'balanced') == native
                tally['paragraphs'] += 1; tally['greedy'] += g; tally['balanced'] += b
                if len(para) > 1:
                    tally['multi'] += 1; tally['greedy_multi'] += g; tally['balanced_multi'] += b
            prev = key
    print(json.dumps(tally))
