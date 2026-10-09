#!/usr/bin/env python3
"""Post-selection comparison of separated-vocal recognition against the frozen mixture baseline.

References score results only; they never generate anchors, choose windows, or repair predictions.
"""
import argparse
import json
from pathlib import Path
import re
from alignment.core import AlignmentError
from alignment.worker import Unavailable
from alignment.full_song import windows, validate
from evaluate_audio_correspondence import compare
from evaluate_full_song import score
from evaluate_segment_anchors import lexical_support
from match_audio_anchors import read_json


def words(text):
    return [x.replace('’', "'").lower() for x in re.findall(r"[A-Za-z]+(?:['’][A-Za-z]+)*", text)]


def raw_window_tokens(work, plan):
    """Recognized lexical tokens per automatic window from retained raw Whisper JSON."""
    out = []
    for w in plan:
        raw = json.loads((work/f"window-{w['id']:02d}.json").read_text())
        out.append([t for row in raw.get('transcription', []) for t in words(row.get('text', ''))])
    return out


def evaluate(work, mixture, baseline, reference):
    result, prepared = read_json(work/'correspondence.json'), read_json(work/'prepared.json')
    old_result, old_prepared = read_json(mixture/'correspondence.json'), read_json(mixture/'prepared.json')
    for item in [prepared, old_prepared]:
        validate(item)
    engine = prepared['engine']
    if engine.get('recognition_input') != 'separated_vocals' or 'separation' not in engine:
        raise AlignmentError('Separated artifact lacks separation provenance')
    if prepared['audio'] != old_prepared['audio'] or prepared['source'] != old_prepared['source']:
        raise AlignmentError('Separated and mixture artifacts describe different inputs')
    new, old = compare(result, baseline, reference), compare(old_result, baseline, reference)

    def hit(a, b):
        return min(a[1], b[1]) > max(a[0], b[0])

    def available(r):
        return {i for i, (g, ref) in enumerate(zip(r['groups'], reference))
                if any(c['eligible'] and hit(c['lines'][0], ref['interval_us']) for c in g)}

    a, b = available(result), available(old_result)
    plan = windows((result['anchors']['audio']['duration_us']*16000+999999)//1000000)

    def lexical(path):
        tokens = raw_window_tokens(path, plan)
        covered = set()
        for i, ref in enumerate(reference):
            for w, ts in zip(plan, tokens):
                bounds = [w['start_sample']*1000000//16000, w['end_sample']*1000000//16000]
                if hit(bounds, ref['interval_us']) and lexical_support(words(ref['text']), ts):
                    covered.add(i)
        return covered, sum(len(t) for t in tokens)

    new_lex, new_tokens = lexical(work)
    old_lex, old_tokens = lexical(mixture)
    bad = {i for i, ref in enumerate(reference)
           if prepared['lines'][i]['estimate'] and not hit(prepared['lines'][i]['estimate'], ref['interval_us'])}
    base_bad = {i for i, ref in enumerate(reference)
                if baseline['lines'][i]['estimate'] and not hit(baseline['lines'][i]['estimate'], ref['interval_us'])}
    refined = score(prepared, reference)
    counts = {s: sum(d['state'] == s for d in result['decisions']) for s in ['supported', 'ambiguous', 'skipped', 'unresolved']}
    return dict(occurrences=len(reference), separated_correspondence=new, mixture_correspondence=old,
                separated_refinement=refined, mixture_refinement=score(old_prepared, reference), ctc=score(baseline, reference),
                recovered_correct_regions=len(a-b), lost_correct_regions=len(b-a), retained_correct_regions=len(a & b),
                candidate_states=counts,
                raw_lexical_tokens=dict(separated=new_tokens, mixture=old_tokens),
                raw_lexical_reference_window_coverage=dict(separated=len(new_lex), mixture=len(old_lex),
                                                           gained=len(new_lex-old_lex), lost=len(old_lex-new_lex)),
                no_raw_lexical_support=dict(separated=len(reference)-len(new_lex), mixture=len(reference)-len(old_lex)),
                new_retained_nonoverlap=len(bad-base_bad),
                m1_pass=all(x >= .9 for x in [new['candidate_availability_fraction']])
                and refined['unresolved'] < new['baseline_unresolved'] and not (bad-base_bad)
                and new['new_supported_reference_nonoverlap'] == 0,
                qualification='Temporal overlap is necessary, not lexical verification; reference-selected lexical diagnostics cannot generate production timing')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('manifest', type=Path)
    a = p.parse_args()
    try:
        manifest = read_json(a.manifest)
        if not isinstance(manifest, list) or not 1 <= len(manifest) <= 10:
            raise AlignmentError('At most ten cases')
        out = []
        for row in manifest:
            base = a.manifest.parent
            out.append(dict(case=row['case'], metrics=evaluate(base/row['separated'], base/row['mixture'],
                                                                read_json(base/row['ctc']), row['reference'])))
        print(json.dumps(dict(status='measured', cases=out), indent=2))
        return 0
    except Unavailable as e:
        print(json.dumps(dict(status='unavailable', reason=str(e))))
        return 3
    except (AlignmentError, OSError, ValueError, KeyError, TypeError) as e:
        p.exit(2, 'Separation evaluation failed: '+str(e)+'\n')


if __name__ == '__main__':
    raise SystemExit(main())
