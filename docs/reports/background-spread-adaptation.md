# Background Spread Adaptation

## Outcome

October 12, 2026. **The background now adapts the strength of its light and dark structure to the artwork, which improved the fit to the development captures in every held-out fold but one, where it was unchanged.** The [visual qualification](visual-qualification-results.md) had found the lightness spread of the background 33% away from the held-out captures on average: too flat for some artwork and too uneven for other artwork. Following the qualification rules, the change was developed only on the development captures; the held-out captures were not used.

## Model

After the blur, each colour is moved toward or away from the artwork's mean colour by the factor (cref / c)^β, where c is the lightness standard deviation of the artwork averaged to 16 × 16 blocks, which describes its coarse structure. Busy artwork (large c) is softened and flat artwork (small c) is strengthened, so that backgrounds converge toward a common spread. Saturation, gain, lift, and the vertical gradient follow unchanged.

## Fit

Only cref and β were fitted, with the published appearance parameters fixed, on development songs A to D with the calibration's block statistics (`background.py spread`, 120 evaluations per fold). Each song was also held out in turn.

| Held-out song | Loss without adaptation | Loss with adaptation (fitted without the song) |
| --- | ---: | ---: |
| A | 14.08 | 14.09 |
| B | 5.89 | 5.14 |
| C | 8.13 | 5.58 |
| D | 44.69 | 41.70 |

The parameters were stable across folds (cref 0.283 to 0.288, β 0.683 to 0.734); the fit on all four songs, cref = 0.285 and β = 0.683, is used. The [sanitized fit record](../reference-data/background/spread.json) lists every fold. The Swift implementation reproduces the fitting model's statistics: for development song C, lightness 31.3 against 31.1 and spread 5.11 against 5.24.

## Limitations

Four development songs constrain two parameters; the held-out improvement is consistent but small for two songs. The background property must be qualified again on captures that were not used in the first visual qualification.
