"""Container and supplied-audio checks for real singing; no synthetic marker assumption."""
import array
import json
import math
import subprocess


def inspect(video, audio):
    def run(*args): return subprocess.check_output(args)
    streams = json.loads(run('ffprobe', '-v', 'error', '-count_frames', '-show_streams', '-of', 'json', str(video)))['streams']
    v = next(s for s in streams if s['codec_type'] == 'video')
    a = next(s for s in streams if s['codec_type'] == 'audio')
    frames = int(v['nb_read_frames'])
    assert (v['width'], v['height'], v['codec_name'], v['avg_frame_rate']) == (1080, 1920, 'h264', '60/1')
    assert a['codec_name'] == 'aac' and a['sample_rate'] == '48000' and a['channels'] == 1
    assert v['color_space'] == v['color_transfer'] == v['color_primaries'] == 'bt709'
    assert v.get('color_range') == 'tv' and float(a.get('start_time', '0')) == 0
    assert abs(float(v['duration'])-frames/60) < .00002 and abs(float(a['duration'])-frames/60) < 1/48000
    times = json.loads(run('ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_frames', '-show_entries', 'frame=best_effort_timestamp_time', '-of', 'json', str(video)))['frames']
    assert len(times) == frames and all(abs(float(t['best_effort_timestamp_time'])-i/60) < .000002 for i,t in enumerate(times))
    def samples(path): return array.array('f', run('ffmpeg','-v','error','-i',str(path),'-map','0:a:0','-ac','1','-ar','48000','-f','f32le','-'))
    x,y = samples(audio),samples(video)
    assert frames == (len(x) + 799) // 800, 'Output must contain the complete supplied audio interval'
    points = range(960,min(len(x),len(y))-960,48)
    energy = sum(x[i]**2 for i in points)
    if energy == 0: raise ValueError('No nonzero supplied audio support')
    fits=[]
    for lag in range(-800,801,16):
        cross=sum(x[i]*y[i+lag] for i in points); target=sum(y[i+lag]**2 for i in points)
        fits.append((cross/math.sqrt(energy*target),lag))
    correlation,lag=max(fits)
    assert correlation>.98 and abs(lag)<=800
    return {'status':'passed','frames':frames,'seconds':frames/60,'width':1080,'height':1920,'fps':60,
            'color_range':v.get('color_range'),'audio':'48-kHz mono AAC','audio_correlation':correlation,
            'audio_lag_samples':lag,'lag_search_step_samples':16,'all_video_pts':'passed',
            'acoustic_alignment_accuracy':'Evaluated separately; container agreement is not lyric accuracy'}
