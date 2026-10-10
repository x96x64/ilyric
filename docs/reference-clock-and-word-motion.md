# Reference Clock Correction and Word Motion

## Outcome and Scope

October 10, 2026. **The V17 reference capture's clock was misaligned by about 0.6 seconds, so the native focus lead is about 0.90 seconds rather than 0.30 seconds; iLyric's measured lead and marquee delay are corrected accordingly.** With word timings now available, the same capture also yields the native word fill: a soft edge, a small lift for every sung word, and an emphasis of scale, lift, and glow for sustained words. iLyric reproduces these as an opt-in presentation option. The reports [Lyrics Motion Timing and Stagger](lyrics-motion-timing.md) and [Title Marquee](title-marquee.md) remain historical records; this report supersedes their absolute timings.

## Clock Correction

[Lyrics Motion Timing and Stagger](lyrics-motion-timing.md) derived song time as capture time plus 0.517 s from the elapsed-time label, assuming that the label truncates. Two independent observations contradict that assumption.

1. **Progress bar.** During the first four seconds, the fill edge of the progress bar advances at 3.084 px/s, matching 987 pixels over the 318.69-second recording (3.097 px/s), with an RMS residual of 0.29 px over 187 frames. Its intercept at the measured bar origin places song time at capture time minus 0.09 s. An origin error of one pixel would move this by 0.32 s, so the uncertainty is about ±0.15 s.
2. **Word fill.** With the +0.517-s clock, native fill of 20-pixel column groups would cross half brightness a median 0.47 s after iLyric's estimated word onsets, although on human-annotated development recordings those estimates are a median 31 ms late rather than early. With the progress-bar clock, the first fill of a line follows iLyric's first-word onset by a median 0.14 s, which is consistent with the half-brightness criterion.

The label therefore appears to round rather than truncate; this remains an inference. This report uses song time = capture time − 0.09 s. Measurements that are relative within the capture (motion duration, stagger, marquee easing and period) are unaffected.

## Corrected Timings

- **Focus lead.** Native scrolling begins a median 0.90 s before iLyric's estimated onset of the next line (interquartile range 0.76–1.11 s, 62 lines). The scroll starts a median 0.33 s before iLyric's estimated end of the previous line, which version 2 rules extend through continuing vocal activity. The lead grows from 0.78 s for gaps under 0.5 s to 1.29 s for gaps of 1–2 s. A clock-independent check gives the same structure: scrolling begins a median 1.07 s before the first fill of the new line. `LocalPresentation.measuredMotion` now uses a 0.90-s lead.
- **Marquee delay.** The first title scroll begins at song time 8.11 s, not 8.71 s.

## Word Fill Measurements

The focused row of V17 was scanned at 30 fps over the whole song. For each 20-pixel column group, a fill event was recorded where ink brightness rose by at least 45% while the paragraph was stationary: 1,848 events, 1,648 within a word interval that iLyric's separated-vocal alignment estimated for the same recording.

- **Lift.** Relative to words in the same row that had not yet filled, a filling word rises 3.5 px. The rise follows a critically damped response with a 0.17-s time constant: half height after 0.27 s and 90% after 0.73 s, measured over 1,783 events. Lift grows with word duration: at 0.8 s after the fill event, words shorter than 0.3 s have risen a median 2.9 px, words of 0.6–1.0 s 4.8 px, and words of 1.5 s or longer 6.2 px.
- **Edge.** On a sustained word, the fill front moves at a steady rate with a 25–35-pixel transition between unfilled and filled ink (10–90%).
- **Emphasis.** One sustained word of 1.66 s was examined frame by frame. Image registration against its resting appearance shows scale growing to 1.05 and lift to about 12 pixels, rising during the latter part of the word and peaking at its end, together with a white glow around the filled glyphs. The emphasis disappears as the paragraph leaves focus.
- **Unfilled opacity.** Two samples gave unfilled-glyph opacities of 0.57 and 0.70 relative to filled glyphs; the existing value of 0.42 is unchanged pending a broader measurement.

## Implementation

`WordMotion` in `LyricsSliceCore` defines the edge width, lift and its time constant, the minimum emphasis duration, peak emphasis scale, additional lift, glow opacity and radius, and an emphasis release time. `WordMotion.measured` uses a 30-pixel edge, a 3.5-pixel lift with a 0.17-s time constant, and, for words of at least 1.0 s, scale 1.05, 8.5 pixels of additional lift, glow opacity 0.5 with an 18-pixel radius, and a 0.3-s release. Emphasis rises with a smoothstep over the word's interval and decays exponentially afterwards. Every quantity is a pure function of output time and the supplied word interval.

`SliceParagraph` draws each timed word at the unfilled opacity and then draws the filled ink through a linear ramp that begins entirely before the word and ends entirely after it, so the endpoints match the previous hard wipe exactly. Scale is applied about each word layer's center, the lift is not rounded to whole pixels, and the glow is drawn as an offset shadow so that it extends beyond the word's raster. `LocalPresentation.wordMotion` and `LyricsInputProbe --motion measured` enable the behavior. Tests cover continuity and bounds of lift and emphasis, snapshot values, rejection for non-Latin-timed input, exact equality with the hard wipe before a word begins, determinism, and intermediate alpha within the soft edge.

## Limitations

The emphasis constants come from one word, and the 1.0-s threshold is chosen from the duration dependence of lift rather than measured directly; the native rule may depend on syllables or supplied metadata. Glow opacity and radius were matched visually. Native glow surrounds only filled glyphs, whereas iLyric scales the glow of the whole word by its progress. The clock correction rests on the progress bar's measured origin; a future capture that shows the elapsed label through a known transition would confirm it.

Neither release readiness nor native iOS 27 Music fidelity is established.
