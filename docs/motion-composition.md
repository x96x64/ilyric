# iLyric First Measured Lyrics Motion and Composition Slice

## Disposition

**Retain the experimental integration with qualifications.** A three-paragraph Latin/Japanese sequence now supports independent rational-time evaluation, two focus transitions, existing Japanese progressive appearance, explicit clipping, and a six-second audiovisual export. The experiment demonstrates composition and export integration; it does not establish native Music motion or full-screen fidelity.

A finer critically damped reconstruction improves average held-out error over the archived coarse candidate. Residual peaks remain approximately nine to ten native pixels, and paragraph-anchor measurements remain appearance-dependent. The next corrective experiment should track corresponding Latin glyph outlines at native resolution through the existing transition before promoting its motion or line-spacing semantics.

## Reference Environment and Provenance

The empirical reference remains reported iPhone 16 running iOS 27.0.1, exact build **Unknown**. Reported settings remain Default Display Zoom; Text Size 4/7 counting the smallest selectable size as 1/7; Bold Text, Reduce Motion, Reduce Transparency, and Increase Contrast off; Light appearance; and English system and Music languages. No external build information was substituted.

V01–V03 retain their established mapping to the comparable English passage. Originals were decoded without modification. Their previous inventory did not include SHA-256 values, so this gate established a private integrity inventory and checked it again after processing. Original decoded PTS match the archived frame lists, all 540 tracked observations reproduce within the public CSV's rounding, and archived coarse-model parameters and residuals reproduce exactly. This is not retrospective verification against an unavailable historical source hash.

All three recordings contain 1180×2556 HEVC with full-range Rec.709 declarations and a 1/600-second time base. Decoded counts are 1807, 1796, and 1777. Adjacent intervals comprise respectively 1775/31, 1767/28, and 1749/27 ten-/nine-tick intervals. Capture cadence does not establish display refresh behavior. No nominal-frame-index timing replaces original PTS.

The earlier static Latin experiment was also reproduced: all four historical comparisons and the version-8 common-origin integration results are unchanged. The fitted size remains 104.25 pixels under supplied observed boundaries, with held-out width RMSE 0.816–1.732 pixels and baseline-proxy RMSE 1.735–2.935 pixels. S04/S05 source-break ambiguities remain unresolved.

The new [version-9 profile](reference-data/v9/profile.json), [motion results](reference-data/v9/motion.json), [observations](reference-data/v9/observations.csv), and [export checks](reference-data/v9/export-validation.json) are additive numerical evidence. Historical reports, reference profiles, and commits remain unchanged. Source media, mappings, hashes, transcriptions, and source-bearing diagnostics remain ignored and private.

## Anchors and Motion Measurements

The reproduced protocol follows the same first-line horizontal-edge centroid over capture times 2–5 seconds, with 180 observations per recording. The native region is reduced fourfold before measurement. The centroid is an image-support proxy, not a baseline. Its absolute y coordinate must not be substituted for the fitted Latin first baseline near 791 pixels.

A leading-glyph region differs from the complete-line trajectory by a nearly constant offset. After subtracting that offset, RMS differences are 0.828, 1.036, and 1.045 pixels; maxima are 1.649, 1.631, and 1.806 pixels. Tracking-window radius sensitivity reaches 3.705–3.814 pixels. These observations corroborate the broad movement but do not explain all fitted residual peaks.

A second tracked line supplies a paragraph-rigidity diagnostic. Its mean centroid separation from the first line changes from approximately 119.56–119.65 pixels before movement to 126.59–127.46 pixels afterward. Across the complete window, separation spans approximately 119.37–128.17 pixels. Source contact sheets confirm the same paragraph and the progression from blurred/dim to sharper support.

Different glyph shapes, blur, contrast, and the fourfold reduction affect these two centroids differently. The separation is therefore **not measured native line advance**, and the change does not establish native scaling or baseline animation. Neither a varying line advance nor a font-size correction was introduced. The approximately 325-pixel first-line displacement also does not establish universal paragraph spacing.

## Candidate Selection and Held-Out Evidence

Three compact analytic response families were tested: cubic Hermite smoothstep, quintic smoothstep, and the existing critical-response form. Even observations select parameters; odd observations test interpolation. Training fits determine onset, scale, offset, and displacement. Cross-recording tests retain those parameters and register only the independently observed half-displacement crossing. This is conditional shape transfer, not independent onset prediction from lyrics or audio.

The finer critical search uses time constants 0.065–0.095 seconds in 0.001-second steps, with a 0.001-second onset grid around the observed crossing. Hermite durations span 0.370–0.470 seconds; quintic durations span 0.450–0.600 seconds, both in 0.002-second steps. Search precision is not physical timing precision.

| Candidate | Selected Scale Across Recordings | Cross-Recording RMSE | Cross-Recording Maximum Error |
| --- | --- | ---: | ---: |
| Cubic Hermite | 0.422 s | 4.061–4.136 px | 16.416–16.991 px |
| Quintic smoothstep | 0.510–0.512 s | 3.918–3.994 px | 14.928–15.296 px |
| Critical response | 0.081 s | **2.218–2.253 px** | **8.939–9.816 px** |

Each recording selects the same critical time constant. Fitted displacement ranges from −324.587 to −324.936 pixels; starting centroids range from 1084.119 to 1084.337 pixels. The candidate is not evidence of Apple's spring constants or implementation.

| Training → Held Out | Critical RMSE | Maximum Error |
| --- | ---: | ---: |
| V01 → V02 | 2.223 px | 8.981 px |
| V01 → V03 | 2.253 px | 9.651 px |
| V02 → V01 | 2.243 px | 9.332 px |
| V02 → V03 | 2.247 px | 9.816 px |
| V03 → V01 | 2.242 px | 9.127 px |
| V03 → V02 | 2.218 px | 8.939 px |

The archived V01-trained critical candidate gave RMS 2.456/2.463 pixels on V02/V03. The finer candidate reduces those averages, but its V03 maximum increases from 9.390 to 9.651 pixels. It is not uniformly better. Within-recording odd-observation RMS is 2.186–2.257 pixels.

Perturbing the cross-recording phase by ±1/60 second raises RMS to approximately 5.70–5.95 pixels and maxima to approximately 25.83–27.00 pixels. The finer result consequently depends on observed phase registration. Native input-event timing, media-clock correspondence, interruption behavior, and a final fidelity tolerance remain unestablished. No extra curve parameters were added to conceal the remaining peaks.

## Composition and Clock Model

`LyricsComposition` contains an ordered list of immutable paragraph inputs, vertical positions, media intervals, explicit interface-time focus events, and optional playback anchors. Each paragraph reuses the established `SliceInput` and whole-paragraph Core Text layout. There is no finalized public project schema, parser, device framework, or general scene graph.

Focus events are ordered by rational timestamp and unique integer order; the last event at a shared timestamp determines focus. Intervals are half-open. Compiled analytic segments store initial position, initial velocity, target, onset, and time constant. Evaluation uses:

```text
x(t) = target + (a + b × elapsed) × exp(−elapsed / tau)
a = initialPosition − target
b = initialVelocity + a / tau
```

Velocity is evaluated analytically. At interruption, the previous segment's position and velocity initialize the next segment. This preserves continuity without previous-frame state. Interruption continuity is a synthetic internal contract, not measured native interaction behavior. The unbroken response approaches its target asymptotically.

Output time schedules video and audio. Interface focus events use output time. Media time is an explicit piecewise mapping from output anchors with rates zero or one; media time drives paragraph appearance and synthetic tone phase. Pause and seek tests exercise this mapping while leaving interface events explicit. The exported fixture uses identity mapping. It does not demonstrate native pause/seek semantics or a generalized audio-edit engine.

Paragraph translation equals the composition anchor minus its local baseline, plus paragraph position minus evaluated scroll. Positive scroll therefore moves text upward. Media-interval membership is retained as an explicit active-state flag; interface focus determines the fixture’s opacity and scroll, so a synthetic seek does not silently invent a focus event.

The synthetic fixture contains three original paragraphs: two-line Latin, two-line Japanese, and a four-line automatically wrapped Latin paragraph. Focus changes at output seconds 1 and 3; paragraph positions are 0, 325, and 650 native pixels. Those spacings reuse the order of magnitude of the inspected displacement but are **synthetic composition inputs**, not a universal native rule. Paragraph media intervals are 0–1, 1–3, and 3–6 seconds.

A common composition first-baseline anchor of 791.25 pixels positions the focused paragraph. Local typography remains unchanged: the Japanese base baseline is 789.25, so its composition placement includes an explicit two-pixel translation. This does not revise the measured Japanese origin or assert a shared native anchor. The Latin rounded synthetic origin and advance remain those of the previous gate.

Focused opacity is one; unfocused opacity is 0.38. Focus-opacity changes are discrete and synthetic. Latin appearance remains static within each paragraph. Japanese glyph appearance and bounded vertical treatment reuse the existing independent event primitives; their public timing remains independently authored. The English-fitted scroll response is also applied to the Japanese paragraph only as a synthetic composition behavior, not validated Japanese focus motion.

## Layout, Clipping, and Delivery

`CompositionRenderer` caches one `SliceParagraph` per input, preserving whole-paragraph shaping, source ranges, line boundaries, fallback, cluster mapping, and measured local geometry. Animation translates already-rendered support. It does not shape words or characters independently, change wrapping during movement, or modify the underlying advances.

Native-coordinate rendering supports consistent 1179- or 1180-pixel paragraph canvases, always 2556 pixels high. The public fixture uses the 1179-pixel screenshot canvas. The extra recording column remains explicit and its origin remains unknown. No provisional UIKit canvas or safe-area geometry is substituted.

The ordered paragraphs share a hard clip at `(72,550)` with width 1040 and height 1000. This rectangle, flat background, and z-order are explicit synthetic composition choices. Native fade boundaries and inactive blur remain unmeasured. Off-viewport glyphs are clipped without reflow.

Delivery uses uniform `contain` into 1080×1920: scale 0.751173709 and horizontal padding 97.1831 pixels for the 1179-pixel canvas. No stretching, silent cropping, or edge-to-edge adaptation occurs. The existing `contain`, `cover`, and `adapt` policies are unchanged. A separate output-space flash uses the existing synthetic synchronization convention and is not Music UI.

## Export Integration and Performance

A small shared `Exporter.video` overload accepts deterministic drawing and PCM callbacks. The previous renderer-specific entry point wraps this overload with its original four-second timeline and audio behavior. H.264/AAC settings, buffer pooling, explicit timestamps, backpressure, endpoint trimming, and atomic publication remain unchanged. This adapter avoids duplicating the AVFoundation writer. `ilyric` command behavior and production scene code remain unchanged.

The new fixture uses synthetic media-clock tones and output-clock synchronization clicks. It exports 360 frames at exact `n/60` timestamps over six seconds. The qualified run took **14.231 seconds**, or **25.298 effective fps**, on Apple M4/macOS 27.0.1 in a release build. Raster work accounted for 14.065 seconds. Wait metrics overlap between the independent audio/video producers and must not be added to wall time.

The compositor currently allocates full native paragraph canvases and temporary Japanese appearance masks per frame. Cached shaping avoids repeated typesetting, but CPU rasterization and copying dominate this bounded run. No GPU readback or new Metal path was introduced. This is a machine-specific short-run observation, not a sustained throughput or memory-growth guarantee; peak memory was not measured in this gate.

## Verification and Visual Inspection

The complete public suites passed **24 Swift tests** and **53 Python tests**, together with release builds and existing probe, typography, outline, slice, appearance, and Latin checks. New tests cover focus selection, simultaneous event ordering, half-open boundaries, analytic response, interrupted continuity, independent media clocks, invalid events, paragraph ordering, clipping, scheduling, and raw raster equality under reordered requests and fresh renderer instances. A public fitting/probe check verifies held-out synthetic response recovery and Swift/Python analytic agreement.

Private Latin calibration and common-origin integration reproduced the version-8 results exactly. All 20 archived V09/V10 Japanese phase comparisons reproduced appearance images, coverage images, and state JSON byte-for-byte. Composition tests additionally compare each cached paragraph's metrics and native raster to the standalone renderer. These preserve local geometry and appearance; synthetic global paragraph placement is a separate operation.

The new video decodes as 1080×1920 H.264, 60/1 fps, 360 frames, six seconds, and Rec.709. Audio is six seconds of 48 kHz mono AAC beginning at zero. All decoded video timestamps passed. The seven synchronization clicks were detected at their expected positions at one-millisecond analysis resolution; all flash-frame intervals passed. Decoder output contains 704 trailing padding samples, while endpoint trimming yields exactly 288,000 samples; the existing priming/trimming convention is preserved.

The architecture-spike regression also passed: 240 frames, four seconds, 1080×1920, 60 fps, correct color/audio metadata, all presentation timestamps, and audiovisual markers. Representative composition frames 65 and 240 passed the existing synthetic codec checks, with text-region mean absolute differences approximately 2.068 and 2.026 code values. These codec comparisons are not native-reference fidelity scores.

Source contact sheets, original synthetic stills, and decoded video frames before, during, and after both transitions were visually inspected. They show actual upward lyric movement, fixed wrapping, distinguishable focus, and Japanese appearance progression. Hard clipping cuts through boundary glyphs, focus opacity switches abruptly, and the background remains flat. These intentional simplifications are visible and are not presented as a complete Music composition. No full-speed human viewing assessment or native side-by-side video fidelity claim is made.

A fresh public checkout at implementation commit `8825a85`, without private references, passed release builds, all 24 Swift and 53 Python tests, every deterministic probe, the original Japanese/Latin synthetic stills, and the new composition export with decoded audiovisual validation. All ten reference-dependent commands returned explicit `unavailable` states. Its working tree remained clean apart from ignored generated files. Subsequent changes contain documentation and sanitized evidence only. Reproduction commands are in [Motion and Composition Commands](motion-composition-commands.md). Verification uses the established Swift 6.4/macOS SDK 27, Python 3.12.14, NumPy 2.3.5, Pillow 12.3.0, and FFmpeg 8.1.2 environment. Existing nonfatal linker search-path warnings remain. The precommit whitespace check rejected CSV CRLF endings; conversion to LF changed no measurements, and the audit was repeated. No failed experiment supplies retained measurements.

## Privacy and Remaining Work

Ignore checks precede private processing. Originals and detailed diagnostics stay under `reference-private/`; public records contain neutral identifiers and numerical data only. Staged files are reviewed for protected content, credentials, and personal paths before each commit. No media, proprietary font, source lyric text, or extracted Apple asset is published. Original human Git identity, attribution convention, historical records, and backup references are preserved.

The integration is usable as a narrow developer video experiment. Native motion onset, relative line behavior during activation, inactive blur, clipping/fades, generalized paragraph spacing, Latin progressive timing, materials, and source-break semantics remain unresolved.

## Next Engineering Gate

**Go for retaining the deterministic composition and export path; no-go for a native motion-fidelity claim.** The smallest corrective experiment is native-resolution, common-origin outline tracking of the same Latin paragraph across the existing V01–V03 transition. Hold out repetitions and compare corresponding glyph support to determine whether the approximately nine-pixel residual peaks reflect rigid motion mismatch, state-dependent geometry, or extraction bias. This requires no new capture initially. Progressive Latin appearance, dynamic materials, full-screen composition, and preliminary external-input integration should not be used to conceal that unresolved measurement question.
