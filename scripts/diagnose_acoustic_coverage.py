#!/usr/bin/env python3
"""Compare separately extracted audio evidence with an alignment artifact.

Research diagnostics only. This command never accepts, repairs, or exports timing.
All output regions are hypotheses for inspection, not verified omitted singing.
"""
import argparse
import json
from pathlib import Path
from align_lyrics import read_artifact
from alignment.core import AlignmentError, digest
from alignment.worker import Unavailable
from alignment.coverage import coverage, lexical_disagreement


def assess(artifact, features, use_corrections=False):
    from alignment.core import validate
    validate(artifact)
    if features.get('version') != 1 or features.get('audio_sha256') != artifact['audio']['sha256'] or features.get('duration_us') != artifact['audio']['duration_us']:
        raise AlignmentError('Audio feature and alignment identities disagree')
    text=features.get('greedy_text')
    if not isinstance(text,str) or len(text)>6000:raise AlignmentError('Invalid bounded greedy evidence')
    if features.get('provenance',{}).get('source_conditioning') != 'audio only; no supplied text':
        raise AlignmentError('Independent audio-only provenance required')
    estimates=[];unresolved=[]
    for line in artifact['lines']:
        value=(line['correction']['interval_us'] if use_corrections and line['correction'] is not None else line['estimate'])
        if value is None:unresolved.append(line['id'])
        else:estimates.append(value)
    duration=artifact['audio']['duration_us']
    return dict(version=1,status='research_diagnostic_only',automatic_acceptance=False,
                audio_sha256=artifact['audio']['sha256'],source_sha256=artifact['source']['sha256'],
                artifact_sha256=digest(json.dumps(artifact,ensure_ascii=False,sort_keys=True).encode()),
                feature_sha256=digest(json.dumps({k:v for k,v in features.items() if k!='measurements'},ensure_ascii=False,sort_keys=True).encode()),
                timing_selection='reviewed corrections where supplied' if use_corrections else 'original estimates',
                unresolved_lines=unresolved,
                spectral=coverage(features.get('spectral_activity_us'),estimates,duration),
                ctc_activity=coverage(features.get('ctc_activity_us'),estimates,duration),
                lexical_score=lexical_disagreement('\n'.join(artifact['source']['paragraphs']),text) if artifact['engine'].get('language')=='en' else None,
                lexical_localization='Unavailable; greedy disagreement does not identify missing words or their time intervals',
                limitations='No calibrated probabilities, verified vocal labels, timestamp repair, or automatic rejection. Inspect acoustic-proxy regions against the original audio.')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('artifact',type=Path);p.add_argument('features',type=Path)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--use-corrections',action='store_true');args=p.parse_args()
    try:
        if not args.artifact.is_file() or not args.features.is_file():raise Unavailable('Optional alignment artifact or acoustic features unavailable')
        if args.features.stat().st_size>2*1024*1024:raise AlignmentError('Acoustic feature file exceeds 2 MiB')
        r=assess(read_artifact(args.artifact),json.loads(args.features.read_text(encoding='utf-8')),args.use_corrections)
        with args.output.open('x',encoding='utf-8') as f:json.dump(r,f,indent=2)
        print(json.dumps(dict(status='research_diagnostic_only',automatic_acceptance=False)))
    except Unavailable as e:print(json.dumps(dict(status='unavailable',reason=str(e))));return 3
    except (AlignmentError,OSError,ValueError,TypeError,KeyError) as e:p.exit(2,'Coverage comparison failed: '+str(e)+'\n')
    return 0

if __name__=='__main__':raise SystemExit(main())
