#!/usr/bin/env python3
"""Score full-song word estimates against human word annotations.

Annotations use the JamendoLyrics word CSV layout (word_start, word_end, line_end in seconds; a
non-empty line_end marks a line's last word). Inputs are private; output contains numbers only.
"""
import argparse
import csv
import json
from pathlib import Path
import statistics
from alignment.core import AlignmentError
from alignment.full_song import validate
from match_audio_anchors import read_json


def annotated_lines(path):
    lines = [[]]
    with path.open(newline='', encoding='utf-8') as stream:
        for row in csv.DictReader(stream):
            lines[-1].append((float(row['word_start']), float(row['word_end'])))
            if row['line_end'] not in ('', 'nan'):
                lines.append([])
    return [x for x in lines if x]


def percentile(values, q):
    ordered = sorted(values)
    return ordered[min(len(ordered)-1, int(q*len(ordered)))]


def summarize(signed_ms):
    a = [abs(x) for x in signed_ms]
    if not a:
        return dict(n=0)
    return dict(n=len(a), median_absolute_ms=statistics.median(a), p90_absolute_ms=percentile(a, .9),
                p95_absolute_ms=percentile(a, .95), signed_median_ms=statistics.median(signed_ms),
                within_100_ms=sum(x <= 100 for x in a)/len(a), within_200_ms=sum(x <= 200 for x in a)/len(a))


def evaluate(artifact, reference):
    """Compare word estimates with annotated words line by line; lines differ only by explicit counts."""
    validate(artifact)
    rows = artifact['lines']
    if len(rows) != len(reference):
        raise AlignmentError('Annotated line count differs')
    onset, offset, even = [], [], []
    counts = dict(lines=len(rows), compared=0, unestimated=0, word_count_mismatch=0)
    for row, words in zip(rows, reference):
        estimates = row.get('word_estimates')
        if not estimates:
            counts['unestimated'] += 1
            continue
        if len(estimates) != len(words):
            counts['word_count_mismatch'] += 1
            continue
        counts['compared'] += 1
        a, b = row['estimate']
        sizes = [w['length_utf16'] for w in estimates]
        for k, (w, (start, end)) in enumerate(zip(estimates, words)):
            onset.append(w['interval_us'][0]/1000-start*1000)
            offset.append(w['interval_us'][1]/1000-end*1000)
            # Baseline: the same line interval divided among words by character count.
            even.append((a+(b-a)*sum(sizes[:k])/sum(sizes))/1000-start*1000)
    return dict(counts=counts, onset=onset, offset=offset, even=even)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('cases', type=Path, help='JSON list of {case, words_csv}')
    p.add_argument('runs', type=Path, help='Directory of CASE.json full-song artifacts')
    a = p.parse_args()
    try:
        cases, total = [], dict(onset=[], offset=[], even=[])
        counts = dict(lines=0, compared=0, unestimated=0, word_count_mismatch=0)
        for c in read_json(a.cases):
            r = evaluate(read_json(a.runs/f"{c['case']}.json"), annotated_lines(Path(c['words_csv'])))
            for k in total:
                total[k] += r[k]
            for k in counts:
                counts[k] += r['counts'][k]
            cases.append(dict(case=c['case'], **r['counts'], onset=summarize(r['onset'])))
        print(json.dumps(dict(status='measured', counts=counts, onset=summarize(total['onset']),
                              offset=summarize(total['offset']), even_split_onset=summarize(total['even']),
                              cases=cases), indent=2))
        return 0
    except (AlignmentError, OSError, ValueError, KeyError, TypeError) as e:
        p.exit(2, 'Word timing evaluation failed: '+str(e)+'\n')


if __name__ == '__main__':
    raise SystemExit(main())
