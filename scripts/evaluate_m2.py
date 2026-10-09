#!/usr/bin/env python3
"""Apply the prospective M2 conditions per song to frozen separated-vocal CTC results.

References score results only. Inputs are private; output contains numbers only.
"""
import argparse
import json
from pathlib import Path
import statistics
from alignment.core import AlignmentError
from alignment.full_song import validate
from evaluate_full_song import errors
from match_audio_anchors import read_json


def hit(a, b):
    return min(a[1], b[1]) > max(a[0], b[0])


def evaluate(artifact, reference, duration_s):
    validate(artifact)
    lines = artifact['lines']
    if len(lines) != len(reference) or any(l['text'] != r['text'] for l, r in zip(lines, reference)):
        raise AlignmentError('Reference occurrences differ')
    n = len(lines)
    placed = sum(l['estimate'] is not None and hit(l['estimate'], r['interval_us']) for l, r in zip(lines, reference))
    unresolved = sum(l['estimate'] is None for l in lines)
    wrong = [i for i, (l, r) in enumerate(zip(lines, reference)) if l['estimate'] and not hit(l['estimate'], r['interval_us'])]
    onset = [(l['estimate'][0]-r['interval_us'][0])/1000 for l, r in zip(lines, reference) if l['estimate']]
    offset = [(l['estimate'][1]-r['interval_us'][1])/1000 for l, r in zip(lines, reference) if l['estimate']]
    on, off = errors(onset), errors(offset)
    large = sum(abs(x) > 2000 for x in onset+offset)
    measurements = artifact.get('measurements', {})
    seconds = measurements.get('total_seconds')
    conditions = dict(
        correct_occurrence_at_least_95=placed/n >= .95, unresolved_at_most_5=unresolved/n <= .05, no_unflagged_displacement=not wrong,
        onset_median_100=on['n'] > 0 and on['median_absolute_ms'] <= 100, onset_p95_250=on['n'] > 0 and on['p95_absolute_ms'] <= 250,
        onset_over_500_at_most_5=on['n'] > 0 and on['over_500_ms']/on['n'] <= .05,
        offset_median_100=off['n'] > 0 and off['median_absolute_ms'] <= 100, offset_p95_250=off['n'] > 0 and off['p95_absolute_ms'] <= 250,
        offset_over_500_at_most_5=off['n'] > 0 and off['over_500_ms']/off['n'] <= .05, no_unflagged_error_over_2s=large == 0,
        preparation_at_most_twice_duration=seconds is not None and seconds <= 2*duration_s)
    return dict(occurrences=n, correct_occurrence=placed, unresolved=unresolved, retained_nonoverlap=len(wrong),
                signed_onset_median_ms=statistics.median(onset) if onset else None,
                signed_offset_median_ms=statistics.median(offset) if offset else None,
                onset=on, offset=off, errors_over_2s=large, preparation_seconds=seconds, duration_seconds=duration_s,
                peak_rss_bytes=measurements.get('peak_rss_bytes'), conditions=conditions, passes=all(conditions.values()))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('cases', type=Path)
    p.add_argument('runs', type=Path)
    a = p.parse_args()
    try:
        out = []
        for c in read_json(a.cases):
            row = {}
            for mode in ['separated', 'mixture']:
                artifact = read_json(a.runs/f"{c['case']}.{mode}.json")
                row[mode] = evaluate(artifact, c['reference'], artifact['audio']['duration_us']/1e6)
            out.append(dict(case=c['case'], nonlexical=c.get('nonlexical', False), license=c.get('license'), **row))
        sep = [r['separated'] for r in out]
        summary = dict(songs=len(out), passing_songs=sum(r['passes'] for r in sep),
                       occurrences=sum(r['occurrences'] for r in sep), correct=sum(r['correct_occurrence'] for r in sep),
                       unresolved=sum(r['unresolved'] for r in sep), retained_nonoverlap=sum(r['retained_nonoverlap'] for r in sep),
                       condition_pass_counts={k: sum(r['conditions'][k] for r in sep) for k in sep[0]['conditions']})
        print(json.dumps(dict(status='measured', summary=summary, cases=out), indent=2))
        return 0
    except (AlignmentError, OSError, ValueError, KeyError, TypeError) as e:
        p.exit(2, 'M2 evaluation failed: '+str(e)+'\n')


if __name__ == '__main__':
    raise SystemExit(main())
