#!/usr/bin/env python3
"""Experimental offline singing alignment and editable timing preparation."""
import argparse
import json
import pathlib
import sys
import tempfile

from alignment.core import AlignmentError, review, source, to_ttml, validate
from alignment.worker import Unavailable


def read_artifact(path):
    if path.stat().st_size > 2 * 1024 * 1024:
        raise AlignmentError('Artifact exceeds 2 MiB')
    def pairs(items):
        result = {}
        for k, v in items:
            if k in result:
                raise AlignmentError('Duplicate JSON field')
            result[k] = v
        return result
    return validate(json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=pairs))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    align = sub.add_parser('align')
    align.add_argument('--audio', type=pathlib.Path, required=True)
    align.add_argument('--lyrics', type=pathlib.Path, required=True)
    align.add_argument('--engine', choices=['ctc', 'tifa'], required=True)
    align.add_argument('--language', choices=['en', 'ja'], required=True)
    align.add_argument('--model', type=pathlib.Path, required=True)
    align.add_argument('--tifa-source', type=pathlib.Path)
    align.add_argument('--pronunciations', type=pathlib.Path)
    align.add_argument('--output', type=pathlib.Path, required=True)
    check = sub.add_parser('validate'); check.add_argument('artifact', type=pathlib.Path)
    edit = sub.add_parser('review'); edit.add_argument('artifact', type=pathlib.Path)
    edit.add_argument('--line', type=int, required=True)
    edit.add_argument('--begin'); edit.add_argument('--end')
    edit.add_argument('--note', required=True)
    edit.add_argument('--output', type=pathlib.Path, required=True)
    export = sub.add_parser('export'); export.add_argument('artifact', type=pathlib.Path)
    export.add_argument('--audio', type=pathlib.Path, required=True)
    export.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    try:
        output = getattr(args, 'output', None)
        if output is not None and (output.exists() or not output.parent.is_dir()):
            raise AlignmentError('Output must be a new file in an existing directory')
        if args.command == 'align':
            if not args.lyrics.is_file() or args.lyrics.stat().st_size > 65536:
                raise AlignmentError('Lyrics must be a readable UTF-8 file no larger than 64 KiB')
            src = source(args.lyrics.read_bytes())
            from alignment.worker import infer
            from alignment.pronunciation import read_overrides
            pronunciation = read_overrides(args.pronunciations, src) if args.pronunciations else None
            with tempfile.TemporaryDirectory(prefix='ilyric-alignment-', dir=output.parent) as work:
                result = infer(args.audio, src, args.engine, args.model, args.tifa_source,
                               args.language, pathlib.Path(work), pronunciation)
            validate(result)
        else:
            result = read_artifact(args.artifact)
            if args.command == 'review':
                result = review(result, args.line, args.begin, args.end, args.note)
        if args.command == 'export':
            from alignment.worker import file_hash
            if not args.audio.is_file() or file_hash(args.audio) != result['audio']['sha256']:
                raise AlignmentError('Export audio does not match alignment source identity')
        if output is not None:
            content = to_ttml(result) if args.command == 'export' else json.dumps(result, ensure_ascii=False, indent=2) + '\n'
            with output.open('x', encoding='utf-8') as stream:
                stream.write(content)
        print(json.dumps({'status': 'ok', 'lines': len(result['lines']), 'unresolved': len(result['unresolved']),
                          'pending_review': sum(x['review'] == 'pending' for x in result['lines'])}))
        return 0
    except Unavailable as e:
        print(json.dumps({'status': 'unavailable', 'reason': str(e)}), file=sys.stderr); return 3
    except (AlignmentError, OSError, ValueError, RuntimeError, AttributeError, IndexError) as e:
        print('Alignment preparation failed: ' + str(e), file=sys.stderr); return 2


if __name__ == '__main__':
    sys.exit(main())
