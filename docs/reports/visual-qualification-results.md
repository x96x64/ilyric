# Visual Qualification Results

## Status

October 12, 2026. **Complete. The visual preset does not meet the approved thresholds: controls meet them, and title marquee, background, typography, focus motion, word fill, the gap indicator, and inactive lines each fail at least one measure.** All eight properties of the approved [Visual Qualification Plan](visual-qualification-plan.md) were measured on the held-out captures N01 to N06 and the six held-out screenshots, with the thresholds fixed beforehand; a property, once measured, cannot be refitted on these captures. Under decision 14 of the [roadmap](../roadmap-to-stable.md), the stable release proceeds on this report as a documented record of fidelity, with the differences below stated as known differences, rather than on a pass of every property.

## Second Capture Set

On October 12, 2026, the maintainer recorded three further captures, N08 to N10, after the background spread adaptation was developed. Before any of them was analysed, they were assigned to re-qualify the background with the same thresholds; the title band of N08, the only one with an overflowing title, is development material for the marquee, whose background remains held out.

## Results

| Property | Measure | Threshold | Result | Met |
| --- | --- | --- | --- | --- |
| Controls | Ink-bounds centre of seven plain control symbols in three paused screenshots | ≤ 3 px | maximum 0.5 px, mean 0.1 px over 21 measurements | Yes |
| Controls | Delay from playback start to the lower controls hiding | 3.79 s ± 0.2 s | 3.80 to 3.87 s, maximum error 0.08 s | Yes |
| Title marquee | Start delay after playback start (N01) | 8.11 s ± 5% | 8.20 s | Yes |
| Title marquee | Cycle period for the measured scroll distance of 942 px | ± 5% | 13.47 s against 13.45 s | Yes |
| Title marquee | Displacement during the first scroll, modulo the scroll distance | RMS ≤ 2 px | 6.6 px | No |
| Background | Mean colour, CIEDE2000, mean over six songs | ≤ 6 | 6.29 (per song 3.3 to 10.8) | No |
| Background | Spatial lightness spread sL, mean absolute relative difference | ≤ 20% | 33% (per song −42% to +41%) | No |
| Typography | Automatic wrapping: line word counts of 83 focused paragraphs (53 with several lines) | identical for every paragraph | 70 of 83 identical (40 of 53 multi-line) | No |
| Typography | Ink width per line, iLyrics minus native | within ±6 px for every line | 116 of 129 lines within ±6 px, median −3 px; 8 lines differ by more than 100 px | No |
| Background, second set (N08 to N10, after spread adaptation) | Mean colour, CIEDE2000 | ≤ 6 | 6.48 (2.1, 9.7, 7.6) | No |
| Background, second set | Lightness spread, mean absolute relative difference | ≤ 20% | 35% (−44%, +36%, −26%) | No |
| Focus motion | Delay from scroll onset to the first word's fill in the new line, iLyrics minus native (medians) | ± 0.15 s | −0.10 s (0.90 against 1.00 s) | Yes |
| Focus motion | Time to 50% of the scroll displacement after onset, difference of medians | ± 0.05 s | −0.067 s | No |
| Focus motion | Time to 90% of the scroll displacement after onset, difference of medians | ± 0.05 s | −0.033 s | Yes |
| Word fill | Crossing of each 40-px column group after the line's first crossing, iLyrics minus native, median over 2,429 matches | ± 0.10 s | 0.00 s | Yes |
| Word fill | Share of matches within ± 0.25 s | ≥ 90% | 64% | No |
| Gap indicator | Appearance after the scroll onset that brings the gap into focus, difference of medians | ± 0.1 s | −0.97 s (0.37 against 1.33 s; 6 and 9 gaps) | No |
| Gap indicator | Disappearance after the next scroll onset, difference of medians | ± 0.1 s | +0.23 s (0.23 against 0.00 s; 9 and 11 gaps) | No |
| Inactive lines | RMS difference of high-passed lightness in the rows below the focused paragraph, median over 43 paired frames | ≤ 7.40, the worst development held-out error | 10.54 | No |

Only N01 has a title that overflows the header. Playback start was taken as the moment the transport symbol changed from play to pause, at a resolution of 1/30 s; in every capture it fell 0.07 to 0.13 s after the recording began.

## Observations

- **Controls** reproduce the reference within a fraction of a pixel and its auto-hide delay within 0.08 s.
- **Marquee** timing matches; the displacement curve differs by 6.6 px RMS. A start 0.09 s later than the model accounts for part of the difference near the start, where the title moves at about 125 px/s.
- **Background** colour is close for four songs and differs most for N05 (10.8) and N02 (7.2); the lightness spread is too low for three songs and too high for two. The [colour-field experiment](background-colour-field.md) already showed that the background keeps more of the artwork's structure than a uniform treatment; a model that adapts the spread to the artwork would be developed on the development captures and qualified on new captures.

- **Typography** wraps most paragraphs as the native screen does and matches line ink widths within a few pixels for nine lines in ten. The 13 differently wrapped paragraphs and the outlying widths are not yet analysed; outlying widths may include neighbouring text recognized in the same row. A balanced line-breaking experiment, suggested by one paragraph of the duet capture N07, matched the development capture V17 worse than the current greedy wrapping (49 against 53 of 55 paragraphs) and was not adopted.
- **Background spread adaptation** improved the development folds but did not carry over to the second capture set: the lightness spread was again too low for two songs and too high for one. The comparison measures the native background through lyrics and controls, which the block statistics only partly exclude; this limits the background measurement itself.

## Paired Comparison

Focus motion, word fill, the gap indicator, and inactive lines were measured by `scripts/reference_validation/qualify_paired.py`, which compares each capture with iLyrics's rendering of the same song from the same library audio. The lyric text of each capture was read from its focused paragraphs with the Vision text recognizer (`extract_lyrics.py`); iLyrics aligned that text automatically, as a user's render would.

This departs from the plan, which proposed to drive the rendering with line and word timing read from the capture, so that synchronization would not enter the comparison. The measures were therefore made relative within each video wherever possible: the focus delay is measured from each video's own scroll onset to its own first word fill, and the gap times from each video's own scroll onsets. Word fill cannot be separated in this way: after each line is aligned at its first crossing, the remaining difference includes the word timing of the automatic alignment, and the 64% within ± 0.25 s is an upper bound on the visual difference, not a measurement of the fill alone. The inactive-line threshold was defined by a template-fit residual on development captures; the paired measure is a direct rendering-against-capture residual on the same lightness scale, so the comparison with 7.40 is approximate.

Per capture, iLyrics minus native:

| Capture | Scroll events (native, iLyrics) | Focus delay | 50% time | Word fill median | Fill within ± 0.25 s | Inactive RMS (frames) |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| N01 | 59, 60 | −0.23 s | −0.07 s | +0.03 s | 74% | 10.1 (28) |
| N02 | 51, 58 | +0.07 s | −0.07 s | +0.20 s | 52% | 16.0 (6) |
| N03 | 56, 57 | −0.22 s | −0.07 s | 0.00 s | 66% | — |
| N04 | 45, 63 | +0.07 s | 0.00 s | −0.10 s | 77% | 23.6 (9) |
| N05 | 61, 79 | −0.23 s | −0.07 s | −0.10 s | 66% | — |
| N06 | 88, 86 | −0.10 s | −0.07 s | +0.13 s | 59% | — |

Inactive frames are paired only when the lyric column of both videos agrees closely, which requires the same lines in the same places; recognition errors and differences in automatic gaps left no such frames for three captures.

The measurement procedure was settled partly on held-out material, which the plan did not foresee. A first trial on N01 showed that the dot test missed dimmed dots and that the synchronization difference dominated absolute times, and the first run on N01 to N03 found only 30 word-fill matches because the brightness step of a filled word, about 20 levels, was below the detection threshold of 25; the threshold was lowered to 12 and the window narrowed before the six captures were measured together. No renderer parameter was changed on held-out evidence. The same trial exposed three defects of the command that are fixed in separate changes: paragraph spacing ([Paragraph Spacing](paragraph-spacing.md), measured on a development capture), a limit of 64 paragraphs in plain lyrics, and paragraphs whose wrapped lines exceeded four.

## Known Differences

- **Focus motion** reaches 50% of its displacement about two frames (0.07 s) earlier than native, while the onset relative to the line's fill and the 90% time are within the thresholds.
- **Word fill** is centred on native timing (median 0.00 s), but individual words spread more widely, mostly from automatic word timing.
- **The gap indicator** appears about 0.4 s after the scroll into the gap in iLyrics and about 1.3 s after it on the native screen, and it leaves about 0.2 s later than native. The dots on the native screen may become detectable only late in a fade-in, which this test does not resolve.
- **Inactive lines** have about 1.6 times the high-passed contrast of native in the paired frames; native inactive lines are dimmer and fade over a longer distance towards the bottom of the screen.
- **The previous paragraph** remains visible above the focused one on the native screen. The iLyrics lyric viewport begins at y = 550 with an 80-px fade, a provisional boundary, so a previous paragraph is at most partly visible; this boundary was not measured.
- **Title marquee** displacement, **background** colour and spread, and **typography** wrapping of some paragraphs differ as reported above.

## Method

The measurement scripts are `scripts/reference_validation/qualify_controls.py`, `qualify_autohide.py`, `qualify_marquee.py`, `qualify_background.py`, `qualify_typography.py`, and `qualify_paired.py`. Typography recognizes focused lines with the macOS Vision text recognizer through `LyricsScreenProbe ocr` and lays out the same text with `LyricsScreenProbe layout`; a line beginning with a capital letter other than the pronoun I is treated as an explicit lyric break. Its first run counted only bright ink and therefore missed the dim, unfilled words of a line in progress; the threshold was corrected to ink clearly above the local background before the results were reported. They read only `reference-private/`, write per-capture results to `reference-private/analysis/visual-qualification/`, and print numbers only. The background comparison renders iLyrics's background for the artwork embedded in each song's audio file with `LyricsScreenProbe background-frames` and applies the block statistics of the background calibration to both videos.
