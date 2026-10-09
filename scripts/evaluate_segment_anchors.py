#!/usr/bin/env python3
"""Post-selection segment/word/CTC comparison. References never enter inference."""
import argparse
import json
from pathlib import Path
import re
from alignment.core import AlignmentError
from alignment.worker import Unavailable
from alignment.audio_anchors import fingerprint,lexical as lexical_units,line_candidates
from alignment.full_song import windows,validate
from alignment.segment_anchors import project
from evaluate_audio_correspondence import compare
from evaluate_full_song import score
from match_audio_anchors import read_json


def words(text):
    return [x.replace('’',"'").lower() for x in re.findall(r"[A-Za-z]+(?:['’][A-Za-z]+)*",text)]


def lexical_support(target,tokens):
    """Same edit criterion, without assigning times to untimed recognized text."""
    if len(target)*len(tokens)>20000000:raise AlignmentError('Lexical diagnostic work limit')
    prior=[(0,0)]*(len(tokens)+1)
    for i,w in enumerate(target,1):
        cur=[(i,0)]
        for j,t in enumerate(tokens,1):
            same=w==t
            cur.append(min((prior[j-1][0]+(not same),prior[j-1][1]-same),
                           (prior[j][0]+1,prior[j][1]),(cur[-1][0]+1,cur[-1][1])))
        prior=cur
    return any(-matches>=2 and cost*100<=30*len(target) for cost,matches in prior[1:])


def evaluate(evidence,result,prepared,word_result,word_prepared,baseline,reference):
    projected,_=project(evidence)
    if projected!=result['anchors']:raise AlignmentError('Segment projection differs from correspondence')
    for item,correspondence in [(prepared,result),(word_prepared,word_result)]:
        validate(item)
        if item['source']!=correspondence['source'] or item['audio']!=correspondence['anchors']['audio'] or item['engine']['correspondence_sha256']!=fingerprint(correspondence):
            raise AlignmentError('Prepared artifact and correspondence identities differ')
    if prepared['engine'].get('segment_evidence_sha256')!=fingerprint(evidence):raise AlignmentError('Segment evidence identity differs')
    new=compare(result,baseline,reference);old=compare(word_result,baseline,reference)
    def hit(a,b):return min(a[1],b[1])>max(a[0],b[0])
    def available(r):return {i for i,(g,ref) in enumerate(zip(r['groups'],reference)) if any(c['eligible'] and hit(c['lines'][0],ref['interval_us']) for c in g)}
    a,b=available(result),available(word_result)
    raw={i for i,(g,ref) in enumerate(zip(result['groups'],reference)) if any(hit(c['lines'][0],ref['interval_us']) for c in g)}
    plan=windows((evidence['audio']['duration_us']*16000+999999)//1000000)
    text_tokens=[[w for s in window['segments'] for w in words(s['text'])] for window in evidence['windows']]
    # Reference-selected windows are diagnostics, never operational candidate generation.
    lexical=set();window_available=set()
    for i,ref in enumerate(reference):
        for w,ts in zip(plan,text_tokens):
            bounds=[w['start_sample']*1000000//16000,w['end_sample']*1000000//16000]
            if hit(bounds,ref['interval_us']) and lexical_support(words(ref['text']),ts):lexical.add(i)
        if i in a:continue
        for w in plan:
            ts=[]
            for ob in projected['observations']:
                if ob['window']!=w['id'] or ob['uncertainty']:continue
                units=lexical_units(ob['text'])
                if not units:continue
                ts.extend(dict(u,interval_us=[ob['begin_tick']*10000,ob['end_tick']*10000]) for u in units)
            if any(c['eligible'] and hit(c['lines'][0],ref['interval_us']) for c in line_candidates(words(ref['text']),ts)):
                window_available.add(i);break
    selected_correct={i for i,d in enumerate(result['decisions']) if d['state']=='supported' and hit(d['region_us'],reference[i]['interval_us'])}
    retained_bad=set();baseline_bad=set()
    for i,ref in enumerate(reference):
        for artifact,bad in [(prepared,retained_bad),(baseline,baseline_bad)]:
            value=artifact['lines'][i]['estimate']
            if value and not hit(value,ref['interval_us']):bad.add(i)
    refined=score(prepared,reference)
    counts={s:sum(d['state']==s for d in result['decisions']) for s in ['supported','ambiguous','skipped','unresolved']}
    return dict(occurrences=len(reference),segment_correspondence=new,word_correspondence=old,
        segment_refinement=refined,word_refinement=score(word_prepared,reference),ctc=score(baseline,reference),
        recovered_correct_regions=len(a-b),lost_correct_regions=len(b-a),retained_correct_regions=len(a&b),
        candidate_states=counts,available_but_not_correctly_selected=len(a-selected_correct),
        recovered_and_correctly_selected=len((a-b)&selected_correct),raw_candidate_correct_regions=len(raw),
        additional_single_window_regions_without_ownership=len(window_available),raw_lexical_reference_window_coverage=len(lexical),
        missing_region_but_raw_lexical_support=len(lexical-a),no_raw_lexical_support=len(reference)-len(lexical),
        new_retained_nonoverlap=len(retained_bad-baseline_bad),
        m1_pass=new['candidate_availability_fraction']>=.9 and refined['unresolved']<new['baseline_unresolved'] and not (retained_bad-baseline_bad) and new['new_supported_reference_nonoverlap']==0,
        qualification='Temporal overlap is necessary, not lexical verification; reference-selected lexical/window diagnostics cannot generate production timing')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('manifest',type=Path);a=p.parse_args()
    try:
        manifest=read_json(a.manifest)
        if not isinstance(manifest,list) or not 1<=len(manifest)<=10:raise AlignmentError('At most ten cases')
        output=[]
        for row in manifest:
            def file(key,name=None):
                path=a.manifest.parent/row[key]
                return read_json(path/name if name else path)
            r=evaluate(file('segment','segments.json'),file('segment','correspondence.json'),file('segment','prepared.json'),
                       file('word','correspondence.json'),file('word','prepared.json'),file('ctc'),row['reference'])
            output.append(dict(case=row['case'],metrics=r))
        print(json.dumps(dict(status='measured',cases=output),indent=2));return 0
    except Unavailable as e:print(json.dumps(dict(status='unavailable',reason=str(e))));return 3
    except (AlignmentError,OSError,ValueError,KeyError,TypeError) as e:p.exit(2,'Segment evaluation failed: '+str(e)+'\n')


if __name__=='__main__':raise SystemExit(main())
