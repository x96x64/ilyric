# iLyric State-Controlled Inactive-Lyric Appearance

## Disposition

**Retain an opt-in Latin inactive-appearance reconstruction with qualifications.** A compact blur-and-contrast transition improves held-out native-to-native appearance diagnostics across V01–V03. The experimental full-screen path now offers cached isolated paragraph blur and deterministic interpolation. Existing commands retain the archived opacity-only scene. Production rendering, typography, motion, Japanese appearance, controls, background, and delivery transforms remain unchanged.

The reported stationary tail and interface changes are consistent with the authored benchmark schedule; no premature motion termination or unintended control disappearance was established. This gate does not validate native Music fidelity, native alpha, the exact blur kernel, or cross-script inactive behavior.

## Reference Environment and Integrity

The reference remains native Music on an iPhone 16 running reported iOS 27.0.1, build **Unknown**. Existing settings remain Default Display Zoom, Text Size 4/7 counting the smallest as 1/7, Bold Text off, Reduce Motion off, Reduce Transparency off, Increase Contrast off, Light appearance, and English system and Music languages.

Original V01–V03 hashes match the existing private inventory. Actual presentation timestamps match the archived frame lists. Fresh full-range Rec.709-to-sRGB extraction reproduces the archived native RGB crops byte-for-byte. The archived v10 outline result also matches its committed numerical record. Original media remain unchanged. No new physical captures were required.

Recordings retain their 1180×2556 native geometry, distinct from 1179×2556 screenshots. This experiment uses the established 1000×850 native crop and actual timestamps in units of 1/600 second. Sixty sampled frames per recording, approximately 50 ms apart, supply three middle-line windows: 180 regional observations per recording. Sampling does not imply a display-refresh measurement.

New [v12 evidence](reference-data/v12/appearance.json) records fitted diagnostics; historical profiles and reports are unchanged. [Reproduction commands](inactive-appearance-commands.md) separate public synthetic checks from private analysis.

## Benchmark Defect Investigation

The original six-second benchmark was retained unchanged. All 360 presentation states and decoded frames were inspected computationally. Focus events occur at seconds 0, 1, and 3. The final transition starts near scroll position 325, reaches 649.981139 at second 4, and reaches 649.999999999999 by the last frame against target 650. There is no scheduled focus event after second 3. The stationary tail is an intentional endpoint hold, not an incorrectly terminated animation.

Optional-control visibility changes occur exactly at frames **120, 240, and 300**: compact Sing appears, expanded Sing replaces it, and lower/optional controls disappear. Time labels change at integer media seconds. These abrupt authored changes remain useful boundary tests; no arbitrary extra animation was added to conceal them.

A fixed-coordinate audit of transport, bottom controls, handle, compact-control, and expanded-control regions covers every decoded frame. In the original video, regional mean differences above two encoded levels occur only at scheduled visibility boundaries. The largest unscheduled handle difference is 0.869 levels; transport is 0.344 and bottom controls 0.265. Compression produces small fluctuations. This bounded audit does not prove the absence of every subpixel artifact, but establishes no alternating visibility or unexpected one-frame removal in those regions. The new video passes the same audit.

The output also deliberately contains 50-ms white audiovisual marker flashes at 0, 1, 1.25, 3, 4, 5, and 5.25 seconds. These are diagnostic content separate from Music interface components. They explain additional brief visible flashes without establishing a rendering defect. Original opacity jumps at focus changes are an acknowledged synthetic appearance limitation; the opt-in Latin treatment smooths that state change.

## Measurement Method and Candidate Models

Geometry remains frozen. The principal diagnostic follows the archived common paragraph translation, rounded to a native pixel, without independent line or glyph registration. Three middle-line regions minimize the outer-line residuals documented in the Latin outline investigation. They remain measurement windows, not renderer-specific offsets or text units.

One sharp V01 template at PTS 2825/600 supplies corresponding glyph support. Local background is estimated from the upper and lower eight rows. The template uses positive contrast normalized by its 95th percentile; both per-column and whole-region normalization are tested. An eight-pixel interior inset tests support-window sensitivity. No OCR, new shaping, or geometry fitting is used.

The measured quantity is mean-channel **nonlinear sRGB contrast**, following explicit full-range Rec.709 interpretation. It is neither calibrated luminance nor measured alpha. Background variation, incomplete support, progressive brightness, rasterization, and remaining common-anchor error remain nuisance factors.

Four bounded hypotheses are compared:

1. Existing opacity-only ratio 0.38 with an immediate focus change, conditionally normalized to the fitted active contrast.
2. Opacity-only with independently fitted shared inactive and active contrast endpoints.
3. Shared bounded Gaussian blur plus contrast with an immediate focus change.
4. The same endpoints with cubic-smoothstep interpolation across an explicit focus event.

Blur candidates are 4, 6, 7, 8, and 10 native pixels. Duration candidates are 0.05, 0.10, 0.15, 0.25, 0.35, and 0.45 seconds. Endpoint gains use only observations earlier than −0.2 seconds or later than +0.5 seconds relative to archived fitted onset. The transition is selected from the training recordings; each excluded recording is evaluated without retuning. The inherited sharp V01 template is shared, so these are held-out **appearance parameters**, not fully independent glyph-template validation.

## Held-Out Results and Sensitivity

Errors are regional RMS differences on a 0–255 diagnostic scale, with equal weight per region and frame. They are not whole-screen similarity scores or final fidelity thresholds.

| Excluded Recording | Existing Ratio | Fitted Opacity Only | Blur and Contrast | Interpolated Blur and Contrast |
| --- | ---: | ---: | ---: | ---: |
| V01 | 11.973 | 11.308 | 10.523 | 9.518 |
| V02 | 9.643 | 9.027 | 7.943 | 7.058 |
| V03 | 9.694 | 9.425 | 8.403 | 7.863 |

All three primary exclusions select blur **8 pixels** and duration **0.15 seconds**. Interpolated training RMS is 6.985, 7.655, and 7.367 respectively. Held-out inactive-state RMS is 7.398, 5.782, and 6.507; transition-window RMS is 12.358, 9.307, and 9.660. Transition residuals remain larger than aggregate errors.

Fitted inactive contrast gains range from 0.223 to 0.233 and active gains from 0.521 to 0.586. Their ratios range approximately 0.391–0.432. The renderer uses **0.42** as a bounded relative appearance choice; those gains do not identify native compositing alpha. Individual regional exploratory blur optima ranged from roughly 5 to the tested upper limit of 10 pixels, exposing spatial support and background confounding rather than establishing per-glyph blur settings.

Whole-region normalization yields held-out interpolated RMS 9.065, 6.239, and 7.125. Interior support yields 10.246, 7.440, and 8.290. The interpolated model retains 8 pixels and 0.15 seconds in all nine normalization/window exclusions. A noninterpolated interior fit selects 10 pixels once, which weakens exact kernel interpretation. Shifting phase by ±1/60 second changes primary held-out interpolated RMS by less than 0.10 levels. These phase shifts are sensitivity tests, not verified native event times.

The diagnostic interpolates precomputed integer-blur losses, whereas rendering interpolates premultiplied cached masks. Pillow and Core Image Gaussian implementations are not asserted to be pixel-identical. The reported held-out errors therefore support the model family and bounded integration, not an end-to-end native Core Text compositing score.

## Experimental Integration and Determinism

`InactiveTreatment` evaluates immutable appearance values directly from rational output time and ordered explicit focus events. It interpolates blur from 8 to 0 and relative opacity from 0.42 to 1 over 0.15 seconds. Outgoing transitions use the symmetric treatment; interrupted transitions preserve value continuity by evaluating preceding event segments analytically. Those outgoing and interruption semantics are synthetic contracts, not new native measurements.

`ScreenRenderer` enables the treatment only through an explicit opt-in. It shapes paragraphs through the existing whole-paragraph path, then caches cropped Latin tiles at integer blur radii 0–8 using software Core Image. Forty-pixel padding bounds support. Fractional radii use additive interpolation inside an isolated transparency layer; source-over interpolation would incorrectly darken overlapping masks. No control or background pixels enter the blur. Viewport clipping and the existing fade apply afterward.

Latin static paragraphs are eligible; Japanese progressive masks, bounded vertical treatment, and opacity path remain unchanged. The cross-script visual difference is deliberate evidence scoping. No per-frame text shaping, blur-kernel creation, font-size change, paragraph-origin change, motion adjustment, new GPU readback, or production export modification is introduced. The separate 0.081-second critical-response motion parameter remains unchanged.

Raw images match under repeated, reversed, and fresh-renderer evaluation on the recorded environment. Separate-process PNGs are byte-identical. Pixel tests preserve every region outside the lyric viewport, the active Latin crop before transition, all paragraph layout metrics, and the original Japanese paragraph renderer. Twenty archived private Japanese phase renderings remain byte-identical; private Latin integration retains its prior result.

## Visual Inspection and Export

Native stills, ten color-interpreted decoded frames spanning focus and visibility boundaries, and nine private source/reconstruction/difference panels were inspected. Normal-speed playback was started in QuickTime Player and its final state verified. This is sampled visual inspection with a playback-completion check, not a continuous human fidelity assessment.

Inactive Latin text is less prominent and softens before leaving focus. No new control-layer blur, obvious tile-edge halo, or unexpected disappearance was observed in the inspected frames. Japanese inactive text remains comparatively sharp. Private panels retain structured outline and contrast differences, especially during transition and in partially supported regions; some reconstruction patches remain too diffuse. Static materials, provisional viewport fading, simplified controls, and the intentionally sparse fixture remain visible limitations.

The new output is 1080×1920 H.264, 60/1 fps, 360 frames, six seconds, limited-range Rec.709 matrix/transfer/primaries with video time base 1/600, and mono 48-kHz AAC beginning at zero. Every video presentation timestamp passes validation. All seven audio markers have zero error at millisecond resolution; expected visual marker frames pass. Audio trimming yields 288,000 samples, with established priming and padding handled separately.

| Optimized Workload | Export Time | Effective FPS | Raster Time | Peak RSS |
| --- | ---: | ---: | ---: | ---: |
| Opt-in inactive appearance | 16.363 s | 22.001 | 16.204 s | 404.84 MiB |
| Unchanged baseline, contemporaneous | 16.796 s | 21.433 | 16.603 s | 342.50 MiB |
| Archived full-screen baseline | 16.465 s | 21.864 | 16.301 s | 343.08 MiB |

Environment: Apple M4, macOS 27.0.1, Swift 6.4, macOS SDK 27, FFmpeg 8.1.2, Python 3.12.14, NumPy 2.3.5, Pillow 12.3.0. Single-run variation prevents a speedup claim. Caching adds approximately 62.34 MiB peak RSS against the contemporaneous baseline. Raster work remains dominant; native canvases, transparency layers, Japanese masks, and cached tiles remain the main evident costs. This does not justify Metal or a backend redesign.

## Verification, Privacy, and Next Gate

The complete public suites pass: 31 Swift tests and 65 Python tests, plus release builds and existing probe, typography, outline, slice, appearance, Latin, motion, and screen checks. New tests cover state boundaries, interruption continuity, synthetic fitting, all 360 visibility states, isolation, unchanged layout, random access, and missing private inputs. Original architecture-spike and composition audiovisual regressions remain intact. Initial Swift test compilation failed on unparenthesized range expressions; correcting test syntax resolved it. No failed run supplies retained evidence.

A fresh public clone at implementation commit `c136d32` builds and passes all 31 Swift and 65 Python tests without `reference-private/`. It passes all existing deterministic probes, renders original Latin/Japanese fixtures, and exports the original composition, full-screen baseline, and opt-in inactive scene. All thirteen private commands return explicit unavailable states. The clone remains clean apart from ignored generated output.

Private sources, transcriptions, hashes, raw crops, masks, and diagnostics remain ignored. Public evidence contains only neutral identifiers, numerical measurements, and explicit qualifications. Deferred requirements are recorded in [product requirements](product-requirements.md); no provider, parser, final schema, SF Symbols renderer, generalized customization, or transition library is implemented.

**Go for retaining the bounded Latin treatment as an experimental option.** The next narrow gate should establish preliminary local user-input integration with supplied line-level timing and explicit observed breaks, using an original fixture and no automated retrieval. Remaining inactive-kernel, progressive-contrast, and Japanese inactive uncertainty must remain visible qualifications. Dynamic materials, symbol licensing and control refinement, external synchronization acquisition, detailed configuration, and generalized transitions remain separate deferred milestones. No additional capture is presently required.
