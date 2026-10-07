#!/usr/bin/env python3
"""Validate the synthetic spike using local FFmpeg tools; no third-party Python modules."""
import array
import json
import math
from pathlib import Path
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args)


def validate(path, width=1080, height=1920, frames=240):
    probe = json.loads(run('ffprobe', '-v', 'error', '-count_frames', '-show_streams', '-show_format', '-of', 'json', str(path)))
    video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
    audio = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
    assert (video['width'], video['height']) == (width, height)
    assert video['r_frame_rate'] == video['avg_frame_rate'] == '60/1'
    assert int(video['nb_read_frames']) == frames
    duration = frames / 60
    assert abs(float(video['duration']) - duration) < 1 / 60000
    assert abs(float(audio['duration']) - duration) <= 1 / 60
    assert abs(float(audio.get('start_time', 0))) <= 1 / 48000
    assert audio['sample_rate'] == '48000' and audio['channels'] == 1
    assert video['color_space'] == video['color_transfer'] == video['color_primaries'] == 'bt709'
    timestamps = json.loads(run('ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_frames',
        '-show_entries', 'frame=best_effort_timestamp_time', '-of', 'json', str(path)))['frames']
    assert len(timestamps) == frames
    assert all(abs(float(f['best_effort_timestamp_time']) - i / 60) < 0.000002 for i, f in enumerate(timestamps))
    decoded = array.array('f', run('ffmpeg', '-v', 'error', '-i', str(path), '-map', '0:a:0', '-f', 'f32le', '-'))
    expected_samples = round(duration * 48000)
    assert expected_samples <= len(decoded) <= expected_samples + 1024
    trimmed = run('ffmpeg', '-v', 'error', '-i', str(path), '-map', '0:a:0',
        '-af', f'atrim=end={duration}', '-f', 's16le', '-')
    assert len(trimmed) // 2 == expected_samples
    packets = json.loads(run('ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_packets',
        '-show_entries', 'packet=pts_time,side_data_list', '-of', 'json', str(path)))['packets']
    priming = packets[0].get('side_data_list', [{}])[0].get('skip_samples', 0)
    assert abs(float(packets[0]['pts_time']) + priming / 48000) < 0.000002
    # Check 1 ms RMS windows near expected markers. AAC pre-echo is tolerated within one video frame.
    marker_times = [base + t for base in range(0, math.ceil(duration), 4) for t in [0, 1, 1.25, 3] if base + t < duration]
    errors = []
    for expected in marker_times:
        center = round(expected * 48000)
        detected = None
        for offset in range(max(0, center - 960), min(len(decoded) - 48, center + 960), 48):
            rms = math.sqrt(sum(x * x for x in decoded[offset:offset + 48]) / 48)
            if rms > 0.15:
                detected = offset / 48000
                break
        assert detected is not None, ('missing audio marker', expected)
        errors.append(detected - expected)
        assert abs(detected - expected) <= 1 / 60
    # Read the center of the synthetic flash independently from compressed video frames.
    scale = min(width / 402, height / 874)
    x = round((width - 402 * scale) / 2 + 45 * scale) - 4
    y = round(833 * scale) - 4
    flashes = run('ffmpeg', '-v', 'error', '-i', str(path), '-an', '-vf',
        f'crop=8:8:{x}:{y},scale=1:1,format=gray', '-f', 'rawvideo', '-')
    assert len(flashes) == frames
    expected_flashes = [any(t <= i / 60 < t + 0.05 - 1e-9 for t in marker_times) for i in range(frames)]
    assert all((value > 180) == expected for value, expected in zip(flashes, expected_flashes)), 'visual marker timing'
    result = dict(dimensions=[width, height], fps='60/1', frames=frames, duration=duration,
        audioCodec=audio['codec_name'], audioDuration=audio['duration'], audioStart=audio.get('start_time'),
        decodedAudioSamples=len(decoded), trimmedAudioSamples=len(trimmed) // 2,
        primingSamples=priming, trailingDecodedPaddingSamples=len(decoded) - expected_samples, color='bt709', markerErrorsSeconds=errors,
        visualMarkerFrames=[i for i, v in enumerate(flashes) if v > 180], presentationTimestamps='all passed')
    print(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    validate(Path(sys.argv[1]), *map(int, sys.argv[2:]))
