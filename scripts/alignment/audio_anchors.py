"""Bounded audio-only lexical evidence; no inference, normalization of display text, or I/O."""
import copy
import json
import re
import unicodedata
from .core import AlignmentError, digest, source
from .full_song import text_targets, windows, artifact
from .passage_search import best_path, overlap

FORMAT = 'ilyric-audio-anchors-1'
POLICY = dict(version=1, minimum_matches=2, maximum_edit_percent=30,
              maximum_line_us=25000000, maximum_internal_gap_us=3000000,
              ambiguity_margin=10, maximum_tokens=10000, maximum_candidates=4000,
              maximum_cells=20000000, maximum_reconciliation_work=100000000)


def fingerprint(value):
    return digest(json.dumps(value, sort_keys=True, separators=(',', ':'),
                             ensure_ascii=False, allow_nan=False).encode())


def fields(value, keys):
    if not isinstance(value, dict) or set(value) != set(keys.split()):
        raise AlignmentError('Missing or unknown anchor field')


def integer(value, lo, hi):
    if type(value) is not int or not lo <= value <= hi:
        raise AlignmentError('Invalid anchor integer or resource limit')


def sha(value, size=64):
    if not isinstance(value, str) or not re.fullmatch('[0-9a-f]{'+str(size)+'}', value):
        raise AlignmentError('Invalid anchor provenance identity')


def ticks_us(value, rate):
    integer(rate, 1, 1000000)
    if 1000000 % rate:
        raise AlignmentError('Anchor timebase must convert exactly to integer microseconds')
    integer(value, 0, 600*rate)
    return value*(1000000//rate)


def validate(record):
    """Strict experimental schema. Raw overlaps remain evidence, not silently repaired timing."""
    try:
        fields(record, 'format audio language timebase_hz resolution_ticks provenance observations')
        if record['format'] != FORMAT or record['language'] != 'en':
            raise AlignmentError('Only experimental English audio anchors are supported')
        audio = record['audio']; fields(audio, 'sha256 duration_us')
        sha(audio['sha256']); integer(audio['duration_us'], 25000, 600000000)
        ticks_us(0, record['timebase_hz'])
        integer(record['resolution_ticks'],1,record['timebase_hz'])
        p = record['provenance']
        fields(p, 'producer revision model weights_sha256 origin decoding')
        sha(p['revision'], 40); sha(p['weights_sha256'])
        for key in ['producer', 'model']:
            if not isinstance(p[key], str) or not 1 <= len(p[key]) <= 160:
                raise AlignmentError('Missing bounded model provenance')
        if p['origin'] not in ['audio_only', 'synthetic']:
            raise AlignmentError('Lyric-conditioned anchors are unsupported')
        fields(p['decoding'], 'lyric_prompt previous_text_context translation')
        if any(v is not False for v in p['decoding'].values()):
            raise AlignmentError('Anchors require unprompted, context-reset, untranslated audio evidence')
        observations = record['observations']
        if not isinstance(observations, list) or len(observations) > 10000:
            raise AlignmentError('At most 10000 recognized observations')
        plan = windows((audio['duration_us']*16000+999999)//1000000)
        ids = set(); chars = 0
        for row in observations:
            fields(row, 'id window text begin_tick end_tick uncertainty')
            if not isinstance(row['id'], str) or not re.fullmatch('[A-Za-z0-9_-]{1,64}', row['id']) or row['id'] in ids:
                raise AlignmentError('Duplicate or invalid observation identity')
            ids.add(row['id']); integer(row['window'], 0, len(plan)-1)
            a, b = (ticks_us(row[k], record['timebase_hz']) for k in ['begin_tick', 'end_tick'])
            w = plan[row['window']]
            if not 0 <= a < b <= audio['duration_us'] or a*16000 < w['start_sample']*1000000 or b*16000 > w['end_sample']*1000000:
                raise AlignmentError('Observation outside its source window or audio')
            if not isinstance(row['text'], str) or not row['text'] or len(row['text']) > 2000:
                raise AlignmentError('Invalid recognized text')
            if any(ord(c)<32 or 0xD800<=ord(c)<=0xDFFF for c in row['text']):
                raise AlignmentError('Invalid recognized text control or surrogate')
            chars += len(row['text'])
            if not isinstance(row['uncertainty'], list) or len(row['uncertainty'])>8 or any(not isinstance(x,str) or not re.fullmatch('[a-z_]{1,64}',x) for x in row['uncertainty']):
                raise AlignmentError('Invalid uncertainty labels; scores are not probabilities')
        if chars > 65536: raise AlignmentError('Recognized text exceeds 64 Ki characters')
        return record
    except (KeyError, TypeError, AttributeError, OverflowError) as e:
        raise AlignmentError('Malformed audio anchors') from e


def lexical(text):
    """English-only words and exact local UTF-16 ranges; unsupported spans remain diagnostic."""
    if any((c.isalnum() and not ('A'<=c<='Z' or 'a'<=c<='z')) or unicodedata.category(c)[0] in 'SM' for c in text):
        return None
    result = []
    for m in re.finditer(r"[A-Za-z]+(?:['’][A-Za-z]+)*", text):
        result.append(dict(word=m[0].replace('’', "'").lower(),
                           start_utf16=len(text[:m.start()].encode('utf-16-le'))//2,
                           length_utf16=len(m[0].encode('utf-16-le'))//2))
    return result


def observations(record):
    validate(record)
    plan = windows((record['audio']['duration_us']*16000+999999)//1000000)
    kept = []; rejected = []
    for row in sorted(record['observations'], key=lambda x:(x['begin_tick'],x['end_tick'],x['id'])):
        a, b = [ticks_us(row[k], record['timebase_hz']) for k in ['begin_tick','end_tick']]
        w = plan[row['window']]; reason = None
        # Exact doubled midpoint comparison, without rounding to an output frame.
        if not w['keep_start_sample']*2000000 <= (a+b)*16000 < w['keep_end_sample']*2000000:
            reason = 'outside_central_window_ownership'
        words = lexical(row['text'])
        if words is None or not words: reason = 'unsupported_recognition_text'
        if row['uncertainty']: reason = 'recognition_uncertainty'
        if reason:
            rejected.append(dict(observation=row['id'],reason=reason)); continue
        for word in words:
            kept.append(dict(word, observation=row['id'], window=row['window'], interval_us=[a,b]))
    if len(kept)>POLICY['maximum_tokens']: raise AlignmentError('Anchor token resource limit')
    return kept, rejected


def line_candidates(words, tokens):
    """Semi-global word edit alignment; audio prefixes/suffixes are free, text deletions are not.

    One optimum per endpoint is retained, with deterministic tie-breaking. This
    bounded generator is not exhaustive; candidate availability must be scored.
    """
    n = len(tokens); m = len(words)
    if not m or m>120: raise AlignmentError('Line requires 1–120 English words')
    trace = [bytearray(n+1) for _ in range(m+1)]
    prior = [(0,0,j) for j in range(n+1)] # edit cost, negative exact matches, start
    for i, word in enumerate(words,1):
        current = [(i,0,0)]; trace[i][0] = 1
        for j, token in enumerate(tokens,1):
            same = word == token['word']
            diagonal = (prior[j-1][0]+(not same),prior[j-1][1]-same,prior[j-1][2])
            deletion = (prior[j][0]+1,prior[j][1],prior[j][2])
            insertion = (current[-1][0]+1,current[-1][1],current[-1][2])
            value, direction = min((diagonal,0),(deletion,1),(insertion,2))
            current.append(value); trace[i][j] = direction
        prior = current
    output = []
    for end in range(1,n+1):
        edits, minus_matches, _ = prior[end]
        if -minus_matches < POLICY['minimum_matches'] or edits*100 > POLICY['maximum_edit_percent']*m:
            continue
        i,j=m,end; pairs=[]
        while i:
            direction=trace[i][j]
            if direction==0:
                if words[i-1]==tokens[j-1]['word']: pairs.append([i-1,j-1])
                i-=1;j-=1
            elif direction==1:i-=1
            else:j-=1
        used=tokens[j:end]
        if not used:continue
        a=min(t['interval_us'][0] for t in used);b=max(t['interval_us'][1] for t in used)
        reasons=[]
        if b-a>POLICY['maximum_line_us']:reasons.append('extended_anchor_region')
        if any(y['interval_us'][0]-x['interval_us'][1]>POLICY['maximum_internal_gap_us'] for x,y in zip(used,used[1:])):
            reasons.append('internal_audio_gap')
        if any(y['interval_us'][0]<x['interval_us'][0] for x,y in zip(used,used[1:])):
            reasons.append('nonchronological_recognition')
        output.append(dict(id=f't{j}-{end}',lines=[[a,b]],token_range=[j,end],
                           matches=-minus_matches,edits=edits,matched_pairs=list(reversed(pairs)),
                           eligible=not reasons,reasons=reasons,utility=100*(-minus_matches)-100*edits))
    # Do not count shifted endpoints around one physical region as independent votes.
    retained=[]
    for c in sorted(output,key=lambda x:(-x['utility'],x['edits'],x['token_range'])):
        duplicate=next((x for x in retained if overlap(c['lines'],x['lines'])),None)
        if duplicate:
            c['eligible']=False;c['reasons'].append('overlapping_region_alternative');c['duplicate_of']=duplicate['id']
        elif c['eligible']:retained.append(c)
    return sorted(output,key=lambda x:x['token_range'])


def match(src, record):
    validate(record)
    if source(src['text'].encode()) != src: raise AlignmentError('Authoritative source identity changed')
    rows=text_targets(src)[0];tokens,rejected=observations(record)
    targets=[lexical(row['text']) for row in rows]
    if sum(len(t) for t in targets)*max(1,len(tokens))>POLICY['maximum_cells']:
        raise AlignmentError('Sequence matching exceeds 20 million cells')
    groups=[]
    for target in targets:
        groups.append(line_candidates([t['word'] for t in target],tokens))
        if sum(len(g) for g in groups)>POLICY['maximum_candidates']:
            raise AlignmentError('Sequence matching exceeds 4000 candidates')
    eligible=sum(c['eligible'] for g in groups for c in g)
    if eligible*eligible*(len(rows)+1)>POLICY['maximum_reconciliation_work']:
        raise AlignmentError('Chronological alternative search exceeds bounded work budget')
    best=best_path(groups);selected=dict(best[2]);decisions=[]
    for i,g in enumerate(groups):
        chosen=next((c for c in g if c['id']==selected.get(i)),None)
        if chosen:
            alternate=best_path(groups,lambda k,c:k==i and overlap(c['lines'],chosen['lines']))
            margin=best[1]-alternate[1]
            state='ambiguous' if margin<POLICY['ambiguity_margin'] else 'supported'
            decision=dict(state=state,candidate=chosen['id'],region_us=chosen['lines'][0],
                          margin=margin,competing_path=list(alternate[2]))
        else:
            decision=dict(state='skipped' if any(c['eligible'] for c in g) else 'unresolved',
                          candidate=None,region_us=None,margin=None,competing_path=[])
        decision.update(occurrence=i,candidate_count=len(g),eligible_count=sum(c['eligible'] for c in g),
                        diagnostic='boundary_refinement_pending' if decision['state']=='supported' else
                        'competing_occurrence_paths' if decision['state']=='ambiguous' else
                        'chronological_conflict' if decision['state']=='skipped' else 'missing_candidate_coverage')
        decisions.append(decision)
    result=dict(format='ilyric-audio-correspondence-1',source=copy.deepcopy(src),anchors=copy.deepcopy(record),
                anchor_sha256=fingerprint(record),policy=POLICY.copy(),tokens=tokens,
                rejected_observations=rejected,source_tokens=targets,groups=groups,decisions=decisions,
                selected_path=list(best[2]),objective=best[1],automatic_acceptance=False,
                interpretation='Uncalibrated lexical agreement; missing coverage cannot identify its acoustic cause; no boundary estimates')
    # Covered observations are not certified vocals; unassigned observations are not missing lyrics.
    used=set()
    for i,decision in enumerate(decisions):
        if decision['state']!='supported':continue
        c=next(c for c in groups[i] if c['id']==decision['candidate'])
        used.update(t['observation'] for t in tokens[slice(*c['token_range'])])
    result['unassigned_observations']=sorted({r['id'] for r in record['observations']}-used)
    gaps=[];end=0
    for d in decisions:
        if d['state']!='supported':continue
        a,b=d['region_us']
        if a>end:gaps.append([end,a])
        end=b
    if end<record['audio']['duration_us']:gaps.append([end,record['audio']['duration_us']])
    result['unassigned_audio_regions_us']=gaps
    result['unassigned_audio_semantics']='Unknown acoustic/lexical coverage; not classified silence or instrumental music'
    return result


def review_artifact(result):
    """Coarse anchors never become timing estimates. Existing explicit correction remains usable."""
    rebuilt=match(result['source'],result['anchors'])
    if fingerprint(rebuilt)!=fingerprint(result):raise AlignmentError('Correspondence evidence changed')
    duration=result['anchors']['audio']['duration_us'];rows=text_targets(result['source'])[0]
    for row,decision in zip(rows,result['decisions']):
        row.update(proposal=None,estimate=None,flags=[decision['diagnostic']],quality={},
                   correspondence=copy.deepcopy(decision))
    return artifact(result['source'],result['anchors']['audio']['sha256'],duration,
                    dict(id='audio-anchor-correspondence-pending-refinement',model_grid_us=20000,
                         anchor_timebase_hz=result['anchors']['timebase_hz'],
                         anchor_resolution_ticks=result['anchors']['resolution_ticks'],
                         correspondence_sha256=fingerprint(result),interpretation='No CTC refinement performed'),
                    windows((duration*16000+999999)//1000000),rows)
