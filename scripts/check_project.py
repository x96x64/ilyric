#!/usr/bin/env python3
"""Public project preparation, strict CLI validation, and supplied-media export check."""
import json
from pathlib import Path
import subprocess
import tempfile
from generate_project_example import generate_project
from validate_local_input import validate


def check(directory):
    root = Path(__file__).resolve().parents[1]
    probe = root / '.build/release/LyricsInputProbe'
    generate_project(directory)
    directory = Path(directory).resolve()
    project, output = directory / 'project.json', directory / 'result.mp4'
    def invoke(file, destination, status=0):
        result = subprocess.run([str(probe), 'project', '--project', str(file), '--output', str(destination)], cwd=directory.parent, capture_output=True, text=True)
        assert result.returncode == status, (result.returncode, result.stderr)
        if status:
            assert not result.stdout
            return result.stderr
        return json.loads(result.stdout)
    record = invoke(project, output)
    assert record['project_version'] == 1 and record['offset_milliseconds'] == 125
    assert record['artwork']['width'] == record['artwork']['height'] == 256
    assert record['export']['frames'] == 601 and record['final_focus'] == 4
    assert [(e['numerator']/e['denominator'], e['paragraph']) for e in record['focus_events']] == [(0, -1), (.625, 0), (2, 1), (3.25, -1), (4.5, 2), (6, 3), (7, 4)]
    measurement = validate(output, directory / 'source.wav', 601)
    original = json.loads(project.read_text())
    failures = [
        {'version': 2, 'inputs': original['inputs']},
        dict(original, future=True),
        dict(original, output={'delivery': 'adapt'}),
        dict(original, visibility={'progress': 1}),
        dict(original, metadata={'title': None}),
        dict(original, inputs={'lyrics': 'lines.lrc', 'audio': 'missing.wav'}),
        dict(original, inputs=dict(original['inputs'], artwork='missing.png')),
        dict(original, timing={'offsetMilliseconds': -1000}),
        dict(original, timing={'offsetMilliseconds': 600000}),
    ]
    for i, value in enumerate(failures):
        bad = directory / 'invalid.json'; bad.write_text(json.dumps(value))
        destination = directory / f'bad-{i}.mp4'
        invoke(bad, destination, 2)
        assert not destination.exists()
    invalid = directory / 'invalid.json'
    invalid.write_text('{"version":1,"version":1}')
    invoke(invalid, directory / 'duplicate.mp4', 2)
    invalid.write_bytes(b'\xff')
    invoke(invalid, directory / 'utf8.mp4', 2)
    invoke(directory / 'missing.json', directory / 'missing.mp4', 2)
    before = output.read_bytes(); invoke(project, output, 2)
    assert output.read_bytes() == before and not list(directory.glob('.*.mp4'))
    return {'status': 'passed', 'export': record, 'validation': measurement, 'invalid_input_checks': 13, 'different_working_directory': True}


if __name__ == '__main__':
    import sys
    if len(sys.argv) == 2:
        result = check(Path(sys.argv[1]))
    else:
        with tempfile.TemporaryDirectory(prefix='ilyric-project-') as temporary:
            result = check(Path(temporary) / 'example')
    print(json.dumps(result, indent=2))
