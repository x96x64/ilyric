#!/usr/bin/env python3
"""Post-selection comparison of complete-sequence CTC on separated vocals against the mixture baseline.

References score results only; they never enter alignment, windows, or repair.
"""
import argparse
import json
from pathlib import Path
from alignment.core import AlignmentError
from alignment.worker import Unavailable
from alignment.full_song import validate
from evaluate_full_song import score
from match_audio_anchors import read_json


def hit(a, b):
    return min(a[1], b[1]) > max(a[0], b[0])


def evaluate(separated, mixture, reference):
    for item in [separated, mixture]:
        validate(item)
        if len(item['lines']) != len(reference) or any(l['text'] != r['text'] for l, r in zip(item['lines'], reference)):
            raise AlignmentError('Reference occurrences differ')
    if separated['source'] != mixture['source'] or separated['audio'] != mixture['audio']:
        raise AlignmentError('Separated and mixture artifacts describe different inputs')
    if separated['engine'].get('ctc_input') != 'separated_vocals':
        raise AlignmentError('Separated artifact lacks separation provenance')

    def summary(artifact):
        raw = [l['proposal'] for l in artifact['lines']]
        available = sum(p is not None and hit(p, r['interval_us']) for p, r in zip(raw, reference))
        retained_bad = {i for i, (l, r) in enumerate(zip(artifact['lines'], reference))
                        if l['estimate'] and not hit(l['estimate'], r['interval_us'])}
        repeated = {i for i in retained_bad
                    if any(j != i and reference[j]['text'] == reference[i]['text'] and hit(artifact['lines'][i]['estimate'], reference[j]['interval_us'])
                           for j in range(len(reference)))}
        return dict(raw_reference_overlap=available, raw_availability_fraction=available/len(reference),
                    retained_nonoverlap=sorted(retained_bad), retained_wrong_repeat=len(repeated), metrics=score(artifact, reference))

    new, old = summary(separated), summary(mixture)
    added = sorted(set(new['retained_nonoverlap'])-set(old['retained_nonoverlap']))
    m1 = (new['raw_availability_fraction'] >= .9 and new['metrics']['unresolved'] < old['metrics']['unresolved'] and not added)
    return dict(occurrences=len(reference), separated=new, mixture=old, new_retained_nonoverlap=len(added),
                retained_nonoverlap_counts=dict(separated=len(new['retained_nonoverlap']), mixture=len(old['retained_nonoverlap'])),
                m1_pass=m1, qualification='Temporal overlap is necessary, not lexical verification; flags remain review evidence')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('manifest', type=Path)
    a = p.parse_args()
    try:
        manifest = read_json(a.manifest)
        if not isinstance(manifest, list) or not 1 <= len(manifest) <= 10:
            raise AlignmentError('At most ten cases')
        base = a.manifest.parent
        out = [dict(case=r['case'], metrics=evaluate(read_json(base/r['separated']), read_json(base/r['mixture']), r['reference']))
               for r in manifest]
        for row in out:
            for side in ['separated', 'mixture']:
                row['metrics'][side]['retained_nonoverlap'] = len(row['metrics'][side]['retained_nonoverlap'])
        print(json.dumps(dict(status='measured', cases=out), indent=2))
        return 0
    except Unavailable as e:
        print(json.dumps(dict(status='unavailable', reason=str(e))))
        return 3
    except (AlignmentError, OSError, ValueError, KeyError, TypeError) as e:
        p.exit(2, 'Separated CTC evaluation failed: '+str(e)+'\n')


if __name__ == '__main__':
    raise SystemExit(main())
