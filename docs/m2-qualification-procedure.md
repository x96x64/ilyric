# M2 Qualification Procedure

## Purpose and Lock

October 9, 2026. This procedure defines the first locked English evaluation for M2 complete-song correspondence. It evaluates the separated-vocal CTC pipeline with the [vocal-activity rules](vocal-activity-rules.md), frozen at commit time before any locked recording is processed. The development recordings EN-F01 through EN-F03 remain regressions and cannot qualify the pipeline.

Four commercially released recordings from the maintainer's local library were selected as EN-Q01 through EN-Q04: a mid-tempo disco arrangement, a fast rock arrangement with dense guitar, a ballad-to-gospel arrangement with repeated choruses and choir, and a sparse ballad. All four are by one performer, which falls short of the release plan's target of three performers and limits generalization. Selection, titles, file locations, and original hashes are recorded only in ignored `reference-private/m2/selection.json`. The maintainer authorized local processing on the condition that the original files are never modified; the evaluation reads them in place and verifies their hashes before and after processing.

**No prediction may be produced for EN-Q01 through EN-Q04 until every reference file exists and its hash is recorded.** Thresholds, rules, and parameters must not change after the first locked run.

## Lyrics Files

For each case, the maintainer places the complete lyric text in `reference-private/m2/EN-Q0N.txt`, using the lyrics as sung on the selected recording:

- UTF-8 plain text, one sung line per text line, with paragraphs separated by one blank line.
- At most four lines per paragraph and 64 paragraphs; no whitespace-only lines.
- English ASCII letters, digits, punctuation, and apostrophes only; the current full-song CTC path rejects other scripts.
- Repeated choruses, ad-libs, and backing lines that are clearly sung as lead lyrics are written out each time they occur. Purely background vocals may be omitted, but the choice must be consistent within a song.

The text is copyright-bearing and remains private.

## Reference Annotation

Open `scripts/annotation/line-annotator.html` in a browser, load the original recording and the lyrics file, and mark each line. The tool loads no predictions and uploads nothing.

1. Press `J` at the first sung sound of the current line and `K` at the last sung sound; `K` advances to the next line. Reduced playback speed is permitted.
2. Press `U` for a line whose boundary is genuinely ambiguous, such as overlapping vocals or a line that merges into the next.
3. Review every line once at normal speed, correcting with the arrow keys, `J`, `K`, and `Backspace`.
4. Export the result to `reference-private/m2/EN-Q0N.reference.json`.

The convention is first-to-last sung sound per supplied line. It may differ from earlier references, whose offsets appear later than the vocal-stem estimates; the [separated-vocal report](separated-vocal-ctc-alignment.md) records that unresolved bias. A single maintainer annotation is practical engineering evidence, not independent multi-annotator ground truth.

## Evaluation

After all references exist, the frozen pipeline is run once per case with `align_full_song.py align --separator`, and `evaluate_separated_ctc.py` scores it against the complete-sequence mixture CTC baseline. The prospective M2 conditions of the [release plan](implementation-release-readiness.md) apply unchanged, reported per song:

- At least 95% of occurrences placed at the correct occurrence and at most 5% unresolved, with no unflagged wrong-chorus or multi-line displacement.
- Onset and offset separately: median absolute error at most 100 ms, p95 at most 250 ms, at most 5% above 500 ms, and no unflagged error above two seconds.
- Complete preparation at most twice the recording duration, with peak memory reported.

Lines marked uncertain are reported separately and included in denominators. Failure-detection recall requires a separate set of controlled mismatches and is not established by this procedure. Results are published only as sanitized aggregate numbers.
