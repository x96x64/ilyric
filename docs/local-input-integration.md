# iLyric Experimental Local Input Integration

## Disposition

**Retain the bounded local-input workflow with qualifications.** Supplied UTF-8 LRC and unprotected local audio now drive the existing experimental full-screen scene through its complete audio duration. Exact event timing, random-access state, whole-paragraph shaping, and the established AVFoundation writer are preserved. This is a practical developer experiment, not a stable public CLI, finalized project format, or native Music fidelity claim.

Historical reports, reference profiles, production `ilyric`, and the export backend remain unchanged. The empirical reference remains reported iPhone 16/iOS 27.0.1, build **Unknown**, with Default Display Zoom, Text Size 4/7 counting the smallest as 1/7, Bold Text/Reduce Motion/Reduce Transparency/Increase Contrast off, Light appearance, and English system and Music languages. No new native measurement or font identity is inferred from this integration.

## Input Contract and Timing

The [supported subset](local-input-subset.md) was defined before implementation. It specifies strict UTF-8, exact decimal timestamps through milliseconds, one signed offset, recognized ignored metadata, multiple timestamp expansion, sorted events, byte-sensitive duplicate handling, explicit gaps, unsupported-extension rejection, and bounded resources. The local `|` continuation extension supplies explicit multiline structure; adjacent timed entries remain separate paragraphs. Supplied boundaries and Core Text automatic wrapping remain distinguishable. S04/S05 source semantics are not resolved by parser behavior.

`LyricsInputCore` has no macOS rendering dependency. Its immutable entries retain exact normalized rational time, original text, source-line provenance, supplied-break status, and line-level timing classification. No Unicode normalization or text trimming changes content. Conflicting simultaneous text is rejected, including canonically equivalent but byte-distinct strings. At most 64 expanded events are accepted.

Output/audio time starts at zero. Positive LRC offsets delay focus events; negative effective times are errors. The latest event owns a half-open interval. Empty events remove focus while retaining the preceding scroll target; leading intervals have no focus. Final text holds through the audio endpoint. These are synthetic presentation semantics, not verified native lyric-event timing.

Audio determines duration. Events at or beyond its endpoint are rejected before export. The writer schedules `n/60` frames and 800 audio samples per frame. Output is extended to the next frame boundary by explicit silence padding of less than one frame. There is no silent lyric-driven truncation, automatic alignment, trim option, or inferred fine-grained highlighting.

## Audio Inspection and Conversion

`LyricsInputMac` accepts one unprotected local audio track, mono/stereo, integral source rates from 8–96 kHz, at most 256 MiB and ten minutes. AVFoundation inspects track format/range and decodes source-rate signed 16-bit PCM. Decoded presentation timestamps are checked on the source sample lattice. A leading track gap is filled explicitly; unsupported internal discontinuities, overlaps, and endpoint disagreements are errors.

Stereo is reduced by an explicit equal-weight arithmetic mean using 32-bit intermediate sums. Integer division rounds toward zero. This intentionally loses stereo separation; opposite-phase content may cancel. AVAudioConverter performs sample-rate conversion with normal priming, explicit end-of-stream flushing, and dithering disabled. Endpoint differences of at most one output sample are explicitly reconciled; larger differences fail. Source decoder blocks beyond an explicit track edit endpoint are removed under the bounded endpoint check.

The existing writer re-encodes supplied PCM as 48-kHz mono AAC at 128 kb/s; codec copying and lossless preservation are not claimed. Tests verified 44.1-kHz stereo PCM WAV, PCM AIFF, AAC LC in M4A, and 48-kHz mono WAV. Other installed decoder formats are not qualified. Protected-media rejection is implemented; no protected-media fixture or DRM bypass was exercised.

Initial direct AVAssetReader resampling ended 17 samples short. A separately flushed converter with priming disabled instead produced 34 excess samples. Normal priming reproduced the expected endpoint. SDK inspection also established that default converter channel remapping does not guarantee stereo downmixing; the final implementation therefore supplies its own deterministic mean. Distinct channel tones validate participation of both channels. These failed candidates were not retained.

## Scene Integration and Determinism

`LyricsInputProbe render --lyrics FILE.lrc --audio FILE --output FILE.mp4` is a separate experimental invocation. It refuses overwrites, requires an existing output directory, reads at most 64 KiB plus one sentinel byte, uses stderr for diagnostics, and emits a JSON result on stdout. Input/usage errors exit 2; export failures exit 1. [Reproduction commands](local-input-commands.md) include the original fixture and independent media checks.

Every nonempty event becomes a separately shaped paragraph. Latin retains fitted size 104.25 and advance 125.5; Japanese-style static input retains size 103.25 and advance 123. A simple Japanese/CJK content heuristic chooses the latter; it is not language identification or universal CJK qualification. Mixed scripts and other fallback coverage remain limited. Static input has no glyph events, Japanese vertical-treatment timing, or progressive wipe inferred from LRC. Existing measured Japanese progressive fixtures remain unchanged.

The composition now accepts one to 64 paragraphs and explicit no-focus events. It compiles the inherited 0.081-second analytic response from supplied events across the entire duration. Placement uses rendered line count plus a provisional 110-pixel paragraph gap; this does not establish native paragraph spacing. Source masks are shaped during setup, with no per-frame paragraph shaping. The current setup also makes a temporary layout pass to obtain heights before constructing cached scene layouts.

Local rendering culls safely outside the provisional viewport and retains at most six Latin inactive tile sets. Cache eviction does not own timeline state and produces identical pixels under reordered requests. The new static Japanese path retains the qualified opacity-only inactive treatment; Latin uses the inherited blur/contrast interpolation. Whole-paragraph advances, existing Japanese progressive geometry, original scene clocks, and motion parameters are unchanged.

The scene keeps original artwork, synthetic metadata defaults, static background, measured component placement, lower controls, and uniform `contain` from 1179×2556 into 1080×1920. The distinct 1180-column recording reference is preserved. Optional controls remain hidden. Normal local output adds no marker flashes, synthetic audio, or fixture visibility schedule. Existing synthetic invocations keep their previous diagnostic markers and schedules.

## Full-Duration and Audiovisual Results

The redistributable fixture supplies five original Latin/Japanese paragraphs, an explicit gap, two multiline paragraphs, a +125-ms offset, and a long final hold. Its audio generator produces distinct stereo tones, leading/trailing silence, and supplied audio-only markers. No binary audio or generated video is committed.

| Observation | Verified Result |
| --- | --- |
| Supplied focus/gap events | 0.625, 2, 3.25 (gap), 4.5, 6, and 7 seconds |
| Final focused paragraph | Index 4 through the selected endpoint |
| Decoded 48-kHz source presentation | 480,144 samples, 10.003 seconds |
| Explicit output padding | 656 samples, 13.667 ms |
| Video | 1080×1920 H.264, 60/1 fps, 601 decoded frames, 10.016667 seconds |
| Video color/timing | Limited-range Rec.709; time base 1/600; all frame timestamps pass |
| Audio | Mono 48-kHz AAC; start zero; track endpoint matches video |
| Export priming / decoder padding | 2,112 / 416 samples; endpoint trimming gives 480,800 samples |
| Independent content correlation | Approximately 0.999921 for all three tested containers |
| Best diagnostic waveform lag | Zero samples on the 16-sample search grid |
| Audio-marker timing | Six detections satisfy the output-frame tolerance; detected offsets are 0 ms at 1-ms resolution |

The correlation is gain-independent and codec-tolerant; it does not establish sample-identical or calibrated audio. Its measured gain of approximately 0.70685 against FFmpeg's stereo-to-mono reference reflects different documented channel-mix normalization. Exact source PCM conversion and immutable state are separately tested. An off-frame event at 5/8 seconds remains exact in the model and first appears in sampled frame 38, without modifying the event to that frame boundary.

Five decoded states spanning Latin focus, Japanese focus, the gap, the late event, and final hold were visually inspected. They retain readable supplied line structure, genuine focus movement after six seconds, static control visibility, and preserved proportions. The gap has no focused text but retains inactive neighbors. Japanese inactive text remains sharper than Latin; placeholder controls, static materials, provisional fades, and unsupported fine-grained highlighting remain visible limitations. This was sampled visual inspection, not a native-fidelity assessment. A separate audit covers all 601 decoded frames: handle, transport, and bottom-control consecutive mean differences never exceed two diagnostic code levels; maxima are 0.953, 0.249, and 0.183 respectively. The diagnostic-flash location stays at 58–59 levels. These checks establish no unexpected control disappearance or flash in the audited regions, not universal artifact absence.

## Performance and Resource Limits

The isolated optimized run rendered **601 frames in 20.216 seconds**, or **29.728 fps**. Raster time was **20.057 seconds**, process wall time **20.59 seconds**, and peak RSS **413.47 MiB**. The machine was Apple M4 running macOS 27.0.1 with Swift 6.4, macOS SDK 27, and FFmpeg 8.1.2. The benchmark and sanitized environment are recorded in [version-1 local-input evidence](local-input-data/v1/validation.json). The fixture is deliberately small; no ten-minute throughput or maximum-event memory-growth claim is made. Source PCM and shaped masks are bounded by the documented input limits rather than streamed indefinitely.

Raster composition remains the dominant measured cost. Parsing and decoding finish before the writer's timed export; process wall time also includes them and setup. Native canvases, transparency layers, visible paragraph rasters, and cached inactive tiles remain allocations. Culling prevents full-canvas rasterization of every off-screen paragraph; tile storage is bounded. No application-level GPU readback, Metal engine, per-frame paragraph shaping, or change to the writer was introduced. Short elapsed/remaining labels retain the inherited per-frame Core Text setup; that cost was not separately profiled. The prior six-second inactive workload differs in paragraph count and Japanese appearance complexity, so its 22.001-fps/404.84-MiB result is contextual rather than a speedup baseline.

## Verification and Privacy

All **40 Swift tests** and **66 Python tests** pass. New tests cover malformed UTF-8/tags/timestamps, canonical-equivalence-sensitive duplicates, offsets, resource limits, exact off-frame timing, gaps, final holds, duration conflicts, source errors, stereo/mono decoding, repeated PCM equality, static shaping, cache eviction, marker exclusion, and reordered state/raw-raster equality. The integration check validates all three source containers plus twelve invalid-input/overwrite cases and temporary-file cleanup.

Release builds and all existing deterministic probes pass. The original four-second architecture-spike, six-second composition, and inactive full-screen exports pass their unchanged audiovisual validators. Private Latin common-origin measurements are unchanged; twenty archived Japanese renderings remain byte-identical. V01–V03 and V09/V10 source hashes and ignore rules are verified. An initial integrity helper used a filename-only mapping as a root-relative path; resolving the documented recording directory completed verification without a hash discrepancy.

The fresh public checkout at implementation commit `5f9efc7` builds, passes both complete suites and deterministic probes, renders the original Latin/Japanese fixtures, and exports original and local-input videos without private material. All thirteen reference-dependent commands report explicit unavailable states. Its working tree remains clean apart from ignored outputs. A synthetic cache test initially supplied an invalid four-digit fractional timestamp; correcting the fixture preserved parser strictness. A fixture assertion initially sampled its intentional trailing silence and was corrected. Existing sandbox cache restrictions and nonfatal linker warnings remain environment limitations.

Private references and reference-derived diagnostics remain ignored. Public changes contain original text, generators, tests, code, numerical results, and documentation only. Historical reports, reference data, human Git identities, attribution trailers, and the original-history backup are preserved. No release, tag, license choice, network retrieval, or production CLI expansion is introduced.

## Next Engineering Gate

**Go for retaining the reproducible local-input experiment.** The next bounded priority is a versioned experimental project configuration for input paths, supplied metadata/artwork, timing policy, and component visibility, with explicit compatibility and reproducibility checks before public stabilization. Broader synchronization formats and lawful acquisition remain subsequent gates; dynamic materials, SF Symbols licensing/control refinement, generalized transitions, and edge-to-edge adaptation remain deferred. Native Music fidelity is unvalidated.
