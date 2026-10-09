"""Optional pinned vocal separation for recognition input only.

Separated vocals feed audio-only Whisper windows. They never replace the
original mixture used for CTC refinement, never become timing evidence by
themselves, and are never redistributed. Public tests import this module
without Torch or Demucs; heavy imports occur only inside separate().
"""
from fractions import Fraction
from .core import AlignmentError
from .worker import Unavailable, file_hash

DEMUCS_VERSION = '4.1.0'
JULIUS_VERSION = '0.2.8'
MODEL_NAME = 'htdemucs'
MODEL_FILE = '955717e8-8726e21a.th'
MODEL_BYTES = 84141911
MODEL_SHA256 = '8726e21a993978c7ba086d3872e7608d7d5bfca646ca4aca459ffda844faa8b4'
SOURCE_RATE = 44100
OUTPUT_RATE = 16000
# Fixed inference policy. shifts=0 removes Demucs' random time-shift averaging.
POLICY = dict(shifts=0, split=True, overlap=0.25, device='cpu', threads=4, stem='vocals', downmix='mean')


def require_separator(weights):
    if weights is None:
        return None
    if not weights.is_file():
        raise Unavailable('Optional pinned htdemucs checkpoint unavailable; provisioning requires approval')
    if weights.name != MODEL_FILE or weights.stat().st_size != MODEL_BYTES or file_hash(weights) != MODEL_SHA256:
        raise AlignmentError('Separation checkpoint identity differs from the pinned artifact')
    return dict(model=MODEL_NAME, file=MODEL_FILE, sha256=MODEL_SHA256, bytes=MODEL_BYTES, policy=dict(POLICY))


def recognition_samples(source_samples):
    """Exact 16-kHz sample count for a 44.1-kHz separated signal of the same duration."""
    if type(source_samples) is not int or source_samples < 0:
        raise AlignmentError('Invalid separated sample count')
    return -(-source_samples * OUTPUT_RATE // SOURCE_RATE)


def downmix(stem):
    """Average channels without normalization; stem is (channels, samples)."""
    if getattr(stem, 'ndim', None) != 2 or stem.shape[0] not in (1, 2):
        raise AlignmentError('Separated stem must be mono or stereo')
    return stem.mean(axis=0)


def align_length(values, expected):
    """Pad or trim polyphase edge samples so recognition windows share the mixture's time base."""
    import numpy as np
    if abs(len(values) - expected) > 2:
        raise AlignmentError('Separated recognition input duration differs from the mixture')
    if len(values) >= expected:
        return values[:expected]
    return np.concatenate([values, np.zeros(expected - len(values), dtype=values.dtype)])


def separate(audio, work, weights, expected_samples, expected_duration_us):
    """Return mono 16-kHz vocals aligned to the mixture's analysis samples, plus provenance."""
    import subprocess
    import time
    try:
        import numpy as np
        import soundfile as sf
        import torch
        from scipy.signal import resample_poly
        from demucs.apply import apply_model
        from demucs.states import load_model
        import importlib.metadata as metadata
    except ImportError as e:
        raise Unavailable('Pinned Demucs separation dependencies unavailable') from e
    versions = dict(demucs=metadata.version('demucs'), julius=metadata.version('julius'), torch=torch.__version__)
    if (versions['demucs'], versions['julius']) != (DEMUCS_VERSION, JULIUS_VERSION):
        raise AlignmentError('Separation package versions differ from the approved pins')
    started = time.perf_counter()
    stereo = work/'separation-input.wav'
    try:
        subprocess.run(['ffmpeg', '-v', 'error', '-nostdin', '-protocol_whitelist', 'file,pipe', '-i', str(audio.resolve()),
                        '-map', '0:a:0', '-vn', '-ac', '2', '-ar', str(SOURCE_RATE), '-t', '600.000021',
                        '-c:a', 'pcm_f32le', '-n', str(stereo)], check=True, capture_output=True, timeout=120)
    except FileNotFoundError as e:
        raise Unavailable('FFmpeg unavailable') from e
    except subprocess.SubprocessError as e:
        raise AlignmentError('Bounded separation decoding failed') from e
    mix, rate = sf.read(stereo, dtype='float32', always_2d=True)
    stereo.unlink()
    if rate != SOURCE_RATE:
        raise AlignmentError('Separation input rate differs')
    duration = Fraction(len(mix) * 1000000, SOURCE_RATE)
    if abs(duration - expected_duration_us) > Fraction(1000000, SOURCE_RATE) + Fraction(1000000, 48000):
        raise AlignmentError('Separation input duration differs from the mixture')
    torch.set_num_threads(POLICY['threads'])
    torch.manual_seed(0)
    model = load_model(str(weights)).eval()
    if list(model.sources) != ['drums', 'bass', 'other', 'vocals'] or model.samplerate != SOURCE_RATE:
        raise AlignmentError('Unexpected separation model configuration')
    loaded = time.perf_counter()
    tensor = torch.from_numpy(np.ascontiguousarray(mix.T))
    reference = tensor.mean(0)
    mean, std = reference.mean(), reference.std()
    if not torch.isfinite(std) or std <= 0:
        raise AlignmentError('Silent or invalid separation input')
    with torch.inference_mode():
        sources = apply_model(model, ((tensor - mean) / std)[None], shifts=POLICY['shifts'], split=POLICY['split'],
                              overlap=POLICY['overlap'], device=POLICY['device'], progress=False)[0]
    vocals = (sources[model.sources.index('vocals')] * std + mean).numpy()
    separated = time.perf_counter()
    mono = downmix(vocals).astype(np.float64)
    resampled = resample_poly(mono, 160, 441).astype(np.float32)
    signal = align_length(resampled, expected_samples)
    sf.write(work/'vocals-16k.wav', signal, OUTPUT_RATE, subtype='FLOAT')
    timing = dict(load_seconds=loaded-started, separation_seconds=separated-loaded,
                  total_seconds=time.perf_counter()-started)
    return signal, dict(versions=versions, vocals_sha256=file_hash(work/'vocals-16k.wav'), measurements=timing)
