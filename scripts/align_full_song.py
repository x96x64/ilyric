#!/usr/bin/env python3
"""Experimental offline full-song proposals, explicit review, and TTML preparation."""
import argparse
import json
from pathlib import Path
import sys
import tempfile
from alignment.core import AlignmentError,source
from alignment.worker import Unavailable,file_hash
from alignment.full_song import load,review,to_ttml,unassigned_audio


def unique_fields(items):
    result={}
    for k,v in items:
        if k in result:raise AlignmentError('Duplicate review field')
        result[k]=v
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='command',required=True)
    align=sub.add_parser('align')
    for name in ['audio','lyrics','model','output']:align.add_argument('--'+name,type=Path,required=True)
    align.add_argument('--separator',type=Path,help='Optional pinned htdemucs checkpoint; separated vocals become the CTC input')
    check=sub.add_parser('validate');check.add_argument('artifact',type=Path)
    edit=sub.add_parser('review');edit.add_argument('artifact',type=Path)
    edit.add_argument('--decisions',type=Path,required=True);edit.add_argument('--output',type=Path,required=True)
    export=sub.add_parser('export');export.add_argument('artifact',type=Path)
    export.add_argument('--audio',type=Path,required=True);export.add_argument('--output',type=Path,required=True)
    export.add_argument('--granularity',choices=['paragraph','line','word'],default='paragraph')
    a=parser.parse_args()
    try:
        output=getattr(a,'output',None)
        if output and (output.exists() or not output.parent.is_dir()):raise AlignmentError('Output must be new and its parent must exist')
        if a.command=='align':
            if not a.lyrics.is_file():raise Unavailable('Local untimed lyrics unavailable')
            if a.lyrics.stat().st_size>65536:raise AlignmentError('Lyrics exceed 64 KiB')
            src=source(a.lyrics.read_bytes())
            from alignment.full_song_worker import infer
            with tempfile.TemporaryDirectory(prefix='full-song-',dir=output.parent) as tmp:
                result=infer(a.audio,src,a.model,Path(tmp),a.separator)
        else:
            result=load(a.artifact)
            if a.command=='review':
                if not a.decisions.is_file():raise Unavailable('Explicit review decisions unavailable')
                if a.decisions.stat().st_size>131072:raise AlignmentError('Review decisions exceed 128 KiB')
                decisions=json.loads(a.decisions.read_text(encoding='utf-8'),object_pairs_hook=unique_fields)
                result=review(result,decisions)
        if a.command=='export':
            if not a.audio.is_file():raise Unavailable('Original audio unavailable')
            if file_hash(a.audio)!=result['audio']['sha256']:raise AlignmentError('Export audio identity differs')
        if output:
            content=to_ttml(result,a.granularity) if a.command=='export' else json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False)+'\n'
            with output.open('x',encoding='utf-8') as stream:stream.write(content)
        print(json.dumps(dict(status='review_required' if any(r['review']=='pending' for r in result['lines']) else 'reviewed',
                              occurrences=len(result['lines']),estimated=sum(r['estimate'] is not None for r in result['lines']),
                              unresolved=sum(r['estimate'] is None and r['correction'] is None for r in result['lines']),
                              unassigned_audio_us=unassigned_audio(result),unassigned_semantics="Unknown support; not verified silence, instruments, or missing words",automatic_acceptance=False)))
        return 0
    except Unavailable as e:print(json.dumps(dict(status='unavailable',reason=str(e))),file=sys.stderr);return 3
    except (AlignmentError,OSError,ValueError,RuntimeError,RecursionError) as e:
        print('Full-song preparation failed: '+str(e),file=sys.stderr);return 2


if __name__=='__main__':raise SystemExit(main())
