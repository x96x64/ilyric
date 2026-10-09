# M2 Qualification Procedure

## Purpose and Lock

October 9, 2026. This procedure defines the first locked English evaluation for M2 complete-song correspondence. It evaluates the separated-vocal CTC pipeline with the [vocal-activity rules](vocal-activity-rules.md), frozen at commit time before any locked recording is processed. The development recordings EN-F01 through EN-F03 remain regressions and cannot qualify the pipeline.

Four commercially released recordings from the maintainer's local library were selected as EN-Q01 through EN-Q04: a mid-tempo disco arrangement, a fast rock arrangement with dense guitar, a ballad-to-gospel arrangement with repeated choruses and choir, and a sparse ballad. All four are by one performer, which falls short of the release plan's target of three performers and limits generalization. Selection, titles, file locations, and original hashes are recorded only in ignored `reference-private/m2/selection.json`. The maintainer authorized local processing on the condition that the original files are never modified; the evaluation reads them in place and verifies their hashes before and after processing.

**No prediction may be produced for EN-Q01 through EN-Q04 until every reference file exists and its hash is recorded.** Thresholds, rules, and parameters must not change after the first locked run.

## Lyrics Files

The maintainer supplied lyric text for each case as `reference-private/m2/EN-Q0N.txt`. Lyrics obtained from published sources do not always match the selected recording. The supplied files are retained unchanged as source text, and paragraphs longer than four lines were split without changing any line, with the unsplit files kept as `EN-Q0N.original.txt`. During annotation, lines are corrected to what is actually sung: edited, inserted, deleted, or marked as not sung. The annotator exports the sung text as `EN-Q0N.sung.txt`, which is the authoritative input for evaluation. Constraints for the exported text are English ASCII characters, at most four lines per paragraph, and 64 paragraphs. The difference between the source and sung text is retained as a realistic mismatch control for later failure-detection evaluation. All text is copyright-bearing and remains private.

## Reference Annotation

Browsers generally cannot play the 96-kHz Apple Lossless originals. Lossless 48-kHz FLAC listening copies are therefore stored as `reference-private/m2/EN-Q0N.listen.flac`; their durations equal the originals', and the originals' hashes and modification times were verified unchanged after conversion. Separated vocal stems, `EN-Q0N.vocals.flac`, are provided only for waveform display. Separation is preprocessing, not a timing prediction, and no alignment output exists for these cases.

A first attempt at real-time onset and offset tapping proved too error-prone for reliable references. The annotator therefore uses two passes. Open `scripts/annotation/line-annotator.html`, load the listening copy, the vocal stem, and the lyrics file.

1. **Tap starts.** During playback, press `Enter` as each line begins; `Backspace` undoes the last tap. Correct the text of any line that differs from the recording.
2. **Refine on the waveform.** For each line, a zoomed vocal-stem waveform is shown around the line. Click to place the start at the first sung sound and Shift-click to place the end at the last sung sound; `P` replays the line. Mark genuinely ambiguous boundaries with `U`.

Export writes `EN-Q0N.sung.txt` and `EN-Q0N.reference.json`. Work is autosaved in the browser. A single maintainer annotation is practical engineering evidence, not independent multi-annotator ground truth; the visual vocal-stem convention may favor energy-based boundaries and is recorded as a limitation.

## Evaluation

After all references and sung-text files exist, the frozen pipeline is run once per case on the sung text with `align_full_song.py align --separator`, and `evaluate_separated_ctc.py` scores it against the complete-sequence mixture CTC baseline. The prospective M2 conditions of the [release plan](implementation-release-readiness.md) apply unchanged, reported per song:

- At least 95% of occurrences placed at the correct occurrence and at most 5% unresolved, with no unflagged wrong-chorus or multi-line displacement.
- Onset and offset separately: median absolute error at most 100 ms, p95 at most 250 ms, at most 5% above 500 ms, and no unflagged error above two seconds.
- Complete preparation at most twice the recording duration, with peak memory reported.

Lines marked uncertain are reported separately and included in denominators. Failure-detection recall requires a separate set of controlled mismatches and is not established by this procedure. Results are published only as sanitized aggregate numbers.
