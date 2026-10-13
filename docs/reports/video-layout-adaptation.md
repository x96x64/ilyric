# Full-Width 9:16 Video Layout Adaptation

## Outcome and Scope

October 13, 2026. Normal video rendering now uses a 1440 × 2560 logical canvas uniformly scaled by 0.75 to 1080 × 1920. The adaptation fills the output without horizontal padding, nonuniform stretching, or vertical cropping. The 1179 × 2556 native reconstruction and 1180-pixel recording variant remain available internally for historical probes. No CLI option was added.

This is a maintainer-approved video adaptation, not measured native iOS 27 iPhone geometry. Historical visual qualification, particularly its wrapping results, does not transfer to the wider layout. Existing native-fidelity limitations remain in force. Completed reports were preserved.

## Baseline and Evidence

The baseline was main commit `3bf9357949e06f67e4265b44d39ae69356f08ccf`. Its contain transform fits the 2556-pixel height into 1920 pixels at scale 0.751173709. A 1179-pixel canvas consequently occupies 885.633803 output pixels, leaving 97.183099 pixels on each side. These are code-derived geometric calculations, not new device measurements. Both the CPU and GPU paths composite the contained scene over black before encoding.

Original synthetic inputs were generated for the investigation: timed paragraphs with generated identifiers, one explicit break, secondary cues, an opening gap, synthetic audio, and an overflowing header. No source lyric text is reproduced in this report. Inputs, prototype source, raster evidence, export reports, binaries, and machine-specific logs remain ignored. Preserved pre-change binaries supplied the baseline exports and native-probe comparisons.

AGENTS.md, the complete roadmap, and the planning study governed the work. Historical visual qualification, full-screen composition, typography, control, marquee, paragraph-spacing, and background reports supplied context only. No private reference capture or real recording was accessed.

## Rendering Alternatives

Before production edits, an optimized ignored prototype compared direct drawing into 1080 × 1920 under a logical 0.75 transform with 1440 × 2560 drawing followed by uniform CPU or Metal/Core Image downsampling. It included public system-font shaping, a runtime-resolved SF Symbol, vector geometry, a vertical mask, and a reduced-resolution blurred synthetic background.

Three 60-frame trials produced the following durations:

| Prototype Path | Duration Range (Seconds per 60 Frames) |
| --- | ---: |
| Direct Output Drawing | 0.570–0.586 |
| Logical Canvas, CPU Downsampling | 1.593–1.606 |
| Logical Canvas, GPU Downsampling | 1.501–1.526 |

In the visible-glyph diagnostic window, direct and downsampled rendering had matching thresholded bounds. White-support intersection-over-union was 0.936 against CPU downsampling and 0.937 against GPU downsampling; mean absolute RGB differences were 1.743 and 1.849 on the 0–255 scale. Whole-frame mean absolute differences were 0.576 and 0.616. These are synthetic raster comparisons, not native-fidelity scores or a demonstration of complete production equivalence.

Direct rendering is feasible and promising for a simpler scene. The prototype does not reproduce the production renderer's cached native glyph layers, additive subpixel interpolation, inactive blur tiles, word-fill masks, emphasis glow, and transparency-layer behavior. Its speed advantage therefore cannot be extrapolated to complete-song export. Runtime symbol rendering and mask filtering also remain environment-dependent.

The selected implementation retains logical-canvas rendering and uniform downsampling. This preserves the established raster and effect sampling mechanisms and avoids introducing a second scale-sensitive rendering path. CPU high-quality resampling and GPU Lanczos resampling remain supported. No new GPU kernel or backend was introduced.

A 1080 × 1920 RGBA8 destination requires approximately 7.91 MiB; a 1440 × 2560 logical image requires approximately 14.06 MiB before additional copies, masks, caches, and encoder buffers. These are storage calculations, not isolated process-memory measurements. The prototype's combined-process peak does not identify separate per-path memory costs. The logical canvas contains 22.33% more pixels than the original native canvas; the production benchmark below measures the resulting workload cost.

## Implementation and Reflow

An immutable internal `LyricsCanvas` selects native or adapted geometry. Normal CLI video rendering selects the adapted canvas before paragraph shaping; existing probe and local-presentation defaults retain native geometry. The existing internal canvas-width field identifies the layout without changing TTML or render-report formats.

The approved anchor rules preserve left offsets, move right anchors by 261 logical pixels, move centered anchors by 130.5 pixels, and move bottom anchors by four pixels. The same anchor resolver positions control rectangles and every runtime SF Symbol center, including More, transport, volume, bottom, translation, and compact singing controls. Symbol names, point sizes, weights, discs, opacity, and proportions remain unchanged. Project-owned icon shapes retain their proportions.

Latin shaping width increases from 987 to 1248 logical pixels. Header bounds increase from 650 to 911 pixels. The marquee clip extends from x = 312–977 to x = 312–1238, increasing its width from 665 to 926 pixels. More moves from x = 1007 to x = 1268. The control-visible lyric viewport becomes `(72, 550, 1301, 954)`; the expanded viewport becomes `(72, 550, 1301, 2010)`.

Automatic text reflows at the wider width. Explicit breaks, paragraph order, text, and source-range coverage are retained. Fewer wrapped rows can change paragraph positions, secondary reserves, scroll distances, and the existing distance-dependent stagger delay. These are approved spatial consequences; the stagger formula and animation parameters are unchanged. Header overflow eligibility can change, but marquee delay, speed, easing, pause, copy gap, and fade widths remain unchanged.

Canvas-dependent bitmap sizes, Core Graphics coordinate flips, text baselines, masks, gap drawing, clipping, and output fitting now use the selected height. The background covers the complete logical canvas. Background colour, contrast, blur, and motion parameters were not retuned; altered aspect ratio changes the sampled spatial field. No safe-area or system-chrome measurement is inferred from the adapted dimensions.

Main timing events, accepted acoustic estimates, alignment, Plan C, CTC, separation, activity detection, TTML import/export, and report formats were not modified. Inherited secondary text remains focus-gated, dim, and unfilled. Explicitly timed secondary cues retain their own fill semantics. Opening-gap ownership and the interlude handoff correction remain intact. Auto-hide retains its event time, sampled offsets, opacity, reveal, and boundary semantics.

## Verification Criteria and Results

The approved preimplementation criteria required full-frame background coverage, equal horizontal and vertical scale, in-bounds settled controls, retained lyric source ranges and explicit breaks, exact timing-event preservation, random-access determinism, retained gap and secondary policies, and correct media dimensions, cadence, and audio mapping.

Five new synthetic regressions verify shared anchors and symbol configuration; reflow and complete ordered source-range coverage; CPU/GPU whole-frame coverage and repeated/shuffled rational timestamps; opening-gap and secondary behavior; and circular More ink with retained native defaults. Boundary evaluations include exact focus and auto-hide times and adjacent microsecond timestamps. Comparisons include fresh renderers and whole-frame buffers rather than crops alone.

For the tested static and artwork-derived synthetic backgrounds, every checked CPU and GPU output pixel was opaque and nonblack. Repeated and shuffled frames matched exactly within each path on the recorded environment. This is not a promise of CPU/GPU raster equality or equality across macOS, font, and GPU versions.

Synthetic native/adapted scenes retained identical imported entries, paragraph count and order, begin/end intervals, supplied appearance events, focus event times and ordering, playback mapping, and auto-hide state values. The fixture deliberately changes automatic row count while preserving its explicit break. Untimed/inherited backing cues produced no additional ink beneath unfocused paragraphs in whole-frame comparisons and retained zero fill; explicitly timed cues retained their exact progress endpoints.

Two original native-probe fixtures, including calibrated inactive/progressive rendering with an artwork background, matched their preserved pre-change whole-frame rasters exactly at 1179 × 2556. Existing native geometry, More, gap, backing, Plan C, and timeline regressions also passed in the full suite.

The normal CLI exported 720 frames over 12 seconds as 1080 × 1920 H.264 at 60/1 fps, with 48-kHz mono AAC. Both tracks began at zero and had a 12-second container duration. Every video presentation timestamp agreed with n/60 within 0.000000334 seconds, the displayed probe precision. Four decoded whole frames spanning the opening gap, focus, and later lyrics contained zero black pixels and zero black edge pixels.

Decoded baseline and adapted audio matched byte-for-byte. Both decoded streams contained 576,448 sample frames, including the same 448 sample frames beyond the nominal 576,000-sample duration. This decoder/codec padding was unchanged; the comparison does not claim that AAC reproduces the original PCM losslessly.

The existing `validate_media.py` spike checker rejected this CLI fixture because its prescribed diagnostic audio markers were absent. That checker was not treated as passing or used to infer a rendering defect. Independent checks established the CLI fixture's dimensions, codecs, track times, every video timestamp, decoded audio equality, and whole-frame edge coverage.

## Optimized Export Performance

Measurements used Apple M4 hardware with 16 GiB memory, macOS 27.0.1, Swift 6.4, Python 3.12.14, NumPy 2.3.5, Pillow 12.3.0, and FFmpeg 8.1.2. No hostname, device identifier, or personal path is recorded.

The final comparison alternated preserved baseline and adapted optimized executables in three isolated pairs. Each fresh process rendered the identical original 12-second, four-paragraph synthetic TTML/audio workload, overflowing header, default artwork background and auto-hide, runtime SF Symbols, and two rendering workers. Compilation and test rendering were not concurrent with these final measurements. `/usr/bin/time -l` supplied peak resident memory; the unchanged render report supplied export duration and effective encoded-frame throughput.

| Metric | Baseline Mean | Adapted Mean | Baseline Range | Adapted Range |
| --- | ---: | ---: | ---: | ---: |
| Export Duration (Seconds) | 27.375 | 32.831 | 26.997–27.861 | 32.248–33.268 |
| Effective Throughput (Frames per Second) | 26.306 | 21.935 | 25.843–26.670 | 21.643–22.327 |
| Peak Resident Memory (MiB) | 709.464 | 836.385 | 704.656–716.391 | 836.188–836.641 |

Sample standard deviations were 0.442/0.526 seconds for duration, 0.422/0.353 frames per second for throughput, and 6.148/0.232 MiB for peak memory, respectively. Mean duration increased 19.93%, throughput decreased 16.62%, and peak resident memory increased 17.89%. This is a measured performance regression associated with the selected adaptation. Output cadence remains 60 fps; export throughput is a separate quantity.

Three samples of one short synthetic workload do not establish sustained performance, long-duration memory behavior, or performance on other hardware and lyric structures. Increased raster area is a plausible contributor, not an isolated attribution of every additional cost. Direct rendering remains a possible later optimization requiring separate effect and quality validation.

## Build and Test Commands

The optimized all-product build passed with `swift build --disable-sandbox --build-system native -c release`. The full Swift command was `swift test --disable-sandbox --build-system native --disable-xctest`, with the previously successful process-local module-cache, framework, plugin, and runtime discovery settings documented in [More Button Measurements](more-button-measurements.md). All 148 tests in 29 suites passed in 177.128 seconds. Those Mac-local settings were kept out of source and CI configuration.

The relevant Python command was `python3 -m unittest discover -s Tests/reference_validation`, using the available Python 3.12 runtime. All 213 tests passed in 3.159 seconds. Native still comparisons, normal CLI video exports, FFprobe timestamp/track inspection, decoded PCM comparison, full-frame pixel checks, and `git diff --check` also passed their applicable checks.

Initial synthetic input attempts used a raw newline and excessive decimal precision, which the existing TTML importer correctly rejected. The private fixture was corrected to its established syntax. An initial wrapping fixture did not cross a row-count threshold, and an icon assertion incorrectly treated a bright-ink threshold as the full antialiased diameter; both test expectations were corrected without changing production geometry. No failed attempt supplies the retained benchmark measurements.

## Evidence Boundaries and Remaining Risks

No V01–V17, N01–N10, IMG_0334–IMG_0339, real audio recording, or private lyric file was accessed. Development, consumed held-out, and reserved classifications were unchanged. No independent visual qualification was performed. No known background, typography, backing-synchronization, or other native visual difference is claimed to be corrected by this adaptation.

Wider automatic wrapping and new spatial paths remain target-specific choices. Font and runtime symbol differences across hosts remain possible. The regression suite covers original synthetic structures rather than every permitted real input. Longer render workloads and cross-host performance remain unmeasured. The native layout remains available internally for regression and rollback through an additive change.

## History and Approval Status

Code and tests are committed as `c4285b382e942d9fc3edd116a2b1ab74b9a84417`, `feat(render): adapt video layout to full-width 9:16`, with the required Codex co-author trailer. The complete staged diff was reviewed for scope and private material; it contained only layout source changes and original synthetic tests.

This report is an uncommitted draft awaiting explicit maintainer approval. No other documentation was revised. The code commit has not been pushed. The final normal push and resulting Swift/Python CI verification remain pending approval and commitment of this report. The existing baseline [CI run 38379844655](https://github.com/x96x64/ilyrics/actions/runs/38379844655) passed both jobs at `3bf9357`; it is not CI evidence for the new commit. No tag, release, publication, force push, history rewrite, download, or deletion was performed.
