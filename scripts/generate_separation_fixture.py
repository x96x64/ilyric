#!/usr/bin/env python3
"""Generate the native separation signal-processing fixture from Demucs, PyTorch, and SciPy.

Random signals only; no weights, recordings, or reference assets. The Swift `AlignmentMacTests` suite
must reproduce the HTDemucs spectrogram, its inverse, and SciPy polyphase resampling.
"""
import base64
import json
import sys
from pathlib import Path
import numpy as np
import torch
from demucs.htdemucs import HTDemucs
from scipy.signal import resample_poly


def b64(a, dtype='<f8'):
    return base64.b64encode(np.ascontiguousarray(a, dtype=dtype).tobytes()).decode()


def main(out):
    rng = np.random.default_rng(20261011)
    model = HTDemucs(sources=['vocals'])  # untrained; only its STFT conventions are used
    x = rng.normal(0, 0.3, 5000)
    with torch.no_grad():
        z = model._spec(torch.from_numpy(x)[None, None])  # (1, 1, 2048, frames)
        frames = z.shape[-1]
        zr = rng.normal(0, 1, (2048, frames)) + 1j * rng.normal(0, 1, (2048, frames))
        y = model._ispec(torch.from_numpy(zr)[None, None], 5000)[0, 0].numpy()
    r = rng.normal(0, 0.3, 4410)
    fixture = dict(signal=b64(x), frames=frames, spec_re=b64(z[0, 0].real.numpy()), spec_im=b64(z[0, 0].imag.numpy()),
                   ispec_re=b64(zr.real), ispec_im=b64(zr.imag), ispec_out=b64(y),
                   resample_in=b64(r), resample_out=b64(resample_poly(r, 160, 441)))
    Path(out).write_text(json.dumps(fixture) + '\n')
    print('frames', frames)


if __name__ == '__main__':
    main(sys.argv[1])
