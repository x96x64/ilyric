#!/usr/bin/env python3
"""Post-selection temporal comparisons only; references never enter anchor matching."""
from alignment.core import AlignmentError
from alignment.full_song import validate
from alignment.audio_anchors import match, fingerprint
from evaluate_full_song import errors


def compare(result, baseline, reference):
    validate(baseline)
    rebuilt=match(result['source'],result['anchors'])
    if fingerprint(result)!=fingerprint(rebuilt):raise AlignmentError('Correspondence evidence changed')
    if baseline['source']!=result['source'] or baseline['audio']!=result['anchors']['audio']:
        raise AlignmentError('Baseline source/audio identity differs')
    if len(reference)!=len(result['decisions']):raise AlignmentError('Reference occurrence count differs')
    duration=result['anchors']['audio']['duration_us']
    for row,ref in zip(baseline['lines'],reference):
        if ref['text']!=row['text']:raise AlignmentError('Reference text/occurrence differs')
        value=ref['interval_us']
        if len(value)!=2 or any(type(t) is not int for t in value) or not 0<=value[0]<value[1]<=duration:
            raise AlignmentError('Invalid reference interval')
    def intersects(a,b):return min(a[1],b[1])>max(a[0],b[0])
    available=selected=conflicts=repeated=baseline_conflicts=new_conflicts=0;onsets=[];offsets=[]
    for i,(g,d,ref) in enumerate(zip(result['groups'],result['decisions'],reference)):
        # Count eligible candidates, independently of chronological selection.
        available+=any(c['eligible'] and intersects(c['lines'][0],ref['interval_us']) for c in g)
        old=baseline['lines'][i]['estimate']
        old_conflict=old is not None and not intersects(old,ref['interval_us'])
        baseline_conflicts+=old_conflict
        if d['state']!='supported':continue
        selected+=1;region=d['region_us'];conflict=not intersects(region,ref['interval_us']);conflicts+=conflict
        new_conflicts+=conflict and not old_conflict
        repeated+=conflict and any(j!=i and r['text']==ref['text'] and intersects(region,r['interval_us']) for j,r in enumerate(reference))
        onsets.append((region[0]-ref['interval_us'][0])/1000);offsets.append((region[1]-ref['interval_us'][1])/1000)
    n=len(reference);old_missing=sum(r['estimate'] is None for r in baseline['lines'])
    return dict(occurrences=n,eligible_candidate_reference_overlap=available,
                candidate_availability_fraction=available/n,supported_regions=selected,unresolved_regions=n-selected,
                supported_reference_nonoverlap=conflicts,new_supported_reference_nonoverlap=new_conflicts,wrong_repeated_reference_overlap=repeated,
                coarse_region_onset=errors(onsets),coarse_region_offset=errors(offsets),
                baseline_unresolved=old_missing,baseline_supported_reference_nonoverlap=baseline_conflicts,
                m1_temporal_screen_pass=available*10>=n*9 and n-selected<old_missing and new_conflicts==0,
                m1_lexical_correctness='unmeasured; interval overlap is necessary but not sufficient',
                timing_refinement='not evaluated',interpretation='Coarse candidate-region errors are not final acoustic boundary accuracy')
