# Title Marquee

## Outcome and Scope

October 10, 2026. **The native Lyrics screen scrolls an overflowing title leftward along a measured easing curve and repeats the scroll after a pause; iLyric now reproduces this motion as an opt-in presentation option.** The motion was measured from the V17 reference capture described in [Lyrics Motion Timing and Stagger](lyrics-motion-timing.md), whose title exceeds the header width. Static header rendering is unchanged unless the option is enabled.

## Measurements

The title band was extracted at the capture's native rate of approximately 60 fps for the first 40 seconds. Horizontal displacement was tracked by subpixel correlation of consecutive frames and checked against direct matching of mid-scroll frames with a resting frame. Integrated tracking underestimated displacement by about 1.2%; direct matching gave 254 and 442 pixels where the fitted model below predicts 255 and 440.

- **Easing.** Scrolling is not constant-speed. Speed jumps to about 125 px/s, peaks near 153 px/s about 2 s into the scroll, and decays to rest over the final 5 s. A cubic Bézier, (0.296, 0.340, 0.567, 1.0), fitted over two cycles with an 8.71-s duration leaves an RMS residual of 0.54 px.
- **Cycle.** One scroll moves the label by its ink width plus a 104-pixel ink gap, after which the second copy occupies the resting position. The measured cycle distance is approximately 908 pixels, a mean speed of 104.3 px/s.
- **Timing.** The first scroll begins at song time 8.71 s. Successive scrolls begin 13.13 s apart, leaving a 4.42-s pause at rest.
- **Clip and fades.** Scrolling ink is visible from x = 312, the artwork's right edge, to x = 977. Opacity ramps linearly over about 20 pixels at the left edge and 22 pixels at the right edge; the right fade is also present at rest.

## Implementation

`TitleMarquee` in `LyricsSliceCore` evaluates the leftward offset from output time alone and evaluates the Bézier by fixed-iteration bisection, so any frame can be rendered independently. `ScreenRenderer` draws two copies separated by the gap, clipped to the measured span through a horizontal opacity mask. The title and artist labels scroll independently when their resting ink would enter the right fade; other labels render exactly as before. `LocalPresentation.marquee` and `LyricsInputProbe --marquee measured` enable the behavior.

Tests cover the fitted easing values and monotonicity, displacement at the two directly matched times, rest before the initial delay and during pauses, random-access periodicity, fade opacity, parameter rejection, pixels at rest and mid-scroll, and identical output for labels that fit.

## Limitations

The constants come from one title in one capture. The scaling of duration with label width, the overflow threshold, and the trigger of the initial delay are assumptions: the initial delay is measured from song start, whereas the native delay may begin when the screen appears. Whether the artist label scrolls on the native screen was not observed, because the reference artist name fits. The marquee runs on output time and therefore continues while playback is paused, which has not been compared with native behavior.

Neither release readiness nor native iOS 27 Music fidelity is established.
