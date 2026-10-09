# Instrumental-Gap Indicator and Pause State

## Outcome and Scope

October 10, 2026. **Retain a fitted, deterministic three-dot instrumental-gap indicator.** The native Music Lyrics screen on the reference iPhone 16, reported iOS 27.0.1, exact build Unknown, shows three dots during instrumental gaps. They fill from left to right across the gap and the group pulses in scale. A model in which the fill completes a fixed 2.22 seconds before the gap ends reproduces all three measured gaps with held-out RMSE of 0.038–0.046 in normalized brightness, better than a model proportional to gap duration. The pulse is a sinusoidal group scale of ±11% whose phase restarts at the gap; its period differs by song, 4.0–5.1 seconds, for an unidentified reason.

This is gate B5 of the [release and fidelity decisions](release-and-fidelity-decisions.md). Pause-state observations are recorded below. Gaps are supplied explicitly; automatic gap detection from lyric timing is not implemented.

## Measurement

Recordings V12, V14, and V16 play through instrumental gaps of 16.5, 10.8, and 20.9 seconds, delimited by the indicator's appearance and disappearance. Crops around the dot row were analyzed at 30 and 60 fps. For each dot, center contrast over a surrounding ring measured brightness; the separation of the outer dots' centroids measured group scale.

- **Geometry.** Dots are 42 native pixels in diameter with 67-pixel center spacing; the first center lies at x = 107 and the focused row at y = 760–762, the active-lyric anchor. The following paragraph's slot lies 226 pixels below.
- **Fill.** Unlit dots show 13–16% of lit contrast. Each dot brightens approximately linearly in order; the third completes 1.9–2.3 seconds before the gap ends, independently of gap length.
- **Pulse.** The group scales about the middle dot between approximately 0.87 and 1.10. Sinusoidal fits give amplitude 0.108–0.114 and phase −0.36 to −0.62 radians relative to gap start, with periods 5.14, 4.92, and 4.00 seconds. A tempo relationship could not be tested: the onset-autocorrelation tempo estimate was unreliable.
- **Entry and exit.** Dots fade in over approximately 0.4 seconds and disappear within approximately 0.15 seconds as the next line takes focus.

The [sanitized measurements](reference-data/gap/indicator.json) record fits, held-out errors, and the rejected proportional model.

## Pause State

The paused captures V11, V13, and V15 show that lower controls remain visible while paused and that the artwork background keeps moving, as recorded in the [background motion report](artwork-background-motion.md). The playback control shows `play.fill`, as fitted in the [control-symbol report](control-symbols.md). Lyrics remain static. The existing renderer already derives paragraph appearance from media time and the background and controls from output time, which matches these observations. Indicator behavior while paused was not captured; the implementation evaluates the indicator from media time, so it freezes while paused. This is an assumption.

## Implementation

`GapIndicator` in `LyricsSliceCore` evaluates fills, per-dot opacity, group scale, and visibility from elapsed media time within a half-open gap interval. Gaps shorter than twice the lead keep half their duration for filling; native short-gap behavior is unmeasured. `CompositionGap` places a gap in a layout slot, and `FocusEvent(gap:)` scrolls focus to it while dimming every paragraph. Gap and paragraph positions must be distinct, and gap events must reference existing gaps. `ScreenRenderer` draws the dots in the lyric layer with the existing viewport clip and fade. `LyricsComposition.gapDemonstration()` provides an original synthetic fixture, and `LyricsScreenProbe` accepts a `-gap` suffix.

Five new Swift tests cover the half-open interval, ordered and complete fill, pulse bounds, short gaps, parameter rejection, gap focus and paragraph dimming, invalid gap references, and random-access raster determinism at the focused slot. All related suites passed. A synthetic render placed the dots at the measured position and size, with progressive fill comparable to the reference.

## Limitations

- The pulse period is a median default; per-song variation is unexplained.
- When the native screen shows the indicator, for example a minimum gap duration, is unknown; gaps must be supplied.
- Paused-indicator behavior, very short gaps, and gaps at song start or end are unmeasured.
- Exit choreography beyond the fade, such as interaction with the next line's motion, is not modeled.

Native iOS 27 Music fidelity is not established.
