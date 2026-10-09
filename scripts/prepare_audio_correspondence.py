#!/usr/bin/env python3
"""Experimental approved local Whisper anchors and bounded English CTC refinement."""
import argparse
import json
from pathlib import Path
import sys
from alignment.core import AlignmentError
from alignment.worker import Unavailable
from alignment.audio_anchor_worker import infer


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['audio','lyrics','runtime','model','ctc','work']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    try:
        print(json.dumps(infer(a.audio,a.lyrics,a.runtime,a.model,a.ctc,a.work)));return 0
    except Unavailable as e:print(json.dumps(dict(status='unavailable',reason=str(e))),file=sys.stderr);return 3
    except (AlignmentError,OSError,ValueError,KeyError,TypeError,RecursionError) as e:
        p.exit(2,'Audio-derived preparation failed: '+str(e)+'\n')


if __name__=='__main__':raise SystemExit(main())
