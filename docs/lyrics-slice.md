# iLyric First Measured Japanese Lyrics Slice

## Disposition

**The deterministic native-space geometry integration is supported within the inspected S09 states; progressive-appearance fidelity remains unvalidated.** A separate experimental renderer preserves whole-paragraph shaping and reproduces the previous common-origin mask comparisons when driven by explicit private appearance annotations. It does not establish native Music fidelity, general Japanese support, or Apple's private implementation.

The next gate should refine progressive appearance on the existing V09/V10 corpus with geometry frozen. Latin typography, focus motion, materials, and full-screen composition should remain separate subsequent gates. No new capture is required immediately.

## Evidence and Coordinates

The reference remains reported iPhone 16 running iOS 27.0.1, exact build **Unknown**. The recorded settings remain Default Display Zoom, Text Size 4/7 counting the smallest selectable size as 1/7, Bold Text/Reduce Motion/Reduce Transparency/Increase Contrast off, Light appearance, and English system and Music languages. Sing disabled and unchanged settings were previously confirmed for V09/V10. These remain reported metadata.

The original V09/V10 hashes matched the prior private inventory before and after comparison. Their established correspondence to the Japanese-only S09 passage is retained. Both recordings are 1180×2556 HEVC with full-range Rec.709 metadata and AAC stereo audio; original timestamps use 1/600-second units. This gate reuses the verified extractions and state annotations rather than repeating media inventory or correspondence work.

The renderer distinguishes the **1179×2556 screenshot canvas** from the **1180×2556 recording canvas**. Both use native pixels and a top-left origin. Changing capture width does not rescale or reflow text. The origin of the extra recording column remains unknown. No UIKit point geometry, safe-area behavior, or 9:16 delivery transform is inferred.

The [v6 profile](reference-data/v6/profile.json), [comparison results](reference-data/v6/slice-validation.json), and [numerical observations](reference-data/v6/observations.csv) preserve new evidence separately from v1–v5. Historical reports and profiles remain unchanged.

## Experimental Implementation

`LyricsSliceCore` evaluates immutable source-range presentation state using the existing rational `Time` type. `LyricsSliceMac` shapes the entire attributed paragraph through one Core Text typesetter, retains the observed two-line structure, and caches masks drawn from the existing shaped glyph runs. `LyricsSliceProbe` provides a separate developer invocation; it does not change the `ilyric` command.

Timed ranges use UTF-16 source indices and must align with shaped cluster boundaries. They do not initiate new shaping. Cross-line ranges, partial clusters, incomplete coverage, invalid intervals, and unintended wrapping are rejected. Recombining the shaped masks reproduces the unchanged whole-paragraph `ReferenceProbe` alpha raster exactly for the public synthetic integration fixture.

Layout, appearance, and vertical treatment remain separate:

- **Layout:** Public system-font selection with bold symbolic traits, requested size 103.25, width 987, explicit observed-break constraint, and one common origin. Locally resolved `.HiraKakuInterface-W6` and `.SFNS-Bold` are environment provenance, not native font identification.
- **Appearance:** An explicit begin/end interval controls a left-to-right wipe across existing glyph support. Upcoming support receives a supplied dim opacity; completed support receives full opacity. This simple wipe is provisional.
- **Vertical treatment:** An independent appearance-event timestamp controls `A × (1 + u) × exp(−u)`, where `u = max(0, event age) / tau`. Missing events retain the upcoming limit. No file identifier or reference-specific timestamp enters renderer code.

The public synthetic defaults use origin (98, 686), advance 123, amplitude 6, and time constant 0.195 seconds, reflecting rounded experimental candidates. Its dim opacity 0.42 and timing are synthetic choices. Private comparisons instead apply the frozen v5 training parameters: advance 123.014/123.047, amplitude 6.030/5.843, time constant 0.19/0.20 seconds, and the previously fitted origin corrections. These values remain fitted reconstruction parameters, not native settings.

Continuous presentation values are evaluated at arbitrary rational times. The raster backend rounds the final vertical mask placement to native integer pixels, matching the preceding diagnostic convention. This quantization is explicit and remains a limitation for eventual smooth temporal reproduction. Horizontal advances and wrapping do not change with state.

Output consists of transparent sRGB appearance and coverage PNGs plus state/metric JSON. Coverage deliberately excludes opacity and highlight clipping while retaining vertical treatment. No artwork, background material, controls, export backend, scene graph, or production parser was added. Existing `SpikeCore`, `RenderMac`, `ReferenceProbe`, and `ilyric` sources remain unchanged.

## Synthetic Fixture and Determinism

The public fixture contains two original Japanese sentences about drawing marks on paper. Its source ranges and quarter-second event spacing are independently authored. It exercises an explicit break, dim support, intermediate highlighting, later appearance, and bounded vertical displacement without commercial text or assets.

Synthetic tests cover rational event boundaries, upcoming and completed states, treatment limits, random timestamp ordering, repeated evaluation, fresh renderer instances, two-line layout, capture-width separation, observed-break handling, and rejection of split combining clusters. Identical state and byte-identical raw raster output were observed in the pinned environment. Separate-process PNG checks also passed. Coverage remains identical when only appearance progression changes and vertical amplitude is zero.

These guarantees apply to the tested environment, not arbitrary future system-font or graphics implementations. There is no wall clock, frame-stepped simulation, presentation-layer state, or previous-frame dependency.

## Private Comparison Method

The comparison reuses ten sharp appearance phases per recording: approximately PTS 4802/4803 through 6779, divided by 600. These cover dim, intermediate, and later states; blurred entry/departure are excluded. The existing 180/195/210 intensity-crossing brackets supply explicit private annotations. The lower 180 bracket and upper 210 bracket define the provisional wipe interval; the upper 195 bracket supplies the vertical event. Missing complete annotations remain unavailable rather than receiving invented timings.

Parameters selected on V09 in v5 render V10, then the direction is reversed. No vertical parameter is refitted in this gate. The opposite recording supplies its measured event inputs, so these remain conditional geometry comparisons, not lyric-timing predictions. Dim opacity is fitted only on the training recording using a white-over-local-background hypothesis: 0.4408 from V09 and 0.4321 from V10.

Principal mask comparisons use the fixed common paragraph origin and the previous localized, contrast-normalized glyph windows. There is no global post-render translation or independent line adjustment. Diagnostic vertical registration within ±8 pixels measures residual displacement only; it is never fed back into rendering. Every direction/model evaluates 150 glyph observations.

Appearance error is evaluated separately against sRGB-interpreted source intensity. Rendered alpha is composited over locally estimated background values. Scores on the intersection of native interior support and rendered coverage reduce contamination from geometry mismatch. This controlled photometric comparison is neither a complete color/material reconstruction nor calibrated luminance measurement.

## Held-Out Results

| Model | V09 → V10 Residual RMSE / Maximum | V10 → V09 Residual RMSE / Maximum |
| --- | ---: | ---: |
| Frozen fixed geometry | 2.421 / 5 px | 2.525 / 5 px |
| Frozen bounded vertical treatment | **0.408 / 1 px** | **0.503 / 1 px** |

No registration reaches the search boundary. These residuals measure additional integer displacement of actual rendered support. They are distinct from v5's continuous-model-versus-integer-observation errors of 0.383/0.531 pixels and must not be interpreted as increased physical measurement precision.

Held-out common-origin IoU is **0.892–0.934** and **0.873–0.936**, exactly reproducing the v5 bounded-treatment scores. Mean glyph IoU is 0.919/0.914, with minima 0.821/0.800. The identical scores demonstrate faithful integration of that diagnostic geometry without independently registered glyph offsets.

All 40 rendered comparisons preserve two lines and width errors **0/+1 pixel** against the corresponding observed 742/653-pixel line widths. The shared size is unchanged. No per-recording font size, horizontal scale, tracking adjustment, or forced-width break was introduced.

On shared interior support, bounded-treatment appearance error is **10.072/10.593 RMS intensity levels** on a 0–255 diagnostic scale. Individual glyph RMS errors reach **45.183/50.602**. At least 96.0%/95.7% of native interior support remains in the shared mask. Including unmatched native interior pixels raises appearance RMS to 12.486/12.859. The error therefore cannot be attributed entirely to misplaced edges.

The approximately two-pixel vertical investigation band is met in these integer diagnostics, but it is not a final fidelity threshold. Outline differences, partial-highlight treatment, event correspondence, compression, and raster quantization remain independent limitations.

## Visual Findings and Limitations

Synthetic early/intermediate/later stills and private source/reconstruction/coverage sheets were visually inspected. The synthetic fixture shows distinct dim and completed support without changing line structure. Private comparisons retain the measured alignment and relative vertical relationships. Local outline differences and partial-highlight differences remain visible; a favorable paragraph IoU does not establish correct appearance progression.

The narrow 180-to-210 crossing interval is only a convenient explicit input convention. It does not measure the complete native wipe duration or softness. A white foreground with one dim-opacity parameter cannot establish native compositing behavior. The final upcoming support and earliest sharp phases retain the previous annotation limits. Native font identity, authored-break semantics, ordinary Latin behavior, other CJK passages, bidirectional text, Sing behavior, focus motion, and dynamic materials remain outside the validated scope.

## Verification and History

All release targets built. The existing nine Swift tests and six new Swift tests passed, as did all 42 Python tests, both existing deterministic probe checks, synthetic outline checks, and the new slice integration check. The private comparison completed in both directions with original source hashes preserved. Reproduction commands are documented in [Experimental Lyrics Slice Commands](lyrics-slice-commands.md).

The unchanged architecture-spike determinism command passed. A new export decoded as 1080×1920, exactly 60 fps, 240 frames, four seconds, Rec.709, and four seconds of 48 kHz mono AAC. All presentation timestamps and audio/visual marker checks passed. Initial sandbox execution could not initialize Core Image; verification succeeded with graphics access outside the sandbox, without renderer changes. An initial reverse-comparison run exposed a recording-index lookup error in the new Python workflow; selecting the held-out recording's own PTS index corrected it before final measurements.

A fresh public-only checkout at implementation commit `1232434` passed all release builds, 15 Swift tests, 42 Python tests, both existing probe checks, synthetic outline and slice checks, and synthetic native-resolution rendering. All six private-reference commands returned explicit `unavailable` results. Its working tree remained clean apart from ignored outputs. Subsequent changes contain only documentation and sanitized numerical evidence.

Private inputs, annotations, masks, images, and diagnostics remain ignored. Public changes contain original synthetic text, renderer/test code, documentation, and sanitized numerical evidence only. Historical commits and reports are preserved; no release or tag is created.

## Next Engineering Gate

**Retain the experimental geometry integration and refine progressive appearance next.** Use the existing V09/V10 frames to measure the complete brightness progression and edge-softness profile around the supplied events, freeze the current paragraph geometry, and fit one bounded appearance candidate with reverse recording holdouts. This is smaller and better supported than beginning Latin integration, focus-motion refinement, or full-screen composition. The current result is a measured experimental slice, not validated native iOS 27 Music fidelity.
