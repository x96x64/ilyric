"""Reads the lyrics of a held-out capture from its focused paragraphs, for rendering the same song with iLyrics.

Samples the capture twice per second, recognizes the focused paragraph (qualify_typography.focused), and writes the
distinct paragraphs in order, one per blank-line-separated block, with explicit breaks where a recognized line begins
with a capital letter other than the pronoun I. The text is private and stays under reference-private.
Usage: extract_lyrics.py N01 [...]
"""
import subprocess
import unicodedata
import sys
import tempfile
from pathlib import Path
import numpy as np
from qualify_typography import REPO, explicit, focused
from analyze import private_root

if __name__ == '__main__':
    root = private_root(REPO/'reference-private')
    for n in sys.argv[1:]:
        capture = root/'new-captures'/f'{n}.MP4'
        duration = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(capture)],
                                        capture_output=True, text=True).stdout)
        blocks, last = [], None
        with tempfile.TemporaryDirectory() as tmp:
            for i, t in enumerate(np.arange(2, duration-1, 0.5)):
                png = Path(tmp)/f'{i}.png'
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{t:.2f}', '-i', str(capture), '-frames:v', '1', str(png)], check=True)
                para = focused(png)
                if not para:
                    continue
                text = para[0]['text']
                for l in para[1:]:
                    text += ('\n' if explicit(l['text']) else ' ')+l['text']
                if text != last:
                    # A paragraph seen while it was still moving may be cut; keep the longest reading of a repeat.
                    if blocks and (text.startswith(blocks[-1]) or blocks[-1].startswith(text)):
                        blocks[-1] = max(blocks[-1], text, key=len)
                    else:
                        blocks.append(text)
                    last = text
        # Recognition sometimes adds diacritics to capital letters (for example A with dot below); fold Latin letters to
        # their base letters, which the alignment requires.
        text = unicodedata.normalize('NFKD', '\n\n'.join(blocks)+'\n')
        text = ''.join(c for c in text if not unicodedata.combining(c))
        (root/'analysis'/'visual-qualification'/f'{n}-lyrics.txt').write_text(text)
        print(n, len(blocks), 'paragraphs')
