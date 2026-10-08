"""Model-free bounded candidate planning and skip-capable chronological selection."""
import copy
import math
from .core import AlignmentError

POLICY = dict(window_us=30000000,stride_us=15000000,max_evaluations=2000,
              agreement_min=.65,similarity_min=.45,utility_floor=.60,ambiguity_margin=.05,
              duplicate_boundary_us=500000,maximum_passage_us=25000000)


def search_windows(duration):
    if type(duration) is not int or not 25000<=duration<=600000000:
        raise AlignmentError('Candidate audio duration must be 25 ms–600 seconds')
    starts=[0]
    while starts[-1]+POLICY['window_us']<duration:starts.append(starts[-1]+POLICY['stride_us'])
    return [dict(id=i,start_us=a,end_us=min(a+POLICY['window_us'],duration)) for i,a in enumerate(starts)]


def assess(candidate, duration):
    """No score is a probability, and an eligible candidate remains unverified."""
    reasons=[]
    for key in ['agreement','similarity']:
        x=candidate.get(key)
        if type(x) not in [int,float] or not math.isfinite(x) or not (-1 if key=='similarity' else 0)<=x<=1:reasons.append('invalid_score')
    lines=candidate.get('lines',[])
    prior=0
    if not lines:reasons.append('missing_line_support')
    for pair in lines:
        if not isinstance(pair,list) or len(pair)!=2 or any(type(x) is not int for x in pair) or not 0<=prior<=pair[0]<pair[1]<=duration:
            reasons.append('invalid_or_skipped_timing');break
        prior=pair[1]
    if candidate.get('unresolved'):reasons.append('model_source_coverage')
    if not reasons:
        if candidate['agreement']<POLICY['agreement_min']:reasons.append('weak_token_agreement')
        if candidate['similarity']<POLICY['similarity_min']:reasons.append('weak_span_similarity')
        if lines[-1][1]-lines[0][0]>POLICY['maximum_passage_us']:reasons.append('extended_passage')
    score=(candidate['agreement']+candidate['similarity'])/2 if not reasons else 0.
    return dict(reasons=sorted(set(reasons)),eligible=not reasons,score=score,
                utility=max(0.,score-POLICY['utility_floor']) if not reasons else 0.)


def overlap(a,b):
    intersection=max(0,min(a[-1][1],b[-1][1])-max(a[0][0],b[0][0]))
    return intersection*2>=min(a[-1][1]-a[0][0],b[-1][1]-b[0][0])


def alternatives(candidates, duration):
    """Keep original candidates; remove near-identical overlapping-window votes."""
    values=[]
    for row in candidates:
        c=copy.deepcopy(row);c.update(assess(c,duration));values.append(c)
    retained=[]
    for c in sorted(values,key=lambda x:(-x['score'],x['id'])):
        if not c['eligible']:continue
        same=next((x for x in retained if all(abs(a-b)<=POLICY['duplicate_boundary_us'] for a,b in zip([c['lines'][0][0],c['lines'][-1][1]],[x['lines'][0][0],x['lines'][-1][1]]))),None)
        if same:c['reasons'].append('duplicate_window_hypothesis');c['duplicate_of']=same['id'];c['eligible']=False
        else:retained.append(c)
    return sorted(values,key=lambda x:x['id'])


def best_path(groups, excluded=None):
    # Each frontier state is (source end, utility, selected (occurrence, candidate)).
    frontier=[(0,0.,())]
    for i,choices in enumerate(groups):
        updated=list(frontier)
        for c in choices:
            if not c['eligible'] or c['utility']<=0 or (excluded and excluded(i,c)):continue
            available=[s for s in frontier if s[0]<=c['lines'][0][0]]
            if not available:continue
            prev=max(available,key=lambda x:x[1])
            updated.append((c['lines'][-1][1],prev[1]+c['utility'],prev[2]+((i,c['id']),)))
        # Earlier endpoints with equal/better utility dominate later endpoints.
        frontier=[];best=-1.
        for state in sorted(updated,key=lambda x:(x[0],-x[1],x[2])):
            if state[1]>best:frontier.append(state);best=state[1]
    return max(frontier,key=lambda x:x[1])


def reconcile(groups, duration):
    if not isinstance(groups,list) or not 1<=len(groups)<=64 or any(not isinstance(g,list) for g in groups) or sum(len(g) for g in groups)>4000:
        raise AlignmentError('Candidate reconciliation resource limit')
    search_windows(duration)
    for group in groups:
        if not isinstance(group,list) or len(group)>64:raise AlignmentError('At most 64 windows per passage')
        ids=[]
        for c in group:
            if not isinstance(c,dict) or not isinstance(c.get('id'),str) or not 0<len(c['id'])<=64:raise AlignmentError('Candidate requires a bounded identity')
            ids.append(c['id'])
        if len(set(ids))!=len(ids):raise AlignmentError('Duplicate candidate identity within occurrence')
    prepared=[alternatives(g,duration) for g in groups]
    best=best_path(prepared);selected=dict(best[2]);decisions=[]
    for i,choices in enumerate(prepared):
        chosen=next((x for x in choices if x['id']==selected.get(i)),None)
        if chosen is None:
            state='skipped' if any(c['eligible'] for c in choices) else 'unresolved'
            decisions.append(dict(state=state,candidate=None,margin=None,alternatives=choices));continue
        alternate=best_path(prepared,lambda j,c:j==i and overlap(c['lines'],chosen['lines']))
        margin=best[1]-alternate[1]
        state='ambiguous' if margin<POLICY['ambiguity_margin'] else 'supported'
        decisions.append(dict(state=state,candidate=chosen['id'],margin=margin,
                              competing_path=list(alternate[2]),alternatives=choices))
    return dict(policy=POLICY.copy(),objective=best[1],selected_path=list(best[2]),passages=decisions,
                interpretation='Uncalibrated candidate ranking, not lexical verification; all timing requires review')


def prepare(raw):
    """Convert selected candidates to the existing explicit review/TTML workflow."""
    from .full_song import text_targets,artifact
    from .core import digest,source
    import json
    src=source(raw['source']['text'].encode())
    if src!=raw['source'] or raw['format']!='ilyric-tifa-candidates-1':raise AlignmentError('Candidate source identity changed')
    if len(raw['groups'])!=len(src['paragraphs']):raise AlignmentError('Candidate occurrence coverage differs')
    selected=reconcile(raw['groups'],raw['audio']['duration_us'])
    rows=text_targets(src)[0]
    for p,decision in enumerate(selected['passages']):
        group_rows=[r for r in rows if r['paragraph']==p]
        chosen=next((x for x in decision['alternatives'] if x['id']==decision['candidate']),None)
        if chosen and len(chosen['lines'])!=len(group_rows):raise AlignmentError('Candidate display-line coverage differs')
        for j,row in enumerate(group_rows):
            row['proposal']=chosen['lines'][j].copy() if chosen else None
            row['estimate']=row['proposal'].copy() if decision['state']=='supported' else None
            row['flags']=['candidate_requires_review'] if decision['state']=='supported' else ['correspondence_'+decision['state']]
            row['quality']=dict(semantics='Uncalibrated TIFA diagnostics, not correctness probabilities',
                agreement=chosen['agreement'] if chosen else None,similarity=chosen['similarity'] if chosen else None)
            row['correspondence']=dict(state=decision['state'],candidate=decision['candidate'],margin=decision['margin'],
                competing_path=decision.get('competing_path',[]),candidate_count=len(decision['alternatives']))
    engine=dict(id='bounded-tifa-passage-search',model_grid_us=10000,provenance=raw['provenance'],policy=POLICY.copy(),
                candidate_evidence_sha256=digest(json.dumps({k:v for k,v in raw.items() if k!='measurements'},sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()))
    result=artifact(src,raw['audio']['sha256'],raw['audio']['duration_us'],engine,raw['windows'],rows)
    result['measurements']=raw.get('measurements',{})
    return result


def central_lines(text, center, units, duration):
    """Map context word occurrences to complete central display lines without shaping."""
    from .core import canonical,make_result,source
    # Map by supplied word occurrence, not substring search. Skipped outer
    # context cannot erase otherwise complete central line support.
    template=make_result(source(text.encode()),'0'*64,duration,{},[])['lines']
    mapping=[];cursor=0
    for line in template:
        n=len(line['alignment_text']);mapping.extend([line['id']]*n)
    wanted=''.join(row['alignment_text'] for row in template)
    got=''.join(canonical(u['text'])[0] for u in units)
    by_line=[[] for _ in template];word_line={};unresolved=[]
    if wanted!=got:unresolved.append('model_source_coverage')
    else:
        for word,u in enumerate(units,1):
            n=len(canonical(u['text'])[0]);assigned=set(mapping[cursor:cursor+n]);cursor+=n
            if len(assigned)!=1:unresolved.append('word_crosses_source_line');continue
            owner=next(iter(assigned));by_line[owner].append(u);word_line[word]=owner
    values=[];center_ids={row['id'] for row in template if row['paragraph']==center}
    for line_id in sorted(center_ids):
        word_units=by_line[line_id]
        if not word_units or any(not 0<=u['begin_us']<u['end_us']<=duration for u in word_units):
            unresolved.append('missing_central_line');continue
        if any(x['end_us']>y['begin_us'] for x,y in zip(word_units,word_units[1:])):unresolved.append('overlapping_word_units')
        values.append([word_units[0]['begin_us'],word_units[-1]['end_us']])
    return values,word_line,center_ids,sorted(set(unresolved))
