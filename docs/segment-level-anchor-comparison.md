# Segment-Level Anchor Comparison

## Outcome and Scope

October 9, 2026. **M1 does not pass, and segment-level anchors do not materially improve correspondence.** Retaining native Whisper segment intervals recovered nineteen previously missing correct-region candidates but lost eleven, a net gain of eight across 140 occurrences. Correct-region availability remained below 90% on every recording. Bounded CTC refinement retained seventeen line estimates, compared with nineteen for word-split anchors and 53 for the frozen complete-sequence CTC baseline.

The recognized lexical content was identical under both representations in all 26 windows. Twenty-nine occurrences lacked sufficient raw lexical support even inside reference-overlapping windows. Timestamp-representation changes alone therefore cannot satisfy M1. This report continues the [Whisper evaluation](audio-derived-correspondence-evaluation.md) and preserves the seven milestones of the [release plan](implementation-release-readiness.md). The production CLI, Swift renderer, project schemas, LRC/TTML importers, audiovisual exporter, correction format, and historical evaluation records are unchanged.

## Implemented Comparison

`scripts/alignment/segment_anchors.py` defines the experimental `ilyric-segment-evidence-1` record. The only decoding change is `whisper.cpp` `-ml 0` instead of `-ml 1`; the pinned multilingual `small` checkpoint, automatic 30-second windows at 26-second strides, greedy decoding, explicit English, and disabled context are unchanged. `prepare_audio_correspondence.py --anchor-mode segment` selects the representation; the default remains the frozen word mode.

Each segment retains its exact recognized text and raw offsets. Segment support is classified as `valid`, `missing`, `invalid`, `out_of_window`, or `ambiguous` (nonchronological within a window) without rounding, clamping, or interpolation. Token-level timing problems are counted separately and never used as boundaries. A valid segment projects its lexical tokens onto the unchanged anchor format with the same parent interval; this is explicitly not word timing. The frozen matcher, thresholds, midpoint window ownership, chronological frontier, ambiguity rule, and bounded CTC refinement are unchanged.

Fourteen public synthetic tests cover invalid token times, missing and out-of-window support, exact non-frame-aligned representation, unmodified Unicode, nonchronological ambiguity, shared segments, repeated occurrences, extra repetitions, window ownership, correction reuse, tamper detection, resource limits, the single decoding difference, and reference-separated scoring. They require no models or private media.

## Baseline Reproduction and Freezing

All three frozen word-mode artifacts were reproduced before the change: `anchors.json`, `correspondence.json`, and `prepared.json` were semantically identical after excluding runtime measurements. EN-F01 served as the development case. No thresholds, windows, or matcher parameters were tuned. Eight implementation files, the decoding arguments, and the matching policy were [hashed and frozen](alignment-data/v12/frozen-policy.json) before EN-F02 and EN-F03. A repeated EN-F01 run produced an identical prepared artifact after excluding measurements.

## Measured Results

References entered scoring only. Correct-region availability means that an eligible candidate overlaps the corresponding reference interval; it does not verify the sung words.

| Case | Lines | Word Availability | Segment Availability | Recovered / Lost | Segment Supported Regions | Final Estimates (Segment / Word / CTC) | Unresolved (Segment / CTC) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| EN-F01 | 26 | 19 (73.1%) | 18 (69.2%) | 2 / 3 | 12 | 2 / 3 / 2 | 24 / 24 |
| EN-F02 | 72 | 43 (59.7%) | 50 (69.4%) | 15 / 8 | 34 | 6 / 10 / 22 | 66 / 50 |
| EN-F03 | 42 | 31 (73.8%) | 33 (78.6%) | 2 / 0 | 27 | 9 / 6 / 29 | 33 / 13 |

No selected segment region failed to overlap its reference, no wrong-repeated-reference overlap was observed, and no retained estimate introduced a new nonoverlap. These observations do not offset the coverage failure: 123 of 140 occurrences remain unresolved after refinement.

Broad segments widen coarse regions. Segment coarse-region onset p95 was 1918, 2738, and 2439 ms, against 1445, 781, and 1140 ms for word-split anchors. In EN-F01, several supplied lines shared one segment interval; the unchanged chronological matcher could not select them together, which accounts for the three lost regions. No hidden subdivision was introduced to conceal that conflict.

| Case | Retained Timing Denominator | Onset Median / p95 / Maximum (ms) | Offset Median / p95 / Maximum (ms) | Onset / Offset Errors >500 ms |
| --- | ---: | --- | --- | --- |
| EN-F01 | 2 | 22.9 / 27.3 / 27.8 | 346.5 / 399.4 / 405.3 | 0 / 0 |
| EN-F02 | 6 | 106.4 / 1,840.9 / 2,179.8 | 247.4 / 803.0 / 943.7 | 2 / 1 |
| EN-F03 | 9 | 165.1 / 1,519.4 / 1,553.7 | 337.5 / 1,053.4 / 1,513.2 | 4 / 1 |

These errors are conditional on support filtering and compare supplied line annotations, not independently verified vocal boundaries. Complete per-case counts, flags, and distributions appear in the [numerical record](alignment-data/v12/evaluation.json).

## Failure Localization

1. **Recognition coverage is dominant.** The [lexical comparison](alignment-data/v12/lexical-comparison.json) found identical raw lexical tokens (242, 488, and 427) under both representations. Within reference-overlapping windows, 5, 15, and 9 occurrences had no raw lexical support under the unchanged edit criterion. Retaining segment text cannot recover words that were never recognized.
2. **Representation loss is real but small.** Three, eight, and zero missing occurrences had raw lexical support without an eligible correct-region candidate. Segment retention recovered part of this loss and introduced comparable loss through broader shared intervals.
3. **Window ownership is minor.** Post-selection single-window analysis without midpoint ownership found one additional region, in EN-F02.
4. **Boundary refinement remains a separate limitation.** Of 73 segment-supported regions, CTC retained seventeen. Chronological conflict, weak lexical agreement, and weak acoustic support remain the most frequent rejection flags.

## Performance and Verification

Measurements used Apple M4, 16 GiB, macOS 27.0.1, and the existing isolated Python 3.12.14 environment. Complete processing took 24.6, 33.6, and 77.9 seconds. Parent peak RSS was 1.15–1.41 GB; the maximum Whisper child peak was 0.67 GB. These are separate high-water marks, not a simultaneous process-tree peak. Concurrent work may influence timings.

All 186 Python and 61 Swift tests passed in the working tree and in a fresh public checkout without models, private recordings, or network access. Release builds, raw BGRA determinism, and the synthetic preparation/correction/export check (1080×1920, 601 frames) passed. The [verification record](alignment-data/v12/verification.json) lists sanitized environment, performance, and resource measurements.

No downloads occurred. The comprehensive allocated inventory began at 15,921,377,280 bytes and measured 16,774,549,504 bytes after documentation verification, below the 17,000,000,000-byte ceiling; growth includes verification rebuilds. Private recordings, lyrics, raw recognition, model weights, and generated media remain ignored.

## Decision and Next Gate

**M1 no-go. Further timestamp-representation or ranking changes to the current Whisper path are not justified.** Segment anchors confirm the earlier localization: most missing correspondence arises from absent lexical recognition in accompanied singing, not from discarded timing.

The smallest justified architectural change is a single permissively licensed vocal-separation stage before audio-only recognition, evaluated under the unchanged M1 criteria with EN-F01 development and frozen EN-F02/03 comparison. The separation model, its code and weight licenses, exact artifact identities, and resource requirements must be documented and explicitly approved before provisioning; current headroom is insufficient without revised authorization. If separation does not raise raw lexical coverage and correct-region availability to the M1 threshold, the next single step is a bounded comparison with one singing-specific aligner rather than further Whisper tuning.

Neither automatic synchronization, release readiness, nor native iOS 27 Music fidelity is established.
