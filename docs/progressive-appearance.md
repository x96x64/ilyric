# iLyric Progressive Appearance Calibration

## Disposition

**Retain a bounded spatially softened appearance model in the experimental Japanese slice.** It improves both reverse-recording holdouts without altering shaped coverage, line metrics, or the frozen vertical treatment. Native Music fidelity, exact compositing behavior, and native lyric timing remain unvalidated. Production `ilyric`, export, focus motion, materials, and delivery policies are unchanged.

The next narrow gate should address Latin typography integration, beginning with the existing S05 wrap-boundary ambiguity and held-out S02–S05 layout checks. The Japanese candidate can remain a qualified experimental baseline. No additional physical recording is required for that immediate work.

## Reference Evidence and Baseline Reproduction

The reference remains reported iPhone 16, iOS 27.0.1, exact build **Unknown**. Settings remain Default Display Zoom; Text Size 4/7 counting the smallest selectable size as 1/7; Bold Text, Reduce Motion, Reduce Transparency, and Increase Contrast off; Light appearance; English system and Music languages. Sing disabled and unchanged settings in V09/V10 remain user-reported confirmations.

Both originals retain their established S09 correspondence and match the documented private SHA-256 inventory before and after analysis. Historical media metadata remains 1180×2556 HEVC Main, full-range Rec.709, AAC LC stereo 44.1 kHz, and a 1/600-second video time base. No transcoding or modification of originals occurred. The 1179-pixel screenshot canvas remains distinct from the 1180-pixel recording canvas.

The preceding slice workflow reproduced every archived observation field exactly. Historical derived aggregate fields are not emitted by that workflow; their underlying observations are identical. The original ten-phase appearance RMS errors remain 10.072/10.593 diagnostic levels; vertical residual RMSE remains 0.408/0.503 pixels, maximum one pixel, with width errors 0/+1 pixel.

New evidence is additive: [v7 profile](reference-data/v7/profile.json), [appearance fits and measurements](reference-data/v7/appearance.json), and [actual renderer comparisons](reference-data/v7/render-validation.json). All earlier reports and profiles remain unchanged. These records distinguish image-derived measurements, fitted reconstruction parameters, and engineering conclusions; they do not identify native font or animation settings.

## Sampling and Color Interpretation

The experiment evaluates **199 decoded observations per recording**, retaining original PTS: V09 4803–6779 and V10 4802–6779, divided by 600. These cover sharp dim, first-line progression, second-line progression, and later partial completion. Blurred entry/departure and a fully settled two-second bright paragraph are not claimed. Each recording supplies its previously measured 180/195/210 interior-intensity crossing brackets. Adjacent observations are approximately 15–16.667 ms apart; equivalent PTS does not imply identical appearance phase.

Existing extractions interpret full-range Rec.709 through FFmpeg's `colorspace` conversion to full-range sRGB. Reference and reconstruction are compared as nonlinear sRGB channel-average code values on a 0–255 scale. They are neither raw encoded Rec.709 channels nor linear-light quantities. No physical luminance or measured native alpha is asserted.

Fifteen known glyph-support windows retain the existing common paragraph origin and frozen v5 vertical model. Background is estimated independently in each column from the upper/lower eight-pixel borders. Contrast-normalized native masks are eroded by one pixel in four directions and intersected with rendered coverage. No local registration changes the reconstruction. Dense comparisons translate cached, already-shaped support by the same integer-placement rule as the renderer; no text unit is independently shaped.

The controlled prediction is `background + (255 − background) × coverage × appearance`. This white-over-local-background hypothesis intentionally excludes material reconstruction. Column sums retain the pixel least-squares objective. Scores therefore measure conditional appearance agreement on shared interior support, with outline and background limitations reported separately.

## Measured Appearance Behavior

Spatial samples show completed regions brighter than upcoming regions, with a broad left-to-right gradient through partially progressed glyphs. A uniform whole-glyph fade does not explain that gradient. Vertical displacement remains governed by the frozen treatment; brightness fitting does not change it.

For measurement summaries, a shared contrast-ratio proxy is normalized between provisional descriptive endpoints 0.44 and 0.98. These numbers are not measured native opacity. Spatial crossings require at least five supported pixels per column, a unique descending crossing, and gaps no larger than four columns; incomplete or ambiguous crossings are rejected.

| Observation | V09 | V10 |
| --- | ---: | ---: |
| Accepted spatial 90%–10% boundary brackets | 14 | 20 |
| Median bracket-midpoint width | 64 px | 63 px |
| Observed midpoint range | 49–68 px | 24–67 px |
| Complete temporal 10%–90% contrast crossings | 13 | 14 |
| Median interval midpoint | 0.183 s | 0.182 s |
| Interval midpoint range | 0.100–0.500 s | 0.083–0.498 s |
| Unavailable complete intervals | 2 | 1 |

Spatial brackets span adjacent supported columns; temporal duration brackets combine uncertainty at both endpoint frames. These are sparse, support-conditioned observations, not a measured blur kernel or universal wipe duration. The 24-pixel spatial outlier and missing intervals expose incomplete support and threshold dependence. The final range lacks a complete appearance annotation in V09; it remains upcoming in the reconstruction instead of receiving invented timing.

## Candidate Models and Fitting

Three compact candidates use the same geometry and explicit private intervals:

1. **Baseline:** Existing hard spatial wipe over the supplied narrow interval, with the preceding training-recording dim fit and full completed opacity.
2. **Spatial:** A moving cubic-smoothstep transition band across already-shaped support, with interval expansion, phase offset, band width, and two shared appearance endpoints.
3. **Temporal:** A cubic-smoothstep interpolation of the entire shaped range, using interval expansion, phase offset, and two shared endpoints, without a horizontal boundary.

The grid tests interval scales 1, 1.5, 2, 3, 4, and 6; phase offsets −0.5 through 1 in quarter-interval steps; and spatial widths 0.25, 0.5, 1, 1.5, 2, and 3 shaped-range advances. Linear least squares fits the two endpoints, bounded to 0.3–0.6 and 0.9–1. Alternate decoded phases train the model; the intervening phases test interpolation. The opposite recording tests transfer without retuning. Both directions are evaluated.

**Both training recordings select spatial scale 3, offset 0, and width 1 advance.** Fitted dim endpoints are 0.44244/0.43287; completed endpoints are 0.98068/0.98191. These are reconstruction values under the stated compositing hypothesis. The temporal candidate selects scale 4 and offset 0 in both directions. The spatial model's approximately 95.34-pixel full band has an approximately 58-pixel 10%–90% smoothstep width; this is a model consequence, not an exact native measurement.

Observed crossing brackets remain required inputs in the held-out recording. This validates conditional appearance transfer, not prediction of native lyric timing from text or audio. Temporal holdouts share neighboring frames and event annotations; they are not statistically independent passages. Exploratory inspection used both repetitions, so this is not a blinded external-corpus validation.

## Held-Out Appearance Results

Dense scores below are pixel-weighted over 199 phases and 15 windows per recording. They differ in sampling and weighting from the archived ten-phase, equal-glyph aggregate.

| Model | V09 → V10 Shared-Interior RMS | V10 → V09 Shared-Interior RMS |
| --- | ---: | ---: |
| Existing hard wipe | 10.811 | 11.036 |
| Spatially softened progression | **6.881** | **6.976** |
| Uniform temporal interpolation | 8.968 | 8.917 |

Within-recording temporal holdout RMS is 6.881/6.759 for the spatial candidate, compared with 10.838/10.907 for the baseline. The improvement therefore extends beyond fitted phases.

Region scores use the same observed contrast-proxy categories for every candidate: upcoming ≤10%, boundary 10%–90%, and completed ≥90%. Categories are column-aggregated and support-conditioned, not independently verified native states.

| Region | Baseline V09 → V10 / Reverse | Spatial V09 → V10 / Reverse | Temporal V09 → V10 / Reverse |
| --- | ---: | ---: | ---: |
| Boundary | 39.976 / 40.110 | **17.301 / 17.718** | 26.263 / 26.539 |
| Completed | 7.622 / 7.831 | **7.041 / 7.171** | 7.348 / 7.415 |
| Upcoming | **3.472 / 3.728** | 3.939 / 3.798 | 6.316 / 5.763 |

The spatial model improves boundary and completed regions but slightly worsens upcoming-region error. The result is not uniform pixelwise improvement. Residual boundary errors remain appreciable; the model is retained as a bounded approximation.

## Sensitivity and Parameter Stability

Changing foreground thresholds to 0.35/0.65, background borders to four/twelve pixels, appearance phase by ±10 ticks, or diagnostic support placement by ±1 pixel retains the spatial candidate's advantage over both alternatives in each direction. Its held-out RMS spans **5.953–8.886** under these perturbations. Registration perturbations are sensitivity experiments only; none changes the retained paragraph origin.

A finer training-only neighborhood retains interval scale 3 but selects phase offset 0.125 in both directions, with width 1.25 from V09 and 1 from V10. Held-out RMS becomes 6.859/6.911. These small improvements do not justify additional precision or repetition-specific defaults. The shared coarse candidate is retained. The offset corresponds to a fraction of the already uncertain crossing interval, and spatial width remains coupled to duration and endpoint estimation.

The fitted dim difference between recordings is approximately 0.00957; completed endpoints differ by approximately 0.00123. Background estimation, capture variation, support selection, and the simple compositing hypothesis remain plausible contributors. Exact opacity, kernel shape, native timing units, and universal parameter values remain unknown. No final appearance threshold is introduced.

## Renderer Integration and Geometry Regression

An optional `SoftAppearance` input extends only `LyricsSliceCore`, `LyricsSliceMac`, and `LyricsSliceProbe`. The original invocation and omitted-appearance behavior preserve the hard wipe. `synthetic-soft` uses the original redistributable Japanese fixture and independently authored events. The rounded synthetic dim/completed values are 0.438/0.981.

Rational timestamps evaluate immutable interval phase independently of the frozen vertical event. The raster path multiplies cached premultiplied glyph support by a deterministic column mask. Whole-paragraph shaping, cluster boundaries, fallback, line breaks, advances, canvas dimensions, and integer vertical placement are unchanged. No new shaping, wall clock, simulation state, Metal, or export path is introduced. This bounded still-rendering experiment allocates temporary mask buffers; no new performance guarantee is claimed.

Actual Swift rendering at the ten archived phases preserves **byte-identical coverage and identical line metrics** in both directions. Consequently the prior geometry comparisons remain unchanged: vertical residual RMSE 0.408/0.503 px, maximum one px, common-origin IoU 0.873–0.936 overall, and width errors 0/+1 px.

Actual-renderer shared-interior RMS improves from **10.072/10.593 to 7.014/7.127**. Maximum individual-glyph RMS decreases from **45.183/50.602 to 25.918/27.759**. These scores retain the archived aggregation and include raster quantization. No independent glyph or line registration conceals disagreement.

## Visual Findings and Verification

The original synthetic fixture and private source/baseline/softened/difference composites were visually inspected, including first-line progression at PTS 5202 and second-line progression at PTS 6240. The softened treatment removes the conspicuous abrupt boundary in the inspected partial states. Outline-shaped residuals, second-line local differences, and brightness mismatches remain visible. The controlled background estimate is not a full-screen material match.

All release targets, **17 Swift tests**, **47 Python tests**, existing deterministic probe checks, synthetic outline/slice checks, and the new appearance check passed. The new check exercises synthetic model selection, held-out interpolation, unavailable support, cross-language mask agreement within one code level, and repeated PNG output. Swift tests verify random-order immutable state and byte-identical raw output, including fresh renderer instances and unchanged coverage.

Private validation reproduced archived observations, checked original hashes, completed both fitting directions and sensitivity variants, and verified the actual raster backend. Commands are documented in [Progressive Appearance Commands](appearance-commands.md).

The unchanged architecture-spike determinism and export checks passed: 1080×1920, 60 fps, 240 frames, four seconds, Rec.709, and four seconds of 48 kHz mono AAC. All decoded presentation timestamps and audiovisual markers passed. The existing endpoint-trimmed AAC padding convention is unchanged.

The initial sandboxed build could not write the Swift module cache and emitted a secondary SDK mismatch diagnostic; the permitted build succeeded without toolchain or source workarounds. A new synthetic measurement test exposed empty support handling, which now reports an unavailable interval. Its duration assertion was corrected to test the observed bracket rather than an unjustified exact midpoint. No failed run supplies retained measurements.

A fresh public-only checkout at implementation commit `698ad18` passed all release builds, 17 Swift tests, 47 Python tests, existing probe checks, synthetic outline/slice/appearance checks, and softened synthetic rendering. All seven private-reference commands returned explicit `unavailable` results. The checkout remained clean apart from ignored generated outputs; subsequent changes contain only documentation and sanitized numerical evidence.

Verification retains the Apple M4, macOS 27.0.1, Swift 6.4, macOS SDK 27, Python 3.12.14, NumPy 2.3.5, and Pillow 12.3.0 environment. Raster equality and numerical results are environment-specific.

## Privacy and Next Gate

Originals, transcriptions, appearance-event annotations, masks, renderings, inspection sheets, and detailed diagnostics remain ignored. Public changes contain code, original synthetic text, numerical evidence, and documentation only. Historical commits, reports, profiles, and backup references are preserved; no release or tag is created.

**Go for retaining the experimental softened appearance; no-go for claiming native appearance fidelity.** The Japanese slice is sufficiently bounded to support a separate Latin typography integration gate, first resolving its known wrapping sensitivity with existing references. Focus motion, dynamic materials, full-screen composition, Sing, and generalized lyric timing remain deferred. Further Japanese appearance work should first test residual boundary profiles across supported glyph interiors in the existing corpus rather than requesting new recordings or adding per-glyph corrections.
