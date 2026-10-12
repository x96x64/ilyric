# Background Colour Field

## Outcome

October 12, 2026. **Drawing the artwork itself remains the background model for real artwork, because it reproduces the reference captures better than a colour field; a colour field is used only for iLyrics's placeholder artwork.** The maintainer observed that the placeholder's music-note symbol showed through the blurred background of the demonstration image and asked whether the background could, like the native screen, carry the artwork's colours without its shapes.

## Candidates

The [calibrated background](artwork-background-calibration.md) draws two orbiting, rotating copies of the artwork, blurs them, and adjusts saturation and brightness. Two replacements for the drawn artwork were tested:

- a **colour field**: six colour clusters of the artwork (k-means at 32 × 32 pixels, deterministic), drawn as soft radial blobs over the mean colour, with blob counts in proportion to cluster shares and positions from a generator seeded by the artwork's pixels;
- the same field with smaller, more numerous blobs over the dominant colour, for more contrast.

Each was calibrated with the existing appearance fit (`scripts/reference_validation/background.py appearance all 300`, with the Swift field written by `LyricsScreenProbe color-field`), on the same development captures and with the same 300 evaluations as the artwork model.

## Results

| Model | Fit loss (lower is better) | Song A | Song B | Song C | Song D |
| --- | ---: | ---: | ---: | ---: | ---: |
| Artwork (current) | 81.8 | 22.9 | 6.2 | 8.4 | 44.3 |
| Colour field | 102.1 | 25.7 | 4.1 | 8.5 | 63.8 |
| Higher-contrast colour field | 127.9 | 62.8 | 6.2 | 7.4 | 51.5 |

The artwork model reproduced the published fit loss of 81.9. The colour field matched mean lightness better for two songs, but it was flatter than the captures: lightness spread, the 95th percentile of chroma, and spatial correlation moved away from their targets. The native background evidently keeps more of the artwork's light and dark structure than a colour field does; making the field more uneven did not recover it.

## Decision

Real artwork keeps the artwork model; its rendered background is byte-identical to the previous version. When the command uses its own placeholder artwork, because the recording has no cover, the background draws the colour field, so the placeholder's symbol no longer shows through. The placeholder is iLyrics's own drawing, so this choice does not affect fidelity to the native screen, for which the placeholder background is unmeasured. The demonstration image was regenerated with only this change.
