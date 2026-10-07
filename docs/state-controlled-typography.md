# iLyric State-Controlled Japanese Typography Refinement

## Disposition

**Continued uncertainty: the evidence does not yet validate a shared S08–S09 Japanese typography model.** Two new recordings reproduce the S08 passage. The other two contain the mixed-script passage represented by S10, not the S09 two-line paragraph. All four files are readable, but the required repeated S09 state evidence is absent. No recording was substituted for a missing case.

S08 provides a useful result: its lower-position screenshot is not representative of the later stable upper-anchor geometry. Repeated recordings show expansion of interior glyph spacing during focus movement, beyond the observed threshold sensitivity. A public-system-font candidate at requested size 103.25 fits both stable S08 recordings with small held-out width errors and also explains the S09 screenshot widths. This is a **fitted reconstruction hypothesis**, not an established native size or state rule. The first measured Lyrics fidelity vertical slice remains deferred until the S09 comparison is controlled.

Production rendering, motion, materials, encoding, delivery transforms, and `ReferenceProbe` are unchanged. The architecture remains retained with qualifications; this experiment does not justify Metal or establish native Music fidelity.

## Reference Environment and Private Provenance

The reported device remains iPhone 16 running iOS 27.0.1, exact build **Unknown**. Configuration remains Default Display Zoom; Text Size 4/7, counting the smallest selectable size as 1/7; Bold Text, Reduce Motion, Reduce Transparency, and Increase Contrast off; Light appearance; and English system and Music languages. These settings were not independently verified in a Settings capture. Apple Music Sing was **reported disabled in all four new recordings**. Track title and identity are not established by this study.

V05–V08 are neutral identifiers for the four additional files. Their exact filename mapping, SHA-256 integrity records, original media, known text, extracted frames, masks, and contact sheets remain under ignored `reference-private/`. Correspondence was determined by visual comparison with private S08, S09, and S10 screenshots and the decoded sequences, not by filename order. V05 and V06 contain S08; V07 and V08 contain S10. Neither S09 nor both requested cases were identified in any new recording. The later pair shows a different passage, despite belonging to the same visible presentation context as S09.

The original recordings were read without transcoding, trimming, overwriting, or changing their timestamps. Decoded derivatives were written separately. Source SHA-256 checks before and after analysis matched. Public [v3 profile](reference-data/v3/profile.json), [numerical results](reference-data/v3/state-typography.json), and [observations](reference-data/v3/observations.csv) contain only reviewed numerical evidence and neutral identifiers. Historical reports and v1/v2 evidence remain unchanged.

## Verified Recording Metadata

All four files are MP4-family containers with 1180×2556 HEVC Main video, decoded as `yuvj420p`, full-range (`pc`) Rec.709 matrix, transfer, and primaries metadata. Audio is AAC LC, stereo, 44,100 Hz. Video and audio start at zero. These are file declarations, not a display calibration.

| ID | Observed Correspondence | Video / Audio Duration, Seconds | Container Samples / Decoded Frames | 9-Tick / 10-Tick Intervals |
| --- | --- | ---: | ---: | ---: |
| V05 | S08 | 10.235000 / 10.228549 | 616 / 615 | 9 / 605 |
| V06 | S08 | 10.450000 / 10.422880 | 629 / 628 | 10 / 617 |
| V07 | S10; S09 absent | 19.220000 / 19.203129 | 1156 / 1155 | 18 / 1136 |
| V08 | S10; S09 absent | 19.938333 / 19.937937 | 1199 / 1198 | 17 / 1180 |

Nominal frame rate is 60/1; actual presentation timestamps use 1/600-second ticks with 15-ms and 16.667-ms intervals. All decoded PTS are strictly increasing, with no longer interior intervals. Each file has one discard-marked terminal packet, accounting for a one-sample container/decoder discrepancy. This does not establish a dropped display frame. Capture omissions before encoding and display-to-capture latency remain unknown. Audio/video endpoint differences reach 27.120 ms in V06; no vocal synchronization claim is made.

In a fourfold-reduced 1040×1400 lyric-region diagnostic, no adjacent decoded arrays are byte-identical. Respectively 204, 289, 772, and 803 adjacent pairs differ by less than 0.05 mean grayscale code values. Background variation and compression prevent classifying these as duplicate display refreshes. The counts measure regional similarity only.

## Reproduction and Measurement Method

The archived S08 size-102 and S09 size-103 native bounds, registration, baseline proxies, and mask IoU reproduced exactly before extension. The reproduction retained the historical encoded-channel measurement method. It did not silently replace earlier evidence with color-managed results.

New comparisons use native capture pixels, top-left origin. The 1179-pixel screenshot width and 1180-pixel recording width remain distinct; no 9:16 transformation or width distortion is applied. Screenshots are converted from their embedded Display P3 ICC profile to sRGB through ImageCms. Video is decoded with its full-range Rec.709 metadata and converted to sRGB through FFmpeg. Numerical code values are therefore not compared directly across unconverted P3 and Rec.709 sources. Color conversion and clipping still limit photometric interpretation.

Known private paragraph text is shaped whole by the unchanged Core Text probe. The inherited width 987 and line advance 128 are reconstruction constraints, not newly measured layout constants. Requested sizes 101–106 are tested in 0.25-pixel increments. Font APIs, resolved names, typographic advances, and visible ink are distinguished. No OCR, per-word shaping, font extraction, or source-asset reuse is involved.

For S08, every decoded frame within original PTS 1700–2900 is analyzed at native resolution. The private protocol specifies the inspected text region, broad line-size bounds for target isolation, and ten fixed cell windows for corresponding glyph ink centroids. These are analysis selections, not rendering constants or automatic lyric recognition. A detection is not itself evidence of full activation or sharpness.

Foreground extraction subtracts an 18-pixel Gaussian background estimate. Contrast thresholds 15/25/35 and luminance cutoffs 100/145 test sensitivity; candidate alpha thresholds are 96/127/160. Interior glyph centroids use independently normalized binary support. Local registration compares each complete line within ±5 pixels; ±3 and ±7 windows provide an additional check. Whole-screen SSIM and PSNR are not used.

## State Sequence and Stable Intervals

V05 and V06 begin with the target below the active line, dim and blurred. Earlier focus changes move its position before it becomes sharp. Foreground support first passes the diagnostic selection at PTS 1837 and 1887, respectively. The preceding samples are 1827 and 1877: approximately 3.045–3.062 seconds and 3.128–3.145 seconds bracket this **threshold crossing**, not the native activation event. Initial masks remain incomplete and must not determine font size.

The target subsequently moves upward and expands in width. It becomes geometrically stable near ink top y=720, then loses sharp support as focus moves onward near 4.6 seconds. Three spatial contrast groups brighten together over the early inspected frames; no independent glyph-progress timing model is established for this line. Changing blur, brightness, and mask support remain separate from measured spacing.

A deterministic bounded-span procedure identifies runs whose ink top and width each remain within two pixels, with no gap above 40 ms and at least 0.5 seconds of observations. This establishes geometric stability, not a native animation state. A 0.1-second guard at each boundary excludes transition-edge appearance from calibration.

| ID | Geometric Stability, PTS / 600 | Observed Duration | Interior Comparison, PTS / 600 | Comparison Frames |
| --- | --- | ---: | --- | ---: |
| V05 | 2197–2746 | 0.915 s | 2257–2686 | 44 |
| V06 | 2217–2786 | 0.948 s | 2277–2726 | 46 |

Neither recording establishes two seconds of settled target display. Changing the span allowance to one or three pixels alters the selected boundaries; these alternatives remain in the numerical evidence. They are investigation settings, not fidelity thresholds.

V07 and V08 begin with earlier lines of the S10 passage, then display the two-line right-aligned mixed-script paragraph. Progressive appearance changes are visible while its lower position persists around 5–9 seconds; it moves upward around 9–11 seconds, followed by the final visible line. These approximately one-second inspection intervals establish correspondence and sequence only. No S09 activation, stable interval, line advance, or repeatability result can be recovered from them.

## Geometry, Repeatability, and Baselines

At the baseline extraction settings, the interior S08 widths are **935 pixels in V05 and 934 pixels in V06**, each with zero within-interval width standard deviation at integer-pixel resolution. Both have ink left x=104 and ink top y=720. Heights vary between 86 and 87 pixels; standard deviations are approximately 0.403 and 0.469 pixels. The one-pixel between-recording width difference falls within extraction sensitivity: lower cutoffs recover widths near 935 in both captures. Across tested extraction settings, mean widths span 934.068–935 for V05 and 934–935 for V06.

The original S08 screenshot has measured width 921 pixels. The 13–14-pixel difference from the new stable states exceeds the approximately one-pixel sensitivity of those states. The video comparison preserves a single unbroken line and left alignment. The independent S09 screenshot retains its observed two-line boundary; its source-authored semantics remain unknown. No width adjustment was used to force wrapping.

At candidate size 103.25, representative S08 baseline proxies equal **799.25 pixels** in both recordings. They are fitted through mask registration, not directly visible baselines. Size 103.5 yields 799.5; size 103 yields 800. The S09 screenshot, measured after color conversion with a sufficiently low cutoff, yields proxies 789.25 and 916.25, advance 127. These differences do not establish a universal anchor, paragraph spacing, or line-advance rule. S08 is only one line; no new multiline advance can be measured from its matched content.

## Apparent Scale and Competing Explanations

Relative to the color-managed S08 screenshot, representative stable-frame interior landmarks fit horizontal spacing ratios **1.014491** and **1.014440**. Across tested foreground settings the ratios span 1.014327–1.014672 and 1.014293–1.014598. Translation-only residual RMSE is 3.923/3.907 pixels; fitting spacing and translation reduces it to 0.125/0.069 pixels. These are fitted landmark diagnostics, not subpixel physical accuracy guarantees.

A same-recording comparison avoids relying on screenshot/video raster equivalence. Frames nearest the screenshot's vertical position occur at PTS 1877 and 1927; their positions are not exactly equal to the screenshot because motion is sampled discretely. From those frames to the stable representatives, fitted spacing expands by **1.063% and 1.115%**. Translation-only RMSE is 2.889/3.029 pixels, versus 0.120/0.092 with spacing fitted. Training the spacing ratio on the other recording and allowing only translation registration on the held-out recording gives RMSE **0.187/0.170 pixels**, maximum residual **0.444/0.339 pixels**. This validates repeated spacing change for the matched line, not onset timing or a continuous animation curve.

The interior landmarks move apart across the line; a brightness-only or boundary-threshold explanation is inadequate for this observation. The near-invariant stable height and remaining raster differences do not independently identify a uniform two-dimensional scale transform. Font-size changes, horizontal transforms, tracking, or combined treatment remain competing implementation explanations. No fitted quantity is attributed to Apple's private implementation, and no motion primitive is changed.

## Core Text Fits and Held-Out Results

The recording-only shared width objective selects **103.25**, with equally weighted recording RMSE **0.707 pixels**. Excluding V05 selects 103.25 and predicts V05 with RMSE 1 pixel. Excluding V06 leaves 103.25 and 103.5 tied on V05; the deterministic selection of 103.25 predicts V06 with zero width error. The tied 103.5 candidate instead produces a two-pixel V06 error. All preserve the observed single-line structure.

| Fixed Candidate | V05 Width Error | V06 Width Error | Representative Mask IoU, V05 / V06 |
| --- | ---: | ---: | ---: |
| 102 | −13 | −12 | 0.707 / 0.709 |
| 103 | −5 | −4 | 0.871 / 0.873 |
| 103.25 | −1 | 0 | 0.927 / 0.927 |
| 103.5 | +1 | +2 | 0.945 / 0.945 |
| 104 | +5 | +6 | 0.873 / 0.871 |

Geometry and shape objectives disagree slightly: 103.5 improves IoU without minimizing width error. Extraction/alpha sensitivity selects 103.25–103.5; held-out width RMSE reaches 2 pixels. Registration windows ±3/5/7 all select the same one-pixel horizontal shift and identical IoU for size 103.25. These observations support a provisional candidate band, not an exact production constant.

The public emphasized-system selection, Japanese language hint, disabled optical sizing, and weight 0.4 reproduce the selected Japanese geometry locally. Weights 0.3 and 0.5 resolve different local fallback weights and alter ink width by approximately two pixels in either direction while preserving the 953.370-pixel typographic advance. No extra weight parameter was selected to absorb the state difference. The default resolves `.HiraKakuInterface-W6`; this is macOS provenance, not native iPhone font identity.

## Independent Screenshot Checks and Remaining Raster Differences

The recording-selected size 103.25 predicts color-managed S09 screenshot widths with errors **+1/+2 pixels**, provided the luminance cutoff retains the upcoming glyphs. At cutoff 100, line IoU is **0.945/0.783**. This is an independent static observation, but its activation phase and repetition remain uncontrolled. The uncertain second-line code point and incomplete highlighting limit outline conclusions.

Applying the old cutoff 145 after P3-to-sRGB conversion removes much of the dim second line. Its detected width collapses from 652 to 309 pixels, producing a misleading +345-pixel width error and IoU 0.470. Cutoffs 80/100/125 recover the full width. This is a measurement-support failure, not evidence of a new font discrepancy. The failed result is retained explicitly. Historical measurements are not reclassified because their encoded-channel method was different and reproduced exactly.

Conversely, size 103.25 is 13 pixels too wide for the earlier S08 screenshot and gives IoU approximately 0.747 at cutoff 100. A universal static-size substitution therefore fails that independent observation. A state-qualified explanation is plausible, but S09 recordings are required before claiming a shared Japanese rule. Width agreement alone cannot settle font outlines, rasterization, baseline semantics, native font identity, or authored breaks.

## Implementation and Verification

The validation layer adds deterministic bounded-span stability summaries, interior-landmark fitting, leave-one-recording-out spacing checks, PTS-preserving decoding, color-managed comparisons, and explicit missing-correspondence reporting. Whole-paragraph shaping and existing candidate-selection logic are reused. No production source or existing historical report is modified.

Public tests exercise actual timestamp duration, missing observations, gradual drift, invalid ordering, translation versus spacing, held-out scale exclusion, and unavailable private inputs using synthetic numerical fixtures. Source captures and diagnostics remain ignored; no private input is required to build or test the repository. [Reproduction commands](state-controlled-typography-commands.md) specify the private manifest and environment requirements.

The release probe build, all nine Swift tests, all 24 Python tests, and both existing deterministic probe integration checks passed. Private checks verified all four source recordings, reproduced the prior Japanese measurements, and explicitly reported `measured_with_missing_correspondence` for S09. A fresh public checkout without `reference-private/` passed the release build, all nine Swift tests, all 24 Python tests, and both probe integration checks. The physical-reference, typography-calibration, and state-control commands each returned explicit `unavailable` results; the checkout remained clean apart from ignored build outputs. No export benchmark was repeated because rendering and encoding are unchanged.

Analysis used the existing Apple M4/macOS 27.0.1 environment, Swift 6.4, FFmpeg/ffprobe 8.1.2, Python 3.12.14, NumPy 2.3.5, and Pillow 12.3.0. The system Python lacked NumPy; private analysis used an available dependency environment. An initial raw-video diagnostic used the encoder's default time base and emitted rounded-DTS warnings despite matching decoded counts. Supplying the source time base removed those warnings; final PTS pairing and counts were verified. Neither warning nor successful process exit was used as proof of capture correctness.

## Next Engineering Gate

Continue the same narrow Japanese state-control gate. The minimum missing evidence is **two original recordings of the exact S09 two-line passage**, approximately **6–8 seconds each**, beginning before activation and continuing through its natural stable interval and departure where feasible. Use the same device settings, Sing disabled, and no manual scrolling or pause during the comparison interval. Identify the passage from the private S09 screenshot, not from S10 or a track-name assumption. Preserve the full available stable interval; do not manufacture a two-second interval if playback does not provide one.

No additional S08 capture is presently required. Compare the new S09 stable observations with the recording-selected 103.25–103.5 candidate band, preserve the observed line break, and hold out each repetition. Only a shared configuration or observable state rule that survives that comparison can justify progression toward the first measured Lyrics fidelity vertical slice. Existing Latin wrapping, mixed-script alignment, motion, and material qualifications remain separate unresolved conditions.
