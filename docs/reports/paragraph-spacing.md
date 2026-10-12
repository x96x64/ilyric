# Paragraph Spacing

## Outcome

October 12, 2026. **The space between consecutive paragraphs was a provisional constant of 110 native pixels and is now 75 pixels, measured on a development capture.** Consecutive single-line paragraphs on the native screen are about 200 px apart; iLyrics placed them 235.5 px apart.

## Discovery

While the paired comparison for the remaining visual properties was being prepared, a frame of the held-out capture N01 placed beside iLyrics's rendering of the same song showed the same line height within paragraphs but visibly wider spacing between them. The [typography qualification](visual-qualification-results.md) measured wrapping and line ink width, not paragraph positions, so this difference had not been measured. The spacing in `LocalScene` was marked in the code as provisional. The held-out capture was used only to notice the difference; it was not measured for the correction.

## Measurement

`scripts/reference_validation/dev_pitch.py` samples settled frames of the development recordings (frames whose lyric column does not change within 0.3 s), finds the centres of text rows below the header, and records the distances between consecutive rows. Distances within a paragraph cluster near the line advance; distances between paragraphs form a second cluster.

On V17, the most recent development capture and the one recorded with the settings of the held-out captures:

| Cluster | Distances | Median | Interquartile range |
| --- | ---: | ---: | ---: |
| Within a paragraph (110 to 140 px) | 120 | 125.0 px | 123 to 127 px |
| Between paragraphs (180 to 225 px) | 26 | 200.5 px | 192 to 202.75 px |

The within-paragraph median agrees with the line advance of 125.5 px fitted earlier. The spacing beyond the line advance is therefore about 200.5 − 125.5 = 75 px. The pooled distances over all seventeen development recordings show the same cluster near 200 px, together with clusters from background vocals and from rows that were not detected; several older recordings use other settings or contain few settled frames, so V17 alone sets the value.

## Change

`LocalScene.paragraphSpacing` is 75 px. Line advance, background-vocal spacing, and the gap slot are unchanged. The renderer's tests pass unchanged, because no test fixed the provisional value.

## Held-Out Check

After the change, the held-out captures N01 to N03 were rendered with iLyrics and measured with the same row-profile method in settled frames between 10 and 170 s. This check was not part of the approved visual qualification plan and has no pre-registered threshold.

| Capture | Native paragraph distance | iLyrics paragraph distance | Native line distance | iLyrics line distance |
| --- | ---: | ---: | ---: | ---: |
| N01 | 201.0 px (7) | 200.0 px (61) | 125.0 px (24) | 127.0 px (30) |
| N02 | 199.0 px (68) | 200.0 px (64) | 122.0 px (138) | 127.0 px (72) |
| N03 | 197.0 px (16) | 199.0 px (17) | 124.0 px (37) | 128.0 px (32) |

Medians, with the number of distances in parentheses. Paragraph distances agree within 2 px. Line distances in the iLyrics renderings are 2 to 5 px larger than native; the method locates blurred text rows at about 2-px resolution and the renderings are scaled from 1080 × 1920 to the native canvas, so this difference is not resolved here.

## Limitations

The value rests on 26 distances from one development capture, measured from row-profile peaks of blurred inactive text at a resolution of about 2 px. Paragraphs followed by background vocals and gap slots were not measured separately. The held-out check above is a single unregistered comparison; the paired comparison of the remaining properties is rendered with this change.
