# Artwork-Derived Dynamic Background

## Outcome and Scope

October 9, 2026. **Retain an experimental artwork-derived background with qualified appearance and provisional motion.** The native Music Lyrics background on the reference iPhone 16 is a heavily blurred, continuously moving color field derived from the track artwork, darker toward the bottom of the screen. iLyric now reconstructs it as two enlarged, rotating, orbiting artwork layers, a large Gaussian blur, a saturation and gain transfer, and vertical darkening, all evaluated from explicit output time. Color, spatial structure, and vertical gradient generalize to held-out songs within approximately 1.4–2.5 tolerance units. Temporal behavior is not identified by the current corpus and remains provisional.

This is gate B1 of the [release and fidelity decisions](release-and-fidelity-decisions.md). The model is an iLyric reconstruction fitted to phase-independent statistics, not Apple's implementation, and it does not reproduce the phase of any recording. The original static gradient remains the default; the new background is opt-in.

## Reference Observations

The private corpus contains nine relevant recordings of three songs on iPhone 16, reported iOS 27.0.1, exact build Unknown, under the previously recorded settings: song A in V01–V03, song B in V05–V06, and song C in V07–V10. V04 was excluded because its song has no corresponding screenshot artwork. Artwork was cropped from the header of one screenshot per song, inside the measured bounds `[96,276,312,492)` with a 12-pixel inset. Crops, frames, and fields remain under ignored `reference-private/`.

Each recording was decoded at 10 fps and quarter resolution. To suppress white lyric and control ink, each 32-pixel block retains the mean of its darkest 30% of pixels; the status-bar rows are removed. Direct observations:

- The background hue matches the artwork hue within approximately 5°, chroma is approximately preserved or slightly increased, and lightness is reduced relative to bright artwork.
- The top of the screen is brighter than the bottom by approximately 8–24 L* units.
- The field changes continuously. Its temporal autocorrelation decays over seconds, with a slow global rotation of approximately 0.01–0.04 radians per second and translations of approximately 10–20 native pixels per second.
- Large dark and light regions resemble enlarged, blurred portions of the artwork.

Temporal statistics differ strongly by song. The block field cannot fully exclude lyric scrolling, blurred inactive lines, and control visibility changes, and song B's recordings last only approximately ten seconds. Whether the motion depends on playback state, tempo, or the song is unknown.

## Model and Fitting

`ArtworkBackground` evaluates two layers at output time *t*. Each layer is the artwork scaled to `scale × canvas height`, centered on an orbit of radius `orbit × canvas height` at angular velocity `orbitRate`, and rotated at `rotationRate`; the two layers use fixed opposite directions and phases. The equal-weight composite receives a Gaussian blur of `blur` native pixels, a saturation multiplier about Rec. 709 luma in encoded sRGB, a uniform `gain`, and a linear vertical darkening of `gradient` from top to bottom.

Ten phase-independent statistics were fitted: mean L* and chroma, spatial L* deviation, top-minus-bottom L*, temporal autocorrelation at 1, 2, and 4 seconds, horizontal and vertical spatial correlation, and median rotation, plus a hue term. Tolerances are the standard deviation across repeated recordings of each song, with fixed floors where repetitions agreed more closely than measurement noise. Fitting used Nelder–Mead with 260 evaluations. Each song was held out in turn, and a final fit used all three.

| Parameter | All Songs | Held-Out A | Held-Out B | Held-Out C |
| --- | ---: | ---: | ---: | ---: |
| Layer scale (× height) | 1.697 | 1.594 | 1.660 | 1.655 |
| Orbit radius (× height) | 0.130 | 0.127 | 0.183 | 0.154 |
| Orbit rate (rad/s) | 0.113 | 0.158 | −0.031 | 0.119 |
| Rotation rate (rad/s) | 0.022 | 0.020 | 0.034 | 0.022 |
| Blur (native px) | 139.1 | 85.1 | 135.3 | 118.6 |
| Saturation | 1.900 | 1.839 | 2.108 | 1.929 |
| Gain | 0.823 | 0.823 | 0.845 | 0.698 |
| Vertical darkening | 0.474 | 0.397 | 0.456 | 0.306 |

Scale, saturation, and gain are stable across folds; blur and darkening vary moderately; orbit rate is not identified.

| Held-Out Song | Appearance RMS z | Temporal RMS z |
| --- | ---: | ---: |
| A | 2.06 | 5.11 |
| B | 1.38 | 5.56 |
| C | 2.53 | 2.55 |

Appearance comprises mean L*, chroma, spatial deviation, vertical difference, and spatial correlations; temporal comprises the three autocorrelations and rotation. One z unit equals the repeatability tolerance. The [sanitized profile](reference-data/background/fit.json) contains targets, tolerances, model statistics, and parameters for every fold. Song identities are not published.

## Implementation and Verification

`ArtworkBackground` in `LyricsSliceCore` validates parameters and returns immutable layer states for any rational time. `ArtworkBackdrop` in `LyricsSliceMac` draws the layers at one-eighth canvas resolution, applies software Core Image blur, color matrix, and gradient multiplication in sRGB, and the screen renderer scales the result to the canvas. `LyricsScreen` gains an optional `background`; when absent, the original static gradient and all existing regressions are unchanged, and component evidence states which treatment is active. `LyricsScreenProbe` accepts a `-background` suffix and a development `background-frames` command.

Swift-rendered background frames reproduce the Python model's ten statistics for all three artworks within 0.5 tolerance units, establishing implementation parity with the fitted model. Rendering 60 background frames took 0.30 seconds on Apple M4. Four new Swift tests cover analytic layer evaluation, parameter rejection, random-access raster determinism across fresh renderers, temporal change, absence of hard artwork edges, and preservation of the static default. All 65 Swift and 196 Python tests passed. `scripts/reference_validation/background.py` reproduces target extraction and fitting from the private corpus.

## Limitations and Next Steps

- **Motion is provisional.** Rotation direction, orbit rate, and decorrelation speed are not identified. The candidate explanation is contamination from lyric motion and short recordings, but this is not established.
- **Phase is unmatched.** The model reproduces statistics, not any native trajectory; the planning study anticipated this outcome for nonrepeating background motion.
- **Layer structure is assumed.** Two counter-moving layers are a modeling choice; other structures could match the same statistics.
- **Encoded-sRGB processing.** Saturation, gain, and blur operate on encoded values. Linear-light processing was not compared.
- **Integration.** Local project rendering still uses the static gradient; enabling the background there requires a project-format version decision.

To identify motion, the next captures should hold playback **paused** on the Lyrics screen for approximately 30 seconds for each of three songs with differing artwork, followed by approximately 30 seconds of playback through an instrumental section, under the recorded settings. Paused captures remove lyric motion and also establish whether the background moves while playback is paused.

Native iOS 27 Music background fidelity is not established.
