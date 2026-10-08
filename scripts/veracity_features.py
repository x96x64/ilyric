#!/usr/bin/env python3
"""Optional pinned CPU singing-activity diagnostic. Local assets only; no acceptance."""
import argparse
import importlib.metadata
import json
from pathlib import Path
import resource
import sys
import time
from alignment.core import AlignmentError
from alignment.worker import Unavailable, file_hash
from alignment.veracity import CHECKPOINT_BYTES, CHECKPOINT_SHA256, REVISION, RATE, FILTER_BYTES, FILTER_SHA256, postprocess, network_config


def dependencies():
    try:
        import torch
        import torchaudio
        import numpy
        import soundfile
        import numba
        if torch.__version__ != '2.8.0' or torchaudio.__version__ != '2.8.0':
            raise Unavailable('Requires isolated torch 2.8.0 and torchaudio 2.8.0')
        return torch, torchaudio, numpy, soundfile
    except (ImportError, OSError) as e:
        raise Unavailable('Optional local veracity dependencies unavailable; no automatic installation') from e


def load_network(checkpoint, torch):
    from alignment.vendor.veracity.model import SingingVoiceDetector
    if not checkpoint.is_file():raise Unavailable('Pinned local veracity checkpoint unavailable')
    if checkpoint.stat().st_size != CHECKPOINT_BYTES or file_hash(checkpoint) != CHECKPOINT_SHA256:
        raise AlignmentError('Unsupported veracity checkpoint identity')
    state = torch.load(checkpoint, map_location='cpu', weights_only=True)
    if not isinstance(state, dict) or not all(isinstance(x, torch.Tensor) for x in state.values()):
        raise AlignmentError('Checkpoint is not a tensor state dictionary')
    net = SingingVoiceDetector(network_config()).eval()
    net.load_state_dict(state, strict=True)
    return net


def predict(net, magnitude, torch, chunk_frames=140):
    # Each output has a 115-frame receptive field. Context is never cut at chunk edges.
    padding = torch.zeros((57, 513), dtype=magnitude.dtype)
    padded = torch.cat((padding, magnitude, padding), dim=0)
    with torch.inference_mode():
        return torch.cat([net.probabilities(padded[i:i+chunk_frames+114][None,None])
                          for i in range(0, len(magnitude), chunk_frames)])


def resample_legacy(signal, original_rate, filter_path, np):
    """resampy 0.2.2 kernel and coefficients; librosa 0.8 floor then ceil-pad rule."""
    from alignment.vendor.resampy022.interpn import resample_f
    if not filter_path.is_file():raise Unavailable('Historical kaiser_best coefficient file unavailable')
    if filter_path.stat().st_size != FILTER_BYTES or file_hash(filter_path) != FILTER_SHA256:
        raise AlignmentError('Unsupported resampling coefficient identity')
    if original_rate == RATE:return signal
    with np.load(filter_path, allow_pickle=False) as data:
        window = data['half_window'].copy(); precision = int(data['precision'])
    ratio = float(RATE) / original_rate
    output = np.zeros(int(len(signal)*ratio),dtype=np.float32)
    if ratio < 1:window *= ratio
    delta = np.zeros_like(window);delta[:-1] = np.diff(window)
    resample_f(signal.reshape(-1,1),output.reshape(-1,1),ratio,window,delta,precision)
    wanted = int(np.ceil(len(signal)*ratio))
    return np.pad(output,(0,wanted-len(output)))


def extract(audio, checkpoint, filter_path):
    started = time.perf_counter()
    if not audio.is_file() or not checkpoint.is_file() or not filter_path.is_file():raise Unavailable('Local audio, pinned checkpoint, or historical filter unavailable')
    if audio.stat().st_size > 256*1024*1024:raise AlignmentError('Audio exceeds 256 MiB')
    identity = file_hash(audio)
    def deny(event, args):
        if event in ('socket.connect','socket.getaddrinfo'):raise Unavailable('Veracity inference forbids network access')
    sys.addaudithook(deny)
    torch, ta, np, sf = dependencies()
    torch.set_num_threads(4); torch.manual_seed(0); torch.use_deterministic_algorithms(True)
    imported = time.perf_counter()
    info = sf.info(str(audio))
    if not 0 < info.frames <= info.samplerate*60 or info.channels not in (1,2):
        raise AlignmentError('Diagnostic requires complete mono/stereo audio of at most 60 seconds')
    net = load_network(checkpoint, torch)
    initialized = time.perf_counter()
    signal, original_rate = sf.read(str(audio),dtype='float32')
    if signal.ndim == 2:signal = np.mean(signal,axis=1)
    signal = resample_legacy(signal,original_rate,filter_path,np)
    if not np.isfinite(signal).all():raise AlignmentError('Nonfinite audio samples')
    if len(signal) <= 512:raise AlignmentError('Audio is too short for documented reflection padding')
    # Defaults made explicit to preserve the upstream magnitude Spectrogram recipe.
    transform = ta.transforms.Spectrogram(n_fft=1024, win_length=1024, hop_length=315,
                   pad=0, window_fn=torch.hann_window, power=1., normalized=False,
                   center=True, pad_mode='reflect', onesided=True)
    magnitude = transform(torch.from_numpy(signal)).T
    prepared = time.perf_counter()
    raw = predict(net, magnitude, torch).tolist()
    inferred = time.perf_counter()
    result = postprocess(raw, len(signal))
    processed = time.perf_counter()
    if file_hash(audio) != identity:raise AlignmentError('Original audio changed during diagnostic')
    result.update(version=1, status='exploratory_diagnostic', automatic_acceptance=False,
        audio_sha256=identity, original_frames=info.frames, original_sample_rate=info.samplerate,
        analyzed_samples=len(signal), raw_scores=raw,
        provenance=dict(repository='CPJKU/veracity',revision=REVISION,checkpoint_sha256=CHECKPOINT_SHA256,
            dependencies={x:importlib.metadata.version(x) for x in ['torch','torchaudio','numba','numpy','soundfile']},
            device='cpu',threads=4,chunk_frames=140,resampling='resampy 0.2.2 kernel/kaiser_best; librosa 0.8 mono and length policy',filter_sha256=FILTER_SHA256,source_conditioning='audio only',
            licensing='Personal noncommercial local evaluation; repository MIT scope interpretation, no checkpoint-specific confirmation'),
        measurements=dict(dependency_import_seconds=imported-started,initialization_seconds=initialized-imported,
            preprocessing_seconds=prepared-initialized,inference_seconds=inferred-prepared,
            postprocessing_seconds=processed-inferred,total_seconds=processed-started,
            peak_rss_bytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*(1 if sys.platform=='darwin' else 1024)),
        limitations='Uncalibrated scores; no independently verified VAD truth, new-singer accuracy, lexical correspondence, endpoint repair, or timing mutation')
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['audio','checkpoint','filter','output']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    try:
        if a.output.exists():raise AlignmentError('Output already exists')
        if not a.output.parent.is_dir():raise AlignmentError('Create an ignored output directory first')
        result=extract(a.audio,a.checkpoint,a.filter)
        with a.output.open('x',encoding='utf-8') as f:json.dump(result,f,indent=2,allow_nan=False)
        print(json.dumps(dict(status='exploratory_diagnostic',automatic_acceptance=False)))
    except Unavailable as e:print(json.dumps(dict(status='unavailable',reason=str(e))));return 3
    except (AlignmentError,OSError,ValueError,RuntimeError) as e:p.exit(2,'Veracity diagnostic failed: '+str(e)+'\n')
    return 0

if __name__=='__main__':raise SystemExit(main())
