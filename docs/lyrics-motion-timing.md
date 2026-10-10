# Lyrics Motion Timing and Stagger

## Outcome and Scope

October 10, 2026. **The native Lyrics screen moves focus about 0.30 seconds before iLyric's estimated line onsets, and lower lines follow the focused line with a distance-dependent delay.** Both behaviors were measured from a complete reference capture of the recording used for the [first real-song video](first-real-song-video.md). iLyric now offers a focus lead and staggered motion as opt-in presentation options; existing scenes are unchanged.

## Reference Capture

The maintainer captured the complete song on the reference iPhone 16, reported iOS 27.0.1, exact build Unknown, under the recorded settings, as V17: 1180×2556, approximately 60 fps, 316.7 seconds. The capture's audio track is effectively silent, consistent with protected playback not being captured, so audio cannot align it. Instead, the elapsed-time label, visible for the first four seconds, changes from 0:00 to 0:01 at capture time 0.483 s and advances at one-second intervals; song time therefore equals capture time plus 0.517 s. Comparing scroll onsets across the song showed no measurable drift (0.02 s over 300 s). The capture remains private.

## Measurements

Vertical scroll was tracked over all 19,033 frames by matching row-luminance profiles of the lyric column between consecutive frames. Eighty-seven motion events were detected.

- **Focus lead.** Sixty-six scroll onsets matched an iLyric line onset within 1.5 s. The native scroll begins a median 0.30 s before iLyric's estimate (interquartile range 0.15–0.57 s). This combines native anticipation and any lateness in iLyric's estimates; the two cannot be separated without audio. The lead is applied to focus only; highlighting keeps the estimated word and line times.
- **Aggregate motion.** Normalized aggregate displacement reaches 50% at 0.167 s and 90% at 0.333 s. A critically damped response with time constant 0.090 s fits within 0.022 RMS, close to the existing 0.081-s focus motion.
- **Stagger.** In 24 large scroll events, five 340-pixel bands reached half displacement 0, 17, 67, 117, and 167 ms after the band containing the focused line. iLyric models the delay as 0.147 ms per layout pixel below the focus target, minus 33 ms, bounded to 0–0.3 s.

## Implementation

`FocusStagger` evaluates each paragraph and gap at its own delayed time on the existing analytic focus segments, so every frame remains a pure function of output time and no frame history is used. `.rigid` reproduces previous output exactly. `LocalPresentation` adds `focusLead` and `stagger`; the lead never moves focus before the previous line's focus or before zero, and the previous line's hold event is omitted when the led focus follows it directly. `LyricsInputProbe --motion measured` enables both. Tests cover exact rigid equivalence, lag of lower paragraphs, settled agreement, parameter rejection, and focus lead without changed highlighting.

## Limitations

The lead may partly compensate for estimate lateness rather than reproduce native anticipation alone. Stagger is modeled by layout distance, not by measured per-line spring parameters, and paragraphs above the focus are not delayed. Word highlighting, the sustained-word effect, background calibration, title marquee, and automatic control hiding remain separate items of the brush-up.
