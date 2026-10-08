"""Pinned diagnostic semantics; standard-library only and no alignment mutations."""
import math
import struct
from fractions import Fraction
from .core import AlignmentError

REVISION = '0983900f136173015f3c5d0b116be014edd33905'
CHECKPOINT_SHA256 = 'f09cd6a55c83c13640622ce67480443ce282e3124dd22fccee8a898bb2ba9dee'
CHECKPOINT_BYTES = 7433173
FILTER_SHA256 = '67fab90360555b1704a6e84f75335eb306b166617f5b4de45a28ea225e69b0bb'
FILTER_BYTES = 262736
RATE = 22050
HOP = 315
# Upstream thresholds are torch.float32, with strict greater-than comparison.
THRESHOLD = struct.unpack('f', struct.pack('f', .51))[0]


def frame_time(index):
    if type(index) is not int or index < 0:
        raise AlignmentError('Frame index must be a nonnegative integer')
    return Fraction(index * HOP, RATE)


def postprocess(scores, samples):
    if type(samples) is not int or not 0 < samples <= RATE * 60:
        raise AlignmentError('Veracity accepts 0–60 seconds, excluding zero duration')
    if not isinstance(scores, list) or len(scores) != samples // HOP + 1:
        raise AlignmentError('Score count does not match the centered STFT grid')
    if any(type(x) not in (int, float) or not math.isfinite(x) or not 0 <= x <= 1 for x in scores):
        raise AlignmentError('Diagnostic scores must be finite values in [0,1]')
    # Exact upstream MedianPool: replicate edges, left 28/right 27,
    # kthvalue(29) of 56 (upper median), not an averaged even-window median.
    smooth = [sorted(scores[min(len(scores)-1, max(0, i+j))] for j in range(-28, 28))[28]
              for i in range(len(scores))]
    spans = []
    for i, value in enumerate(smooth):
        a, b = i*HOP, min((i+1)*HOP, samples)
        if value > THRESHOLD and a < b:
            if spans and spans[-1][1] == a:spans[-1][1] = b
            else:spans.append([a,b])
    return dict(filtered_scores=smooth, intervals_samples=spans,
                time_denominator=RATE, hop_samples=HOP,
                threshold=THRESHOLD, median_frames=56,
                interval_semantics='Half-open sample-and-hold on native score grid, clipped to analyzed audio; not measured vocal boundaries')


def network_config():
    return dict(n_mels=80, sample_rate=RATE, f_min=27.5, f_max=8000,
                n_stft=513, frame_len=1024, filterbank='mel_orig', spec_len=372,
                magscale='log', arch='ismir2015', **{'arch.batch_norm':1,
                'arch.convdrop':'none', 'arch.firstconv_zeromean':'0mean'})
