#!/usr/bin/env python3
"""Public synthetic preparation/export check; deliberately does not claim singing accuracy."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from alignment.core import make_result, source, review, to_ttml, digest
from generate_local_audio import generate
from validate_local_input import validate


def check(folder):
    folder = Path(folder); folder.mkdir(parents=True, exist_ok=False)
    audio = folder/'source.wav'; generate(audio)
    root = Path(__file__).resolve().parents[1]
    text = (root/'fixtures/alignment/lyrics.txt').read_text(encoding='utf-8')
    src = source(text.encode())
    intervals = [(625000, 1800000), (1810000, 3200000), (4500000, 5500000), (5510000, 6950000), (7000000, 10003000)]
    units = [dict(text=t, begin_us=a, end_us=b) for t, (a, b) in zip(text.replace('\n\n', '\n').split('\n'), intervals)]
    result = make_result(src, digest(audio.read_bytes()), 10003000,
                         dict(identity='synthetic-unit-output-not-inference', precision_us=10000), units)
    (folder/'estimated.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    for i in range(5):
        result = review(result, i, note='Original synthetic fixture boundary accepted')
    result = review(result, 1, '1.810123', '3.25', note='Synthetic correction exercises exact non-frame boundary')
    (folder/'reviewed.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    ttml = folder/'prepared.ttml'; ttml.write_text(to_ttml(result))
    root = Path(__file__).resolve().parents[1]
    video = folder/'video.mp4'
    r = subprocess.run([str(root/'.build/release/LyricsInputProbe'), 'render', '--lyrics', str(ttml),
                        '--audio', str(audio), '--format', 'ttml', '--highlighting', 'disabled', '--output', str(video)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    exported = json.loads(r.stdout)
    assert exported['timed_segments'] == 0 and exported['export']['frames'] == 601
    assert [(x['numerator']/x['denominator'], x['paragraph']) for x in exported['focus_events']] == [(0,-1),(.625,0),(3.25,-1),(4.5,1),(6.95,-1),(7,2),(10.003,-1)]
    return dict(status='passed', evidence='Synthetic software correctness, not acoustic accuracy', export=exported,
                media=validate(video, audio, 601), source_preserved=src['text']==text)


if __name__ == '__main__':
    if len(sys.argv) > 1:
        print(json.dumps(check(sys.argv[1]), indent=2))
    else:
        with tempfile.TemporaryDirectory() as d:
            print(json.dumps(check(Path(d)/'example'), indent=2))
