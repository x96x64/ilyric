# iLyric Common-Origin Glyph-Outline Validation

## Disposition

**Go for a first measured Japanese Lyrics typography vertical slice, with explicit qualifications.** Repeated V09/V10 observations support a small bounded vertical-treatment reconstruction over the shared size-103.25 Core Text paragraph. Fixed geometry with appearance normalization does not explain the observed contour displacement. The remaining uncertainty is sufficiently bounded for an experimental slice; native Music fidelity and Apple's private implementation remain unestablished.

This conclusion supersedes the previous gate's unresolved disposition without modifying its historical report. Production rendering, focus motion, materials, export, UI, and delivery transforms are unchanged. The architecture remains retained with qualifications; Metal is not justified by this experiment.

## Reference Evidence

The device remains reported iPhone 16, iOS 27.0.1, build **Unknown**. Reported settings remain Default Display Zoom; Text Size 4/7 counting the smallest selectable size as 1/7; Bold Text, Reduce Motion, Reduce Transparency, and Increase Contrast off; Light appearance; English system and Music languages. Sing disabled and unchanged settings in V09/V10 were previously confirmed. These are reported capture conditions, not independently inspected Settings measurements.

Both original recordings remain mapped to the Japanese-only S09 passage. Source SHA-256 values matched the prior private inventory before and after analysis. Full decoding again yielded 1209 frames for V09 and 1229 for V10. Verified historical metadata remains 1180×2556 HEVC Main, full-range Rec.709, AAC LC stereo at 44,100 Hz, and 1/600-second video time base. Video durations are 20.118333 and 20.450000 seconds; audio durations are 20.085102 and 20.450476 seconds. Nine- and ten-tick adjacent intervals remain distinct from nominal 60 fps. No new capture or correspondence investigation was required.

Six freshly decoded, color-managed frames were pixel-identical to the prior extractions. The sharp-dim, first-line-completed, and late common-origin measurements reproduced exactly, including sharp-dim IoU 0.725122/0.725813 at the old fixed 128-pixel advance. This establishes continuity with v4 rather than silently replacing its extraction method.

Original media, source hashes, private text, crops, masks, and visual inspection sheets remain ignored. Only neutral identifiers and numerical evidence appear in the [v5 profile](reference-data/v5/profile.json), [results](reference-data/v5/glyph-outline.json), and [observation table](reference-data/v5/observations.csv). These are internal validation records, not a final project schema.

## Phase Selection and Measurement

The new extraction covers PTS 4753–6819 in V09 and 4752–6819 in V10, with 208 decoded observations each. Every timestamp is an original PTS; elapsed time is computed using the verified 1/600 time base.

| Phase | V09 PTS | V10 PTS | Interpretation |
| --- | ---: | ---: | --- |
| Sharp dim | 4803 | 4802 | Both lines dim; residual common settling remains possible |
| Early progression | 4922 | 4922 | First line starts brightening |
| First-line progression | 5202, 5501, 5791 | 5202, 5501, 5791 | Sequential appearance changes |
| Second-line progression | 6071, 6240, 6420 | 6070, 6240, 6420 | First line bright; second line changing |
| Later progression | 6600, 6779 | 6599, 6779 | Second line remains partly upcoming |

These are observed appearance phases, not native lyric events. Phase pairs differ by at most one tick at the selected timestamps, but equivalent glyph appearance can differ more. Therefore the model uses each recording's observed brightness-crossing brackets rather than assuming equal PTS implies identical progress. Each crossing is bracketed by adjacent decoded frames, approximately 15–16.667 ms apart. The final glyph does not reach the baseline-195 crossing in V09 before extraction ends; that crossing is explicitly unavailable. V10 brackets it at PTS 6799–6809, after the last scored phase at 6779. No fully bright, stationary two-second paragraph interval is claimed. Blurred entry and departure remain outside the fitted domain.

Whole-paragraph shaping remains canonical. The unchanged `ReferenceProbe` uses the public bold system-font API, size 103.25, width 987, and the existing explicit observed break. The local Japanese fallback remains `.HiraKakuInterface-W6`; native font identity and authored-break semantics remain unknown. The original 128-pixel raster advance is retained for reproduction. A shared fitted advance correction is then applied to already shaped output; there is no independent line or character shaping.

Fifteen fixed spatial observation windows, inherited from the inspected paragraph geometry, cover the corresponding glyph regions. They do not define a general timing-unit schema. The shared horizontal origin remains x=98; the vertical coordinate parameterization starts at y=686 with a 123-pixel reference advance. Both vertical origin and advance receive shared fitted corrections. Choosing 123 as the coordinate parameterization does not constrain the fitted advance to that value.

For each window, the median of its upper and lower eight-pixel borders estimates background. A column-wise 95th-percentile foreground contrast normalizes brightness, retaining dim portions during partial highlighting. Threshold 0.5 defines the primary outline mask. This is a measurement-support model, not an opacity measurement or material reconstruction. Comparisons interpret full-range Rec.709 into sRGB; a separate linear-light variant applies the sRGB transfer inverse before normalization. Channel averages are diagnostic intensity measures, not calibrated luminance.

Independent vertical registration supplies diagnostic outline-position observations. Final paragraph scoring uses one trained origin, one trained advance, and the same state rule everywhere. It never substitutes independently registered glyph or line positions into the held-out reconstruction. The complete paragraph score aggregates all nonoverlapping observation windows in their common coordinate system. This localized metric is distinct from the v4 whole-line binary-mask metric and from whole-screen similarity.

## Competing Models

The fixed-geometry model fits only one origin and one advance after appearance normalization. Thus brightness, local background, and partial horizontal highlighting can change without moving the layout. Synthetic fixed-outline controls additionally apply observed column-wise contrast and zero- or one-pixel blur.

The measurement-support explanation is tested through those controls, threshold changes, background-border changes, global versus column-wise normalization, linear-light interpretation, and contour-support rejection. An additional brightness-linked geometric proxy tests whether instantaneous intensity alone adequately predicts the apparent displacement. Its intensity endpoints, 145 and 252 in the diagnostic sRGB channel average, are provisional descriptive levels, not native opacity constants.

The bounded vertical candidate uses:

```text
y = 686 + b + line × (123 + d) + A × (1 + u) × exp(−u)
u = max(0, elapsedSinceObservedBrightnessCrossing) / tau
```

The response is the upcoming limit before the crossing or when the crossing is absent. Its four shared fitted parameters are origin correction `b`, advance correction `d`, amplitude `A`, and time constant `tau`. The time-constant grid spans 0.08–0.40 seconds in 0.01-second steps; linear least squares determines the other parameters, with amplitude bounded to 0–10 pixels. A threshold-195 crossing of mean supported interior intensity supplies the explicit event variable. This analytic form is an iLyric reconstruction candidate, not identification of an Apple spring or animation implementation.

Parameters are fitted on one recording and evaluated on the other without geometric retuning, then reversed. The held-out recording supplies its own measured appearance events. These are conditional geometry predictions, not predictions of lyric timing from audio or text. Both repetitions informed exploratory protocol inspection; the reverse holdouts are not a blinded independent corpus experiment.

## Held-Out Results

Each direction evaluates 150 glyph observations across ten phases. Position errors compare continuous model predictions with integer-pixel diagnostic outline registrations. Mask scoring rounds the predicted displacement to an integer pixel. Subpixel residuals therefore do not imply subpixel physical measurement accuracy.

| Model | V09 → V10 RMSE / Maximum | V10 → V09 RMSE / Maximum |
| --- | ---: | ---: |
| Fixed geometry, normalized appearance | 2.408 / 4.743 px | 2.521 / 5.013 px |
| Instantaneous-brightness proxy | 1.111 / 4.306 px | 1.123 / 4.270 px |
| Bounded vertical treatment | **0.383 / 1.354 px** | **0.531 / 1.482 px** |

| Training Recording | Origin Correction | Fitted Advance | Amplitude | Time Constant |
| --- | ---: | ---: | ---: | ---: |
| V09 | −0.084 px | 123.014 px | 6.030 px | 0.19 s |
| V10 | −0.100 px | 123.047 px | 5.843 px | 0.20 s |

The corresponding settled first-baseline proxies are approximately 789.17 and 789.15 pixels. These are fitted registration values, not directly measured native baselines. The advance describes the underlying reconstruction after separating progressive vertical treatment; it does not invalidate the historical observation that independently registered apparent separations varied from 123 to 129 pixels.

Held-out common-origin paragraph IoU is **0.892–0.934** for V09 → V10 and **0.873–0.936** for V10 → V09. Fixed geometry yields 0.681–0.832 and 0.674–0.831, respectively. Mean glyph IoU rises from 0.779/0.773 to 0.919/0.914; minimum glyph IoU rises from 0.440/0.441 to 0.821/0.800. The improvement is not confined to an aggregate score, although localized outline and raster differences remain. The earliest two sharp phases produce the weakest common-origin agreement.

No horizontal scaling, tracking change, width adjustment, rewrapping, or new size was introduced. The S08/S09 base-size evidence and historical held-out width RMSE of 0–1 pixel are retained, including the S09 742/653-pixel ink widths and candidate width errors of 0/+1 pixel. Vertical treatment over the existing shaped support does not alter horizontal glyph advances. The new state response has only been tested on S09, not asserted as a universal S08, Latin, mixed-script, or CJK rule.

## Contours and Appearance Bias

Native-to-native comparisons from PTS 6240 to 6779 identify second-line integer contour shifts of approximately **−1, −2, −3, −5, −3, −1, and 0 pixels**, in the same spatial order in both recordings. Independently translated native masks retain IoU 0.932–0.998. Paired vertical contour crossings corroborate the displacement: the fourth window changes by −5.204 and −5.078 pixels on average, while the final upcoming window changes by only −0.008 and −0.016 pixels. The paired-edge method rejects columns with changed edge counts or ambiguous displacement and reports coverage rather than assigning zero motion to lost support.

First-line windows are substantially more stable but not uniformly stationary: the final first-line window still changes by approximately −0.743/−0.648 pixels in contour position. This qualifies a strict interpretation of “first line completed.” Its brightness is complete before every outline has settled.

These spatially ordered contour changes explain why the earlier average second-line centroid moved approximately two pixels without requiring a two-pixel rigid shift of the entire line. The evidence favors a progressing local vertical treatment. It does not prove which native compositing operation produces it.

Across 600 fixed-outline appearance controls, contrast and tested blur produce **zero best-fit integer displacement**. Centroid shifts nevertheless range from −0.268 to +0.526 pixels, illustrating appearance-dependent support bias. This bounded control cannot reproduce the observed five-pixel contour displacement. It does not exhaust all possible asymmetric native appearance kernels. Uniform font resizing, a changing base advance, and separate per-reference sizes are unnecessary within the measured sharp interval.

## Sensitivity and Uncertainty

Thresholds 0.35/0.50/0.65, global normalization, linear-light interpretation, added one-pixel blur, and four-/eight-/twelve-pixel background borders retain amplitudes approximately 5.72–6.03 pixels and time constants 0.18–0.20 seconds. Held-out position RMSE remains approximately 0.355–0.538 pixels; maxima remain below 1.50 pixels. Three registration windows, −8…8, −8…12, and −8…18 pixels, select the same displacement in all 300 primary observations.

Changing the brightness crossing from 195 to 180 or 210 expands the fitted time-constant band to 0.17–0.21 seconds. Held-out RMSE becomes 0.374–0.549 pixels, with maximum 1.561 pixels. Excluding the earliest two or three training phases retains amplitudes 5.99–6.05 pixels and time constants 0.19–0.20 seconds; evaluating all held-out phases gives maxima up to 1.694 pixels. The earliest sharp observations remain the principal residual limitation, consistent with incomplete focus settling or state correspondence error.

These results support provisional **investigation bands**, not final fidelity requirements: approximately two pixels of local vertical residual over this sharp interval, roughly six pixels of bounded treatment, and approximately 123 pixels of reconstructed base advance. Crossing uncertainty, integer registration, phase selection, capture compression, and renderer rasterization limit precision. No native baseline, native font identity, exact highlight semantics, or private animation implementation has been established.

## Implementation and Verification

Changes are limited to deterministic diagnostic fitting, outline-support analysis, reverse holdouts, synthetic tests, and new evidence records. `ReferenceProbe`, production sources, all historical reports, and v1–v4 data remain unchanged. The model is not integrated into production.

The release probe build, nine Swift tests, 39 Python tests, both existing deterministic probe checks, and the new synthetic outline-support check passed. Private validation reproduced the six historical comparisons, verified original hashes, and completed the common-origin and sensitivity experiments. Private source/model/difference sheets were inspected; no visual diagnostic is published. Commands are recorded in [Glyph-Outline Validation Commands](glyph-outline-commands.md).

An initial diagnostic run failed because a glyph window extended left of the probe image; explicit transparent padding corrected the coordinate handling. No result from that failed run is used. An auxiliary inspection script initially shadowed a standard-library module and was renamed within the private diagnostics. A cross-runtime exact-coefficient check differed at floating-point roundoff; the same-runtime check reproduced coefficients exactly. These failures did not require changes to the renderer or the physical evidence.

A fresh public-only checkout at tooling commit `a8ca799` passed the release build, all nine Swift and 39 Python tests, both deterministic probe checks, and the synthetic outline check. All five reference-dependent commands returned explicit `unavailable` results. The checkout remained clean apart from ignored build outputs. Subsequent changes contain documentation and sanitized numerical evidence only.

The analysis retains the existing Apple M4, macOS 27.0.1, Swift 6.4, FFmpeg 8.1.2, Python 3.12.14, NumPy 2.3.5, and Pillow 12.3.0 context. Public checks also run with the system Python. Toolchain linker search-path warnings persist, but all Swift tests execute successfully. Results remain environment-specific.

## Next Engineering Gate

**The Japanese ambiguity is sufficiently bounded for a first measured typography slice.** Its minimum scope is one experimental native-space, two-line Japanese paragraph with whole-paragraph shaping, the shared base configuration, explicit observed break constraints, and deterministic appearance-event inputs. Evaluate arbitrary rational timestamps with one common origin and the bounded vertical candidate; retain synthetic public text and private comparisons separately.

The next slice should preserve shaping when mapping presentation state to glyph support, verify the provisional two-pixel investigation band across held-out phases, and report residual outline differences. It must not imply solved focus motion, materials, complete UI fidelity, general Japanese timing, or native-font identity. No additional physical recording is required before this bounded integration experiment.
