#!/usr/bin/env python3
"""Experimental local-only passage search; all resulting estimates require review."""
import argparse
import json
from pathlib import Path
import sys
import tempfile
from alignment.core import AlignmentError,source
from alignment.worker import Unavailable
from alignment.passage_search import prepare


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['audio','lyrics','model','tifa-source','output']:parser.add_argument('--'+name,type=Path,required=True)
    a=parser.parse_args()
    try:
        if a.output.exists() or not a.output.parent.is_dir():raise AlignmentError('Output directory must be new, with an existing parent')
        if not a.lyrics.is_file():raise Unavailable('Local untimed lyrics unavailable')
        if a.lyrics.stat().st_size>65536:raise AlignmentError('Lyrics exceed 64 KiB')
        src=source(a.lyrics.read_bytes())
        from alignment.passage_worker import search
        with tempfile.TemporaryDirectory(prefix='tifa-search-',dir=a.output.parent) as work:
            raw=search(a.audio,src,a.model,a.tifa_source,Path(work))
        result=prepare(raw);a.output.mkdir()
        for filename,data in [('candidates.json',raw),('estimated.json',result)]:
            (a.output/filename).write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
        print(json.dumps(dict(status='review_required',lines=len(result['lines']),supported=sum(x['estimate'] is not None for x in result['lines']),automatic_acceptance=False)));return 0
    except Unavailable as e:print(json.dumps(dict(status='unavailable',reason=str(e))),file=sys.stderr);return 3
    except (AlignmentError,OSError,ValueError,RuntimeError,ImportError) as e:print('Passage search failed: '+str(e),file=sys.stderr);return 2


if __name__=='__main__':raise SystemExit(main())
