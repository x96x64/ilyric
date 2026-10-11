# Core ML Port Feasibility

## Outcome and Scope

October 11, 2026. **Both neural models of the alignment pipeline convert to Core ML with output matching PyTorch, and run two to four times faster; the separation weights can be supplied at first launch without redistribution.** The maintainer decided that iLyric should run natively on macOS without a Python setup step, and that the htdemucs separation weights, which carry no license statement and were trained partly on non-public recordings, must not be bundled but obtained on first use. This report establishes feasibility; the Swift implementation of the pipeline is not yet written.

Environment: Apple M4, macOS 27.0.1, coremltools 9.0 (about 16 MB of wheels, installed offline without upgrading NumPy 2.5.3), PyTorch 2.8.0. Converted packages remain under the ignored `artifacts/coreml/`.

## Recognition Model

`facebook/wav2vec2-base-960h` (Apache-2.0) was traced with log-softmax output and converted to an ML program with a flexible input of 1–30 s at 16 kHz, matching the pipeline's 30-second windows and shorter final window. On 30-second and 13.7-second windows of separated vocals:

| Variant | Compute Units | Largest Log-Probability Difference | Frame Labels Agreeing | Time per 30 s |
| --- | --- | ---: | ---: | ---: |
| Float32 | CPU only | 0.0031 | 100% | 0.91 s |
| Float32 | All | 0.0027 | 100% | 0.30 s |
| Float16 | All | Overflow | 97.1% | 0.17 s |

PyTorch on the CPU took 0.58 s. Float32 with all compute units is used; float16 is unusable without further work. The model's per-window normalization is applied outside the network.

## Separation Model

`HTDemucs` computes a complex short-time Fourier transform, which Core ML does not support. The network between the transform and its inverse was isolated: it takes the complex-as-channels spectrogram and the waveform of one 343,980-sample segment and returns both branch outputs. The split reproduces the complete model exactly. Conversion required two local workarounds: disabling PyTorch's fused attention fast path before tracing, and unwrapping one-element constants that NumPy 2 refuses to cast. With all compute units, the converted network matched PyTorch to 1.8×10⁻⁶ in the spectral branch and 1.2×10⁻⁷ in the waveform branch, and took 0.34 s per segment against 1.25 s. Disabling constant folding made the GPU compiler fail, so the folded model is used.

## Weights at First Launch

The converted weight file holds 522 entries. 499 are byte-identical to checkpoint tensors, directly or after a transpose or a split of attention projections. Of the remaining entries, the sinusoidal positional tables and a zero block depend only on tensor shapes and contain no checkpoint values, so they may be shipped. The others are deterministic functions of checkpoint tensors, consistent with the frequency embedding expanded over time and with attention weights and biases scaled at conversion. A manifest of these transforms, containing no weights, would let iLyric download the official checkpoint, verify its SHA-256, rebuild the weight file, and compile the model on the user's Mac.

## Remaining Work

1. Swift short-time Fourier transform and inverse with Accelerate, matching Demucs's reflect padding, Hann window, and normalization; segment overlap and weighting as in `apply_model`.
2. Swift reader for the PyTorch checkpoint archive, a weight-file writer, and a transform manifest generated and verified at build time against a reference conversion.
3. Swift forced CTC alignment, proposals, word grouping, and version 2 vocal rules, verified against the Python implementation on stored emissions.
4. End-to-end parity: line and word estimates on the development recordings must match the Python pipeline within the reported tolerances.

## Limitations

Parity was measured on one recording's windows and on synthetic input for the separation network. Timing excludes model compilation and first-load costs. The transform manifest has not been built, so the identification of the derived entries is an inference from their values and sizes. The checkpoint's terms of use remain unknown; downloading it on the user's machine avoids redistribution but does not establish a license.

Neither release readiness nor a native pipeline is established.
