"""Bounded, review-first full-song preparation; no inference in this module.

Forced correspondence is a proposal, never a verified match. Public rendering
schemas and the 60-second excerpt artifact remain unchanged.
"""
import copy
import json
import math
import re
from difflib import SequenceMatcher
from xml.sax.saxutils import escape
from .core import AlignmentError, canonical, digest, make_result, source

GRID_US = 20000
MAX_US = 600000000


def windows(samples, rate=16000):
    if type(samples) is not int or not 0 < samples <= rate*600 or rate != 16000:
        raise AlignmentError('Full-song analysis requires 16-kHz audio of at most 600 seconds')
    size, stride = rate*30, rate*26
    starts = [0]
    while starts[-1]+size < samples:
        starts.append(starts[-1]+stride)
    result = []
    for i, start in enumerate(starts):
        end = min(samples, start+size)
        left = 0 if i == 0 else (start+min(samples, starts[i-1]+size))//2
        right = samples if i+1 == len(starts) else (end+starts[i+1])//2
        result.append(dict(id=i, start_sample=start, end_sample=end,
                           keep_start_sample=left, keep_end_sample=right))
    return result


def owned_frames(row, frame_count, expected):
    """Central ownership selects existing model frames; never averages overlap."""
    selected=[]
    for local in range(frame_count):
        sample=row['start_sample']+local*320
        if row['keep_start_sample']<=sample<row['keep_end_sample']:
            if sample//320!=expected+len(selected):
                raise AlignmentError('Window reconciliation introduced a missing or duplicate frame')
            selected.append(local)
    return selected


def text_targets(src):
    template = make_result(src, '0'*64, 1, {}, [])['lines']
    tokens, owners = [], []
    for row in template:
        words = re.findall(r"[A-Za-z]+(?:['’][A-Za-z]+)*", row['text'])
        if not words or canonical(''.join(words))[0] != row['alignment_text']:
            raise AlignmentError('Full-song CTC currently supports English ASCII letters and contractions only; use the existing Japanese excerpt workflow')
        text = '|'.join(x.replace('’', "'").upper() for x in words)
        if tokens:
            tokens.append('|'); owners.append(None)
        tokens.extend(text); owners.extend([row['id']]*len(text))
    if len(tokens) > 6000:
        raise AlignmentError('Full-song text exceeds 6000 CTC labels')
    return template, tokens, owners


def path(emissions, targets, blank=0):
    """Global monotonic CTC occurrence path over stitched bounded-window scores.

    Trace memory is explicitly capped. Leading/trailing blanks and internal gaps
    have acoustic costs, not reference-derived endpoints. Unsupported words can
    still be forced: downstream support checks must retain that uncertainty.
    """
    frames = len(emissions)
    if not targets or len(targets)>6000 or not 0 < frames <=30000:
        raise AlignmentError('Full-song frame or target limit')
    width=len(emissions[0]); labels=[blank]
    if type(blank) is not int or not 0 <= blank < width:
        raise AlignmentError('Invalid blank label')
    for target in targets:
        if type(target) is not int or target == blank or not 0 <= target < width:
            raise AlignmentError('Invalid CTC label')
        labels.extend([target,blank])
    count=len(labels)
    if frames*count > 120000000:
        raise AlignmentError('Full-song CTC trace exceeds 120 MB; reduce input, not model limits')
    scores=[-math.inf]*count;scores[0]=0.;trace=[]
    skip=[j>1 and v!=blank and v!=labels[j-2] for j,v in enumerate(labels)]
    for emission in emissions:
        if len(emission)!=width or any(not math.isfinite(float(x)) for x in emission):
            raise AlignmentError('Nonfinite or inconsistent acoustic scores')
        choices=bytearray(count);next_scores=[-math.inf]*count
        for j,label in enumerate(labels):
            value=scores[j]
            if j and scores[j-1]>value:value=scores[j-1];choices[j]=1
            if skip[j] and scores[j-2]>value:value=scores[j-2];choices[j]=2
            next_scores[j]=value+float(emission[label])
        trace.append(choices);scores=next_scores
    state=count-1 if scores[-1]>=scores[-2] else count-2
    if not math.isfinite(scores[state]):return None
    spans=[[frames,0] for _ in targets]
    for frame in range(frames-1,-1,-1):
        if state%2:
            span=spans[state//2];span[0]=frame;span[1]=max(span[1],frame+1)
        state-=trace[frame][state]
    return spans if all(a<b for a,b in spans) else None


def greedy(ids, alphabet, blank=0):
    result=[];prior=None
    for value in ids:
        if value!=prior and value!=blank:result.append(alphabet[value])
        prior=value
    return ''.join(result).replace('|',' ')


def proposals(src, duration, emissions, tokens, owners, spans, vocab, blank=0):
    rows=text_targets(src)[0];alphabet={v:k for k,v in vocab.items()}
    repeated={r['alignment_text'] for r in rows if sum(x['alignment_text']==r['alignment_text'] for x in rows)>1}
    best=[max(range(len(e)),key=lambda x:e[x]) for e in emissions]
    for row in rows:
        indices=[i for i,owner in enumerate(owners) if owner==row['id'] and tokens[i]!='|']
        row['proposal']=None;row['estimate']=None;row['flags']=[];row['quality']={}
        if row['alignment_text'] in repeated:row['flags'].append('repeated_occurrence_requires_review')
        if spans is None:
            row['flags'].append('no_complete_path');continue
        a,b=spans[indices[0]][0],spans[indices[-1]][1]
        proposal=[a*GRID_US,min(duration,b*GRID_US)]
        local=greedy(best[a:b],alphabet,blank)
        observed=canonical(local)[0]
        support=sum(sum(emissions[t][vocab[tokens[i]]] for t in range(*spans[i]))/(spans[i][1]-spans[i][0]) for i in indices)/len(indices)
        ratio=SequenceMatcher(None,row['alignment_text'],observed,autojunk=False).ratio()
        row['proposal']=proposal
        row['quality']=dict(forced_mean_log_support=support,greedy_similarity=ratio,
                            semantics='Uncalibrated review diagnostics; greedy and forced paths share the same speech model')
        if support < -3.0:row['flags'].append('weak_acoustic_support')
        if ratio < .55:row['flags'].append('weak_lexical_agreement')
        if any((spans[i][1]-spans[i][0])*GRID_US>1500000 for i in indices):row['flags'].append('extended_character_support')
        if proposal[1]-proposal[0]>20000000:row['flags'].append('extended_line_support')
        if any(x!='repeated_occurrence_requires_review' for x in row['flags']):continue
        row['estimate']=proposal.copy()
    return rows


def fingerprint(result):
    immutable={k:result[k] for k in ['format','source','audio','engine','windows']}
    immutable['lines']=[{k:v for k,v in row.items() if k not in ['correction','review']} for row in result['lines']]
    return digest(json.dumps(immutable,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode())


def artifact(src, audio_hash, duration, engine, windows_, rows):
    result=dict(format='ilyric-full-song-experiment-1',source=src,
                audio=dict(sha256=audio_hash,duration_us=duration),engine=engine,
                windows=windows_,lines=rows,history=[],automatic_acceptance=False)
    result['proposal_sha256']=fingerprint(result)
    return validate(result)


def interval(row):
    return row['correction']['interval_us'] if row['correction'] else row['estimate']


def validate(result, ready=False):
    try:
        if result['format']!='ilyric-full-song-experiment-1' or result['automatic_acceptance'] is not False:
            raise AlignmentError('Unsupported full-song artifact')
        src=source(result['source']['text'].encode())
        if src!=result['source']:raise AlignmentError('Source identity or structure changed')
        duration=result['audio']['duration_us']
        if type(duration) is not int or not 0<duration<=MAX_US or not re.fullmatch('[0-9a-f]{64}',result['audio']['sha256']):
            raise AlignmentError('Invalid full-song audio identity or duration')
        passage=result['engine'].get('id')=='bounded-tifa-passage-search'
        if result['engine']['model_grid_us']!=(10000 if passage else GRID_US):raise AlignmentError('Unsupported model temporal resolution')
        if fingerprint(result)!=result['proposal_sha256']:raise AlignmentError('Original proposals changed; use reviewed corrections')
        if not isinstance(result['history'],list) or len(result['history'])>4096:
            raise AlignmentError('Review history exceeds 4096 entries')
        if passage:
            from .passage_search import search_windows
            expected_windows=search_windows(duration)
        else:
            count=result['engine'].get('analysis_samples',(duration*16000+999999)//1000000)
            if type(count) is not int or abs(count*1000000-duration*16000)>1000000:
                raise AlignmentError('Analysis sample count differs from source duration')
            expected_windows=windows(count)
        if len(expected_windows)!=len(result['windows']) or any(any(row.get(k)!=v for k,v in expected.items()) for row,expected in zip(result['windows'],expected_windows)):
            raise AlignmentError('Bounded-window source geometry changed')
        template=text_targets(src)[0]
        if len(template)!=len(result['lines']):raise AlignmentError('Source occurrence coverage changed')
        prior=0
        for expected,row in zip(template,result['lines']):
            for key in ['id','paragraph','start_utf16','length_utf16','text','alignment_text','range_map']:
                # JSON converts range tuples to lists.
                if json.dumps(expected[key])!=json.dumps(row[key]):raise AlignmentError('Source occurrence mapping changed')
            if row['review'] not in ['pending','accepted','corrected']:raise AlignmentError('Unsupported review state')
            for value in [row['estimate'],row['proposal'],interval(row)]:
                if value is not None and (not isinstance(value,list) or len(value)!=2 or any(type(x) is not int for x in value) or not 0<=value[0]<value[1]<=duration):
                    raise AlignmentError('Invalid interval')
            if not isinstance(row['flags'],list) or len(row['flags'])>16 or any(not isinstance(x,str) for x in row['flags']):
                raise AlignmentError('Invalid diagnostic flags')
            if not isinstance(row['quality'],dict):raise AlignmentError('Invalid diagnostic scores')
            for key in ['forced_mean_log_support','greedy_similarity']:
                if key in row['quality'] and (type(row['quality'][key]) not in [int,float] or not math.isfinite(row['quality'][key])):
                    raise AlignmentError('Nonfinite diagnostic score')
            correction=row['correction']
            if correction and (correction.get('origin')!='manually_corrected' or not isinstance(correction.get('note'),str) or not correction['note'].strip() or len(correction['note'])>2000 or row['review']!='corrected'):
                raise AlignmentError('Corrections require provenance and review')
            if row['review']=='corrected' and not correction:raise AlignmentError('Missing correction')
            if row['review']!='pending':
                if not any(x.get('line')==row['id'] and x.get('action')==row['review'] and x.get('interval_us')==interval(row) and x.get('note') for x in result['history']):
                    raise AlignmentError('Missing matching review history')
            value=interval(row)
            if value:
                if value[0]<prior:raise AlignmentError('Effective intervals overlap or reverse occurrence order')
                prior=value[1]
            if ready and (value is None or row['review']=='pending'):raise AlignmentError('Every occurrence requires a reviewed interval before complete export')
        return result
    except (KeyError,TypeError,AttributeError,RecursionError) as e:
        raise AlignmentError('Malformed full-song artifact') from e


def unassigned_audio(result):
    """Complement of effective line intervals, never an instrumental classifier."""
    validate(result);gaps=[];end=0
    for row in result['lines']:
        value=interval(row)
        if value is None:continue
        if value[0]>end:gaps.append([end,value[0]])
        end=value[1]
    if end<result['audio']['duration_us']:gaps.append([end,result['audio']['duration_us']])
    return gaps


def review(result, decisions):
    validate(result);out=copy.deepcopy(result)
    if not isinstance(decisions,list) or not 0<len(decisions)<=256:raise AlignmentError('Supply 1–256 explicit review decisions')
    seen=set()
    for decision in decisions:
        if not isinstance(decision,dict) or set(decision)-{'line','interval_us','note'}:raise AlignmentError('Invalid review decision')
        line=decision.get('line');note=decision.get('note')
        if type(line) is not int or not 0<=line<len(out['lines']) or line in seen or not isinstance(note,str) or not note.strip() or len(note)>2000:
            raise AlignmentError('Review requires a unique occurrence and a bounded note')
        seen.add(line);row=out['lines'][line]
        if 'interval_us' in decision:
            row['correction']=dict(interval_us=decision['interval_us'],origin='manually_corrected',note=note)
            row['review']='corrected'
        elif row['estimate'] is not None and row['correction'] is None:row['review']='accepted'
        else:raise AlignmentError('Unresolved or corrected occurrence requires explicit correction bounds')
        out['history'].append(dict(line=line,action=row['review'],interval_us=interval(row),note=note))
    return validate(out)


def to_ttml(result):
    validate(result,ready=True)
    def stamp(t):return f'{t//1000000}.{t%1000000:06d}s'
    paragraphs=[]
    for p,text in enumerate(result['source']['paragraphs']):
        lines=[r for r in result['lines'] if r['paragraph']==p]
        paragraphs.append(f'<p begin="{stamp(interval(lines[0])[0])}" end="{stamp(interval(lines[-1])[1])}">'+ '<br/>'.join(escape(x) for x in text.split('\n'))+'</p>')
    xml='<tt xmlns="http://www.w3.org/ns/ttml" xml:space="preserve"><body><div>'+''.join(paragraphs)+'</div></body></tt>\n'
    if len(xml.encode())>65536:raise AlignmentError('Prepared TTML exceeds the existing importer limit')
    return xml


def load(path):
    if not path.is_file():
        from .worker import Unavailable
        raise Unavailable('Full-song artifact unavailable')
    if path.stat().st_size>2*1024*1024:raise AlignmentError('Artifact exceeds 2 MiB')
    def pairs(items):
        result={}
        for k,v in items:
            if k in result:raise AlignmentError('Duplicate JSON field')
            result[k]=v
        return result
    try:
        return validate(json.loads(path.read_text(encoding='utf-8'),object_pairs_hook=pairs,
            parse_constant=lambda _: (_ for _ in ()).throw(AlignmentError('Nonfinite JSON'))))
    except (ValueError,UnicodeError,RecursionError) as e:raise AlignmentError('Invalid full-song JSON: '+str(e)) from e
