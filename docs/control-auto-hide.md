# Control Auto-Hide

## Outcome and Scope

October 10, 2026. **During playback, the native Lyrics screen hides its lower controls about 3.8 seconds after playback begins and extends the lyrics to the bottom edge; iLyric now offers this as an opt-in presentation option.** The behavior was measured from the V17 reference capture on the clock established in [Reference Clock Correction and Word Motion](reference-clock-and-word-motion.md). Previously, iLyric clipped lyrics above the controls for the whole video, which [the first real-song video](first-real-song-video.md) recorded as a defect.

## Measurements

- **Timing.** The progress bar, transport controls, volume slider, and lower buttons disappear together between two consecutive frames at song time 3.78 s. The translation and singing buttons above the progress bar disappear with them; the header and grabber remain.
- **Reveal.** Lyrics in the newly exposed area cross-fade in over about 0.13 s, measured as the correlation of that area with its settled appearance.
- **Extent.** With controls hidden, lyric contrast continues to the bottom of the screen and declines over roughly the last 300 pixels, from about y = 2,250 to the bottom edge at 2,556.

## Implementation

`LyricsScreen` gains an opt-in `expandsLyrics` flag. When it is set and lower controls are hidden, the lyrics component uses `expandedViewport` (x 72, y 550, width 1,040, to the bottom edge) with the existing 80-pixel top fade and a 300-pixel bottom fade; otherwise the original viewport is unchanged. `LocalPresentation.hideControls` adds a screen event that hides the lower, translation, and singing controls at the given time and enables the expanded viewport; `measuredControlHide` is 3.78 s, and `LyricsInputProbe --controls auto-hide` applies it. The renderer's bounded paragraph cache grows from six to twelve paragraphs because more inactive paragraphs are visible. Tests cover the viewport switch, the unchanged default, and the expanded fade profile.

## Limitations

The 0.13-s cross-fade is not reproduced; the viewport switches within one frame. The trigger of the native delay is unknown: the capture began at the start of playback, so the delay may instead count from the last interaction. Controls that reappear on interaction are not modeled. The bottom fade length and shape are approximate.

Neither release readiness nor native iOS 27 Music fidelity is established.
