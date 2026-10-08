#!/usr/bin/env python3
"""Evaluate private alignment artifacts against separately supplied reference intervals.

Manifest: a JSON list of {id, role, language, result, lines:[{text,begin_us,end_us}]}.
Result paths are relative to the manifest. Output contains IDs/numbers only, no lyrics.
"""
import argparse
import json
from pathlib import Path
from alignment.core import AlignmentError, canonical, interval, validate
from alignment.metrics import summarize
from align_lyrics import read_artifact


def evaluate(manifest):
    path = Path(manifest)
    if path.stat().st_size > 2 * 1024 * 1024:
        raise AlignmentError('Reference manifest exceeds 2 MiB')
    cases = json.loads(path.read_text())
    if not isinstance(cases, list) or len(cases) > 64:
        raise AlignmentError('At most 64 reference cases are supported')
    rows=[]
    for case in cases:
        r = read_artifact(path.parent/case['result'])
        refs = case['lines']
        if len(refs) != len(r['lines']):
            raise AlignmentError('Reference line count differs from source')
        errors={'onset':[], 'offset':[]}; missing=0
        for line, ref in zip(r['lines'], refs):
            if line['text'] != ref['text']:
                raise AlignmentError('Reference text differs; no fuzzy pairing is performed')
            if not 0 <= ref['begin_us'] < ref['end_us'] <= r['audio']['duration_us']:
                raise AlignmentError('Invalid reference interval')
            # Score original model estimates, never reviewed corrections.
            estimate=line['estimate']
            if estimate is None:
                missing+=1;continue
            errors['onset'].append(estimate[0]-ref['begin_us'])
            if not ref.get('offset_censored', False):
                errors['offset'].append(estimate[1]-ref['end_us'])
        rows.append({'case':case['id'], 'role':case['role'], 'language':case['language'],
                     'engine':r['engine']['identity'], 'unmatched_lines':missing,
                     'errors_us':errors, 'metrics':{k:summarize(v) for k,v in errors.items()}})
    return rows


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('manifest',type=Path)
    args=parser.parse_args()
    try:
        print(json.dumps(evaluate(args.manifest),indent=2))
    except (AlignmentError, OSError, ValueError, KeyError, TypeError) as e:
        parser.exit(2, 'Alignment evaluation failed: '+str(e)+'\n')
