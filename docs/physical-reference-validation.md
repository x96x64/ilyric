# iLyric Physical-Reference Validation

## Disposition

The Swift, Core Text, Core Graphics/Core Image, and AVFoundation architecture is **retained with qualifications**. Physical references expose substantial differences from the deliberately synthetic spike: capture geometry, type size and weight, wrapping, alignment, focus timing, and background variation. They do not demonstrate an architectural obstacle to deterministic reconstruction. No production renderer, timeline, export backend, or existing spike test was changed. Metal is not justified by these measurements.

This gate establishes an initial measured reference and reproducible diagnostics. It does **not** establish native Music fidelity. The next narrow gate is typography calibration in native reference coordinates, using the existing private screenshots before introducing measured motion or materials into a scene.

The planning study and architecture-spike report remain unchanged historical records. Their provisional 402×874 canvas and synthetic constants are not physical measurements.

## Reference Environment and Provenance

The reported device is **iPhone 16, iOS 27.0.1**. The exact device build is **Unknown**. No external build lookup was substituted for device evidence.

| Setting | Reported Value |
| --- | --- |
| Display Zoom | Default |
| Text Size | 4/7, counting the smallest selectable size as 1/7 |
| Bold Text | Off |
| Reduce Motion | Off |
| Reduce Transparency | Off |
| Increase Contrast | Off |
| Appearance | Light |
| System Language | English |
| Music Language | English |

Ten original screenshots, identified locally as S01–S10, and four original recordings, V01–V04, were inspected. IDs follow filename sorting within the supplied screenshot and recording directories. The filename mapping and supplied reference notes remain private. The reported settings were not independently verified in a Settings capture.

All originals, transcribed reference text, extracted frames, masks, contact sheets, diagnostic images, and intermediate arrays remain under ignored `reference-private/`. Git ignore checks cover both inputs and diagnostic outputs; no reference file is tracked. The public data contains numerical observations, fitted parameters, sanitized stream metadata, and locally resolved font names. It contains no commercial lyrics, artwork, audio, source images, font files, private paths, or extracted Apple assets.

The [internal profile](reference-data/v1/profile.json) is version 1 of a validation representation, not a finalized iLyric project schema. Each profile value records an evidence status; relevant values also include units, source IDs, method, and uncertainty. `reported`, `measured`, `fitted`, `inferred`, `engineering_inference`, `calculated`, `provisional`, `definition`, and `unknown` are intentionally distinct. [Numerical results](reference-data/v1/results.json) accompany [540 measured trajectory observations](reference-data/v1/trajectories.csv). Measurements are preserved separately from model parameters.

## Verified Capture Properties

All screenshots are **1179×2556 RGB PNGs with a Display P3 ICC profile**. All recordings use an MP4-family container and **1180×2556 HEVC Main**, decoded as `yuvj420p`, with full-range (`pc`) Rec.709 matrix, transfer, and primaries metadata. These are declarations in the files, not a calibration of the device display. Audio is **AAC LC, stereo, 44,100 Hz**. Both streams begin at timestamp zero.

| Source | Video Duration (s) | Audio Duration (s) | Container Video Samples | Decoded Frames | 9-Tick / 10-Tick Intervals |
| --- | ---: | ---: | ---: | ---: | ---: |
| V01 | 30.065000 | 30.065669 | 1808 | 1807 | 31 / 1775 |
| V02 | 29.886667 | 29.887392 | 1797 | 1796 | 28 / 1767 |
| V03 | 29.571667 | 29.566259 | 1778 | 1777 | 27 / 1749 |
| V04 | 19.536667 | 19.531882 | 1175 | 1174 | 18 / 1155 |

Video timestamps use **1/600-second ticks**. The nominal rate is `60/1`, but decoded intervals are 15 or 16.6667 ms. Frame index divided by 60 is therefore not capture time. There are no non-increasing decoded timestamps or longer interior intervals in this corpus. Each recording contains one terminal packet marked for discard; that accounts for the container/decoded count discrepancy. It is not evidence of an interior dropped frame. Display refreshes missed before encoding cannot be excluded.

No adjacent decoded frames are byte-identical within the tested 1040×1400 lyric-region crop after fourfold reduction. Nevertheless, 274, 401, 246, and 325 adjacent pairs respectively have mean absolute differences below 0.05 code values in that reduced region. Compression and animated backgrounds prevent interpreting these nearly unchanged regions as proof of duplicate source display frames. No full-screen perceptual duplicate classifier was used.

Audio/video track endpoints differ by at most 5.408 ms. This establishes container timing consistency, not perceptual synchronization of vocals and highlighting. No commercial audio was exported into public fixtures.

## Coordinates and Measurement Method

Native screenshot coordinates are top-left-origin pixels, with x increasing rightward and y downward. The recording's extra column remains explicit; its origin is unknown. Dividing screenshots by three suggests 393×852 logical points, but neither the point scale nor UIKit view geometry was directly measured. All fitting uses pixels.

Original-resolution screenshots were inspected, with private contact sheets used only for navigation. Visible text was supplied manually in private cases; OCR was not used. Local foreground masks subtract an 18-pixel Gaussian background estimate from the encoded RGB-channel mean. Thresholds of 15, 25, and 35 code values test sensitivity. This operation estimates visible ink, not calibrated luminance or alpha. It does not equate Display P3 and Rec.709 color values.

Bounds use half-open intervals. Font side bearings, punctuation, blur, clipping, and highlighting can move visible bounds without moving a layout origin. Direct ink measurements are therefore separated from reconstructed margins and baselines. Whole-screen SSIM and PSNR were not used as typography evidence.

## Static Geometry

The following small model explains several ordinary states without separate constants for each screenshot. Uncertainties are practical measurement bands, not statistical confidence intervals.

| Relationship | Native-Pixel Result | Status and Scope |
| --- | --- | --- |
| Dismissal handle | `[500,198,680,210)` | Measured; approximately ±1 px across seven control-visible states |
| Artwork bounds | `[96,276,312,492)` | Manually measured; approximately ±2 px across English and Japanese examples |
| Title ink origin | x≈352, y≈337–339 | Measured; width and descenders depend on content |
| Artist ink origin | x≈352, y≈397–399 | Measured; content-dependent bounds |
| Progress bar | `[96,1683,1083,1704)` | Measured; approximately ±1 px across seven states |
| Volume bar | `[171,2192,982,2214)` | Measured; approximately ±1 px across seven states |
| Ordinary English first-line ink top | y=715–718 | Measured across S02–S05 and S07; approximately ±3 px extraction uncertainty |
| Lyric horizontal layout | x≈96 to 1083; width≈987 | Fitted shared model; approximately ±4 px, including side-bearing uncertainty |
| English line advance | ≈128 | Fitted across multiple paragraphs; approximately ±3 px |
| English first baseline | ≈792 | Fitted through Core Text registration; approximately ±5 px; not directly visible |
| Expanded Sing control | `[969,1353,1083,1587)` | Manually measured in S07; approximately ±3 px |

Transport controls occupy a stable band around y≈1947, with centers near x≈271, 590, and 909. Bottom controls occupy a band near y≈2359, with centers near x≈248, 590, and 932. The circular translation and compact Sing affordances, where present, are centered near `(153,1530)` and `(1026,1530)`. These are manual approximate component locations, not extracted icon geometry or measured hit targets. Their visible arrangement supports later full-screen scene modeling; no complete Music interface was implemented.

Important exceptions prevent a universal lyric anchor. S08's sharp Japanese active line has ink bounds `[104,1053,1025,1139)`. S09's two-line Japanese state begins near y=710. S10's mixed-script paragraph is right-aligned, with measured right ink edges at x=1075 and 1080. S02 and S08 hide the lower controls; other captures retain them. S05 includes an additional smaller text treatment whose role is unresolved. It must not be labeled translation or backing vocals without evidence.

Inactive lines are visibly blurred and have lower contrast. Their apparent bounds are threshold-dependent. The first repeated two-line English block moves approximately 325 pixels between focus states, but this does not establish a universal paragraph-spacing rule. Native clipping and fade boundaries also remain unknown. System status chrome, the recording-related display occlusion, application content, and safe areas are separate concepts; screenshot dimensions do not establish their individual bounds.

## Typography Findings

The unchanged spike resolves **Helvetica** for Latin and **HiraginoSans-W3** for Japanese. The diagnostic candidate uses the public Core Text system-font API with the bold symbolic trait; this machine resolves **`.SFNS-Bold`** and **`.HiraKakuInterface-W6`**. These observed macOS names do not identify the native iPhone Music fonts.

The spike was tested at 81 native pixels, corresponding to its synthetic size 27 under the explicit three-pixel hypothesis. A small candidate grid tested sizes 99, 102, 104, 105, and 108, with the shared 987-pixel width and 128-pixel line advance. The spike retains its synthetic 111-pixel advance at this test scale, 17 pixels below the fitted reference advance. Whole paragraphs remain shaped together. Timed words or characters were not independently laid out.

| Case | Spike Result | Candidate Result | First-Line Registered Mask IoU |
| --- | --- | --- | ---: |
| S02, three-line English | Different second/third-line wrapping; first-line ink width −189 px | Size 104; all three observed wraps matched; width errors −2, −1, 0 px | 0.797; spike 0.211 |
| S04, explicit observed break (S04B) | Width errors −141, −82 px | Size 104; width errors −4, +1 px | 0.824; spike 0.188 |
| S08, Japanese | One line, but ink width −132 px | Size 102; width error +1 px | 0.925; spike 0.151 |
| S10, mixed script | Width errors −123, −131 px; spike alignment remains left | Size 104 with explicit right alignment; width errors 0, +5 px | 0.777; spike 0.174 |

The S04 unbroken transcription does not produce the observed wrap with either the spike or candidate. Supplying the observed line break produces the S04B result. This is evidence that source-authored breaks or another layout constraint must be resolved; it is not proof that a font change alone fixes wrapping. The known break is recorded privately and is not silently attributed to Core Text.

At size 104, the Japanese-only line is 19 pixels too wide; size 102 reduces that error to one pixel. Conversely, size 102 undershoots the English S02 widths by 10–21 pixels. A single global size correction is therefore not established. The mixed-script comparison preserves its explicit break and right alignment; it does not identify whether native timing, language fallback, or content metadata determines that alignment.

Mask comparisons register the first known line by at most ±5 pixels after ink-bound alignment. For the chosen candidates, additional translations are zero or one pixel vertically. S02 IoU ranges approximately 0.795–0.798 as the foreground threshold changes; S08 ranges 0.923–0.928. Matching line widths does not eliminate remaining glyph-mask discrepancies. Private registered overlays also show localized vertical differences within partially progressed Latin lines. Weight, outline/optical-size differences, fallback metrics, state-dependent glyph treatment, and rasterization remain possible contributors; the experiment does not isolate them. Baselines remain fitted, and punctuation coverage is limited to the observed examples. No proprietary fonts were extracted or redistributed.

## Motion Measurements and Fits

V01–V03 contain comparable English passages. The first repeated focus transition was analyzed densely over native capture times 2–5 seconds. A 1040×1400 region beginning at `(72,500)` was reduced fourfold. Horizontal glyph-edge energy provided a vertical line-centroid trajectory. A bounded tracking window followed the same inspected line; radius variants of 11, 13, and 15 reduced pixels measured sensitivity. Analysis may track adjacent observations; the resulting renderer representation remains an explicit arbitrary-time function.

The archived CSV contains 180 measurements per capture at original integer presentation timestamps. The observation is an edge centroid, not a typographic baseline. A separate leading-glyph region produces a constant anchor offset of approximately −4.3 px, but after removing that offset differs by only 0.83–1.04 px RMS and at most 1.81 px. This supports the measured trajectory while retaining blur and contrast uncertainty.

Two deterministic candidates were fitted with a 10-ms onset/parameter grid and least-squares offset/amplitude. The cubic candidate uses `3u²−2u³`, clamped to a finite interval. The critical candidate uses `1−(1+u)exp(−u)` after onset, where its duration parameter is a time constant. Neither is asserted to be Apple's implementation. Even observations train the fit; odd observations provide a within-capture holdout.

| Source | Hermite Duration (s) | Hermite Holdout RMS / Maximum (px) | Critical Onset / Time Constant (s) | Critical Holdout RMS / Maximum (px) |
| --- | ---: | ---: | ---: | ---: |
| V01 | 0.42 | 4.126 / 16.822 | 3.08 / 0.08 | 2.478 / 8.879 |
| V02 | 0.43 | 4.149 / 15.009 | 3.24 / 0.08 | 2.634 / 13.776 |
| V03 | 0.42 | 4.129 / 17.359 | 3.13 / 0.08 | 2.671 / 10.699 |

The critical fits have offsets 1083.76–1084.71 px and amplitudes −324.58 to −324.90 px. Their complete parameters and residual statistics are archived. Fixing the Hermite duration to the spike's synthetic 0.8 seconds gives RMS errors of 17.06–17.14 px and maximum errors of 63.25–66.60 px. That synthetic timing is unsuitable as a native reconstruction.

Using V01's critical shape, amplitude, and offset on V02 and V03, with only measured half-crossing phase registration, produces RMS errors of 2.456 and 2.463 px and maxima of 9.757 and 9.390 px. Registration shifts are 0.152066 and 0.051551 seconds. This is a held-out shape test; it is not independent validation of onset timing. Maximum residuals still exceed the estimated measurement band, so the critical candidate is not accepted as a final motion specification. More complex models were not fitted merely to reduce residuals before typography and anchor definitions are resolved.

Other transitions were inspected but not fitted. Position is the only independently fitted motion component. Opacity, blur radius, and scale were not separately identifiable with sufficient confidence; no scale curve was inferred from luminance or blur.

## Repeatability and Progressive Highlighting

Settled anchor means in the last half-second of the measurement window are 758.680, 759.564, and 759.370 px: a spread of **0.884 px**. Within-capture standard deviations are 0.523–0.695 px. Changing the tracking-window radius produces median differences of 0.20–0.57 px and transient maxima of 3.71–3.81 px. These observations do not support treating every measured transient position as subpixel ground truth.

Ordinary English highlighting progresses from left to right through the inspected line, leaving completed regions brighter and upcoming regions dimmer without an observed change in line wrapping. The reconstruction preserves whole-paragraph shaping. Three fixed glyph groups in V01 cross half of their observed contrast range at approximately 0.932, 1.298, and 1.930 seconds. After focus-phase registration, corresponding V02 crossings differ by approximately −19, −2, and −2 ms. The first V03 group is already bright and changes by only four code values; its crossing is rejected as unavailable. The other V03 groups differ by approximately −35 and −2 ms. These are contrast-proxy timings, not verified source word timestamps.

The foreground-minus-background contrast proxy ranges roughly 89–101 code values before a detectable change and 136–195 afterward in the first two recordings. It does not identify alpha, luminance in physical units, or a universal completed/upcoming color. Edge softness could not be isolated from glyph geometry, background variation, and capture rasterization. Japanese and mixed-script screenshots show active/upcoming treatments, but no supplied recording establishes their progression timing. S07 establishes a Sing-related static state and expanded vocal control; ordinary timing measurements are not transferred to Sing.

Provisional **investigation bands**, not fidelity acceptance criteria, are ±2 px for settled-anchor comparisons, approximately ±4 px for this moving-anchor measurement, and ±50 ms for repeated contrast-crossing alignment. The latter accommodates observed variability and capture sampling. Final typography, motion, and material tolerances remain unset. Historical synthetic codec/export thresholds remain separate and unchanged.

## Interactions and Instrumental Gaps

V04 visibly contains paused and playing states. Later elapsed-time labels change from approximately 0:54 at capture PTS 8397/600 to 0:58 at 8697/600, and from 0:58 at 9296/600 to 1:03 at 9596/600. These discontinuities support a seek-like interpretation. The precise gesture, input timestamp, and media-clock mapping were not captured. The visible focus changes are separated enough that an interruption during an unfinished focus transition is not established. Pause/resume response latency, interruption initial conditions, and Lyrics entry/exit behavior remain unmeasured. Lower-control disappearance in V01–V03 is not treated as proof of Lyrics entry or exit.

The instrumental-gap indicator is a distinct three-dot state. In S01, dot x-spans are `[95,131)`, `[156,192)`, and `[217,253)`; y-span is `[744,780)`. In S06, x-spans are `[83,126)`, `[153,195)`, and `[222,265)`; y-span is `[740,784)`. The common vertical center is approximately y=762, and the middle dot remains centered near x=174. Diameters change from approximately 36 to 43–44 px and center spacing from approximately 61 to 69–70 px, with approximately ±2 px extraction uncertainty. Brightness also changes. Two stills establish appearance differences, not animation order, period, or phase. No generic loading-indicator behavior is assumed.

## Backgrounds and Materials

A foreground-free right-edge strip at x=1120–1160, y=550–2150 was sampled every 120 decoded frames while retaining each selected PTS. Encoded Rec.709 RGB means vary temporally by channel ranges of approximately **35–45 code values in V01**, **13–18 in V02**, **19–26 in V03**, and **13–19 in V04**. Changes in top-to-bottom strip gradients also establish spatially varying evolution.

Comparable passages have different background states. Their first strip means are approximately `(73.70,73.31,66.57)`, `(67.22,66.95,62.50)`, and `(75.60,72.71,66.45)`. This weakens a simple assumption that the background is solely a fixed function of displayed media time. It does not prove randomness: an independent phase, session state, or other deterministic input remains possible. A static blurred backdrop is therefore insufficient for temporal reference reproduction.

Artwork and background colors are visually related in the supplied examples, but an artwork-to-background transfer function, blur kernel, compositing equation, phase rule, and gamut mapping were not measured. No private material pipeline is claimed. There is no measured workload showing that Core Graphics/Core Image cannot implement a suitable reconstruction; no new GPU backend or material benchmark was introduced.

## Native Layout and Delivery

For a 1179×2556 screenshot reference delivered at 1080×1920, uniform `contain` uses scale **0.751173709**, with **97.1831-pixel horizontal offsets** and no vertical offset. Uniform `cover` uses scale **0.916030534**, with a **−210.6870-pixel vertical offset**, cropping the native top and bottom. Neither changes native wrapping.

An edge-to-edge 9:16 layout that reflows text or moves surrounding UI is an `adapt` presentation. It is not native screenshot reproduction. No adaptation policy was implemented, and the historical synthetic scene's transform remains unchanged.

## Implementation and Verification

The internal `ReferenceProbe` target reads explicit text/layout parameters and a rational timestamp, shapes a whole paragraph with Core Text, emits font/run and line metrics, and optionally places it on a 1179×2556 transparent canvas using an analytic fitted trajectory. It has no wall-clock or previous-frame animation state. The public `ilyric` executable is unchanged.

Python validation provides exact timestamp statistics, uniform transforms, bounded local-mask registration, deterministic model fitting/evaluation, private-input guards, metadata inspection, native ink measurements, motion/repeatability diagnostics, and appearance proxies. All reference-dependent output stays private. The absence of references produces an explicit `unavailable` result without requiring NumPy, Pillow, an Apple Music subscription, or network access. See [reference-validation commands](reference-validation-commands.md).

Validation on Apple M4, macOS 27.0.1 build 26A434, Swift 6.4, macOS SDK 27, and FFmpeg/ffprobe 8.1.2 included:

- All **nine existing Swift tests**, including rational scheduling, interruption continuity, event ordering, Core Text coverage, and random-access raw raster equality: passed.
- **Nine public Python tests** covering timestamp intervals, transforms, model fitting/holdout, arbitrary-order evaluation, mask registration, degeneracy, path escape, and unavailable inputs: passed.
- Release `ReferenceProbe` build and **eight ordered synthetic evaluations at four timestamps**, plus a new-directory regression run: Swift/Python positions agreed within 1e-9; repeated PNGs were byte-identical on this machine.
- **Six diagnostic evaluations at four timestamps spanning the measured transition**: repeated PNGs were byte-identical. Original independent diagnostic text was used; the resulting image was visually inspected.
- Private analysis of **10 screenshots and 4 recordings**: decoded frame/PTS counts matched, all selected inputs were readable, and five typography cases across four screenshots were evaluated. Contact sheets, original screenshots, selected recording frames, control details, and text crops were visually inspected.
- Fresh public checkout without `reference-private/`: all nine Swift tests, nine Python tests, the release build, deterministic probe checks, and path-guard regression passed. Reference analysis returned `unavailable` before optional dependencies were loaded. The checkout remained clean apart from ignored build/test artifacts.

The first fresh-checkout probe run exposed a Foundation path-alias inconsistency between existing temporary paths and nonexistent output directories. The privacy guard rejected a valid synthetic output before writing it. Resolving the existing parent before appending new path components corrected the defect; a focused regression check covers new output directories. The initial scene-probe build exposed a Swift numeric-type mismatch in a rectangle initializer; it was corrected before validation. One path-guard test initially compared resolved and unresolved macOS temporary-directory paths; the expectation was corrected to test canonical paths. A bytecode-cache check encountered a sandbox restriction and passed after its cache was redirected into ignored artifacts. A resource-reporting wrapper recorded 68.87 seconds for one full private analysis but failed to query a protected system statistic; its exit status was not treated as analysis failure or proof of successful memory measurement. The analysis was separately rerun without that wrapper. No new renderer performance claim or cross-machine raster-equality guarantee follows from this gate.

## Limitations and Next Gate

Native font identity, exact native baselines, source-authored line breaks, a universal paragraph-spacing rule, UIKit point/safe-area geometry, and state selection remain unresolved. The four typography screenshots do not cover every glyph, punctuation rule, or fallback path. Only one repeated focus transition has a quantitative model comparison. Scale, blur, opacity, highlight-edge softness, Sing timing, Japanese/mixed-script timing, gap timing, interruption latency, and full Lyrics entry/exit remain unmeasured or insufficiently separated. Material reconstruction is limited to broad spatial and temporal observations.

Proceed with **native-space typography calibration**: resolve authored breaks, preserve whole-paragraph shaping, evaluate a shared Latin/CJK metric model against the existing English, Japanese, and mixed-script cases, and retain localized residuals. Do not transfer the candidate sizes directly into the production renderer as universal constants. The existing screenshots are sufficient to begin this gate; no additional capture is required for that immediate work.

Before a subsequent temporal fidelity gate, the minimum missing evidence is two repetitions each of: an approximately 12-second Japanese/mixed-script passage containing a focus transition and progressive highlighting; an approximately 12-second Sing-enabled passage comparable to an ordinary reference; and an approximately 10-second ordinary instrumental gap continuing into the first lyric. A separate approximately 8-second interaction clip, repeated twice, is needed only when validating interruption behavior: interrupt an active focus transition, then pause and resume. Keep device settings unchanged and preserve original recordings. These captures address specific unresolved behaviors rather than duplicating the measured ordinary English transition.
