#!/usr/bin/env python3
"""Public offline CLI and audiovisual integration check using original input files."""
import json
from pathlib import Path
import subprocess
import tempfile
from generate_local_audio import generate
from validate_local_input import validate


def check():
    root = Path(__file__).resolve().parents[1]
    probe = root / '.build/release/LyricsInputProbe'
    results = []
    with tempfile.TemporaryDirectory(prefix='ilyric-input-') as folder:
        folder = Path(folder)
        audio = folder / 'source.wav'
        generate(audio)
        lyrics = root / 'fixtures/local-input/lines.lrc'
        def invoke(source, lrc, output, status=0):
            command = [str(probe), 'render', '--lyrics', str(lrc), '--audio', str(source), '--output', str(output)]
            result = subprocess.run(command, capture_output=True, text=True)
            assert result.returncode == status, (result.returncode, result.stderr)
            if status:
                assert not result.stdout and not output.exists()
                return result.stderr
            value = json.loads(result.stdout)
            assert value['export']['frames'] == 601 and value['final_focus'] == 4
            assert value['output_padding_samples'] == 656
            assert [(row['numerator']/row['denominator'], row['paragraph']) for row in value['focus_events']] == [(0, -1), (.625, 0), (2, 1), (3.25, -1), (4.5, 2), (6, 3), (7, 4)]
            return value
        for extension, codec in [('wav', None), ('aiff', 'pcm_s16be'), ('m4a', 'aac')]:
            source = audio
            if codec:
                source = folder / ('source.' + extension)
                subprocess.run(['ffmpeg', '-v', 'error', '-i', str(audio), '-c:a', codec, str(source)], check=True)
            output = folder / (extension + '.mp4')
            record = invoke(source, lyrics, output)
            measurement = validate(output, source, 601)
            results.append(dict(format=extension, export=record, validation=measurement))
        # Refusal checks must finish before exporting and leave no partial file.
        for i, text in enumerate(['[00:99]A', '[00:01]A\n[00:01]B', '[offset:-1]\n[00:00]A', '[00:11]Beyond audio', '[00:00]<00:00.1>A', '[00:00]' + 'x'*500]):
            lrc = folder / 'bad.lrc'; lrc.write_text(text)
            invoke(audio, lrc, folder / ('bad' + str(i) + '.mp4'), 2)
        bad = folder / 'invalid-utf8.lrc'; bad.write_bytes(b'\xff')
        invoke(audio, bad, folder / 'utf8.mp4', 2)
        invoke(folder / 'missing.wav', lyrics, folder / 'missing-audio.mp4', 2)
        invoke(audio, folder / 'missing.lrc', folder / 'missing-lyrics.mp4', 2)
        broken = folder / 'broken.wav'; broken.write_text('not audio')
        invoke(broken, lyrics, folder / 'broken.mp4', 2)
        result = subprocess.run([str(probe), 'render', '--unknown'], capture_output=True)
        assert result.returncode == 2 and not result.stdout
        previous = (folder / 'wav.mp4').read_bytes()
        result = subprocess.run([str(probe), 'render', '--lyrics', str(lyrics), '--audio', str(audio), '--output', str(folder/'wav.mp4')], capture_output=True)
        assert result.returncode == 2 and (folder/'wav.mp4').read_bytes() == previous
        assert not list(folder.glob('.*.mp4'))
    return dict(status='passed', formats=results, invalid_input_checks=12)


if __name__ == '__main__':
    print(json.dumps(check(), indent=2))
