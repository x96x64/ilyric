# iLyric First Measured Full-Screen Lyrics Composition

## Disposition

**Retain the separate experimental full-screen scene with qualifications.** The existing Latin/Japanese lyric layout, Japanese appearance, analytic focus motion, and AVFoundation writer now compose with measured interface positions at native reference resolution. Arbitrary rational-time evaluation, public synthetic rendering, and audiovisual export pass their regression checks. No architectural obstacle or requirement for Metal was found.

The result is a measured placement experiment with provisional visual treatments. It does **not** establish native Music fidelity, calibrated interface typography, native materials, inactive blur, or native control semantics. The next bounded gate should characterize inactive-lyric appearance using existing references while freezing geometry and motion.

## Evidence and Provenance

The canonical empirical reference remains native Music on a reported iPhone 16 running iOS 27.0.1, build **Unknown**. Recorded settings remain Default Display Zoom; Text Size 4/7 counting the smallest as 1/7; Bold Text, Reduce Motion, Reduce Transparency, and Increase Contrast off; Light appearance; English system and Music languages. These are reported device conditions, not externally inferred build metadata.

Geometry comes from the [physical-reference report](physical-reference-validation.md) and v1 profile. Typography, appearance, and motion retain the qualifications in the later archived reports, including the [Latin outline diagnostic](latin-outline-motion.md). All historical reports and v1–v10 records remain unchanged. New [v11 profile](reference-data/v11/profile.json), [geometry comparisons](reference-data/v11/geometry.json), and [export measurements](reference-data/v11/export.json) distinguish inherited measurements, fitted reconstruction parameters, calculated transforms, and provisional treatments.

Private comparisons inspect S02, S03, S04, S05, S07, and S09. Original 1179×2556 PNGs with embedded profiles were read without modification and converted from Display P3 to sRGB for local comparison. S02–S05 hashes matched the existing private inventory. A gate-specific inventory establishes and rechecks S07/S09 integrity; it does not claim retrospective verification against an earlier unavailable hash. All six source hashes match before and after processing. Source filenames, hashes, transcriptions, images, and overlays remain private.

## Scene and Clock Architecture

`LyricsScreen` contains an immutable lyric composition, synthetic metadata, explicit media duration and volume, and ordered interface-visibility events. Its snapshot contains the existing lyric snapshot, progress, elapsed/remaining seconds, playback state, and a small fixed list of typed components. Each component records bounds, visibility, z-order, clipping, and evidence status. This is neither a general UI framework nor a finalized public schema.

`ScreenRenderer` caches the existing whole-paragraph layouts, original artwork, a static palette gradient, header Core Text lines, and a one-column fade mask. It draws the background, lyrics, header and playback components, then optional controls. Every component is clipped to its explicit bounds. Optional Sing controls sit above the lyric layer. Shapes are independently drawn; no extracted icons, commercial artwork, font files, or private frameworks are included.

Output time schedules frames and interface visibility. The existing explicit playback-anchor mapping supplies media time for lyric appearance, synthetic tone phase, progress, and elapsed/remaining labels. Running state comes from the selected playback anchor. Focus events remain separate interface events. Tests cover a media pause without freezing the independently supplied focus sequence. No native pause or seek semantics are inferred.

Visibility events are ordered by rational timestamp and unique order; the last event at a shared timestamp applies. Intervals are half-open. Every frame is independently evaluated; there is no wall clock, previous-frame state, SwiftUI presentation state, or simulation loop. The unvalidated Latin relative-line diagnostic is not integrated. The inherited 0.081-second critical-response parameter remains a qualified iLyric reconstruction choice.

## Native Geometry and Component Findings

All coordinates use native pixels with a top-left origin. Component bounds below are half-open, not hit targets or inferred safe areas.

| Component | Scene Geometry | Evidence and Qualification |
| --- | --- | --- |
| Artwork | `[96,276,312,492)` | Inherited manual measurement, approximately ±2 px; original geometric image |
| Title / artist ink origin | `(352,338)` / `(352,398)` | Inside archived observed ranges; header sizes 51/49 are provisional |
| Dismissal handle | `[500,198,680,210)` | Inherited measurement, approximately ±1 px |
| Progress | `[96,1683,1083,1704)` | Inherited measurement, approximately ±1 px; explicit media progress |
| Transport centers | `(271,1947)`, `(590,1947)`, `(909,1947)` | Approximate observed centers; original, smaller placeholder shapes |
| Volume | `[171,2192,982,2214)` | Inherited measurement, approximately ±1 px; explicit level |
| Bottom-control centers | `(248,2359)`, `(590,2359)`, `(932,2359)` | Approximate observed centers; provisional bounds and symbols |
| Translation / compact Sing centers | `(153,1530)` / `(1026,1530)` | Approximate observed locations; explicit visibility inputs |
| Expanded Sing | `[969,1353,1083,1587)` | Inherited manual measurement, approximately ±3 px; affordance only |
| Lyrics viewport | `[72,550,1112,1500)` | Provisional clipping rectangle; exact native boundary remains unknown |

Layout comparisons have zero edge error against the five inherited rectangular constraints. This verifies implementation of archived inputs; it is not an independent new physical fit. The synthetic raster separately recovers exact handle, progress, and volume bounds with local contrast extraction. Its title and artist ink begin at `(352,338)` and `(352,398)`; their content-dependent raster bounds are `[352,338,623,385)` and `[352,398,581,434)`.

Private overlays use the same coordinates in every screenshot without a fitted global transform. They confirm the broad placement relationships and the expanded-control location in S07. At the primary contrast threshold, S03/S05/S09 progress support reproduces the archived bounds; S05/S09 volume support does likewise. Other slider extractions reach the padded measurement window because background gradients and nearby support contaminate the simple mask. They are explicitly marked unreliable. S02 lower controls are absent in the inspected state, so its incidental contrast is not treated as a slider measurement. No threshold-dependent result silently replaces historical geometry.

Time-label bounds, metadata clipping width, artwork corner radius, slider opacity, control silhouette, symbol size, and control materials remain provisional. The header uses legitimate public system-font APIs independently of lyric font selection. Locally resolved fonts are not identified as native Music fonts. A matching ink origin does not validate header typography.

## Lyrics, Fades, and Visual State

The scene reuses all three original paragraphs from the motion-composition fixture. Whole-paragraph shaping, source ranges, line-break classifications, Latin size 104.25, Japanese size 103.25, Japanese bounded vertical treatment, and softened appearance remain unchanged. Automatic and supplied breaks retain their existing distinctions and unresolved source semantics.

The common composition anchor remains 791.25 pixels. Its inherited two-pixel translation of the Japanese base paragraph is a synthetic composition placement, not a revision to the measured local Japanese origin. Focus changes remain at output seconds 1 and 3, with synthetic paragraph positions 0, 325, and 650. The English-derived movement applied to Japanese remains an explicit synthetic integration assumption.

The new viewport applies a deterministic 80-pixel cubic-smoothstep alpha fade at its upper and lower edges. Native screenshots show fading and blurred inactive support, but do not identify the exact clip or fade function. Both the rectangle and fade are therefore **provisional**. The fully opaque interior preserves the old composition's transparent lyric raster byte-for-byte. No line reflow, font-size adjustment, or additional lyric movement is introduced.

Inactive paragraphs retain the previous opacity-only treatment and lack native-like blur. This discrepancy is conspicuous in private overlays and synthetic stills. The soft edge removes the earlier abrupt hard cut but does not solve inactive appearance or establish native fade fidelity.

The six-second fixture uses original artwork, the synthetic title and artist, a supplied 180-second track duration, and volume 0.62. Media progress advances from zero to six seconds. Translation is visible initially; compact Sing appears at two seconds, expanded Sing at four seconds, and lower/optional controls are hidden at five seconds. These are authored test events, not inferred Music interaction rules. Sing visibility does not alter vocals, lyric timing, or appearance behavior.

## Background, Chrome, and Delivery

A cached original gradient shares colors with the generated geometric artwork. It is static and does not reconstruct the temporal native background variation already observed in the corpus. No native blur kernel, material transfer function, phase rule, or compositing equation is claimed. Animated materials remain a separate workload and evidence question; this experiment does not justify Metal.

System status information, Dynamic Island occlusion, home indicators, and safe areas are not fabricated. The screen intentionally omits system chrome and unmeasured ancillary badges or menu behavior. Application content retains native positions despite those omissions.

The screenshot canvas remains 1179×2556; the composition input retains the distinct 1180-pixel recording canvas without rescaling text. The origin of the extra recording column remains unknown. The public fixture uses screenshot width. No provisional UIKit point canvas is substituted.

Delivery uses uniform `contain` into 1080×1920: scale **0.751173709**, horizontal margins **97.1831 pixels**, and no vertical crop. The entire native layout remains visible. A recording-width canvas has a correspondingly different horizontal margin. No nonuniform stretch, silent reflow, `cover` crop, or `adapt` layout is introduced. The small existing audiovisual diagnostic flash remains separate from native screen content.

## Export Validation and Performance

`LyricsScreenProbe` is a separate experimental target with native still, delivery still, and six-second video invocations. Production `ilyric`, the previous slice/composition commands, and the AVFoundation export backend are unchanged. The writer continues to schedule 360 frames at exact `n/60`, with 800 synthetic 48-kHz PCM samples per frame and the established diagnostic clicks.

Decoded output is **1080×1920 H.264, 60/1 fps, 360 frames, six seconds, Rec.709**, with mono 48-kHz AAC starting at zero and lasting six seconds. Every video timestamp passes the existing tolerance. All seven audio markers have zero error at the validator's millisecond resolution; all expected visual flashes pass. Endpoint trimming yields 288,000 audio samples, with the existing 2,112 priming samples and 704 trailing decoded padding samples handled separately. Encoded-file byte identity is not required.

Measurements use an optimized build on Apple M4, macOS 27.0.1, Swift 6.4, and macOS SDK 27. FFmpeg is 8.1.2. These are isolated single-process runs, not a throughput distribution or sustained memory-growth study.

| Workload | Frames | Export Time | Effective FPS | Raster Time | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: |
| New full-screen scene | 360 | 16.465 s | 21.864 | 16.301 s | 343.08 MiB |
| Previous composition, contemporaneous run | 360 | 14.363 s | 25.065 | 14.210 s | 327.38 MiB |
| Previous composition, archived run | 360 | 14.231 s | 25.298 | 14.065 s | Not measured |

The new workload adds approximately **14.6% export time** relative to the contemporaneous composition. Process wall time is 16.48 seconds. Writer append time is 0.0123 seconds and finalization 0.0032 seconds. Producer wait counters overlap and must not be summed into wall time.

Raster work dominates. Existing per-frame native paragraph canvases and Japanese mask buffers remain allocations; the screen adds a lyric layer, full native composition, fade clipping, and cached-background drawing. Artwork, header layout, gradient, and fade are initialized once. Short time labels are typeset each frame and could be cached if profiling warrants it. No application-level GPU readback or new synchronization path is introduced. The measured cost does not justify a backend redesign; animated materials and longer-duration memory behavior remain untested.

## Tests, Inspection, and Limitations

All **28 Swift tests** and **61 Python tests** pass, together with release builds and every existing deterministic probe. New checks cover component bounds, visibility boundaries, event ordering, separate clocks, clipping, fades, z-order metadata, native-to-output transforms, raw equality under reordered timestamps and fresh renderers, label ink, and unavailable private inputs. Separate-process native PNGs are byte-identical for repeated synthetic requests on the recorded environment.

Latin private integration reproduces the archived v8 results exactly. Twenty Japanese private phase renderings reproduce appearance PNGs, coverage PNGs, and state/layout JSON byte-for-byte. Full-screen cached paragraph metrics and raster data match standalone paragraph rendering. The fully opaque lyric viewport interior matches the previous composition raster exactly. The 0.081-second motion and immutable snapshots are inherited without parameter changes.

The original four-second architecture-spike video and previous six-second composition export both pass dimensions, cadence, duration, color, audio, timestamp, and marker regression checks. No production export behavior was changed.

A fresh public checkout at the implementation commit passes release builds, all public tests, deterministic probes, original Latin/Japanese stills, the old composition video, and the full-screen native still/video without `reference-private/`. All twelve private commands return explicit unavailable states. The checkout remains clean apart from ignored outputs.

Native stills, private placement overlays, and six decoded video frames spanning both focus transitions and optional-control changes were visually inspected. They show readable fixed wrapping, actual upward movement, preserved aspect ratio, and correct scene layering in the inspected states. Obvious residuals include missing inactive blur, abrupt focus-opacity changes, provisional fade boundaries, static background, smaller placeholder transport symbols, simplified Sing geometry, and omitted system/ancillary content. This is not a full-speed human fidelity assessment.

Initial visual inspection found missing secondary labels because Core Text image bounds inherited a previous text position. Resetting the text position before measuring bounds corrected the new path; a raster test now guards the labels. The installed Swift Testing macro rejected a key-path predicate, which was replaced with an equivalent closure. A private title-mask window initially included nearby artist ink; separating the measurement window corrected that diagnostic. No failed run supplies the retained benchmark or geometry record.

## Privacy and Next Gate

Private originals, transcriptions, captures, hashes, crops, masks, overlays, and detailed diagnostics remain ignored. Public data contains neutral identifiers, numerical geometry, fitted/provisional classifications, and sanitized export measurements. Commits preserve human identities and the verified attribution convention. Historical reports, profiles, and backup references are unchanged; no release or tag is created.

**Go for retaining the full-screen experimental scene.** The smallest justified next gate is state-controlled inactive-lyric appearance: use existing repeated recordings to characterize blur and contrast around focus changes while freezing shaping, anchors, motion, and component placement. Test a bounded appearance model with held-out repetitions before integration. Measured dynamic materials, control refinement, and preliminary external-input handling remain subsequent work. Native Music fidelity and a complete usable public renderer are not yet established.
