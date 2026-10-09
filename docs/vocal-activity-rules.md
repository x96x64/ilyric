# Vocal-Activity Boundary and Duration Rules

## Outcome and Scope

October 9, 2026. **Two vocal-stem rules remove every observed unflagged displacement and leading-audio absorption on the development recordings.** They are development results, not qualification. The rules were selected after inspecting EN-F01 through EN-F03, so those recordings can no longer test them without bias. M2 qualification on newly supplied, independently annotated recordings remains required.

This gate follows the [separated-vocal CTC report](separated-vocal-ctc-alignment.md). The production CLI, Swift renderer, project schemas, importers, exporter, and correction format are unchanged. No downloads occurred.

## Rules

Both rules apply only when complete-sequence CTC aligns separated vocals. They use the vocal stem's 20-ms RMS level relative to its own 99th-percentile level.

1. **Implausible duration.** An estimate shorter than 40 ms per alignment character is withheld with the flag `implausible_duration`. Across the three recordings, every retained estimate that overlapped its reference lasted at least 53.3 ms per character; the single displaced estimate lasted 30 ms per character.
2. **Leading inactivity.** An estimate's onset moves to the first frame within it whose level is no more than 30 dB below the reference level. Onsets only move later; offsets and proposals never change. An estimate with no active frame is withheld with `no_vocal_activity`. The trim is recorded as `vocal_onset_trim_us`.

A symmetric rule that extended offsets through continuing vocal activity was examined and rejected: it corrected EN-F01's early offsets but overshot substantially on EN-F02 and EN-F03. A constant offset correction was not introduced, because the early-offset bias may reflect the reference annotation convention rather than acoustic error.

## Development Results

Retained-estimate errors below use the estimates themselves. Earlier reports scored proposals, which were identical to estimates before these rules; the evaluator now reports both.

| Case | Retained Estimates (Rules / Before) | Unresolved (Rules / CTC Mixture Baseline) | Retained Nonoverlap (Rules / Before) | Onset p95 / Maximum (ms, Rules) | Onset p95 / Maximum (ms, Before) |
| --- | ---: | ---: | ---: | --- | --- |
| EN-F01 | 21 / 21 | 5 / 24 | 0 / 0 | 308.2 / 553.8 | 553.8 / 13,179.6 |
| EN-F02 | 43 / 44 | 29 / 50 | 0 / 1 | 254.1 / 743.5 | 496.8 / 2,160.1 |
| EN-F03 | 41 / 41 | 1 / 13 | 0 / 0 | 600.7 / 1,339.0 | 600.7 / 1,359.0 |

Median absolute onset error is 44–50 ms on every recording. Median absolute offset error remains 214–243 ms, with estimates ending early. On this development material, every recording satisfies the M1 conditions: raw availability is at least 97.2%, unresolved occurrences are fewer than the complete-sequence mixture baseline, and no retained estimate fails to overlap its reference. Because the rules were tuned on the same recordings, this is not an M1 pass. The [numerical record](alignment-data/v15/evaluation.json) contains complete statistics.

Against the prospective M2 boundary targets, onset medians satisfy 100 ms, onset p95 exceeds 250 ms on EN-F01 and EN-F03, offset medians exceed 100 ms everywhere, and EN-F01 and EN-F02 exceed 5% unresolved. These gaps define the remaining development work.

## Verification

All 201 Python tests passed, including five new tests for duration withholding, onset-only trimming, inactive estimates, unresolved rows, and deterministic level computation. The three recordings were reprocessed end to end with the rules active.

## Next Steps

1. Obtain at least four newly supplied, lawfully usable English recordings, annotated before any prediction is inspected, and evaluate the frozen pipeline once under M2.
2. Investigate early offsets with an explicit annotation convention, distinguishing the end of the final sung vowel from the end of the textual line.
3. Reduce unresolved occurrences flagged for weak lexical agreement, which dominate EN-F02.

Neither automatic synchronization, release readiness, nor native iOS 27 Music fidelity is established.
