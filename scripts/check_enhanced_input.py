#!/usr/bin/env python3
"""Offline enhanced-input audiovisual and refusal verification with original media."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from generate_enhanced_example import generate_project
from validate_local_input import validate


def decoded_progression(folder):
    """Localized encoded-RGB proxy on this original fixture, not alpha or luminance."""
    measurements=[]
    for script, frames, regions in [('Latin', [126, 144, 174, 189], [(534, 605), (626, 700)]),
                                    ('Japanese', [336, 369, 396, 417], [(534, 605), (626, 697)])]:
        scores=[]
        for frame in frames:
            decoded=[]
            for mode in ['enabled', 'disabled']:
                decoded.append(subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(folder/(mode+'.mp4')),
                    '-vf', f'select=eq(n\\,{frame})', '-fps_mode', 'passthrough', '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-']))
            assert all(len(raw)==1080*1920*3 for raw in decoded)
            lines=[]
            for y0, y1 in regions:
                values=[]
                for y in range(y0, y1):
                    for x in range(165, 950):
                        offset=(y*1080+x)*3
                        if sum(decoded[1][offset:offset+3])>660:
                            values.append(sum(decoded[0][offset:offset+3])/3)
                assert len(values)>100
                lines.append(dict(supported_pixels=len(values), mean_encoded_rgb_proxy=sum(values)/len(values),
                                  bright_fraction_above_200=sum(v>200 for v in values)/len(values)))
            scores.append(dict(frame=frame, numerator=frame, denominator=60, lines=lines))
        second=[row['lines'][1]['mean_encoded_rgb_proxy'] for row in scores]
        assert all(a+5<b for a,b in zip(second,second[1:])), second
        assert scores[0]['lines'][1]['bright_fraction_above_200']<.05
        assert scores[-1]['lines'][1]['bright_fraction_above_200']>.99
        assert all(row['lines'][0]['bright_fraction_above_200']>.99 for row in scores)
        measurements.append(dict(script=script, observations=scores))
    return measurements


def check(destination=None):
    root = Path(__file__).resolve().parents[1]
    probe = root/'.build/release/LyricsInputProbe'
    temp = tempfile.TemporaryDirectory(prefix='ilyric-enhanced-') if destination is None else None
    folder = Path(temp.name)/'example' if temp else Path(destination)
    generate_project(folder)
    folder = folder.resolve()
    def invoke(command, output, expected=0):
        result = subprocess.run([str(probe), *command, '--output', str(output)], capture_output=True, text=True, cwd=folder.parent)
        assert result.returncode == expected, (result.returncode, result.stderr)
        if expected:
            assert not result.stdout and not output.exists()
            return
        return json.loads(result.stdout)
    outputs = []
    for mode in ['enabled', 'disabled']:
        value = json.loads((folder/'project.json').read_text())
        value['timing']['highlighting'] = mode
        config = folder/(mode+'.json'); config.write_text(json.dumps(value))
        output = folder/(mode+'.mp4')
        result = invoke(['project', '--project', str(config)], output)
        assert result['project_version'] == 2 and result['timed_segments'] == 10
        assert result['audio_samples'] == 480144 and result['output_padding_samples'] == 656
        assert result['highlighting'] == mode and result['final_focus'] == 2
        assert [(row['numerator']/row['denominator'], row['paragraph']) for row in result['focus_events']] == [(0, -1), (.625, 0), (3.25, -1), (4.5, 1), (7, 2)]
        outputs.append(dict(mode=mode, export=result, validation=validate(output, folder/'source.wav', 601)))
    progression=decoded_progression(folder)
    direct=folder/'direct.mp4'
    direct_result=invoke(['render', '--lyrics', str(folder/'lines.lrc'), '--audio', str(folder/'source.wav'),
                          '--format', 'enhanced-lrc', '--highlighting', 'enabled'], direct)
    assert direct_result['focus_events']==outputs[0]['export']['focus_events']
    direct_validation=validate(direct,folder/'source.wav',601)
    invalid = ['[00:00]<00:00>A', '[00:00]<00:00>A<00:00>', '[00:00]<00:01>A<00:00.5>',
               '[00:00]<00:00>e<00:01>\u0301<00:02>', '[00:00]<00:00>A<00:11>',
               '[00:00]<00:00>A<00:02>\n[00:01]Next', '[00:00]<00:00>A<00:01>\n|Untimed',
               '[00:00]<00:00>A<00:01.1234>', '[00:00][00:01]<00:00>A<00:02>',
               '[00:00]<00:00>مرحبا<00:01>', '[00:00]<00:00>👩‍💻<00:01>']
    for i, content in enumerate(invalid):
        file = folder/'bad.lrc'; file.write_text(content)
        invoke(['render', '--lyrics', str(file), '--audio', str(folder/'source.wav'), '--format', 'enhanced-lrc'], folder/f'bad-{i}.mp4', 2)
    for i, arguments in enumerate([['--format', 'ttml'], ['--highlighting', 'enabled'], ['--format', 'enhanced-lrc', '--highlighting', 'estimated']]):
        invoke(['render', '--lyrics', str(folder/'lines.lrc'), '--audio', str(folder/'source.wav'), *arguments], folder/f'bad-options-{i}.mp4', 2)
    assert not list(folder.glob('.*.mp4'))
    report = dict(status='passed', outputs=outputs, decoded_progression=progression, direct_command_validation=direct_validation, refusal_checks=len(invalid)+3)
    if temp: temp.cleanup()
    return report


if __name__ == '__main__':
    print(json.dumps(check(sys.argv[1] if len(sys.argv)>1 else None), indent=2))
