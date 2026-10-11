#!/usr/bin/env python3
"""Generate the native alignment parity fixture from the Python reference implementation.

Inputs are original synthetic lyrics, a synthetic label set, deterministic synthetic emissions, and a
synthetic vocal stem; no model, recording, or reference asset is used. The Swift `AlignmentTests` suite
must reproduce every recorded output.
"""
import base64
import json
import math
import sys
from difflib import SequenceMatcher
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
from alignment.core import source
from alignment.full_song import (apply_vocal_rules, owned_frames, path, proposals, text_targets, vocal_activity_db,
                                 windows)

LYRICS = "Paper skies above\nWe don't look down\n\nPaper skies above\nHum along, hum along\n\nQuiet rooms\n"
LABELS = ['<pad>', '|', "'"] + [chr(c) for c in range(ord('A'), ord('Z') + 1)]


def main(out):
    rng = np.random.default_rng(20261011)
    src = source(LYRICS.encode())
    rows, tokens, owners = text_targets(src)
    vocab = {c: i for i, c in enumerate(LABELS)}
    frames = 600  # 12 s at 20 ms
    # Plan: each line occupies a stretch; the last line is sung over noise so its evidence is weak.
    emissions = np.full((frames, len(LABELS)), -6.0)
    emissions[:, 0] = -0.2
    plan, t = [], 15
    for line in rows:
        ids = [k for k, o in enumerate(owners) if o == line['id']]
        for k in ids:
            length = int(rng.integers(2, 6))
            plan.append((k, t, t + length)); t += length + int(rng.integers(0, 2))
        t += 25
    for k, a, b in plan:
        if owners[k] == rows[-1]['id']:
            continue
        emissions[a:b, vocab[tokens[k]]] = -0.05
        emissions[a:b, 0] = -4.0
    emissions += rng.normal(0, 0.3, emissions.shape)
    emissions = emissions - np.log(np.exp(emissions).sum(1, keepdims=True))
    duration = frames * 20000
    spans = path(emissions.tolist(), [vocab[c] for c in tokens], 0)
    result = proposals(src, duration, emissions.tolist(), tokens, owners, spans, vocab, 0)
    # Synthetic stem: tone bursts where lines are sung, quiet elsewhere.
    samples = (rng.normal(0, 0.002, frames * 320)).astype(np.float32)
    for k, a, b in plan:
        s, e = a * 320, (b + 3) * 320
        samples[s:e] += (0.3 * np.sin(np.arange(e - s) * 0.07)).astype(np.float32)
    level, reference = vocal_activity_db(samples.astype(np.float64))
    apply_vocal_rules(result, level, reference)
    win = windows(16000 * 70)
    owned = [owned_frames(w, (w['end_sample'] - w['start_sample'] - 400) // 320 + 1, 0 if i == 0 else None)
             if i == 0 else None for i, w in enumerate(win)]
    pairs = [('paperskiesabove', 'paperskiesabove'), ('paperskiesabove', 'papskiesabov'), ('humalong', 'hmalonghum'),
             ('quietrooms', ''), ('', ''), ('abcabba', 'cbabac')]
    fixture = dict(
        lyrics=LYRICS, labels=LABELS, duration_us=duration,
        emissions=base64.b64encode(emissions.astype('<f8').tobytes()).decode(), frames=frames,
        samples_head=base64.b64encode(samples[:32000].astype('<f4').tobytes()).decode(),
        level_head=dict(zip(['level', 'reference'], vocal_activity_db(samples[:32000].astype(np.float64)))),
        tokens=tokens, owners=owners, spans=spans,
        level=level, reference=reference,
        rows=[dict(id=r['id'], proposal=r['proposal'], estimate=r['estimate'], flags=r['flags'],
                   support=r['quality'].get('forced_mean_log_support'), similarity=r['quality'].get('greedy_similarity'),
                   words=[dict(start=w['start_utf16'], length=w['length_utf16'], interval=w['proposal']) for w in r.get('words', [])] or None,
                   word_estimates=[dict(start=w['start_utf16'], length=w['length_utf16'], interval=w['interval_us']) for w in r['word_estimates']]
                   if r.get('word_estimates') else None,
                   onset_trim=r['quality'].get('vocal_onset_trim_us'), offset_extension=r['quality'].get('vocal_offset_extension_us'))
              for r in result],
        windows=[dict(id=w['id'], start=w['start_sample'], end=w['end_sample'], keep_start=w['keep_start_sample'], keep_end=w['keep_end_sample']) for w in win],
        first_owned=owned[0],
        ratios=[dict(a=a, b=b, ratio=SequenceMatcher(None, a, b, autojunk=False).ratio()) for a, b in pairs])
    Path(out).write_text(json.dumps(fixture, indent=1) + '\n')
    print(json.dumps(dict(rows=len(result), estimated=sum(r['estimate'] is not None for r in result),
                          flags=sorted({f for r in result for f in r['flags']}))))


if __name__ == '__main__':
    main(sys.argv[1])
