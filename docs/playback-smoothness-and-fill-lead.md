# Playback Smoothness, Fill Lead, and Control Transition

## Outcome and Scope

October 11, 2026. **A frame-by-frame comparison of iLyric's second complete video with the native V17 capture found three visible defects: word fill trailing native by 0.22 seconds, scrolling that stepped in whole pixels, and controls that vanished instantly. All three are corrected.** The comparison scanned both videos with the same procedure on the clock established in [Reference Clock Correction and Word Motion](reference-clock-and-word-motion.md). The maintainer reported the same three defects independently after viewing the video.

## Fill Lead

For each line with word estimates, the time at which the columns of the first word crossed half brightness was measured in both videos. The native screen crosses a median 0.18 s before iLyric's estimated onset; iLyric crossed 0.05 s after it. Over 35 lines measurable in both videos, iLyric trailed native by a median 0.22 s (interquartile range 0.16–0.26 s). Scroll starts already agreed (median difference −0.01 s over 61 lines), and the exported audio was confirmed to be sample-aligned with the source. Because iLyric's word onsets are a median 31 ms late relative to human annotations ([Word-Level Alignment](word-level-alignment.md)), the native fill evidently begins slightly before the sung onset.

`LocalPresentation.fillLead` moves supplied word intervals earlier for appearance only, clamped at zero; focus timing and layout are unchanged. `measuredFillLead` is 0.22 s, and `LyricsInputProbe --motion measured` applies it.

## Subpixel Motion

Core Graphics places an unscaled image on whole pixels even when its rectangle is fractional, so the slow end of each critically damped scroll advanced in alternating one-pixel and zero-pixel steps. A normalized correlation estimator, validated on synthetic shifts of 0.3, 0.5, and 1.7 pixels, showed the tail of a synthetic scroll alternating between 0.75 and 0.25 pixels per frame. Moving lyric images are now drawn at the two neighboring rows with complementary weights, summed additively in a bounded transparency layer, which is exact vertical linear interpolation. After the change the same tail decreases monotonically: 0.95, 0.80, 0.65, 0.55, 0.45, 0.40 pixels per frame. Inactive tiles apply the same interpolation within their existing additive layer, now bounded to the tile instead of the whole canvas.

## Control Transition

The native lower controls do not disappear in one frame. Tracking the pause control at 60 fps shows the controls sliding down by 29, 79, 141, 208, 267, 323, 372, 413, and 460 pixels in successive frames from song time 3.79 s, while their opacity falls through 0.85, 0.65, 0.46, 0.31, 0.21, 0.13, 0.08, and 0.05; lyrics fade into the vacated area at the same time. [Control Auto-Hide](control-auto-hide.md) had recorded only presence at fixed positions and therefore reported an abrupt change.

`ControlTransition` stores these samples, with a short extrapolated tail after the controls become invisible, and interpolates them from output time. While it runs, the lower controls are drawn translated and faded, and the lyrics mask blends the original and expanded fades by the revealed fraction. The hide event moves to 3.79 s. The elapsed and remaining labels now round to the nearest second, as the native label does.

## Verification

Tests cover two-row interpolation of a one-pixel image at a quarter-pixel offset, the control transition before, during, and after hiding, label rounding, and fill-lead shifting with unchanged focus and layout.

## Limitations

The fill lead is one constant measured on one recording; it combines native anticipation with any residual bias of the reference clock (about ±0.15 s). The control samples beyond 460 pixels are extrapolated, and controls reappearing on interaction are not modeled. Subpixel interpolation applies vertically only.

Neither release readiness nor native iOS 27 Music fidelity is established.
