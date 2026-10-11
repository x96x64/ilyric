#!/usr/bin/env python3
"""Build the platform wheel for pip from a staged release tree (docs/distribution.md).

  build_wheel.py STAGE VERSION OUTDIR

STAGE holds bin/ilyrics and share/ilyrics/templates. The binary is installed through the wheel's scripts scheme into the
environment's bin directory, and the templates through the data scheme into its share directory, so the command finds
them in its installation prefix.
"""
import base64
import hashlib
import os
import stat
import sys
import zipfile
from pathlib import Path

TAG = 'py3-none-macosx_14_0_arm64'


def record(data):
    return 'sha256=' + base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b'=').decode(), len(data)


def main(stage, version, out):
    stage, out = Path(stage), Path(out)
    out.mkdir(parents=True, exist_ok=True)
    name = f'ilyrics-{version}'
    data = f'{name}.data'
    info = f'{name}.dist-info'
    entries = [(f'{data}/scripts/ilyrics', stage / 'bin/ilyrics', 0o755)]
    for path in sorted((stage / 'share').rglob('*')):
        if path.is_file():
            entries.append((f'{data}/data/{path.relative_to(stage).as_posix()}', path, 0o644))
    readme = (Path(__file__).resolve().parent / 'README.md').read_text()
    metadata = '\n'.join([
        'Metadata-Version: 2.1', 'Name: ilyrics', f'Version: {version}',
        'Summary: Lyrics videos of the iPhone Music Lyrics screen, with on-device synchronization',
        'Home-page: https://github.com/x96x64/ilyrics', 'License: Apache-2.0',
        'Classifier: Operating System :: MacOS', 'Classifier: Environment :: Console',
        'Requires-Python: >=3.8', 'Description-Content-Type: text/markdown', '', readme])
    wheel = f'Wheel-Version: 1.0\nGenerator: ilyrics build_wheel.py\nRoot-Is-Purelib: false\nTag: {TAG}\n'
    target = out / f'{name.replace("-", "_", 0)}-{TAG}.whl'
    rows = []
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as z:
        for arc, path, mode in entries:
            content = path.read_bytes()
            item = zipfile.ZipInfo(arc, date_time=(2026, 1, 1, 0, 0, 0))
            item.external_attr = (stat.S_IFREG | mode) << 16
            item.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(item, content)
            rows.append((arc, *record(content)))
        for arc, text in [(f'{info}/METADATA', metadata), (f'{info}/WHEEL', wheel),
                          (f'{info}/LICENSE', (Path(__file__).resolve().parents[1] / 'LICENSE').read_text())]:
            content = text.encode()
            z.writestr(zipfile.ZipInfo(arc, date_time=(2026, 1, 1, 0, 0, 0)), content)
            rows.append((arc, *record(content)))
        rows.append((f'{info}/RECORD', '', ''))
        z.writestr(zipfile.ZipInfo(f'{info}/RECORD', date_time=(2026, 1, 1, 0, 0, 0)),
                   ''.join(f'{a},{h},{n}\n' for a, h, n in rows))
    print(target)


if __name__ == '__main__':
    main(*sys.argv[1:4])
