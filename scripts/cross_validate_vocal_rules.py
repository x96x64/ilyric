#!/usr/bin/env python3
"""Leave-one-song-out selection of separated-vocal acceptance and boundary rules.

Inputs are private: a JSON list of cases, each with a complete-sequence separated-vocal artifact,
its vocal stem, and human line references. For every held-out song, thresholds are chosen on the
other songs only and then scored on the held-out song. Output contains numbers only.
"""
import argparse
import collections
import itertools
import json
from pathlib import Path
import numpy as np
import soundfile as sf
from alignment.full_song import vocal_activity_db


def hit(a, b):
    return min(a[1], b[1]) > max(a[0], b[0])


def load(case):
    artifact = json.loads(Path(case['artifact']).read_text())
    x, rate = sf.read(case['stem'], dtype='float32')
    if rate != 16000:
        raise ValueError('Vocal stem must be 16 kHz')
    level, p99 = vocal_activity_db(x)
    lines = []
    for i, (l, r) in enumerate(zip(artifact['lines'], case['reference'])):
        if l['text'] != r['text']:
            raise ValueError('Reference text differs')
        p = l['proposal']
        following = next((x['proposal'][0] for x in artifact['lines'][i+1:] if x['proposal']), None)
        lines.append(dict(proposal=p, ref=r['interval_us'], following=following, chars=len(l['alignment_text']),
                          support=l['quality'].get('forced_mean_log_support'), similarity=l['quality'].get('greedy_similarity')))
    return dict(lines=lines, level=np.array(level), p99=p99)


def accept(line, gate):
    support, similarity, low, high = gate
    if line['proposal'] is None:
        return False
    rate = (line['proposal'][1]-line['proposal'][0])/1000/line['chars']
    return line['support'] >= support and line['similarity'] >= similarity and low <= rate <= high


def gate_score(songs, gate):
    accepted = [l for s in songs for l in s['lines'] if accept(l, gate)]
    correct = sum(hit(l['proposal'], l['ref']) for l in accepted)
    return correct - 25*(len(accepted)-correct)


def bounds(song, gate, onset_db, offset_db, extension_us):
    out = []
    level, p99 = song['level'], song['p99']
    for l in song['lines']:
        if not accept(l, gate):
            continue
        a, b = l['proposal']
        i0, i1 = a//20000, -(-b//20000)
        active = [i for i in range(i0, min(i1, len(level))) if level[i] > p99-onset_db]
        if not active:
            continue
        a2 = max(a, active[0]*20000)
        limit = min(b+extension_us, l['following'] if l['following'] is not None else b+extension_us)
        j = i1
        while j < len(level) and j*20000 < limit and level[j] > p99-offset_db:
            j += 1
        b2 = min(max(b, j*20000), max(b, limit))
        if b2 > a2:
            out.append(((a2-l['ref'][0])/1000, (b2-l['ref'][1])/1000, hit((a2, b2), l['ref'])))
    return out


def summary(results):
    on, off = np.abs([r[0] for r in results]), np.abs([r[1] for r in results])
    return dict(n=len(results), onset_median_ms=float(np.median(on)), onset_p95_ms=float(np.percentile(on, 95)),
                onset_over_500=float((on > 500).mean()), offset_median_ms=float(np.median(off)),
                offset_p95_ms=float(np.percentile(off, 95)), offset_over_500=float((off > 500).mean()),
                errors_over_2s=int((on > 2000).sum()+(off > 2000).sum()), nonoverlap=sum(not r[2] for r in results))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('cases', type=Path)
    a = p.parse_args()
    cases = json.loads(a.cases.read_text())
    songs = {c['case']: load(c) for c in cases}
    gates = list(itertools.product([-4.0, -3.5, -3.0, -2.75, -2.5, -2.25, -2.0, -1.75],
                                   [0.0, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.55], [40, 50], [300, 400, 600, 1000, 1e9]))
    boundary_grid = [(30.0, d, e) for d in [20.0, 25.0, 30.0, 35.0] for e in [300000, 600000, 1000000]]
    total = collections.Counter()
    results, choices = [], []
    for held in songs:
        train = [s for k, s in songs.items() if k != held]
        gate = max(gates, key=lambda g: gate_score(train, g))

        def cost(prm):
            s = summary([r for t in train for r in bounds(t, gate, *prm)])
            return s['offset_median_ms']+0.3*s['offset_p95_ms']+s['onset_median_ms']+0.3*s['onset_p95_ms']
        prm = min(boundary_grid, key=cost)
        choices.append(dict(case=held, gate=gate, boundary=prm))
        lines = songs[held]['lines']
        accepted = [l for l in lines if accept(l, gate)]
        total.update(lines=len(lines), accepted=len(accepted), correct=sum(hit(l['proposal'], l['ref']) for l in accepted))
        results += bounds(songs[held], gate, *prm)
    print(json.dumps(dict(status='cross_validated', placement=dict(total), boundaries=summary(results),
                          gate_choices=collections.Counter(str(c['gate']) for c in choices).most_common(),
                          boundary_choices=collections.Counter(str(c['boundary']) for c in choices).most_common()), indent=2))


if __name__ == '__main__':
    main()
