# Word Fill Continuity and Emphasis Selection

## Outcome and Scope

October 11, 2026. **The word fill now runs continuously through each line, and sustained-word emphasis is limited to the last word of a line lasting at least 1.5 seconds.** The maintainer observed, in the seventh Man in the Mirror video, that the fill paused briefly after each word and that emphasis appeared too often, including in the middle of lines.

## Emphasis Selection

The faint-halo signal of the native glow was compared, in the V17 capture, with iLyric's word estimates of at least 0.6 s. Words of 1.0–2.0 s in the middle of a line produced no halo response (−2,316 to 5,086 halo pixels above the running median), whereas most long line-final words produced strong responses (19,000–38,000). Line-final responses coincide with scrolling, which also changes the halo signal, so the duration threshold could not be measured precisely. With [the earlier rule](reference-clock-and-word-motion.md), every word of at least 1.0 s, 23 words of this recording were emphasized. Requiring the last word of the line removes the mid-line cases, and raising the duration to 1.5 s, which still includes the frame-by-frame example of 1.66 s, leaves 7. `WordMotion.emphasisFinalOnly` restricts emphasis to the last timed word of a paragraph, and `WordMotion.measured` uses 1.5 s.

## Fill Continuity

Native fill does not pause between words: when a gap separates two sung words, the earlier word fills more slowly and finishes when the next begins. With `WordMotion.bridgesGaps`, each word's segment of the paragraph's fill front extends to the next word's start, and the existing 0.12-s smoothing then removes the remaining changes of speed. Lift and emphasis keep the supplied word intervals.

Tests confirm that a long mid-line word is not emphasized while a long final word is, and that a word is still filling during the gap before the next word.

## Limitations

The 1.5-s threshold reflects the maintainer's comparison and one measured example, not a fitted value; emphasis of words with long offset extensions may still exceed the native rate.

Neither release readiness nor native iOS 27 Music fidelity is established.
