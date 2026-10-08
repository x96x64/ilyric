#!/usr/bin/env python3
"""Experimental model-free correspondence from saved audio-only lexical evidence."""
import argparse
import json
from pathlib import Path
import sys
from alignment.core import AlignmentError, source
from alignment.worker import Unavailable, file_hash
from alignment.audio_anchors import match, review_artifact


def read_json(path):
    if not path.is_file(): raise Unavailable('Saved audio anchors unavailable')
    if path.stat().st_size>4*1024*1024: raise AlignmentError('Anchors exceed 4 MiB')
    def pairs(items):
        result={}
        for k,v in items:
            if k in result: raise AlignmentError('Duplicate JSON field')
            result[k]=v
        return result
    return json.loads(path.read_text(encoding='utf-8'),object_pairs_hook=pairs,
                      parse_constant=lambda _: (_ for _ in ()).throw(AlignmentError('Nonfinite JSON')))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for key in ['anchors','lyrics','audio','output']:parser.add_argument('--'+key,type=Path,required=True)
    parser.add_argument('--review-output',type=Path)
    a=parser.parse_args()
    try:
        outputs=[p for p in [a.output,a.review_output] if p is not None]
        if len({p.resolve() for p in outputs})!=len(outputs) or any(p.exists() or not p.parent.is_dir() for p in outputs):
            raise AlignmentError('Outputs must be distinct, new files with existing parents')
        if not a.lyrics.is_file() or not a.audio.is_file():raise Unavailable('Local audio or authoritative lyrics unavailable')
        if a.lyrics.stat().st_size>65536:raise AlignmentError('Lyrics exceed 64 KiB')
        if a.audio.stat().st_size>256*1024*1024:raise AlignmentError('Audio exceeds 256 MiB')
        result=match(source(a.lyrics.read_bytes()),read_json(a.anchors))
        if file_hash(a.audio)!=result['anchors']['audio']['sha256']:raise AlignmentError('Anchor/source audio identity differs')
        prepared=review_artifact(result) if a.review_output else None
        # All validation occurs before either output is created.
        for path,value in [(a.output,result),(a.review_output,prepared)]:
            if path:
                with path.open('x',encoding='utf-8') as stream:
                    stream.write(json.dumps(value,ensure_ascii=False,sort_keys=True,indent=2,allow_nan=False)+'\n')
        counts={state:sum(d['state']==state for d in result['decisions']) for state in ['supported','ambiguous','skipped','unresolved']}
        print(json.dumps(dict(status='review_required',counts=counts,timing_estimates=0,automatic_acceptance=False)))
        return 0
    except Unavailable as e:
        print(json.dumps(dict(status='unavailable',reason=str(e))),file=sys.stderr);return 3
    except (AlignmentError,OSError,ValueError,KeyError,TypeError,RecursionError) as e:
        print('Audio correspondence failed: '+str(e),file=sys.stderr);return 2


if __name__=='__main__':raise SystemExit(main())
