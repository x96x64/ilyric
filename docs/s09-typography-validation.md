# iLyric S09 State-Controlled Typography Validation

## Disposition

**The shared Japanese base-size discrepancy is resolved for the measured sharp S08/S09 states; complete state-controlled typography remains a no-go.** The S08-selected public Core Text size 103.25 predicts both new S09 repetitions without adjustment, preserving the observed two-line structure with ink-width errors of 0 and +1 native pixel. All four recording exclusions retain that candidate. No screenshot-specific size is justified.

A single fixed paragraph transform and line advance do not explain all observed states. Progressive appearance is accompanied by repeatable relative vertical differences and changing masks. Independent line registration can conceal this failure. The evidence supports a shared experimental base configuration, but not a complete shared state rule or native Music fidelity. Production rendering and all prior engineering reports remain unchanged. The architecture remains retained with qualifications; no evidence justifies Metal.

## Reference Environment and Provenance

The reference remains reported iPhone 16 running iOS 27.0.1, exact build **Unknown**. Settings remain Default Display Zoom; Text Size 4/7, counting the smallest selectable size as 1/7; Bold Text, Reduce Motion, Reduce Transparency, and Increase Contrast off; Light appearance; English system and Music languages. Sing disabled and unchanged settings were explicitly confirmed for both new recordings. These are **reported metadata**, not independent Settings measurements. Continuous observed playback through the comparison interval supports the intended natural-playback condition; input-event timestamps were not recorded.

Directory comparison with the existing corpus discovered two additional recordings, assigned V09 and V10. Original-resolution source inspection and decoded sequences establish that both contain S09's Japanese-only two-line passage. Neither was substituted with S10. Existing V05/V06→S08 and V07/V08→S10 classifications are retained; the distinction between the two passages of the same song is additionally user-confirmed. Track identity is not required or published.

Exact filenames, source SHA-256 values, private text, original screenshots, recordings, extracted frames, masks, and inspection sheets remain ignored. Source hashes matched before and after processing. The [v4 profile](reference-data/v4/profile.json), [numerical results](reference-data/v4/s09-typography.json), and [PTS observations](reference-data/v4/observations.csv) record neutral identifiers and numerical evidence only. The internal profile is not a production schema. Previous v1–v3 evidence and reports remain intact.

## Verified Media Properties

Both originals are MP4-family containers containing 1180×2556 HEVC Main video, `yuvj420p`, full-range Rec.709 matrix, transfer, and primaries metadata. Audio is AAC LC, stereo, 44,100 Hz. Both streams begin at zero. These are file declarations, not display calibration.

| ID | Video / Audio Duration, Seconds | Container Samples / Decoded Frames | 9-Tick / 10-Tick Intervals |
| --- | ---: | ---: | ---: |
| V09 | 20.118333 / 20.085102 | 1210 / 1209 | 19 / 1189 |
| V10 | 20.450000 / 20.450476 | 1230 / 1229 | 20 / 1208 |

The nominal rate is 60/1, but original PTS use 1/600-second ticks with 15-ms and 16.667-ms adjacent intervals. Timestamps are strictly increasing; no longer interior intervals were found. Each recording has one terminal discard-marked packet. These observations do not establish display refresh rate or exclude pre-encoding capture omissions. The maximum audio/video endpoint difference is 33.231 ms; no vocal synchronization inference follows.

Reduced lyric-region comparisons found no byte-identical adjacent arrays and respectively 805/754 near-duplicate pairs below 0.05 mean grayscale code values. Compression and background changes prevent interpreting these as duplicated display frames.

## Reproduction and Method

The prior encoded-channel S08 size-102 and S09 size-103 screenshot bounds and registered metrics reproduced exactly. Representative v3 S08 size-103.25 comparisons and the color-managed S09 static comparison also reproduced exactly. Unrelated architecture, export, motion, and material experiments were not repeated.

The unchanged `ReferenceProbe` shapes each complete private paragraph using the public system-font API with bold symbolic traits. The local Japanese fallback remains `.HiraKakuInterface-W6`; native iPhone font identity remains **unknown**. Paragraph width 987 and initial line advance 128 are inherited reconstruction constraints. Sizes 101–106 in 0.25 increments form the bounded diagnostic grid. Explicit observed breaks remain separate from unknown authored semantics. No width adjustment forces wrapping.

New video measurements use native top-left pixel coordinates and full-range Rec.709-to-sRGB conversion. Screenshot comparisons retain their Display P3-to-sRGB conversion. Neither the extra recording column nor 9:16 delivery is used to distort layout. Known private text supplies correspondence; no OCR is used.

Every decoded frame in PTS 4200–7100 is analyzed: 291 observations per recording. All expected lines must be unambiguously identified, with full cell support. Foreground extraction retains the 18-pixel Gaussian background subtraction, thresholds 15/25/35, and tests luminance cutoffs 80/100/125/145. Baseline cutoff 100 is selected from the earlier documented dim-S09 failure at 145, before this gate's fit. Candidate alpha cutoffs are 96/127/160.

Measurements of ink and cell centroids are **image-derived observations**. Requested sizes, baseline proxies, spacing ratios, and registrations are **fitted reconstruction values**. Native-state explanations remain **inferences or hypotheses**. Numerical residuals below one pixel do not establish subpixel physical accuracy.

## State Sequence and Stability

Both recordings begin with the target below the active paragraph, dim and blurred. Around 7.6–8.0 seconds it moves upward and becomes sharp. The first complete baseline extraction occurs at PTS 4583/600 and 4573/600; the preceding frames bracket these support crossings within approximately 16.667 ms. They are not measured native activation times. The earliest masks retain blur and cannot establish font scale independently.

At PTS 4803/600 and 4802/600 the target is sharp but dim. Progressive brightening then traverses the first and second lines. At PTS 6240/600 the first line is bright while the second remains partly upcoming; PTS 6779/600 captures later second-line progression. Focus departs near 11.6 seconds, and the target loses sharp support. These are inspected presentation states, not source lyric timestamps or a Sing timing model.

The bounded-span criterion limits every line's left edge, ink top, and width to two pixels, with a maximum observation gap of 40 ms and minimum run duration 0.5 seconds. It does not constrain glyph height or brightness. A 0.1-second boundary guard defines fitting interiors.

| ID | Selected Run, PTS / 600 | Duration | Interior, PTS / 600 | Interior Frames |
| --- | --- | ---: | --- | ---: |
| V09 | 5432–6140 | 1.180 s | 5501–6071 | 58 |
| V10 | 5421–6120 | 1.165 s | 5481–6060 | 59 |

No two-second interval of complete unchanged typography is established. Horizontal widths remain stable longer, while vertical ink relationships and highlight treatment evolve. One- and three-pixel span variants choose different runs; boundary guards of 0/0.1/0.2 seconds all retain candidate 103.25 at the baseline extraction.

## Geometry and Shared Candidate

Both selected interiors measure line widths **742/653 pixels**, left edges **103/102 pixels**, and zero within-interior width deviation at integer-pixel resolution. Between-recording width difference is zero. First-line ink-top means are 710.276/710.288 pixels; second-line means are 837.690/837.678. Top standard deviations are approximately 0.45–0.50 pixels. Ink-top separation averages 127.414/127.390 pixels; this is not a native baseline advance.

| Fixed Size | S09 Line-Width Errors, Both Recordings |
| --- | --- |
| 102 | −9, −7 px |
| 103 | −2, −1 px |
| 103.25 | 0, +1 px |
| 103.5 | +2, +3 px |
| 104 | +5, +6 px |

Each S09 repetition independently selects 103.25 and predicts the other with width RMSE **0.707 pixels**. The combined equal-recording S08/S09 fit also selects 103.25, RMSE **0.707 pixels**. Excluding V05, V06, V09, or V10 preserves that size and observed structure; held-out RMSE is respectively **1.000, 0.000, 0.707, 0.707 pixels**. This is stronger than separately fitting each screenshot. The archived S08 widths remain 935/934 pixels, and their earlier screenshot remains narrower by 13–14 pixels; its different state is not silently relabeled as a font error.

Cutoffs 80/100 and tested candidate-alpha thresholds retain 103.25, with width RMSE approximately 0.707–1.581 pixels. At cutoff 125, partial dim support can shift selection to 103; cutoff 145 fails complete-paragraph support in some selected frames and is explicitly unavailable for fitting. This failure is retained rather than scored as a new typography discrepancy. The earlier S08 103.25–103.5 sensitivity band remains historical evidence; it is not retroactively narrowed.

## Spacing, Appearance, and Competing Models

The first-detectable-to-stable comparison produces apparently expanding first-line spacing, but its held-out residuals are large: approximately 2.164/0.815 pixels on line one and 3.932/1.998 on line two. Applying the archived S08 mean expansion ratio gives residuals up to 4.235 pixels. These are **failed controls**, not proof that the underlying size differs: the first detectable S09 masks remain blurred and partially supported, and their phase is not equivalent to the earlier S08 comparison.

Comparing the sharp dim phase with the later phase instead yields horizontal ratios **0.999090/0.998961** on line one and **0.998898/0.998746** on line two. Translation-only residuals are already approximately 0.25–0.35 pixels. Held-out spacing residuals are **0.155/0.154 pixels** and **0.276/0.235 pixels**, respectively. These small apparent contractions do not establish a meaningful native tracking change; higher cutoffs bias the centroids. A universal 1.1% expansion applied throughout active highlighting is unsupported. S08's earlier focus-transition evidence remains valid for its observed interval.

From the first-line-completed phase to the later phase, mean binary cell centroids on line two move upward approximately **2.03–2.06 pixels relative to line one**. Threshold/cutoff variants retaining the dim support yield approximately **2.014–2.082 pixels** across both recordings. This repeated relative movement is inconsistent with a common paragraph translation alone. Appearance-dependent support and local glyph treatment still prevent identifying a uniform scale, tracking operation, or font-metric change as Apple's implementation.

The smallest supported model therefore has a shared base font configuration plus an unresolved state-dependent vertical/appearance treatment. No per-recording size, per-line size, or arbitrary production offset was introduced.

## Localized Masks and Baseline Limits

At the selected interior representative frames, size 103.25 gives registered line IoU approximately **0.835/0.855** in both recordings. Baseline proxies are **789.25/918.25 pixels**, implying 129 pixels between independently registered lines. They are fitted proxies, not measured native baselines.

At the sharp dim phase, individual line IoU is approximately **0.889–0.891 / 0.856–0.858**. One common paragraph translation with fixed advance 128 reduces aggregate IoU to **0.725–0.726**. Later, the bright first line reaches approximately **0.922–0.925**, while the second varies with progression. At PTS 6779/600, individual second-line IoU is **0.801–0.808**, but common-origin aggregate IoU is only **0.757–0.760**. Independent alignment must not conceal this paragraph-level discrepancy.

Fitted baseline-proxy separation is 123 pixels in the sharp dim phase, 129 in the selected interior, 126 around first-line completion, and 123 in the later phase. Testing a fixed 127-pixel candidate advance does not remove the need for different relative registrations. A universal line advance or baseline-state correction is therefore not validated. Paragraph spacing remains unmeasured.

Registration-window sensitivity and threshold variants are retained in v4 results. The private alternate-code-point diagnostic modestly worsens second-line mask agreement without changing width; it does not establish the native source encoding. Outline, rasterization, antialiasing, blur, and partial-progress differences remain distinct from the now-stable base-size fit. No whole-screen similarity score or final fidelity threshold is adopted.

## Implementation, Verification, and Limitations

The validation layer adds unambiguous multiline support checks, whole-paragraph stability vectors, common-origin mask registration, explicit external-model predictions, phase-specific measurements, and synthetic regression coverage. Whole-paragraph shaping, rational timestamps, production typography, motion, materials, export, and delivery policies are unchanged.

The release probe build, nine Swift tests, 32 Python tests, both deterministic probe integration checks, and private S09 validation passed. A fresh public checkout at the tooling commit, without the private corpus, passed the same release build, nine Swift tests, 32 Python tests, and both probe checks. All four reference-dependent commands returned explicit `unavailable` results; its working tree remained clean apart from ignored build outputs. Subsequent changes contain documentation and numerical evidence only. Commands and private protocol are documented in [S09 Typography Validation Commands](s09-typography-commands.md). No export benchmark is repeated because the export and renderer are unchanged.

Analysis uses the existing Apple M4/macOS 27.0.1 environment, Swift 6.4, FFmpeg 8.1.2, Python 3.12.14, NumPy 2.3.5, and Pillow 12.3.0. Results remain environment-specific. An initial extraction stopped when a dim cell had no foreground support; the corrected diagnostic records such observations as unavailable rather than treating them as valid landmarks. Source media and all reference-bearing diagnostics remain private.

## Next Engineering Gate

**Go for retaining one experimental Japanese base configuration; no-go for declaring the complete state-controlled typography gate or a temporal fidelity slice validated.** The prior 102-versus-103 discrepancy no longer warrants separate Japanese size constants. The remaining blocker is relative vertical glyph/line treatment during progressive appearance, not missing S09 repetition.

The smallest next experiment uses the existing V09/V10 recordings: compare corresponding sharp glyph outlines before, during, and after their appearance change with one held-out repetition, preserving a common paragraph origin. Test whether a bounded vertical treatment explains the residuals without changing base advances or independently shaping timed units. This is a typography diagnostic, not authorization to refine motion timing or introduce production animation. No additional capture is required immediately. A measured Lyrics vertical slice should follow only when that state distinction survives the common-origin and held-out checks; unresolved Latin wrapping and mixed-script semantics remain separate limits.
