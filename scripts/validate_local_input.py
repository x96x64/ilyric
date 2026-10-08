#!/usr/bin/env python3
"""Validate supplied-audio output independently with FFmpeg; synthetic fixtures only."""
import array
import json
import math
from pathlib import Path
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args)


def validate(video_path, source_path, frames):
    streams = json.loads(run('ffprobe', '-v', 'error', '-count_frames', '-show_streams', '-of', 'json', str(video_path)))['streams']
    video = next(s for s in streams if s['codec_type'] == 'video')
    audio = next(s for s in streams if s['codec_type'] == 'audio')
    assert (video['width'], video['height'], video['codec_name']) == (1080, 1920, 'h264')
    assert video['r_frame_rate'] == video['avg_frame_rate'] == '60/1'
    assert int(video['nb_read_frames']) == frames
    duration = frames / 60
    assert abs(float(video['duration']) - duration) < 1 / 60000
    assert abs(float(audio['duration']) - duration) < 1 / 48000
    assert audio['codec_name'] == 'aac' and audio['sample_rate'] == '48000' and audio['channels'] == 1
    assert abs(float(audio.get('start_time', 0))) < 1 / 48000
    assert video['color_space'] == video['color_transfer'] == video['color_primaries'] == 'bt709'
    pts = json.loads(run('ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_frames', '-show_entries',
                         'frame=best_effort_timestamp_time', '-of', 'json', str(video_path)))['frames']
    assert len(pts) == frames and all(abs(float(row['best_effort_timestamp_time']) - i / 60) < .000002 for i, row in enumerate(pts))
    source = array.array('f', run('ffmpeg', '-v', 'error', '-i', str(source_path), '-map', '0:a:0', '-ac', '1', '-ar', '48000', '-f', 'f32le', '-'))
    decoded = array.array('f', run('ffmpeg', '-v', 'error', '-i', str(video_path), '-map', '0:a:0', '-f', 'f32le', '-'))
    expected = frames * 800
    assert expected <= len(decoded) <= expected + 1024
    trimmed = run('ffmpeg', '-v', 'error', '-i', str(video_path), '-map', '0:a:0', '-af', f'atrim=end={duration}', '-f', 's16le', '-')
    assert len(trimmed) // 2 == expected
    # Gain-independent content and timing check; codec output need not be sample-identical.
    points = range(960, min(len(source), len(decoded)) - 960, 24)
    energy = sum(source[i] ** 2 for i in points)
    assert energy > 1
    fits = []
    for lag in range(-800, 801, 16):
        cross = sum(source[i] * decoded[i + lag] for i in points)
        target = sum(decoded[i + lag] ** 2 for i in points)
        fits.append((cross / math.sqrt(energy * target), lag, cross / energy))
    correlation, lag, gain = max(fits)
    assert correlation > .98 and abs(lag) <= 800
    marker_errors = []
    for time in [.625, 2, 3.25, 4.5, 6, 7]:
        if time >= len(source) / 48000:
            continue
        center = round(time * 48000)
        crossing = None
        for offset in range(center - 960, center + 960, 48):
            rms = math.sqrt(sum(x*x for x in decoded[offset:offset+48]) / 48)
            if rms > .15:
                crossing = offset / 48000
                break
        assert crossing is not None and abs(crossing-time) <= 1/60
        marker_errors.append(crossing-time)
    packets = json.loads(run('ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_packets', '-show_entries',
                             'packet=pts_time,side_data_list', '-of', 'json', str(video_path)))['packets']
    priming = packets[0].get('side_data_list', [{}])[0].get('skip_samples', 0)
    assert abs(float(packets[0]['pts_time']) + priming / 48000) < .000002
    return dict(status='passed', width=1080, height=1920, frames=frames, seconds=duration, video_time_base=video['time_base'],
                color_range=video.get('color_range'), audio_samples_trimmed=expected, audio_decoded_padding=len(decoded)-expected,
                audio_priming_samples=priming, content_correlation=correlation, content_gain=gain, content_lag_samples=lag,
                marker_errors_seconds=marker_errors, video_timestamps='all passed')


if __name__ == '__main__':
    print(json.dumps(validate(Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])), indent=2))
