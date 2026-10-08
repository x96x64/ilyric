#!/usr/bin/env python3
"""Compare private occurrence annotations after search; never select model inputs."""
import argparse
from collections import Counter
import json
from pathlib import Path
from alignment.core import AlignmentError
from alignment.full_song import load
from alignment.passage_search import prepare,reconcile
from alignment.worker import Unavailable,file_hash
from evaluate_full_song import score


def conflicts(result, refs, qualified=True):
    return [i for i,(row,ref) in enumerate(zip(result['lines'],refs))
            if (row['estimate'] if qualified else row['proposal']) is not None
            and min(row['proposal'][1],ref['interval_us'][1])<=max(row['proposal'][0],ref['interval_us'][0])]


def compare(baseline, revised, raw, refs):
    if baseline['source']!=revised['source'] or baseline['audio']!=revised['audio']:
        raise AlignmentError('Comparison requires identical text and audio identities')
    regenerated=prepare(raw)
    if regenerated['proposal_sha256']!=revised['proposal_sha256']:
        raise AlignmentError('Candidate evidence differs from prepared proposals')
    old=score(baseline,refs);new=score(revised,refs)
    old_bad=conflicts(baseline,refs);new_bad=conflicts(revised,refs)
    availability=[]
    for p,group in enumerate(raw['groups']):
        indices=[i for i,r in enumerate(revised['lines']) if r['paragraph']==p]
        # Diagnostic only: no annotation access exists in the inference worker.
        matching=[c['id'] for c in group if len(c['lines'])==len(indices) and not c['unresolved']
                  and all(min(pair[1],refs[i]['interval_us'][1])>max(pair[0],refs[i]['interval_us'][0])
                          for pair,i in zip(c['lines'],indices))]
        availability.append(bool(matching))
    return dict(baseline=old,revised=new,
        qualified_reference_nonoverlap=dict(baseline=len(old_bad),revised=len(new_bad),
            newly_introduced=len(set(new_bad)-set(old_bad))),
        provisional_support_gained=sum(a['estimate'] is None and b['estimate'] is not None for a,b in zip(baseline['lines'],revised['lines'])),
        provisional_support_lost=sum(a['estimate'] is not None and b['estimate'] is None for a,b in zip(baseline['lines'],revised['lines'])),
        passage_states=dict(Counter(x['state'] for x in reconcile(raw['groups'],raw['audio']['duration_us'])['passages'])),
        paragraphs_with_any_complete_overlapping_candidate=sum(availability),paragraphs=len(availability),
        caveat='Reference overlap is a coarse conflict test, not lexical verification; candidate availability uses annotations only after inference')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('manifest',type=Path);p.add_argument('baseline_directory',type=Path);p.add_argument('search_directory',type=Path)
    a=p.parse_args()
    try:
        if not a.manifest.is_file():raise Unavailable('Private full-song annotations unavailable')
        if a.manifest.stat().st_size>2*1024*1024:raise AlignmentError('Reference manifest exceeds 2 MiB')
        manifest=json.loads(a.manifest.read_text());out=[]
        if not isinstance(manifest,list) or not 1<=len(manifest)<=10:raise AlignmentError('At most ten cases')
        for ref in manifest:
            case=ref['id']
            if case not in ['EN-F01','EN-F02','EN-F03']:raise AlignmentError('Unsupported evaluation case identity')
            old=load(a.baseline_directory/(case+'.json'));new=load(a.search_directory/case/'estimated.json')
            path=a.search_directory/case/'candidates.json'
            if path.stat().st_size>8*1024*1024:raise AlignmentError('Candidate record exceeds 8 MiB')
            raw=json.loads(path.read_text())
            out.append(dict(case=case,audio_sha256=new['audio']['sha256'],source_sha256=new['source']['sha256'],
                duration_us=new['audio']['duration_us'],comparison=compare(old,new,raw,ref['lines']),
                measurements=raw['measurements'],provenance=raw['provenance']))
        print(json.dumps(dict(status='measured',reference_manifest_sha256=file_hash(a.manifest),cases=out),indent=2));return 0
    except Unavailable as e:print(json.dumps(dict(status='unavailable',reason=str(e))));return 3
    except (AlignmentError,OSError,ValueError,TypeError,KeyError) as e:p.exit(2,'Passage comparison failed: '+str(e)+'\n')


if __name__=='__main__':raise SystemExit(main())
