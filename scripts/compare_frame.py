#!/usr/bin/env python3
"""Compare a Rec.709 still with the same decoded frame in nonlinear Rec.709 RGB."""
import json
import math
import subprocess
import sys

still, video, frame = sys.argv[1:]

def decode(path, filters=None):
    command = ['ffmpeg', '-v', 'error', '-i', path]
    if filters:
        command += ['-vf', filters]
    return subprocess.check_output(command + ['-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'])

a = decode(still)
b = decode(video, f'select=eq(n\\,{int(frame)})')
assert len(a) == len(b) == 1080 * 1920 * 3

def difference(left, right):
    mae = sum(abs(x - y) for x, y in zip(left, right)) / len(left)
    mse = sum((x - y) ** 2 for x, y in zip(left, right)) / len(left)
    return mae, 10 * math.log10(255 ** 2 / mse) if mse else float('inf')

mae, psnr = difference(a, b)
# Fixed synthetic text region; a whole-frame average alone could hide lyric defects.
def text_region(raw):
    return b''.join(raw[(y * 1080 + 155) * 3:(y * 1080 + 930) * 3] for y in range(680, 1370))
text_mae, text_psnr = difference(text_region(a), text_region(b))
print(json.dumps(dict(frame=int(frame), meanAbsoluteError=mae, psnrDB=psnr,
                     textMeanAbsoluteError=text_mae, textPSNRDB=text_psnr), indent=2))
# Spike-only lossy-codec tolerances, not native Music fidelity thresholds.
assert mae <= 3 and psnr >= 35 and text_mae <= 4 and text_psnr >= 30
