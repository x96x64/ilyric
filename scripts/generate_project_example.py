#!/usr/bin/env python3
"""Create an entirely original, reproducible project in a new local directory."""
import json
from pathlib import Path
import shutil
import struct
import sys
import zlib
from generate_local_audio import generate


def artwork(path):
    width = height = 256
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            circle = (x - 180) ** 2 + (y - 72) ** 2 < 32 ** 2
            rows.extend((235, 180, 110) if circle else (35 + x // 3, 65 + y // 4, 95 + (x + y) // 8))
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'sRGB', b'\0') + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))


def generate_project(destination):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=False)
    fixture = Path(__file__).resolve().parents[1] / 'fixtures' / 'project'
    for name in ['project.json', 'lines.lrc']:
        shutil.copyfile(fixture / name, destination / name)
    generate(destination / 'source.wav')
    artwork(destination / 'artwork.png')
    return {'status': 'generated', 'version': 1, 'duration_seconds': 10.003}


if __name__ == '__main__':
    print(json.dumps(generate_project(sys.argv[1])))
