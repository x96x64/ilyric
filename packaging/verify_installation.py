#!/usr/bin/env python3
"""Verify local release packages without contacting registries or installing globally."""
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import wave
import zipfile


def run(args, env=None):
    result = subprocess.run([str(x) for x in args], env=env, capture_output=True, text=True, timeout=180)
    if result.returncode != 0:
        raise RuntimeError(f'{args[0]} exited with {result.returncode}: {result.stderr}')
    return result.stdout


def verify(packages):
    version = re.search(r'static let version = "([^"]+)"',
                        (Path(__file__).resolve().parents[1] / 'Sources/ilyrics/main.swift').read_text())[1]
    root = Path(tempfile.mkdtemp(prefix='ilyrics-install-check-')).resolve()
    archive = packages / f'ilyrics-{version}-macos-arm64.tar.gz'
    npm = packages / f'ilyrics-{version}.tgz'
    wheel = packages / f'ilyrics-{version}-py3-none-macosx_14_0_arm64.whl'
    checksums = packages.joinpath('SHA256SUMS').read_text()
    for package in [archive, npm, wheel]:
        digest = hashlib.sha256(package.read_bytes()).hexdigest()
        assert f'{digest}  {package.name}' in checksums, package.name
    prefix = root / 'archive'
    prefix.mkdir()
    with tarfile.open(archive) as tf:
        for member in tf.getmembers():
            target = prefix / member.name
            assert target.resolve().is_relative_to(prefix.resolve())
            assert not member.issym() and not member.islnk()
        tf.extractall(prefix)
    with zipfile.ZipFile(wheel) as z:
        names = z.namelist()
        assert any(n.endswith('.dist-info/LICENSE') for n in names)
        metadata = z.read(f'ilyrics-{version}.dist-info/METADATA').decode()
        assert f'Version: {version}\n' in metadata
    run([sys.executable, '-m', 'venv', root / 'pip'])
    run([root / 'pip/bin/python', '-m', 'pip', 'install', '--no-index', '--no-deps', wheel])
    env = dict(os.environ, npm_config_cache=str(root / 'npm-cache'))
    run(['npm', 'install', '--global', '--prefix', root / 'npm', '--offline', '--ignore-scripts',
         '--no-audit', '--no-fund', npm], env)
    rate = 48000
    tone = b''.join(struct.pack('<h', int(3000 * math.sin(2 * math.pi * 330 * i / rate)))
                    for i in range(rate))
    with wave.open(str(root / 'tone.wav'), 'wb') as f:
        f.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        f.writeframes(tone * 2)
    (root / 'lyrics.lrc').write_text('[00:00.100]Paper boats\n[00:01.000]Quiet water\n')
    baseline = None
    rows = []
    for channel, binpath in [('archive', prefix / 'bin'), ('npm', root / 'npm/bin'),
                             ('pip', root / 'pip/bin')]:
        env = dict(os.environ, PATH=str(binpath) + os.pathsep + os.environ['PATH'],
                   ILYRICS_MODELS=str(root / 'empty-model-cache'))
        env.pop('ILYRICS_TEMPLATES', None)
        binary = Path(shutil.which('ilyrics', path=env['PATH'])).resolve()
        assert binary.is_relative_to(root)
        assert run(['ilyrics', '--version'], env).strip() == f'ilyrics {version}'
        status = run(['ilyrics', 'models', 'status'], env)
        assert 'Templates: ' in status and 'not found' not in status
        assert str(root) in status and 'Models:    not installed' in status
        doctor = subprocess.run(['ilyrics', 'doctor'], env=env, capture_output=True, text=True, timeout=60)
        assert doctor.returncode == 1 and 'Alignment models: not installed' in doctor.stdout
        assert re.search(r'^ok\s+Model templates:', doctor.stdout, re.M), doctor.stdout
        assert [line for line in doctor.stdout.splitlines() if line.startswith('FAIL')] == [
            'FAIL Alignment models: not installed'], doctor.stdout
        out, report = root / f'{channel}.mp4', root / f'{channel}.json'
        run(['ilyrics', 'render', root / 'tone.wav', root / 'lyrics.lrc', '-o', out,
             '--jobs', '2', '--title', 'Paper Boats', '--artist', 'Original Fixture', '--report', report], env)
        details = json.loads(report.read_text())
        assert out.stat().st_size > 0
        digest = hashlib.sha256(binary.read_bytes()).hexdigest()
        if baseline is None:
            baseline = digest
        assert digest == baseline
        row = {'channel': channel, 'version': version, 'binarySHA256': digest,
               'templatesResolved': True, 'renderPassed': True, 'report': details}
        if shutil.which('ffprobe'):
            probe = json.loads(run(['ffprobe', '-v', 'error', '-count_frames', '-show_streams',
                                    '-of', 'json', out]))
            video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
            assert (video['width'], video['height']) == (1080, 1920)
            assert video['nb_read_frames'] == '120' and video['avg_frame_rate'] == '60/1'
            row['decodedFrames'] = 120
        rows.append(row)
    # Only summaries leave the temporary installation tree; generated media are never uploaded.
    print(json.dumps({'version': version, 'checks': rows}, indent=2))
    shutil.rmtree(root)


if __name__ == '__main__':
    verify(Path(sys.argv[1]).resolve())
