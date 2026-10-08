#!/usr/bin/env python3
"""Offline TTML interoperability, decoded multiline progression, and safety checks."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from generate_ttml_example import generate_project
from validate_local_input import validate
from check_enhanced_input import decoded_progression


def check(destination=None):
    root = Path(__file__).resolve().parents[1]
    probe = root/'.build/release/LyricsInputProbe'
    temp = tempfile.TemporaryDirectory(prefix='ilyric-ttml-') if destination is None else None
    folder = Path(temp.name)/'example' if temp else Path(destination)
    generate_project(folder)
    folder = folder.resolve()
    def invoke(command, output, expected=0):
        result = subprocess.run([str(probe), *command, '--output', str(output)], capture_output=True, text=True, cwd=folder.parent)
        assert result.returncode == expected, (result.returncode, result.stderr)
        if expected:
            assert not result.stdout and not output.exists() and result.stderr.startswith('LyricsInputProbe: ')
            return
        return json.loads(result.stdout)
    outputs = []
    for mode in ['enabled', 'disabled']:
        value = json.loads((folder/'project.json').read_text())
        value['timing']['highlighting'] = mode
        config = folder/(mode+'.json'); config.write_text(json.dumps(value))
        output = folder/(mode+'.mp4')
        result = invoke(['project', '--project', str(config)], output)
        assert result['project_version'] == 3 and result['timed_segments'] == 10
        assert result['audio_samples'] == 480144 and result['output_padding_samples'] == 656
        assert result['highlighting'] == mode and result['final_focus'] == 2
        assert [(row['numerator']/row['denominator'], row['paragraph']) for row in result['focus_events']] == [(0, -1), (.625, 0), (3.25, -1), (4.5, 1), (7, 2), (10.003, -1)]
        outputs.append(dict(mode=mode, export=result, validation=validate(output, folder/'source.wav', 601)))
    progression = decoded_progression(folder)
    direct = folder/'direct.mp4'
    direct_result = invoke(['render', '--lyrics', str(folder/'lines.ttml'), '--audio', str(folder/'source.wav'),
                            '--format', 'ttml', '--highlighting', 'enabled'], direct)
    assert direct_result['focus_events'] == outputs[0]['export']['focus_events']
    direct_validation = validate(direct, folder/'source.wav', 601)
    invalid = json.loads((root/'fixtures/ttml/invalid.json').read_text())
    for i, content in enumerate(invalid.values()):
        file = folder/'bad.ttml'; file.write_text(content)
        invoke(['render', '--lyrics', str(file), '--audio', str(folder/'source.wav'), '--format', 'ttml'], folder/f'bad-{i}.mp4', 2)
    alternate = '<?xml version="1.0" encoding="UTF-16"?><!DOCTYPE tt [<!ENTITY e "expanded">]><tt xmlns="http://www.w3.org/ns/ttml" xml:space="preserve"><body><div><p begin="0s" end="1s">A</p></div></body></tt>'
    for i, content in enumerate([b'\xff', b'A'*65537, alternate.encode('utf-16-le'), alternate.encode('utf-16-be')]):
        file = folder/'bad.ttml'; file.write_bytes(content)
        invoke(['render', '--lyrics', str(file), '--audio', str(folder/'source.wav'), '--format', 'ttml'], folder/f'bad-bytes-{i}.mp4', 2)
    for version in [1, 2]:
        value = json.loads((folder/'project.json').read_text()); value['version'] = version
        file = folder/'bad.json'; file.write_text(json.dumps(value))
        invoke(['project', '--project', str(file)], folder/f'bad-version-{version}.mp4', 2)
    assert not list(folder.glob('.*.mp4'))
    report = dict(status='passed', outputs=outputs, decoded_progression=progression,
                  direct_command_validation=direct_validation, refusal_checks=len(invalid)+6)
    if temp: temp.cleanup()
    return report


if __name__ == '__main__':
    print(json.dumps(check(sys.argv[1] if len(sys.argv)>1 else None), indent=2))
