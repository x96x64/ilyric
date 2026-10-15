# Reviewing and Correcting an Alignment

Automatic timing should be checked against the recording before publishing a video. The report records the evidence and fallback decisions; an `aligned` status is not a guarantee that a line is correct.

## Produce Reviewable Files

Use your own matching recording and plain lyrics:

```bash
ilyrics align song.m4a lyrics.txt -o lyrics.ttml --report alignment.json --verbose
ilyrics render song.m4a lyrics.ttml -o review.mp4
```

Choose unused output names, or use `--force` deliberately to replace existing files. Inspect the report, listen to the recording, and review the video. Start with placed or omitted lines, then inspect aligned lines where timing sounds wrong. Editing the JSON report does not change the TTML or rendered video.

## Read the Alignment Report

`align --report` writes `ilyrics-alignment-report-1`. `render --report` writes `ilyrics-render-report-1`; when rendering plain text, its `alignment` field contains the same alignment-report structure. Rendering supplied timing has no `alignment` field because no alignment was performed.

| Field | Meaning |
| --- | --- |
| `audio`, `duration_us` | Audio basename and decoded duration in microseconds |
| `compute_units` | `cpu` by default; `all` with `--fast` |
| `ignored_input_lines` | Discarded input lines with reasons, including section labels |
| `seconds` | Measured processing seconds for decoding, separation, and alignment |
| `lines[].line`, `text` | One-based normalized lyric-line number and displayed text; the number is not necessarily the physical source-file line |
| `status` | `aligned`: an acoustic estimate was accepted; `placed`: fallback timing was assigned; `omitted`: an unresolved vocable-only line was omitted from TTML |
| `interval_us` | Start/end pair in microseconds from audio start; an accepted interval or fallback interval. An omitted row can still contain fallback metadata, but is absent from exported TTML |
| `flags` | Diagnostic reasons associated with the alignment decision |
| `background` | Associated backing text, or `null`; existing support restrictions apply |
| `words` | Accepted word estimates, or `null`; each has `start_utf16`, `length_utf16`, and `interval_us` |
| `proposal_us`, `proposal_words` | Candidate line and word timing before acceptance, or `null`; these are not additional accepted estimates |
| `support`, `similarity` | Acoustic support and text-similarity diagnostics, or `null`; neither is a calibrated probability of correctness |
| `language`, `readings` | Present only with `--language ja`: `"ja"`, and the readings used for words aligned by pronunciation, each with `line`, `text`, and `reading` |

Word text ranges are zero-based UTF-16 code-unit offsets into that row's `text`, not byte offsets or character counts. Intervals are half-open: the start is included and the end excluded. Divide microseconds by 1,000,000 to obtain seconds. `null` means that the estimate or diagnostic is unavailable; it does not mean zero. Low-confidence accepted lines may be exported with a steady line-level fill rather than separate word fills, so inspect the TTML as well as the report.

For example, this illustrative excerpt identifies a fallback line; it is not a complete report or a measured result:

```json
{
  "line": 2,
  "text": "Morning light",
  "status": "placed",
  "interval_us": [3000000, 5500000],
  "words": null
}
```

This interval is 3.0–5.5 seconds. It does not establish that those words were sung there. `--keep-ad-libs` retains otherwise omitted vocables without making their timing reliable.

## Correct the TTML

Make a copy so the original automatic result remains available:

```bash
cp lyrics.ttml lyrics-reviewed.ttml
```

In a text editor, locate the paragraph by its text. If listening establishes that an illustrative `Morning light` line should run from 3.2 to 5.7 seconds, change:

```xml
<p begin="3s" end="5.5s">Morning light</p>
```

to:

```xml
<p begin="3.2s" end="5.7s">Morning light</p>
```

The exact values must come from your recording. For a word-timed paragraph, span `begin` and `end` values are relative to the paragraph's start. Moving the paragraph with unchanged span values moves all its words together. Changing the paragraph's duration may require changing its span intervals so that they still fit. Keep paragraphs and spans ordered and non-overlapping, preserve spaces inside spans, and avoid adding formatting whitespace between spans. See the [TTML rules](input-formats.md#ttml).

```bash
ilyrics render song.m4a lyrics-reviewed.ttml -o reviewed.mp4
```

This uses your supplied timing without realignment. Listen and inspect again; the renderer validates the format and interval bounds, not whether the words match the singing.

## Render Reports and Sharing

A render report contains `frames`, `jobs`, and an `export` object. Export metrics include `width`, `height`, `frames`, elapsed processing `seconds`, `effectiveFPS`, and the measured `rasterSeconds`, `appendSeconds`, `backpressureSeconds`, and `finishSeconds`. Processing time is not video duration; at 60 fps, video duration is `frames / 60`. The timing components may overlap and should not be added as an elapsed-time total.

Reports can contain lyric text, backing text, discarded input lines, and the audio basename. Before attaching a report to an issue, remove material you cannot share while retaining the fields needed to explain the problem. See [Getting Help](../SUPPORT.md#getting-help).
