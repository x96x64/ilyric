"""Reads the lyrics of a held-out capture from its focused paragraphs, for rendering the same song with iLyrics.

Samples the capture twice per second, recognizes the focused paragraph (qualify_typography.focused), and writes the
distinct paragraphs in order, one per blank-line-separated block, with explicit breaks where a recognized line begins
with a capital letter other than the pronoun I. A paragraph read again after the lyric column has scrolled by at least
80 px is a repeat and is kept. The text is private and stays under reference-private.
Usage: extract_lyrics.py N01 [...]
"""
import subprocess
import unicodedata
import sys
import tempfile
from pathlib import Path
import numpy as np
from PIL import Image
from qualify_typography import REPO, explicit, focused
from analyze import private_root

def shift(a, b):
    """Displacement of row profile b relative to a, by least mean absolute difference within ±300 px."""
    a, b = a-a.mean(), b-b.mean()
    errors = {s: np.abs(a[max(0, s):len(a)+min(0, s)]-b[max(0, -s):len(b)+min(0, -s)]).mean() for s in range(-300, 301, 2)}
    return min(errors, key=errors.get)


if __name__ == '__main__':
    root = private_root(REPO/'reference-private')
    for n in sys.argv[1:]:
        capture = root/'new-captures'/f'{n}.MP4'
        duration = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(capture)],
                                        capture_output=True, text=True).stdout)
        blocks, last, previous = [], None, None
        with tempfile.TemporaryDirectory() as tmp:
            for i, t in enumerate(np.arange(2, duration-1, 0.5)):
                png = Path(tmp)/f'{i}.png'
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{t:.2f}', '-i', str(capture), '-frames:v', '1', str(png)], check=True)
                para = focused(png)
                column = np.asarray(Image.open(png).convert('L')).astype(float)[560:2000, 90:1100].mean(1)
                scrolled = previous is not None and abs(shift(previous, column)) >= 80
                previous = column
                if scrolled:
                    last = None
                if not para:
                    continue
                text = para[0]['text']
                for l in para[1:]:
                    text += ('\n' if explicit(l['text']) else ' ')+l['text']
                if text != last:
                    # A paragraph seen while it was still moving may be cut; keep the longest reading of a repeat.
                    if blocks and last is not None and (text.startswith(blocks[-1]) or blocks[-1].startswith(text)):
                        blocks[-1] = max(blocks[-1], text, key=len)
                    else:
                        blocks.append(text)
                    last = text
        # Recognition sometimes adds diacritics to capital letters (for example A with dot below); fold Latin letters to
        # their base letters, which the alignment requires.
        text = unicodedata.normalize('NFKD', '\n\n'.join(blocks)+'\n')
        text = ''.join(c for c in text if not unicodedata.combining(c))
        # Recognition occasionally reads the pronoun I as a vertical bar.
        text = text.replace('|', 'I')
        (root/'analysis'/'visual-qualification'/f'{n}-lyrics.txt').write_text(text)
        print(n, len(blocks), 'paragraphs')
