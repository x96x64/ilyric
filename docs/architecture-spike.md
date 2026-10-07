# iLyric Architecture Spike

## Scope and Evidence

This experiment evaluates the architectural baseline in [the preserved planning study](planning-study.md), not visual fidelity to native Music. The study is byte-for-byte unchanged (SHA-256 `efb317f976fb34ff729f82c3b911fee8381b70a9f74b3f56d4856c89f387f142`). Its historical placeholder command is superseded by `ilyric`.

The authored fixture is four seconds rather than the study’s proposed 12–15 seconds. This deliberately smaller scene exercises the relevant timeline, typography, raster, audio, and export boundaries. All appearance and motion constants are synthetic. No physical iPhone captures or measurements were available. The 402×874 logical canvas is provisional geometry from the study, fitted uniformly into portrait output; it is not a measured device preset.

## Implementation

`SpikeCore` contains normalized rational time, exact frame scheduling, explicitly ordered events, compiled cubic Hermite motion segments, immutable presentation snapshots, a pure contain transform, and deterministic PCM synthesis. It has no macOS rendering imports. Simultaneous events are ordered by their unique integer order; the last event at a timestamp takes effect. Marker and word intervals are half-open. Interrupted motion preserves position and velocity. Output time and seek-mapped media time are distinct; interface motion follows output time. Pause behavior is not implemented.

`RenderMac` shapes complete paragraphs with Core Text and caches their raster images. It preserves source ranges, explicit newlines, measured baselines, and fallback-font names. Eight authored Latin word intervals clip the existing paragraph raster through Core Text offsets. Latin and Japanese paragraphs each occupy two lines. Additional automated fixtures exercise combining marks, mixed scripts, and automatic wrapping. General cluster-aware timing, bidirectional layout, CJK punctuation conformance, and iPhone font equivalence remain untested.

The renderer composes an original orbit-and-disk artwork, a static blurred backdrop, a translucent panel, two text groups, independent placeholder playback shapes, a progress bar, and a synchronization flash. Core Image performs one clamped-edge Gaussian blur at 35 synthetic logical pixels in an extended-linear-sRGB working space. The result is converted to Rec.709 and cached before foreground composition. CPU Core Graphics draws directly into pooled BGRA video buffers; text is not reshaped or rerasterized per frame. No custom Metal code, SwiftUI layout, or Core Animation presentation state is involved.

The backend uses `AVAssetWriter` and its pixel-buffer adaptor with independent asynchronous video and audio producers, coordinated on the main actor. The adaptor is isolated in the backend as a macOS 14 compatibility choice; newer receiver APIs have not been evaluated. Readiness polling provides backpressure, with a 30-second stall timeout. A single frame is held by the application at a time; the encoder and pool own their internal buffering. Video timestamps are exactly `n/60`; 800 mono PCM samples at 48 kHz correspond to each frame. Audio combines a 223.25 Hz media-time tone with 1 kHz output-time markers. Video output is finalized through a temporary sibling file.

The writer supplies H.264 at a requested 12 Mb/s and AAC at 128 kb/s. Both source pixel buffers and output settings carry Rec.709 primaries, transfer, and matrix tags. PNGs retain their color profile. Encoded-file byte identity is not a requirement.

## Reproduction and Test Results

[Developer commands](spike-commands.md) describe the three experimental commands and validation scripts. There are no external Swift dependencies, import parsers, production schemas, generalized scene graph, device presets, release packages, or stable production CLI.

The complete `scripts/test.sh` suite passed all nine tests using Swift Testing. Tests cover rational reduction and fractional-frame schedules, large rational comparisons, simultaneous event ordering, half-open boundaries, seeks, interrupted-motion continuity, all 240 timeline states in a fixed permutation, pure geometry, Core Text layout/source coverage, raw raster equality, and PCM determinism. The optimized package builds successfully. Remaining linker warnings concern nonexistent search directories supplied by the installed Command Line Tools, not unresolved symbols.

Full-resolution `ilyric determinism` runs compared seven timestamps in sequential, shuffled, repeated, and fresh-renderer orders. SHA-256 results were identical across two separate processes. This is observed byte equality for CPU-rendered BGRA output on the recorded environment. It is not a promise of equality after OS, font, toolchain, or architecture changes. No cross-environment raster tolerance has been qualified.

## Media Validation

`scripts/validate_media.py` passed for both four-second exports (1080×1920 and 2160×3840) and the ten-minute 1080×1920 repetition. Each short file contains exactly 240 decoded frames, `60/1` average and nominal frame rates, four-second video and AAC tracks, audio starting at zero, and Rec.709 metadata. Every decoded video presentation timestamp matched `n/60` within the probe’s two-microsecond tolerance. All four markers matched their expected three-frame visual flashes and audio onset within the validator’s 1 ms analysis resolution.

The long file contains 36,000 frames, exactly 600-second video/audio tracks, and 28,800,000 PCM samples after endpoint trimming. All 600 audio-marker measurements returned zero offset at 1 ms resolution, including the marker at 599 seconds; all 1,800 corresponding bright video frames occurred at the expected positions. No accumulated audiovisual drift was observed within that resolution. The untrimmed decoder returned 28,800,960 samples: its 960-sample tail is 20 ms and exceeds one video frame. The container duration is correct, but an application that ignores the track endpoint can expose that padding. Exact decoded sample count therefore requires honoring the endpoint, as explicitly tested.

Raw AAC decoding exposes encoder padding even when the track duration is exact. The four-second file signals 2,112 priming samples through its initial packet’s skip-sample metadata. FFmpeg returns 192,448 samples after priming; applying the declared four-second endpoint yields exactly 192,000 samples. The remaining 448 samples are 9.33 ms of decoded tail padding, below one output frame. Consumers must honor track endpoints; raw packet concatenation is not a validated delivery path.

Six important positions were inspected: start, moving focus, seek boundary, post-interruption recovery, second focus event, and final lyric gap. Full-resolution stills and decoded frames showed readable Latin/Japanese text, intended wrapping, complete artwork/control geometry, visible highlight changes, and no observed clipping. A color-managed contact sheet used FFmpeg’s `colorspace` filter to convert Rec.709 to sRGB for viewing. This inspection is not the study’s three-reviewer native-reference assessment.

The pixel regression check compares nonlinear Rec.709 RGB from stills and decoded frames, including a separate text region. Its synthetic lossy-codec limits are mean absolute error ≤3/255 and PSNR ≥35 dB overall, and ≤4/255 and ≥30 dB in the text region. These are export sanity checks, not Apple Music fidelity thresholds. Frames 0, 67, 75, 95, 180, and 239 all passed: overall PSNR ranged from 39.37 to 40.79 dB and text-region PSNR from 37.78 to 40.53 dB. Maximum mean absolute errors were 2.057/255 overall and 2.421/255 in the text region. The earlier color-defective export failed the same test at frame 75 (28.94 dB overall, 27.34 dB in text), demonstrating that the check detects the observed error.

## Benchmark Conditions and Results

Measurements were taken on October 7, 2026, on a MacBook Air (`Mac16,12`), Apple M4 with 10 CPU cores (4 performance, 6 efficiency), 8 GPU cores, and 16 GiB memory. The operating system was macOS 27.0.1, build `26A434`. Swift was 6.4 (`swiftlang-6.4.0.30.4`, Clang `2100.3.30.1`); the SDK was macOS 27.0. Swift 5 language mode was used. Media analysis used FFmpeg/ffprobe 8.1.2. Resolved fonts were Helvetica and HiraginoSans-W3; no font files are bundled. The installed `Helvetica.ttc` SHA-256 was `658718d77497145281cb0ec45ff2fe7c6e18062b2a38f837d0d792d9be3a9ba3`; the installed Hiragino W3 collection SHA-256 was `ff92033a300f55aff2f45f57479a560af2c5467973b425d3f724f870af07f83e`. These fingerprints record the experiment’s environment, not permission to redistribute those fonts.

Builds used `swift build -c release`. Export wall time is measured inside the exporter from writer setup through final file move; renderer initialization is listed separately. `/usr/bin/time -l` measures the whole process, including startup. Effective fps is frame count divided by export wall time, not the delivered frame rate, which remains exactly 60 fps. Resident memory and footprint are distinct operating-system counters. Measurements are machine-specific single runs, not a benchmark distribution or a production performance guarantee.

| Workload | Frames | Export Wall Time | Effective FPS | Raster Time | Setup Time | Process Wall Time | Peak RSS |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1080×1920, 4 s | 240 | 2.4895 s | 96.40 | 2.3621 s | 0.0717 s | 2.88 s | 75.63 MiB |
| 2160×3840, 4 s | 240 | 9.6543 s | 24.86 | 9.4842 s | 0.0432 s | 9.70 s | 189.81 MiB |
| 1080×1920, 600 s, repeated fixture | 36,000 | 369.2423 s | 97.50 | 364.4223 s | 0.0503 s | 369.30 s | 91.95 MiB |

The short runs reported peak memory footprints of 62.63 MiB and 201.91 MiB. The 1080p writer append calls totaled 0.00285 s, combined producer backpressure waits 0.00019 s, and finalization 0.00313 s. At 2160p those values were 0.00523 s, 0.02563 s, and 0.00376 s. Producer waits include actor scheduling delay and should not be added to infer process wall time. The long run accumulated 366.79 s in readiness awaits while rasterization occupied the shared actor; this is not a measurement of 366.79 s of encoder stalls. Fair scheduling or backend callbacks would need evaluation before integrating an interactive preview. The long run’s peak footprint was 71.41 MiB, and RSS snapshots were 90.69, 83.17, and 82.78 MiB. This showed no monotonic memory growth over the tested workload; it does not prove an indefinite bound for arbitrary scenes.

## Bottlenecks and Limits

Raster drawing consumed about 95% of the short 1080p export and 98% of the 2160p export. A two-second CPU sample at 10 ms intervals during the long run found the main thread predominantly in Core Graphics image sampling and compositing: 113 of 163 main-thread samples passed through the backdrop’s `CGContextDrawImage` call. This identifies repeated scaling of the cached logical-resolution background as an optimization candidate. The sample is indicative, not an exhaustive profiler study; the long-run timing includes its overhead.

There are no repeated application-level GPU readbacks: the backdrop is materialized once during setup, and the frame pipeline is CPU raster to pixel buffer. Core Text shaping and text-mask creation also occur only during setup. Pixel buffers come from the writer pool; per-frame bitmap contexts and small PCM buffers/format descriptions remain allocations that could be reduced. Encoder internals and GPU utilization were not measured directly. No persistent encoder stall remained after independent track feeding was introduced.

A static cached blur does not validate animated materials, repeated full-screen blur passes, complex backdrop dependencies, or a GPU-resident compositor. The near-fourfold raster cost at twice the linear dimensions is consistent with a pixel-bound CPU path. That inference does not establish how a future dynamic-effects workload would behave. Metal is not justified by the present minimum-throughput gate alone.

## Failed Experiments and Corrections

- Sandboxed Swift builds could not write compiler caches, and sandboxed Core Image initialization failed. Authorized host execution was required. This does not establish support for a sandboxed application distribution.
- The installed Command Line Tools did not expose XCTest. Swift Testing initially also failed because compiler-plugin and runtime search paths were missing. The native SwiftPM build-system fallback did not resolve that setup. `scripts/test.sh` derives the necessary installed paths without modifying the toolchain.
- An initial color constant required a newer deployment target. The implementation instead uses explicit Rec.709 throughout the raster/export path.
- A layout assertion incorrectly treated trailing whitespace advances as visible width. Subtracting Core Text’s trailing-whitespace width fixed the measurement without modifying source ranges or line breaking.
- Lockstep video/audio feeding timed out after 30 seconds. Independent track producers repaired the encoder backpressure dependency.
- Output metadata alone did not preserve the intended colors. Explicit source-buffer transfer, primaries, and matrix attachments removed the additional transfer conversion. Decoded pixel regression now guards this path.
- The installed FFmpeg lacks `zscale`. Its available `colorspace` filter was used for viewing conversions; raw Rec.709 comparisons do not depend on that filter.

## Architecture Assessment

**Retained with qualifications.** The bounded synthetic vertical slice passes the study’s relevant architecture gates: random-order raw-frame equality on a pinned environment, valid exact-60-fps export, marker synchronization within one frame over ten minutes, more than 15 encoded fps at 1080p, memory well below 4 GiB without observed duration-dependent growth, and a successfully validated short 2160p export. This supports continuing the Swift/Core Text/Core Image/Core Graphics/AVFoundation architecture for measurement-led development. It does not qualify a production renderer or native Music reproduction.

The evidence supports rational, arbitrary-time snapshot evaluation; cached Core Text shaping/rasterization; ordinary Apple raster composition; and explicit AVFoundation writing for this bounded synthetic scene. It weakens the assumption that a GPU compositor is necessary for the initial performance target. It also demonstrates that export integration requires correct source color metadata and independent track backpressure handling; process completion alone would not have found the color defect.

The study’s proposed ≥15 encoded fps and ≤4 GiB memory thresholds are engineering gates, not Apple measurements. Native typography, measured motion, Sing behavior, dynamic materials, permitted production font choices, capture uncertainty, human A/B review, cross-environment compatibility, and visual-fidelity thresholds remain unresolved. The complete iOS 27 fidelity objective is not validated.

## Next Gate

Acquire lawful, private reference captures from the study’s specified physical iPhone/iOS 27 configuration, record exact build/settings and uncertainty, and compare Core Text line breaks, advances, baselines, and motion with those measurements. Then test the measured material workload before deciding whether to replace CPU compositing with Core Image/Metal. Keep production input formats and release work deferred until those gates provide evidence.
