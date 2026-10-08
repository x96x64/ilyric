#!/usr/bin/env python3
"""Read-only annotation intake checks; never certifies human review or freezes partitions."""
import argparse
import json
from pathlib import Path
import sys
from alignment.core import AlignmentError
from alignment.worker import Unavailable, file_hash
from alignment.vocal_annotations import load, validate, validate_review


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--record', type=Path, required=True)
    p.add_argument('--audio', type=Path, required=True)
    p.add_argument('--pass-a', type=Path)
    p.add_argument('--pass-b', type=Path)
    a = p.parse_args()
    try:
        record, identity = load(a.record)
        summary = validate(record)
        if not a.audio.is_file(): raise Unavailable('Original local annotation audio is unavailable')
        if a.audio.stat().st_size > 512*1024*1024: raise AlignmentError('Annotation source exceeds 512 MiB')
        if file_hash(a.audio) != record['audio_sha256']: raise AlignmentError('Original audio SHA-256 differs from annotation')
        if record['review_status'] == 'reviewed':
            if a.pass_a is None or a.pass_b is None: raise Unavailable('Both original independent human passes are required')
            first, first_hash = load(a.pass_a); second, second_hash = load(a.pass_b)
            summary = validate_review(record, first, first_hash, second, second_hash)
        elif a.pass_a is not None or a.pass_b is not None:
            raise AlignmentError('Initial-pass validation does not accept review inputs')
        summary.update(record_sha256=identity, audio_sha256_verified=True,
                       audio_sample_metadata='Declared; separately verify sample rate and decoded source frame count before freezing')
        print(json.dumps(summary, indent=2)); return 0
    except Unavailable as e:
        print(json.dumps(dict(status='unavailable', reason=str(e)))); return 3
    except (AlignmentError, OSError) as e:
        p.exit(2, 'Annotation validation failed: '+str(e)+'\n')


if __name__ == '__main__': raise SystemExit(main())
