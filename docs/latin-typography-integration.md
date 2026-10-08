# iLyric Measured Latin Typography Integration

## Disposition

The evidence supports a shared experimental **static Latin configuration conditional on supplied observed line structure**. It does not establish a shared automatic-wrapping rule or native Music fidelity. Size 104.25 native pixels remained selected in every case exclusion and extraction-sensitivity variant. Common-origin vertical residuals remain larger than the completed Japanese result and require state-controlled investigation before Latin motion or appearance integration.

The production renderer, export backend, Japanese typography, bounded vertical treatment, and softened appearance are unchanged. Historical reports and reference profiles remain archival records.

## Reference Evidence and Integrity

The sources are private screenshots S02, S03, S04, and S05; the existing calibration identifier S04B denotes the observed-break comparison of S04. All four files were verified as 1179×2556 PNG images with Display P3 profiles. Their private transcriptions agree with the observed line text when line boundaries are replaced with spaces; punctuation was retained. OCR was not used.

The reported device is iPhone 16 running iOS 27.0.1, with build **Unknown**. Reported settings remain Default Display Zoom, Text Size 4/7 counting the smallest setting as 1/7, Bold Text off, Reduce Motion off, Reduce Transparency off, Increase Contrast off, Light appearance, and English system and Music languages. Capture-state assertions from the later Japanese recordings were not transferred to these English screenshots.

The previous screenshot inventory did not contain original SHA-256 values. A private hash inventory was therefore established in this gate and verified again after processing. This demonstrates preservation during this investigation, not retrospective verification against an unavailable historical hash. All four archived numerical comparisons reproduced exactly, providing additional continuity evidence.

Coordinates remain native capture pixels with a top-left origin. The 1179-pixel screenshot width remains distinct from the 1180-pixel recording width. No delivery transform was changed. Inputs, hashes, text, renderings, and source-bearing diagnostics remain under ignored `reference-private/`.

## Baseline Reproduction and Method

The archived size-104.5, width-987 comparisons reproduced their complete comparison records, including visible bounds, registration, baseline proxies, and mask agreement. Historical line-width errors were +2/+3/+3 pixels for S02, +3/−2/+1 for S03, 0/+2 for S04, and +3/+3/0 for S05. Their case-balanced width RMSE was approximately 2.236 pixels.

Historical reproduction retained the original encoded-channel extraction. New measurements interpreted the embedded Display P3 profile and converted to sRGB before localized extraction. Neither encoded intensity nor mask membership is calibrated luminance or measured opacity.

The candidate grid used public system-font selection with bold traits, sizes 103.5–105 in 0.25-pixel increments, and widths 983, 987, and 991 pixels. The locally resolved `.SFNS-Bold` name is environment provenance, not identification of the native iPhone Music font. No font files were copied or redistributed.

Two structure hypotheses were compared: inherited private input structure and explicitly supplied observed boundaries. Whole-paragraph Core Text shaping was preserved in both. Incorrect wrapping made a candidate ineligible. Case-balanced width error prevented longer paragraphs from dominating selection. Each case was subsequently excluded from selection and predicted without size retuning.

Primary extraction used contrast threshold 25, intensity floor 100, and candidate alpha threshold 127. Sensitivity varied contrast through 15/25/35, intensity floor through 100/145, and alpha through 96/127/160. These are diagnostic extraction choices, not native presentation parameters. The lower floor retains partially dim glyph support.

## Observed Breaks and Wrapping

S02 and S03 have three observed lines and no explicit newline in the inherited input. S04 has two observed lines and an explicit observed break in its existing comparison input. S05 has three observed lines but no inherited newline.

At size 104.25, unbroken S04 input did not reproduce the observed structure at any tested width. An explicit observed constraint remains necessary within this candidate family. The evidence does not establish whether that constraint came from authored lyric structure, another input rule, or native layout behavior.

S05 exposes a different ambiguity. At size 104.25, width 983 produces the observed line structure automatically; width 987 produces a longer second line and shorter third line. The competing second line has a Core Text typographic width of 985.259 pixels, whereas the observed constrained second line measures 732.753 pixels. This is a genuine wrapping boundary within the tested width uncertainty. It does not justify choosing a screenshot-specific width or declaring the observed boundary source-authored.

With explicit observed boundaries, widths 983, 987, and 991 tie. Width 987 is therefore retained as a **provisional prior**, not a newly identified native width. The resulting held-out experiment predicts widths conditional on supplied structure; it does not predict the structure itself.

## Shared Latin Configuration

With inherited structure at width 987, size 104.5 achieved width RMSE 1.837 pixels under the new extraction. Excluding S05 selected 104.25 and failed to reproduce S05 wrapping. This model is not stable as an automatic-layout explanation.

With observed structure, size 104.25 achieved case-balanced width RMSE 1.225 pixels. Every exclusion retained that size.

| Reference | Line-Width Errors (Pixels) | Held-Out Width RMSE (Pixels) | Independent Line-Mask IoU |
| --- | --- | --- | --- |
| S02 | 0, +1, +1 | 0.816 | 0.809, 0.863, 0.872 |
| S03 | 0, −3, 0 | 1.732 | 0.884, 0.815, 0.880 |
| S04 | −1, +1 | 1.000 | 0.874, 0.877 |
| S05 | 0, 0, −2 | 1.155 | 0.814, 0.876, 0.847 |

All exclusions across the 18 extraction variants retained size 104.25. Full-set width RMSE ranged from 1.225 to 1.486 pixels; the largest sensitivity-test held-out width RMSE was 1.915 pixels. This supports parameter stability within the tested family and corpus, not universal Latin typography support. Previous weight and optical investigations were not repeated without new contradictory evidence.

## Common-Origin Geometry

Visible ink, typographic advances, and fitted baselines were measured separately. First-line visible ink begins at y=716–718 across the four references. Baselines cannot be read directly from these ink bounds: punctuation, descenders, partial brightness, and raster support differ.

A case-balanced fit to the diagnostic baseline proxies produced one shared x origin of 96.083 pixels, first baseline of 791.165 pixels, and line advance of 125.479 pixels. These are reconstruction parameters. Individual paragraph fits gave advances from 123.5 to 129 pixels, indicating unresolved vertical or appearance-state variation. They do not establish paragraph spacing.

The principal comparison renders each paragraph with one shared origin and advance. No per-line registration or per-reference translation is applied. Independent line registration supplies diagnostic residuals only. In each exclusion, origin and advance were fitted from the remaining cases.

| Held-Out Reference | Common-Origin Mask IoU | Baseline-Proxy RMSE (Pixels) | Maximum Absolute Baseline Residual (Pixels) |
| --- | --- | --- | --- |
| S02 | 0.797 | 1.735 | 2.937 |
| S03 | 0.737 | 2.935 | 4.079 |
| S04 | 0.799 | 2.049 | 2.444 |
| S05 | 0.785 | 2.672 | 4.037 |

Excluded-case first-baseline fits ranged from 790.213 to 791.853 pixels, advances from 125.000 to 126.111, and x origins from 96.000 to 96.222. Full-set common-origin IoUs were 0.799, 0.780, 0.799, and 0.796 respectively. Full-set horizontal ink-origin errors were zero except for a −1-pixel S03 third-line difference.

Additional origin-registration windows of ±3, ±5, and ±7 pixels were diagnostic only. Improvements from those translations were not substituted for the principal scores. Threshold sensitivity was most pronounced in S05, whose common-origin IoU varied from 0.723 to 0.804 as dim support was excluded. This demonstrates why a single mask score cannot establish geometry fidelity.

The approximately 4.08-pixel maximum held-out vertical residual remains inside the earlier approximately five-pixel baseline investigation band, but that band is not a final acceptance requirement. Residual vertical structure remains material and unresolved.

## Experimental Integration

`LyricsSliceProbe` now accepts the internal `latinStatic` paragraph style and an original `synthetic-latin` fixture. The style supports one to four rendered lines, automatic wrapping or explicit observed boundaries, and static opacity. It rejects progressive appearance configuration, appearance events, and nonzero vertical-treatment amplitude. Japanese timing parameters are not inherited.

A single whole-paragraph Core Text typesetter remains responsible for shaping. Complete shaped lines are rasterized without independently shaping timed words or characters. Source ranges and break classifications distinguish automatic wrapping, explicit observed boundaries, and paragraph end. The internal representation is not a finalized public lyric schema.

The public synthetic fixture uses size 104.25 and width 987 with rounded origin (96, 687) and advance 125.5. Private comparisons use the full-precision fitted origin and advance reported above. The rounded synthetic defaults are not additional native measurements.

Immutable rational-time state and arbitrary-order evaluation are preserved. Static Latin appearance does not vary with timestamp. Existing Japanese fixture selection and omitted-style behavior remain compatible.

## Verification and Visual Findings

Release builds passed. The complete suite passed 20 Swift tests and 50 Python tests. Public deterministic checks covered the original probe, typography, glyph outlines, Japanese slice, progressive appearance, and Latin integration. Latin fixtures cover single lines, explicit boundaries, automatic wrapping, punctuation, kerning-sensitive pairs, ligature-capable words, and combining characters. Complete alpha rasters and source ranges matched the unchanged whole-paragraph `ReferenceProbe` for the shaping-isolation fixtures. Repeated and reordered timestamps produced identical raster output in the measured environment.

All 20 archived V09/V10 Japanese phase comparisons reproduced coverage images, appearance images, and state JSON byte-for-byte. The earlier Japanese geometry and appearance evidence therefore remains unchanged. The original synthetic export regression also passed: 1080×1920, 60 fps, 240 frames, four seconds, Rec.709 video, and four seconds of 48 kHz mono AAC, including timestamp and audiovisual-marker checks.

A fresh public checkout at implementation commit `151ba56`, without private references, passed release builds, both test suites, all deterministic checks, and all three synthetic slice fixture modes. Nine reference-dependent commands returned explicit `unavailable` states. Detailed commands are recorded in [Latin Integration Commands](latin-integration-commands.md).

Visual inspection of private source/rendering contact sheets confirmed the constrained line structures and width relationships. Vertical and outline differences remain visible. The reference mixes dim and bright progressive support; the static white rendering deliberately does not reproduce that appearance. The original synthetic Latin still showed readable punctuation and no clipping. These observations do not establish native fidelity.

During test development, an overlong automatic-wrap fixture correctly exceeded the four-line experimental limit and was shortened. A numerical fitting assertion was changed from exact floating-point equality to a tolerance. Neither issue required widening renderer scope. Existing linker warnings did not prevent successful verification.

## Privacy and Reproducibility

Source and diagnostic ignore rules were verified before processing. Public version-8 evidence contains numerical measurements, neutral identifiers, fitted parameters, and classifications only. Private text, source filenames, source imagery, and personal paths are excluded. Staged changes were reviewed for protected content and credentials before publication.

The measured environment was Apple M4, macOS 27.0.1, Swift 6.4 (`swiftlang-6.4.0.30.4`), macOS 27 SDK, Python 3.12.14, NumPy 2.3.5, and Pillow 12.3.0. Raster equality is an environment-specific regression result. No new performance or cross-platform raster claim is made.

## Remaining Uncertainty and Next Gate

Native font identity, source-authored break semantics, a unique automatic-layout width, and the causes of the vertical differences remain unknown. Four static English cases cannot establish a universal script rule, paragraph-spacing policy, or timing model.

Proceed with constrained static Latin integration as an experimental result. The next gate should measure **Latin anchor and line-advance behavior across states in the existing recordings**, before implementing focus motion or progressive appearance. The smallest experiment is to follow the same English paragraph through sharp comparable states and test whether the present vertical residuals persist under controlled support and common-origin registration. Existing recordings should be inspected before requesting additional captures. Automatic source-break inference remains outside the supported model.
