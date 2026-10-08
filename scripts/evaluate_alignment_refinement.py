#!/usr/bin/env python3
"""Optional private-artifact evaluation; no inference or network access.

Manifest: list of {case, variant, role, result}. Result paths are relative to it.
Only neutral case IDs and numerical diagnostics are returned. Both matched and
negative development controls are required; thresholds are frozen before scoring
held-out cases. A not-flagged result is not qualified automatic acceptance.
"""
import argparse
import json
from pathlib import Path
import re
from align_lyrics import read_artifact
from alignment.core import AlignmentError
from alignment.endpoints import fit_review_threshold, confusion
from alignment.worker import Unavailable


def evaluate(path):
    if not path.is_file():raise Unavailable('Private refinement manifest unavailable')
    if path.stat().st_size>65536:raise AlignmentError('Refinement manifest exceeds 64 KiB')
    entries=json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(entries,list) or not 1<=len(entries)<=64:raise AlignmentError('Supply 1–64 cases')
    rows=[];seen=set()
    for x in entries:
        if set(x)!={'case','variant','role','result'} or not re.fullmatch(r'(EN|JA)[0-9]{2}',x['case']):raise AlignmentError('Invalid neutral case identity')
        if x['variant'] not in ['matched','omit_middle','duplicate','absent','early_end'] or x['role'] not in ['development','held-out']:
            raise AlignmentError('Unsupported case classification')
        target=path.parent/x['result']
        if not target.is_file():raise Unavailable('Private refinement artifact unavailable')
        r=read_artifact(target);engine=r['engine']['identity']
        if engine not in ['ctc','tifa']:raise AlignmentError('Unsupported evaluated engine')
        key=(x['case'],engine,x['variant'])
        if key in seen:raise AlignmentError('Duplicate evaluated occurrence')
        seen.add(key)
        score=r['engine']['metadata'].get('token_agreement' if engine=='tifa' else 'forced_token_log_support')
        rows.append(dict(case=x['case'],engine=engine,variant=x['variant'],role=x['role'],
                         matched=x['variant']=='matched',score=score,unresolved=bool(r['unresolved'])))
    fits={};metrics=[]
    for engine in sorted({x['engine'] for x in rows}):
        fits[engine]=fit_review_threshold([x for x in rows if x['engine']==engine and x['role']=='development'])
        for role in ['development','held-out']:
            selected=[x for x in rows if x['engine']==engine and x['role']==role]
            metrics.append(dict(engine=engine,role=role,**confusion(selected,fits[engine])))
    return dict(evidence='Experimental review flags, not calibrated correctness probabilities',thresholds=fits,cases=rows,confusion=metrics)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('manifest',type=Path);args=parser.parse_args()
    try:print(json.dumps(evaluate(args.manifest),indent=2))
    except Unavailable as e:
        print(json.dumps(dict(status='unavailable',reason=str(e))));raise SystemExit(3)
    except (AlignmentError,OSError,ValueError,TypeError,KeyError) as e:parser.exit(2,'Refinement evaluation failed: '+str(e)+'\n')
