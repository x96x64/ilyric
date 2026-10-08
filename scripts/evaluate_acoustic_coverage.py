#!/usr/bin/env python3
"""Bounded private-control evaluator; outputs neutral identifiers and numbers.

Manifest entries: case, variant, role, artifact, features. Paths are relative to
manifest. Labels are independently established by control construction. Freeze
uses development only; score requires the saved thresholds and never refits.
"""
import argparse
import json
from pathlib import Path
import re
from align_lyrics import read_artifact
from alignment.core import AlignmentError, digest
from alignment.worker import Unavailable
from alignment.coverage import fit_threshold, flagged, confusion
from alignment.endpoints import quality_gate
from diagnose_acoustic_coverage import assess


def read_manifest(path, development_only=False):
    if not path.is_file():raise Unavailable('Private acoustic-control manifest unavailable')
    if path.stat().st_size>65536:raise AlignmentError('Control manifest exceeds 64 KiB')
    entries=json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(entries,list) or not 1<=len(entries)<=128:raise AlignmentError('Supply 1–128 controls')
    rows=[];seen=set()
    for x in entries:
        if set(x)!={'case','variant','role','artifact','features'} or not re.fullmatch(r'(EN|JA)[0-9]{2}',x['case']):raise AlignmentError('Invalid neutral case identity')
        if x['variant'] not in ['matched','omit_middle','duplicate','absent','early_end','misordered'] or x['role'] not in ['development','diagnostic-reuse','reserved']:raise AlignmentError('Invalid control classification')
        if development_only and x['role']!='development':continue
        a=path.parent/x['artifact'];f=path.parent/x['features']
        if not a.is_file() or not f.is_file():raise Unavailable('Private alignment or acoustic feature unavailable')
        if f.stat().st_size>2*1024*1024:raise AlignmentError('Feature file exceeds 2 MiB')
        artifact=read_artifact(a);features=json.loads(f.read_text(encoding='utf-8'));d=assess(artifact,features)
        engine=artifact['engine']['identity'];key=(x['case'],engine,x['variant'])
        if engine not in ['tifa','ctc'] or key in seen:raise AlignmentError('Duplicate or unsupported engine')
        seen.add(key)
        oldscore=artifact['engine']['metadata'].get('token_agreement' if engine=='tifa' else 'forced_token_log_support')
        rows.append(dict(case=x['case'],variant=x['variant'],role=x['role'],engine=engine,matched=x['variant']=='matched',
                         spectral=d['spectral']['score'],ctc_activity=d['ctc_activity']['score'],lexical=d['lexical_score'],
                         legacy_flag=quality_gate(oldscore,0.989473283290863 if engine=='tifa' else -2.598405957221985,bool(artifact['unresolved']))=='review_required',
                         audio_sha256=features['audio_sha256'],feature_sha256=digest(f.read_bytes())))
    return rows


def freeze(rows):
    if any(x['role']!='development' for x in rows):raise AlignmentError('Freeze input contains nondevelopment controls')
    thresholds={}
    for engine in ['ctc','tifa']:
        thresholds[engine]={}
        for feature in ['spectral','ctc_activity','lexical']:
            selected=[dict(x,score=x[feature]) for x in rows if x['engine']==engine and x[feature] is not None]
            thresholds[engine][feature]=fit_threshold(selected)
    return dict(version=1,thresholds=thresholds,development_rows_sha256=digest(json.dumps(rows,sort_keys=True).encode()),
                semantics='Experimental high-score review flag; not automatic acceptance or calibrated probability')


def score(rows, frozen):
    if frozen.get('version')!=1:raise AlignmentError('Unsupported frozen threshold record')
    development=[x for x in rows if x['role']=='development']
    if digest(json.dumps(development,sort_keys=True).encode()) != frozen.get('development_rows_sha256'):
        raise AlignmentError('Frozen thresholds do not identify these development inputs')
    results=[]
    for engine in ['ctc','tifa']:
        for role in ['development','diagnostic-reuse','reserved']:
            subset=[x for x in rows if x['engine']==engine and x['role']==role]
            for feature in ['legacy','spectral','ctc_activity','lexical']:
                decisions=[]
                for x in subset:
                    flag=x['legacy_flag'] if feature=='legacy' else flagged(x[feature],frozen['thresholds'][engine][feature])
                    decisions.append(dict(case=x['case'],variant=x['variant'],matched=x['matched'],flag=flag,legacy_flag=x['legacy_flag']))
                for combine in ([False] if feature=='legacy' else [False,True]):
                    ds=[dict(x,flag=(True if x['legacy_flag'] else x['flag'])) if combine else x for x in decisions]
                    results.append(dict(engine=engine,role=role,candidate=feature+('_or_legacy' if combine else ''),
                                        confusion=confusion(ds),by_class={v:confusion([x for x in ds if x['variant']==v]) for v in sorted({x['variant'] for x in ds})},decisions=ds))
    return dict(version=1,evidence='Constructed mismatch controls; no automatic acceptance',thresholds=frozen,rows=rows,results=results)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('mode',choices=['freeze','score']);p.add_argument('manifest',type=Path)
    p.add_argument('--frozen',type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
    try:
        if a.output.exists():raise AlignmentError('Output already exists')
        rows=read_manifest(a.manifest,a.mode=='freeze')
        if a.mode=='freeze':r=freeze(rows)
        else:
            if a.frozen is None or not a.frozen.is_file():raise Unavailable('Frozen development thresholds unavailable')
            if a.frozen.stat().st_size>65536:raise AlignmentError('Frozen thresholds exceed limit')
            r=score(rows,json.loads(a.frozen.read_text()))
        with a.output.open('x') as f:json.dump(r,f,indent=2)
        print(json.dumps(dict(status='experimental_evaluation',automatic_acceptance=False)))
    except Unavailable as e:print(json.dumps(dict(status='unavailable',reason=str(e))));return 3
    except (AlignmentError,OSError,ValueError,TypeError,KeyError) as e:p.exit(2,'Coverage evaluation failed: '+str(e)+'\n')
    return 0

if __name__=='__main__':raise SystemExit(main())
