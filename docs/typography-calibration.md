# iLyric Native-Space Typography Calibration

## Disposition

**A shared typography model suitable for the first measured Lyrics fidelity vertical slice is not yet established.** A small public-system-font model substantially explains ordinary Latin ink geometry, but wrapping remains sensitive to an underidentified paragraph width. Two Japanese cases require different effective sizes under the tested model. The mixed-script case does not establish a general alignment or fallback rule.

The Swift, Core Text, Core Graphics/Core Image, and AVFoundation architecture remains **retained with qualifications**. This experiment does not contradict deterministic arbitrary-time rendering or justify Metal. Production typography, motion, materials, output transforms, and the `ilyric` executable are unchanged. No native iOS 27 Music fidelity claim follows from these results.

## Starting Evidence and Provenance

The [planning study](planning-study.md), [architecture spike](architecture-spike.md), [physical-reference validation](physical-reference-validation.md), and [v1 reference profile](reference-data/v1/profile.json) remain unchanged historical records. Before extension, the four archived typography comparisons reproduced exactly: native ink bounds, selected candidate advances and widths, and threshold-specific first-line mask IoU. The reproduction workflow additionally retains the unbroken S04 diagnostic.

The reference environment remains reported **iPhone 16, iOS 27.0.1, build Unknown**, Default Display Zoom, Text Size 4/7 with the smallest selectable size counted as 1/7, Bold Text off, Reduce Motion off, Reduce Transparency off, Increase Contrast off, Light appearance, and English system and Music languages. No externally researched build identifier was substituted.

Eight original screenshot sources were analyzed: S02, S03, S04, S05, S07, S08, S09, and S10. S04B denotes the explicit-observed-break comparison of S04, not another capture. The originals are 1179×2556 Display P3 screenshots. All measurements remain in native screenshot pixels with a top-left origin; UIKit points and safe-area semantics are not inferred. Recordings were not reanalyzed during this static gate. Their previously verified metadata and timing findings remain in the historical report.

Originals, private transcriptions, probe inputs, crops, masks, and inspection composites remain under ignored `reference-private/`. Git ignore checks and tracked-file audits precede processing and publication. Public [v2 profile](reference-data/v2/profile.json) and [numerical results](reference-data/v2/typography.json) contain sanitized identifiers, measurements, fitting results, and qualifications only. They are an internal evidence supplement, not a finalized project schema.

## Methodology and Evidence Categories

Known text was supplied through the private workflow; OCR was not used. Observed line structure is stored independently of the input paragraph. S02, S03, S05, and the separately evaluated Sing-related S07 use automatic wrapping. S04B, S09, and S10 use explicit observed boundaries whose source semantics remain unknown.

Each candidate uses one Core Text typesetter for the entire paragraph. Source ranges are UTF-16 ranges; timed words, highlight units, and glyphs are not laid out separately. The probe reports drawing origins, typographic widths excluding trailing whitespace, ascent/descent/leading, baseline-relative glyph-path bounds, resolved run metrics, and explicit versus automatic input breaks. These local metrics are distinct from screenshot ink bounds.

The initial grid varied requested size from 101 to 106 pixels in 0.25-pixel steps at width 987. Widths 983 and 991 were separately tested at sizes 104–105 in 0.25-pixel steps, using the earlier ±4-pixel width uncertainty rather than an unconstrained screenshot-specific width search. Reference ink extraction retains the previous 18-pixel background-blur subtraction and tests contrast thresholds 15, 25, and 35. Candidate alpha thresholds 96, 127, and 160 test raster-edge sensitivity. Additional reference luminance cutoffs 100, 125, and 145 expose dim-glyph sensitivity. These code-value operations are not calibrated photometric measurements.

Selection requires matching observed line content and line count, then minimizes mean squared ink-width error with equal weight per case. Incorrect wrapping is ineligible regardless of width score. Leave-one-case-out analysis records excluded-case errors, wrapping failures, and all equally scored candidates. Sing-related S07 is excluded from ordinary Latin fitting. Individual-line mask IoU uses bounded integer registration within ±5 pixels after ink-origin alignment. Registration translations and boundary hits remain visible; independently registered lines do not prove a correct shared paragraph layout.

Native ink bounds are **measured image-derived values**. Sizes, baselines, registration translations, and selected configurations are **fitted reconstruction parameters**. Proposed explanations are **engineering inferences**. Investigation bands are **provisional**, and unidentifiable properties remain **unknown**. No fitted model is attributed to Apple's private implementation.

## Font Models and Public API Findings

The unchanged synthetic spike resolves Helvetica and HiraginoSans-W3 locally and remains too small. Its historical discrepancies reproduced without change.

The default candidate selects the public system UI font and applies the bold symbolic trait. On this Apple M4/macOS 27.0.1 environment it resolves `.SFNS-Bold` and `.HiraKakuInterface-W6`. The emphasized-system UI font, English/Japanese UI-font language hints, explicit automatic optical sizing, and weight 0.4 reproduce the default candidate geometry. The resolved names describe this macOS environment only; native Music font identity remains unknown.

Disabling optical sizing or specifying optical size 34 changes Latin advances and can change wrapping. For example, S02 no longer preserves the observed structure; S03 ink-width errors become approximately +22/+17/+8 pixels with optical sizing disabled. Weights 0.3 and 0.5 respectively narrow or widen Latin geometry and do not explain a general improvement. No additional weight or optical-size parameter was retained. This bounded probe does not exhaust all public font variations.

The Japanese fallback reports requested size 104, an identity font matrix, and weight approximately 0.4, yet S08's ten-glyph advance totals 960.295 pixels. At size 102 the advance is 941.828 pixels. A requested size is therefore not a direct measurement of glyph advance or optical ink size. UI-font language hints and optical-size variants do not change this Japanese geometry. Weight variants change ink slightly while leaving these advances unchanged. No proprietary font files were extracted or redistributed.

## Line Structure and Alignment

S04's observed boundary is not reproduced by the unbroken input at widths 983, 987, or 991. Its original unbroken comparison allocates UTF-16 line lengths 20/3; the observed-break input allocates 16/7. S09 likewise wraps unbroken input as 10/5 rather than the observed eight- and seven-character lines. S10's observed two-line structure also requires a boundary constraint under the tested width range.

These are **observed input constraints with unknown source semantics**. The evidence does not distinguish source-authored newlines, content metadata, or another native layout constraint. Width was not reduced to conceal these cases. Automatically matching S02, S03, or S05 also does not prove their source lacks authored breaks.

S10 remains explicitly right-aligned as observed. At size 104 and the inherited x=96 canvas origin, its two right ink-edge errors are +2 and 0 pixels; left-edge errors are +2 and −5 pixels. Alignment is therefore evaluated separately from paragraph width and local registration. There is no evidence that mixed script itself selects right alignment.

## Latin Results and Parameter Stability

At width 987, the shared ordinary Latin fit selects size **104.5**, with case-balanced ink-width RMSE **2.236 pixels**. Sizes are fitted in native raster coordinates, not measured native font settings.

| Case | Line Ink-Width Errors, Pixels | Registered Line IoU at the Baseline Threshold |
| --- | --- | --- |
| S02 | +2, +3, +3 | 0.808, 0.838, 0.827 |
| S03 | +3, −2, +1 | 0.895, 0.830, 0.846 |
| S04B, observed break | 0, +2 | 0.879, 0.827 |
| S05 | +3, +3, 0 | 0.785, 0.811, 0.640 |
| S07, separate Sing-related static check | −1, +2, +2 | 0.904, 0.863, 0.850 |

Excluding S02, S03, or S04B retains size 104.5; held-out width RMSE is respectively 2.708, 2.160, and 1.414 pixels. Excluding S05 selects 104.25 and fails the held-out wrapping requirement. At that size, a longer second line still fits within 987 pixels. This discrete failure cannot be represented as a small width residual.

At width 983, size 104.25 yields RMSE 1.458 pixels and all four fixed-width exclusion checks preserve wrapping. At width 991, size 105 is required by the full set, with RMSE 5.500 pixels. Joint width/size selection favors 983/104.25, but excluding S05 leaves widths 983, 987, and 991 equally scored at size 104.25; only 983 preserves S05's held-out structure. Thus the apparently better narrow-width fit is not independent evidence that native width equals 983. The boundary remains underidentified.

Contrast/alpha sensitivity retains Latin size 104.5 at width 987; case-balanced RMSE ranges 2.236–2.979 pixels. Lower luminance cutoffs reduce this to 1.837–1.947 pixels without changing the selected size. The geometry is promising, but parameter stability is conditional on width and observed input structure.

## Japanese and Mixed-Script Results

| Case and Candidate | Ink-Width Errors, Pixels | Registered Line IoU |
| --- | --- | --- |
| S08, size 102 | +1 | 0.925 |
| S09, size 103 with observed break | −1, 0 | 0.890, 0.764 |
| S10, size 104 with observed break and right alignment | 0, +5 | 0.777, 0.745 |

The two Japanese cases jointly select size 102.25, with case-balanced width RMSE 4.183 pixels. Excluding S08 selects 103 and produces a +9-pixel held-out width error. Excluding S09 selects 102 and produces held-out errors −8/−6 pixels, RMSE 7.071. Candidate alpha sensitivity shifts the joint optimum to 102.5. A Japanese-specific size of 102 is therefore not supported as a general correction.

S08 has a sharp active line substantially below the ordinary first-line anchor. S09 has a two-line paragraph near the upper anchor with visibly different completed/upcoming treatment. State, content, font/fallback metrics, and capture rasterization are not independently controlled. Their relative contribution remains unknown; apparent effective-size differences must not be labeled a measured native scale animation.

One S09 second-line glyph has uncertain source code-point identity. An alternate-form diagnostic at size 102 leaves width errors unchanged but changes second-line IoU from 0.695 to 0.684. This does not identify the native encoding and limits outline claims for that line. Punctuation observations in Latin and CJK are insufficient for general punctuation or fallback rules.

The mixed-script width objective selects size 103.5, with errors −3/+1 and RMSE 2.236 pixels. Its first-line IoU is only 0.733, compared with 0.777 at size 104 and 0.798 at 104.5. Minimizing width alone therefore does not optimize outline agreement. Alpha and luminance sensitivity shift its optimum to 103.75. A single mixed-script case cannot support an exclusion test or a new script-specific rule.

A shared size across ordinary Latin, Japanese, and mixed cases selects 104.5 but has case-balanced width RMSE **10.156 pixels**; S08 is 24 pixels too wide. The evidence rejects promotion of that single-size candidate, not the Core Text architecture.

## Baselines, Line Advance, and Paragraph Spacing

Baseline proxies register each candidate line to its screenshot mask and translate the known Core Text baseline into native coordinates. They remain **fitted proxies**, not directly observed native baselines.

At Latin size 104.5, per-case first-baseline fits span **789.0–793.83 pixels**. Fitted line advances are S02 125.0, S03 125.5, S04B 129.0, and S05 124.0 pixels. A case-balanced shared regression gives first baseline **791.466**, line advance **125.325**, residual RMSE **1.903**, and maximum absolute residual **3.291 pixels**. These are diagnostic summary parameters, not new rendering constants.

The earlier approximate baseline y=792 remains compatible with a conservative **±5-pixel investigation band**. There is no justification for a one-pixel baseline acceptance rule. The earlier approximately 128-pixel line advance is not established as universal: independently registered line proxies span 124–129 pixels. S09's fitted advance is 127 pixels; S10's is 128. Neither establishes transfer across states or scripts.

Side bearings explain why native ink edges are not identical to the paragraph origin. Partial highlighting, dim glyphs, blur, outline differences, and rasterization can influence registration. Inactive paragraphs are not controlled samples of paragraph spacing: their blur and state differ, and source grouping is unresolved. No universal paragraph-spacing parameter was fitted from the line-advance measurements.

## Measurement Sensitivity and Remaining Differences

At the default candidate alpha threshold, changing contrast thresholds 15–35 leaves extracted widths unchanged and moves some vertical ink edges by one pixel. Lowering the luminance cutoff changes some edges by up to two pixels. This supports a provisional **0–2-pixel extraction-sensitivity allowance**, not a final geometry tolerance or a complete uncertainty budget.

S05's third-line width is unchanged when the luminance cutoff decreases from 145 to 100, but IoU rises from **0.640 to 0.863**. The default cutoff excludes parts of dim glyphs. It would be incorrect to attribute that entire discrepancy to font outlines. S09's second line is also threshold-sensitive; at size 103 its IoU ranges approximately 0.735–0.768 over contrast thresholds. Bright S08 is more stable: size-102 IoU ranges 0.923–0.928.

Localized shape residuals remain even where line widths match. No whole-screen SSIM or PSNR was used. The sensitivity study does not measure physical repeat-capture variability: these are repeated analyses of fixed images. Exact local reproduction and deterministic probe pixels establish tool repeatability only. No final fidelity thresholds are adopted.

## Implementation and Verification

`ReferenceProbe` now exposes bounded public font controls and per-line/run diagnostics. The validation layer adds UTF-16 range interpretation, case-balanced selection, exclusion analysis, tied-candidate reporting, baseline-proxy fitting, and threshold/width sensitivity. The old foreground routine gains an optional luminance cutoff while preserving its default behavior. Production renderer and timeline sources are unchanged, as are `contain`, `cover`, and `adapt` concepts.

Validation used Apple M4, macOS 27.0.1, Swift 6.4 (`swiftlang-6.4.0.30.4`), macOS 27 SDK, Python 3.12.14, NumPy 2.3.5, and Pillow 12.3.0. Results are environment-specific. A sandboxed initial build could not write the compiler module cache; the permitted build then succeeded. Existing Command Line Tools linker search-path warnings remain nonfatal.

The release probe build, all nine existing Swift tests, all seventeen Python unit tests, the existing eight-evaluation random-access probe check, and the new synthetic typography integration checks passed. The latter cover explicit/automatic breaks, UTF-16 source coverage, alignment, line advance, public font options, invalid inputs, and identical PNG output across repeated timestamps. Private baseline reproduction reported four archived cases with no differences; extended calibration analyzed eight cases. Native S08/S09 state crops and S05/S09 candidate comparisons were visually inspected locally.

A fresh public checkout without `reference-private/` built and passed the complete Swift and Python suites and both probe integration checks. Both physical-reference analysis and typography calibration returned an explicit `unavailable` state without the private corpus. No media export benchmark was repeated because this gate changes neither production rendering nor export. Reproduction commands and private input conventions are documented in [Typography Calibration Commands](typography-calibration-commands.md).

## Next Engineering Gate

Proceed with **state-controlled typography refinement**, not a cross-script fidelity vertical slice. The smallest material unresolved question is whether the Japanese size difference persists when the same glyphs are observed repeatedly in comparable settled active states. The Latin wrap-boundary sensitivity should remain an explicit validation condition; source-authored break semantics must not be guessed.

Minimum additional evidence: for each Japanese passage represented by S08 and S09, provide **two original recordings of approximately 6–8 seconds**, covering arrival in the active state and at least two seconds of settled readable display. Preserve device settings, record whether Sing is enabled, and avoid manual scrolling during the settled interval. These four short recordings distinguish repeatability and state effects from a fixed script correction; they do not authorize a motion or highlighting-model refinement in this gate. No additional English capture is required immediately. Previously documented temporal and material capture requirements remain separate.

Retain the calibrated candidates and uncertainty bounds in validation tooling. A subsequent measured vertical slice should begin only after a shared rule or defensible state distinction explains Japanese geometry and survives exclusion checks without screenshot-specific size constants.
