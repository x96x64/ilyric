# Latin Glyph-Outline Motion Validation

## Disposition

Proceed to the first measured full-screen Lyrics composition. The remaining motion discrepancy is a **bounded approximation error with unresolved measurement and phase uncertainty**, not a demonstrated architectural limitation. No renderer, typography, motion, export, or delivery-policy parameter changes are made. A relative-line diagnostic improves average agreement but does not establish a transferable native geometry rule.

This conclusion applies to one repeated English transition in V01–V03. It does not establish native Music fidelity, general Latin motion behavior, or Apple's private implementation. The [motion-composition report](motion-composition.md) and all earlier reports remain unchanged. New numerical evidence is recorded in [profile v10](reference-data/v10/profile.json), [motion comparisons](reference-data/v10/motion.json), and [sensitivity summaries](reference-data/v10/sensitivity.json).

## Reference Environment and Integrity

The reference device is a reported iPhone 16 running iOS 27.0.1, build **Unknown**. Recorded settings remain Default Display Zoom; Text Size 4/7 counting the smallest as 1/7; Bold Text, Reduce Motion, Reduce Transparency, and Increase Contrast off; Light appearance; English system and Music languages.

V01, V02, and V03 were located through the established private inventory. Their original SHA-256 values and complete decoded presentation-timestamp lists matched the archived inventory. Hashes were checked again after analysis. Originals were not modified. The source geometry remains 1180×2556 recording pixels, distinct from 1179×2556 screenshots. Original full-range Rec.709 interpretation was retained before conversion to sRGB for diagnostic processing.

Each recording supplied 180 frames: PTS 1208–2995 for V01/V02 and 1208–2996 for V03, in units of 1/600 second. Frame selection and alignment use those timestamps, not frame number divided by 60. The common native template is V01 at PTS 2825/600. That shared template is an explicit measurement reference; it is not a new renderer origin or per-recording calibration.

The archived 540-observation trajectory and v9 critical-response results were reproduced before extension. The archived six directional holdouts had 2.218–2.253-pixel positional RMSE and 8.939–9.816-pixel peaks. No historical value was replaced.

## Outline and Common-Coordinate Method

Eight fixed spatial regions span the same known three-line paragraph: three regions on each of the first two lines and two on the third. Correspondence follows the existing private transcription and inspection; OCR is not used. Whole-paragraph shaping, supplied line boundaries, font configuration, advances, and layout remain fixed and outside the fitting search.

Native-resolution crops are decoded without temporal resampling. A top/bottom-border median estimates local background. Positive foreground contrast is normalized by its 95th percentile with a 20-code-value floor. The primary method normalizes each column; a global-gain alternative measures sensitivity to spatially varying appearance. These nonlinear sRGB-channel contrast values are neither measured alpha nor calibrated physical luminance.

Thresholded row profiles are registered within ±14 native pixels around the archived coarse trajectory. Low correlation or boundary optima are unavailable, rather than forced measurements. The principal threshold is 0.5; 0.35 and 0.65 provide sensitivity checks. Registration is integer-pixel and cannot establish subpixel physical displacement.

A median of supported local shifts provides one common translation per frame. Local shifts minus that translation expose residual structure. Independent region fits are diagnostic only: the principal prediction uses one fitted common trajectory plus, for the relative candidate, one shared coefficient. It never uses per-frame local offsets to improve the reported common-origin mask score.

Paired vertical contour edges provide a second diagnostic. Columns with incompatible edge counts or excessive displacement are excluded, and coverage is reported. This avoids converting missing or changing glyph support into an unconditional geometric measurement.

## Competing Explanations and Holdouts

Three bounded explanations were evaluated: fixed rigid geometry; rigid geometry with appearance-dependent extraction; and one relative-line treatment. No additional motion-curve family was introduced.

The relative diagnostic is `c * (line_index - 1) * (1 - progress)`, centered on the middle line. The coefficient is bounded to ±10 pixels. For residual decomposition, progress is measured common displacement normalized between early and late observations. For predictive comparisons, progress comes from the frozen critical-response curve. Neither quantity identifies native lyric-event timing.

### Common Translation and Phase

The critical time constant remains **0.081 seconds**. Onset, offset, and amplitude are fitted on alternating observations from a training recording. Held-out recordings use half-displacement correspondence, not independent onset prediction. With the new normalized-outline anchor, six directional holdouts give **2.502–2.624 pixels RMSE**, with **7.024–9.242-pixel peaks**.

This is not a demonstrated improvement over the archived centroid RMSE: the anchor and normalization changed. Peaks are somewhat lower, but the remaining trajectory error persists. Changing the time constant to absorb it is not justified.

Perturbing correspondence by ±1/60 second raises RMSE to **5.339–6.486 pixels** and peaks to **22.857–28.562 pixels**. This is a bounded sensitivity experiment, not a measured native onset uncertainty interval. Capture time is known; native event onset remains inferred. Timing and motion-shape error cannot be completely separated with these observations.

### Relative Residuals

Leave-one-recording-out fits use the other two recordings, with no held-out coefficient retuning:

| Held-Out Recording | Coefficient (Pixels) | Rigid Residual RMSE | Relative Residual RMSE | Relative Maximum |
| --- | ---: | ---: | ---: | ---: |
| V01 | −4.269 | 2.789 | 1.595 | 5.000 |
| V02 | −4.658 | 2.618 | 1.682 | 5.000 |
| V03 | −4.240 | 2.821 | 1.552 | 5.000 |

These are residuals after measured common translation, not complete animation-prediction errors. Early first-line residual means are +4.778 to +5.578 pixels; third-line means are −3.500 to −2.467 pixels. Late first-line means are −0.456 to +0.400 pixels and the other line means are zero under this decomposition. A repeated apparent relative pattern therefore remains after common movement is removed.

The stricter predictive comparison trains both common motion and the relative coefficient on one recording and tests another. Across all six directions, rigid local-position RMSE is **3.393–3.813 pixels**; the relative candidate gives **2.730–2.951 pixels**. Common-origin native-template IoU increases from **0.679–0.688** to **0.688–0.706**. Relative-model peaks remain **8.309–11.067 pixels**, and one direction has a slightly worse peak than rigid prediction. Single-recording coefficients range from −3.890 to −4.679 pixels.

The improvement comes from one additional relative degree of freedom, not a better critical-response curve. The template belongs to V01; although it is fixed across comparisons, training and validation are not completely independent of this shared measurement template. The corpus does not support a general font, scaling, tracking, or baseline rule.

## Appearance Support and Measurement Sensitivity

Global versus column normalization retains the relative pattern. Across thresholds and normalization variants, two-recording fitted coefficients range from **−4.988 to −4.240 pixels**, and relative residual RMSE ranges from **1.447 to 1.818 pixels**. At threshold 0.35, 42 V03 region observations become unavailable; the primary threshold retains all 4,320 region observations. A narrower ±10-pixel search retains 3,898 observations with identical shifts and rejects 422. Rejection is a support limitation, not evidence of zero motion.

Fixed-geometry controls apply symmetric Gaussian blur of 0, 2, 4, or 6 pixels and uniform or spatially varying contrast to private native support. Across 288 threshold/region/appearance combinations, apparent registration changes span **−2 to +2 pixels** despite no geometry change. This establishes a plausible source of bias, not an exhaustive simulation of native compositing. It does not explain the full repeated early relative pattern by itself.

Paired contours retain early first-line mean displacements of +4.426 to +4.732 pixels and third-line means of −3.148 to −1.823 pixels. However, early first-line column coverage is only 24.7–25.1%, compared with roughly 76.5% late coverage. Blurred outlines, partial highlighting, background gradients, and threshold-dependent support substantially limit geometric interpretation. Late contour means are near zero, with a first-line maximum mean of +0.597 pixels across recordings.

Private visual inspection of early, moving, and late native frames confirmed a blurred upcoming paragraph, sharpening during movement, and nonuniform brightness in later states. The observations support the numerical concern about changing outline support. They do not independently establish a relative transform. Common-origin red/green mask overlays show reduced early vertical disagreement with the relative candidate, but retain contour-thickness differences and moving-phase translation residuals. Late overlays largely coincide. No font-size, width, or line-advance correction was introduced.

## Implementation and Verification

The changes add focused Python common-translation, bounded fitting, profile-registration, support-control, and private comparison tools. Numerical records contain neutral identifiers and aggregate measurements only. Original references, masks, crops, transcriptions, and generated diagnostics remain ignored; no source-derived imagery is published.

All 24 Swift tests and 57 Python tests passed. Release builds, existing deterministic probe checks, new synthetic outline controls, and archived motion reproduction also passed. The private V01–V03 experiment completed with the limitations reported above. Latin integration results exactly reproduce v8 numerical evidence. Twenty Japanese private renderings reproduce archived appearance PNGs, coverage PNGs, and state/layout JSON byte-for-byte. No Swift source or renderer behavior changes.

The existing six-second composition export remains 1080×1920, exactly 60 fps, 360 decoded frames, with AAC audio starting at zero and lasting six seconds. All video presentation timestamps pass validation; audiovisual marker errors are zero under the existing marker checks. Encoder priming and decoded trailing padding are handled by the existing media validator. Encoded-file byte identity is not required.

A fresh public checkout passed verification without the private corpus, including release builds, all public tests, deterministic probes, original Latin/Japanese synthetic stills, composition export, and explicit unavailable results from private commands. Reproduction commands are documented separately in [Latin outline commands](latin-outline-commands.md).

## Next Gate

**Go: first measured full-screen Lyrics composition.** Retain the current analytic focus motion with its qualified residual envelope. Keep the relative-line candidate diagnostic; neither its limited generality nor its geometric interpretation justifies integration.

The minimum next scene should combine the already measured artwork and header placement, title/artist geometry, lyric viewport, progress, transport, volume, and bottom controls with original assets and explicit timing. Preserve native coordinates, distinct capture geometries, and an explicit delivery transform. Clipping, inactive appearance, materials, and timing must retain their measured or provisional classifications. Full Music reproduction and native fidelity remain unestablished. No new physical capture or additional narrow motion-model search is required before that integration experiment.
