# Visual Qualification Results

## Status

October 12, 2026. **In progress.** Four of the eight properties of the approved [Visual Qualification Plan](visual-qualification-plan.md) have been measured on the held-out captures N01 to N06 and the six held-out screenshots. Each measurement was made once with the thresholds fixed beforehand; a property, once measured, cannot be refitted on these captures. Typography, focus motion, word fill, the gap indicator, and inactive lines remain; they require the lyric text and timing read from the captures.

## Second Capture Set

On October 12, 2026, the maintainer recorded three further captures, N08 to N10, after the background spread adaptation was developed. Before any of them was analysed, they were assigned to re-qualify the background with the same thresholds; the title band of N08, the only one with an overflowing title, is development material for the marquee, whose background remains held out.

## Results So Far

| Property | Measure | Threshold | Result | Met |
| --- | --- | --- | --- | --- |
| Controls | Ink-bounds centre of seven plain control symbols in three paused screenshots | ≤ 3 px | maximum 0.5 px, mean 0.1 px over 21 measurements | Yes |
| Controls | Delay from playback start to the lower controls hiding | 3.79 s ± 0.2 s | 3.80 to 3.87 s, maximum error 0.08 s | Yes |
| Title marquee | Start delay after playback start (N01) | 8.11 s ± 5% | 8.20 s | Yes |
| Title marquee | Cycle period for the measured scroll distance of 942 px | ± 5% | 13.47 s against 13.45 s | Yes |
| Title marquee | Displacement during the first scroll, modulo the scroll distance | RMS ≤ 2 px | 6.6 px | No |
| Background | Mean colour, CIEDE2000, mean over six songs | ≤ 6 | 6.29 (per song 3.3 to 10.8) | No |
| Background | Spatial lightness spread sL, mean absolute relative difference | ≤ 20% | 33% (per song −42% to +41%) | No |

Only N01 has a title that overflows the header. Playback start was taken as the moment the transport symbol changed from play to pause, at a resolution of 1/30 s; in every capture it fell 0.07 to 0.13 s after the recording began.

## Observations

- **Controls** reproduce the reference within a fraction of a pixel and its auto-hide delay within 0.08 s.
- **Marquee** timing matches; the displacement curve differs by 6.6 px RMS. A start 0.09 s later than the model accounts for part of the difference near the start, where the title moves at about 125 px/s.
- **Background** colour is close for four songs and differs most for N05 (10.8) and N02 (7.2); the lightness spread is too low for three songs and too high for two. The [colour-field experiment](background-colour-field.md) already showed that the background keeps more of the artwork's structure than a uniform treatment; a model that adapts the spread to the artwork would be developed on the development captures and qualified on new captures.

## Method

The measurement scripts are `scripts/reference_validation/qualify_controls.py`, `qualify_autohide.py`, `qualify_marquee.py`, and `qualify_background.py`. They read only `reference-private/`, write per-capture results to `reference-private/analysis/visual-qualification/`, and print numbers only. The background comparison renders iLyrics's background for the artwork embedded in each song's audio file with `LyricsScreenProbe background-frames` and applies the block statistics of the background calibration to both videos.
