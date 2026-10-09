# Complete-Sequence CTC Alignment on Separated Vocals

## Outcome and Scope

October 9, 2026. **Aligning the complete supplied lyrics to separated vocals is the strongest synchronization result recorded by iLyric, but it does not pass M1 under the frozen criteria.** Replacing the mixture with the pinned Demucs vocal stem as the CTC input doubled retained line estimates from 53 to 106 of 140 occurrences and reduced unresolved occurrences from 87 to 34. EN-F01 and EN-F03 satisfied every M1 condition. EN-F02 failed one condition: a single retained estimate did not overlap its reference and was not flagged as a displacement.

This experiment follows the [vocal-separation recognition report](vocal-separation-recognition.md), which identified it as the next single step. No new model or package was downloaded. The production CLI, Swift renderer, project schemas, importers, exporter, and correction format are unchanged.

## Implemented Change

`align_full_song.py align --separator PATH` runs the pinned `htdemucs` separation described in the previous report and replaces the 16-kHz mixture with the aligned 16-kHz vocal stem as the input to the existing windowed English CTC alignment. The source hash, duration, window plan, central frame ownership, monotonic path, proposal rules, review flags, and artifact format are unchanged; the engine record adds the separation identity. Running EN-F01 without `--separator` reproduced the frozen complete-sequence CTC artifact exactly.

EN-F01 served as development without parameter changes. Five implementation files were [hashed and frozen](alignment-data/v14/frozen-policy.json) before EN-F02 and EN-F03. Two model-free tests cover the option and its unavailable-dependency exit status.

## Measured Results

References entered scoring only. Raw availability counts proposals that overlap the corresponding reference interval; overlap does not verify the sung words.

| Case | Lines | Raw Availability (Separated / Mixture) | Retained Estimates (Separated / Mixture) | Unresolved (Separated / Mixture) | Retained Nonoverlap (Separated / Mixture) | M1 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| EN-F01 | 26 | 26 (100%) / 18 | 21 / 2 | 5 / 24 | 0 / 0 | Pass |
| EN-F02 | 72 | 70 (97.2%) / 70 | 44 / 22 | 28 / 50 | 1 / 0 | Fail |
| EN-F03 | 42 | 42 (100%) / 41 | 41 / 29 | 1 / 13 | 0 / 0 | Pass |

The EN-F02 displacement concerns one short line whose reference lasts approximately 0.45 seconds. The retained estimate lasts 60 milliseconds and begins approximately 1.7 seconds after the reference ends, between correctly placed neighbors. It carries only the generic repeated-occurrence review flag. No retained estimate overlapped a different identical occurrence.

| Case | Retained Timing Denominator | Onset Median / p95 / Maximum (ms) | Offset Median / p95 / Maximum (ms) | Onset / Offset Errors >500 ms |
| --- | ---: | --- | --- | --- |
| EN-F01 | 21 | 47.7 / 553.8 / 13,179.6 | 242.9 / 474.6 / 844.4 | 2 / 1 |
| EN-F02 | 44 | 47.8 / 496.8 / 2,160.1 | 217.2 / 633.8 / 1,767.5 | 3 / 8 |
| EN-F03 | 41 | 49.6 / 600.7 / 1,359.0 | 234.7 / 443.7 / 459.0 | 3 / 0 |

These errors compare supplied line annotations and are conditional on the existing proposal rules. The [numerical record](alignment-data/v14/evaluation.json) contains complete flags and distributions.

## Interpretation

Separation removes the dominant acoustic obstacle to forced alignment of the supplied text. Recognition coverage, which limited the anchor architecture, does not constrain this path because the supplied lyrics remain authoritative and complete. Repeated-occurrence placement was also correct for every retained estimate.

The remaining failures are boundary and failure-detection problems rather than correspondence failures:

1. **Unflagged short-line displacement.** A very short estimate for a multi-character line was accepted.
2. **Leading-audio absorption.** EN-F01's first line began approximately 13.2 seconds early, absorbing introductory audio; it remained unflagged.
3. **Systematic early offsets.** Median absolute offset error is 217–243 ms on every recording, while median absolute onset error is 48–50 ms. Signed development analysis shows that estimates end before the reference: median signed offset error is −243, −155, and −235 ms. This may reflect CTC emission timing on sustained final vowels or a difference in annotation convention; its cause is not established.
4. **Residual unresolved lines.** EN-F02 retains 28 unresolved occurrences, mostly with weak lexical agreement.

Against the prospective M2 targets, onset medians already satisfy the 100-ms condition, but onset p95, offset median, unresolved fraction on EN-F01 and EN-F02, and the absence of unflagged errors above two seconds do not. EN-F02 and EN-F03 have now been observed with this architecture and can no longer serve as unbiased holdouts.

## Performance and Verification

Complete preparation took 164.3, 231.2, and 251.1 seconds, of which separation took 142.4, 197.4, and 220.1 seconds; CTC inference took 10.8–18.1 seconds. EN-F02 and EN-F03 ran concurrently with each other and with background-model fitting, so these are upper bounds. Peak RSS was 2.51–2.96 GB. The proposed operational target of at most twice the recording duration requires controlled measurement.

All 196 Python tests passed. No downloads occurred. The [verification record](alignment-data/v14/verification.json) lists sanitized measurements.

## Decision and Next Gate

**M1 no-go by one unflagged displacement; go for separated-vocal CTC as the lead synchronization architecture.** The Whisper anchor path is retained only as historical evidence.

The next gate should develop failure detection and boundary treatment on EN-F01 through EN-F03, which are now development material, without relaxing any acceptance threshold: implausible-duration flags for short estimates, detection of leading and trailing audio absorbed by the first and last lines, and investigation of the offset bias, using vocal-stem activity as evidence where it is independently justified. Qualification then requires a new locked English set under M2: at least four newly supplied, lawfully usable recordings annotated before any prediction is inspected. Japanese automatic alignment remains unevaluated.

Neither automatic synchronization, release readiness, nor native iOS 27 Music fidelity is established.
