#!/usr/bin/env python3
"""Original stereo PCM fixture; no third-party dependencies or reference material."""
import math
from pathlib import Path
import struct
import sys
import wave


def generate(path, rate=44100, seconds=10.003):
    path = Path(path)
    if path.exists():
        raise ValueError('Refusing to overwrite audio')
    if rate not in (44100, 48000) or not 0 < seconds <= 600:
        raise ValueError('Fixture bounds')
    with wave.open(str(path), 'wb') as output:
        output.setparams((2, 2, rate, 0, 'NONE', 'not compressed'))
        for start in range(0, round(seconds * rate), rate):
            data = bytearray()
            for i in range(start, min(start + rate, round(seconds * rate))):
                t = i / rate
                # Leading/trailing silence and distinctive tone changes check supplied content.
                tone = 0 if t < .25 or t > seconds - .25 else .13 * math.sin(2 * math.pi * (330 if t < 5 else 550) * t)
                marker = sum(.5 * math.sin(2 * math.pi * 1400 * t) for event in [.625, 2, 3.25, 4.5, 6, 7] if event <= t < event + .02)
                left = max(-1, min(1, tone + marker))
                right_tone = 0 if t < .25 or t > seconds - .25 else .11 * math.sin(2 * math.pi * (440 if t < 5 else 660) * t)
                right = max(-1, min(1, right_tone + marker * .8))
                data.extend(struct.pack('<hh', round(left * 32767), round(right * 32767)))
            output.writeframes(data)
    return {'sample_rate': rate, 'channels': 2, 'frames': round(seconds * rate)}


if __name__ == '__main__':
    import json
    print(json.dumps(generate(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 44100)))
