# Artwork Background Calibration

## Outcome and Scope

October 11, 2026. **The fitted artwork background is recalibrated so that nearly neutral artwork yields a subdued background while colorful artwork keeps its color.** The maintainer observed that iLyric's background was darker, more saturated, and more changeable than the native screen. Measured against the native V17 capture of a high-contrast, nearly neutral cover, the previous model reached CIELAB lightness 17 against 33 and a 95th-percentile chroma of 28 against 7. The revised model adds a lift term, a saturation that adapts to the artwork's mean chroma, and a smaller canvas-covering layer scale. It improves held-out fit on all four covers. The reports [Artwork Background](artwork-background.md) and [Artwork Background Motion](artwork-background-motion.md) remain historical records; motion parameters are unchanged.

## Model Changes

- **Lift.** After the gain, a constant is added before vertical darkening: (x·gain + lift)·(1 − gradient·y). A lower gain with a positive lift compresses the blurred artwork toward a mid tone, as a translucent material would.
- **Adaptive saturation.** The saturation multiplier is scaled by C/(C + c₀), where C is the mean CIELAB chroma of the artwork resampled to 192 × 192 pixels. C is computed once from the input, so frames remain pure functions of time.
- **Covering scale.** The layer side may be as small as 1.28 canvas heights, the smallest size that covers the canvas at any rotation and orbit position, so neither the reconstruction nor the renderer exposes the canvas.
- **95th-percentile chroma.** Mean chroma barely responds to a small saturated region, such as a logo on a neutral cover, so the fitting objective adds the 95th-percentile chroma of the block field.

## Fitting

Appearance parameters were fitted by Nelder–Mead to seven statistics (lightness, mean chroma, spatial lightness deviation, top-to-bottom lightness difference, two spatial correlations, and 95th-percentile chroma) on songs A–C from recordings V01–V10 and song D from V17, with leave-one-song-out folds. A first fit without a blur bound selected a 23-pixel blur, which left the artwork recognizable; the statistics are computed on 8-pixel blocks and do not penalize visible detail. The blur was therefore bounded below at 100 pixels, near the previous 110–139-pixel fits, and every fold settled at that bound.

| Held-Out Song | Previous Model | Revised Model |
| --- | ---: | ---: |
| A | 46.1 | 24.3 |
| B | 27.2 | 11.6 |
| C | 42.0 | 34.0 |
| D | 136.1 | 102.8 |

The adaptation constant c₀ was consistent across folds (7.4–9.0). Song D remains poorly predicted when held out: its lightness depends on fitting it directly, which indicates that the native background adapts to artwork luminance in a way the model does not represent. With all four songs, song D reaches lightness 25.5 against 33.0, mean chroma 2.5 against 2.4, and 95th-percentile chroma 8.8 against 7.4. The selected parameters are scale 1.385, blur 100.0, saturation 4.898, gain 0.3971, gradient 0.4239, lift 0.2212, and c₀ 7.83; the [numerical record](reference-data/background/appearance.json) lists every fold.

## Implementation

`ArtworkBackground` gains `lift` and `chromaHalf` (c₀) with defaults that preserve earlier parameter sets, and a static `meanChroma` that uses the same sRGB-to-CIELAB conversion as the fitting code. `ArtworkBackdrop` computes the artwork's chroma once at initialization and applies the lift through the color-matrix bias. Swift frames reproduce the Python reconstruction to within 0.05 lightness units on all three checked covers. `scripts/reference_validation/background.py appearance MODE EVALUATIONS` reproduces the fit from the private inputs. Tests cover chroma measurement, adaptive saturation, and parameter validation.

## Limitations

Four covers constrain seven parameters, and the blur bound is a visual judgment rather than a fitted value. Lightness for high-contrast neutral artwork remains about 8 units too dark. Phase is not matched to any native recording.

Neither release readiness nor native iOS 27 Music fidelity is established.
