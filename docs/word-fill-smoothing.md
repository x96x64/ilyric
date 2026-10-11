# Word Fill Smoothing

## Outcome and Scope

October 11, 2026. **Short words no longer fill in a single frame, and sustained words no longer tremble while their emphasis grows and releases.** The maintainer observed both defects in the fifth Man in the Mirror video. Word fill now follows a smoothed paragraph front, and scaled words are resampled with high-quality interpolation.

## Measurements

The native fill front of one focused line was traced at 60 fps in the V17 capture. It advances continuously, typically at 400–900 pixels per second, with brief faster steps across spaces. A two-letter word that iLyric estimated at 0.04 s filled natively over about 0.12 s. With per-word linear fill, iLyric filled such a word within two or three frames. The overall scroll motion was compared in the same way: native and iLyric reach half of a scroll after 0.167 and 0.150 s and 90% after 0.317 and 0.333 s, so scroll timing was left unchanged.

## Implementation

`SliceParagraph` builds a piecewise-linear fill front along the paragraph's advance from the supplied word intervals. With `WordMotion.smoothing` greater than zero, each word's fill progress is derived from the exact average of that front over a centered window, computed from its knots, so every frame remains a pure function of time. A jump in the front becomes a ramp at least as long as the window, while timing far from any word boundary is unchanged. `WordMotion.measured` uses 0.12 s. Words drawn at a scale other than one are resampled with high-quality interpolation instead of the nearest-neighbor sampling used for unscaled cached glyphs. Across the rise and release of an emphasized fixture word, rendered at 60 fps, the word's ink width now changes monotonically in each phase.

Tests confirm that a 20-ms word is still filling 30 ms after it begins, that output long before and after all words is unchanged, and that smoothing windows above one second are rejected.

## Limitations

The 0.12-s window is matched to one observed word. A centered window lets a word begin filling up to half the window before its supplied start.

Neither release readiness nor native iOS 27 Music fidelity is established.
