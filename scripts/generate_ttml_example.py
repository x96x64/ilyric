#!/usr/bin/env python3
"""Generate a version-3 project using original text, artwork, and audio."""
import json
from pathlib import Path
import shutil
import sys
from generate_local_audio import generate
from generate_project_example import artwork


def generate_project(destination):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=False)
    fixture = Path(__file__).resolve().parents[1] / 'fixtures/ttml'
    for name in ['project.json', 'lines.ttml']:
        shutil.copyfile(fixture / name, destination / name)
    generate(destination / 'source.wav')
    artwork(destination / 'artwork.png')
    return {'status': 'generated', 'version': 3, 'duration_seconds': 10.003}


if __name__ == '__main__':
    print(json.dumps(generate_project(sys.argv[1])))
