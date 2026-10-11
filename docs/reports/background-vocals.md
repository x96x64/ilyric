# Background Vocals

## Outcome and Scope

October 11, 2026. **Background vocals now appear as a smaller secondary line under the focused lyric line, as on the native screen.** Lyrics may mark them with parentheses; the alignment tool attaches them to the aligned lines at export, and the TTML importer reads them from `ttm:role="x-bg"` spans, the convention used by Apple's TTML lyrics. Background vocals are not aligned separately: a secondary line fills across its main line's interval, which is an approximation.

## Measurements

In the V17 reference capture, the same phrase appears once as a focused main line and later as a background line. Both are bold. The background line's ink is 0.652 times as wide, so its type size is taken as 0.652 of the main size. It shares the main line's left margin, its first baseline lies about 138 pixels below the main line's last baseline, and it shows the same unfilled-then-filled treatment as the main line. In the sampled frames, background lines appear only under the focused line.

## Implementation

- **Export.** `background_vocals()` matches each lyrics line, with parenthesized phrases removed and whitespace normalized, to the next aligned line with the same text; its phrases become that line's background vocals. A line made only of parenthesized phrases attaches to the most recently matched line. `align_full_song.py export --background FILE` writes untimed `ttm:role="x-bg"` spans, which inherit the line's interval, for line and word granularity.
- **Import.** The TTML importer accepts at most one `ttm:role="x-bg"` span per paragraph, excludes it from the main text, and records its text and interval in `LyricEntry.background`. Other `ttm:role` values are rejected.
- **Display.** `SecondaryLine` holds the text, interval, and measured layout constants. `ScreenRenderer` draws it wrapped to the paragraph width at the measured size and offset, with the unfilled opacity and a 30-pixel soft fill ramp, weighted by the same focus transition that blends the focused paragraph. `LocalScene` reserves layout space below such a paragraph and applies the word fill lead to the secondary interval.

Tests cover the mapping, export, parsing, rejection of other roles, layout reservation, and drawing only under the focused paragraph.

## Limitations

Background vocals overlapping the lead vocal are not aligned, so their fill follows the main line rather than the backing singers. The native screen expands space for a background line only while it is focused; iLyric reserves the space permanently. The reserved height for wrapped background lines is estimated from character count. The offset and size come from a single phrase.

Neither release readiness nor native iOS 27 Music fidelity is established.
