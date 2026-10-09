# Artwork Background Motion

## Outcome and Scope

October 9, 2026. **The artwork-derived background continues moving while playback is paused, and the existing model reproduces its measured motion statistics once comparisons use matched durations.** Six new captures isolate background motion from lyric scrolling. They also expose an evaluation error in the [background report](artwork-background.md): model sequences of 12 seconds were compared with reference sequences of 10–30 seconds, although the autocorrelation statistic depends on sequence length. With matched durations, refitted orbit and rotation reproduce the paused-capture statistics with held-out RMS z of 0.76, 2.16, and 1.45. The earlier conclusion that motion was not identified is superseded; that report remains unchanged as a historical record.

The appearance parameters, Swift implementation, and opt-in status are unchanged. Native fidelity is not established.

## Captures

The maintainer recorded six screen captures of approximately 30 seconds each on the reference iPhone 16, reported iOS 27.0.1, exact build Unknown, under the recorded settings: songs A, B, and C, each once paused on the Lyrics screen (V11, V13, V15) and once playing through an instrumental section (V12, V14, V16). Original hashes were recorded before processing; the files were not modified. Frames, fields, and crops remain under ignored `reference-private/`.

Direct observations:

- While paused, the background changes continuously, at a median rate comparable to playback: 0.0077 versus 0.0083 mean luminance units per second for song A. Background motion therefore follows interface time, not media time, consistent with evaluating `ArtworkBackground` from output time.
- Paused captures decorrelate more slowly than playing captures of the same song; for song B, 4-second autocorrelation is 0.81 paused and 0.41 playing. Lyric scrolling had contaminated the earlier playing-only measurements.
- Lower controls remain visible while paused.
- Playing captures show the three-dot instrumental-gap indicator, which remains unmodeled and belongs to gate B5.

## Corrected Motion Fit

`scripts/reference_validation/background.py motion` holds the fitted appearance fixed and refits orbit radius, orbit rate, and rotation rate against the paused captures' 1-, 2-, and 4-second autocorrelation and median rotation. Model sequences match each capture's duration at 5 fps. Each song was held out in turn, and a final fit used all three.

| Parameter | All Songs | Held-Out A | Held-Out B | Held-Out C |
| --- | ---: | ---: | ---: | ---: |
| Orbit radius (× height) | 0.0865 | 0.0879 | 0.1383 | 0.0644 |
| Orbit rate (rad/s) | 0.1233 | 0.1205 | 0.1210 | 0.1129 |
| Rotation rate (rad/s) | −0.0259 | −0.0254 | −0.0405 | −0.0315 |
| Held-out RMS z | — | 0.76 | 2.16 | 1.45 |

Orbit rate is stable across folds and close to the original appearance fit; rotation is consistently negative, matching the measured rotation sign, which the original fit had reversed. One z unit equals the stated tolerance: 0.03, 0.05, and 0.08 for the three autocorrelations and 0.01 rad/s for rotation. The [sanitized motion profile](reference-data/background/motion.json) contains targets, model statistics, and every fold.

`ArtworkBackground.fitted` now uses the all-song motion parameters. Swift-rendered 30-second sequences reproduce the Python model's motion statistics within 0.033 autocorrelation and 0.002 rad/s rotation for all three artworks.

## Remaining Limitations

- Appearance parameters were fitted jointly with temporal terms evaluated at mismatched durations. Appearance statistics are largely duration-independent, but the appearance fit has not been repeated.
- Song B's held-out autocorrelation remains below the reference at 4 seconds.
- Motion is matched statistically; trajectories and phase are not reproduced.
- Each song has one paused capture; repeatability of paused motion is unmeasured.

Native iOS 27 Music background fidelity is not established.
