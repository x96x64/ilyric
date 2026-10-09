# Separated-Vocal Acceptance and Boundary Rules

## Outcome and Scope

October 10, 2026. **Version 2 vocal rules raise cross-validated correct placement from about 66% to 90.5% of lines while keeping displacement near zero.** The [locked M2 evaluation](m2-locked-evaluation.md) showed that the speech-model lexical gate rejected mostly correct proposals and that offsets ended early. Version 2 replaces the gate with separated-stem evidence, extends offsets through continuing vocal activity, and flags implausibly slow lines. Leave-one-song-out cross-validation over seventeen human-annotated recordings estimates 703 correct placements among 705 accepted of 777 lines, a median onset error of 42 ms, and a median offset error of 65 ms.

These are development estimates. The seventeen recordings comprise the three original development recordings and the fourteen M2 recordings, which became development material once observed. No unseen requalification has occurred, and M2 is not passed by this report.

## Rules

Version 2 applies only when complete-sequence CTC aligns separated vocals. Proposals are preserved unchanged.

1. **Acceptance.** A proposal becomes an estimate when its forced-path mean log support is at least −3.5, its greedy similarity is at least 0.15, and its duration lies between 40 and 400 ms per alignment character. Rejections carry `weak_separated_support`, `weak_separated_lexical_agreement`, `implausible_duration`, or `implausible_rate`. Earlier speech-model flags remain as diagnostics.
2. **Onset.** The onset moves later past leading frames more than 30 dB below the stem's 99th-percentile level, as in version 1.
3. **Offset.** The offset extends through following frames no more than 20 dB below the reference level, by at most 0.6 seconds and never past the next proposal's onset.
4. **Uncertain boundary.** An estimate whose duration per character exceeds 1.75 times the song's median accepted rate keeps its estimate and receives `uncertain_boundary`.

Estimates without active vocal frames are withheld with `no_vocal_activity`. The engine record stores every parameter under `vocal_rules`, version 2.

## Selection Method

For each of the seventeen recordings in turn, rule parameters were chosen on the other sixteen and scored on the held-out recording. Acceptance thresholds maximized correct accepted proposals with a penalty of 25 per displaced acceptance. Boundary parameters minimized a weighted sum of onset and offset median and p95 errors. `scripts/cross_validate_vocal_rules.py` reproduces the procedure from private inputs. The selected acceptance thresholds were identical in fifteen folds, and the boundary parameters in sixteen; the uncertain-boundary ratio was identical in all seventeen.

Two alternatives were examined and rejected: a constant offset shift of up to 250 ms, which the exploratory cross-validation never preferred over activity-based extension, and stricter acceptance thresholds, which discarded correct proposals.

## Results

| Measure | Cross-Validated Estimate |
| --- | ---: |
| Lines | 777 |
| Accepted / correct placement | 705 / 703 (90.5% of lines) |
| Onset median / p95 | 42 / 335 ms |
| Offset median / p95 | 65 / 713 ms |
| Onset / offset errors > 500 ms | 4.5% / 7.0% |
| Errors > 2 s | 21 |

In the development analysis of the selected rule, `uncertain_boundary` flagged 52 of 700 estimates and covered 11 of 15 errors above two seconds. Large errors arise mainly where a line absorbs a sustained note, an ad-lib, or an adjacent instrumental passage.

End-to-end processing of all seventeen recordings with the implemented rules, using parameters chosen on every song, placed 700 of 777 lines correctly with no displaced estimate; six songs met the 95% placement condition and the 5% unresolved condition. These figures verify that the implementation matches the cross-validated simulation and are optimistic. Remaining M2 gaps are onset and offset p95 errors, the residual errors above two seconds, and unresolved lines concentrated in a few songs. The [numerical record](alignment-data/v17/evaluation.json) contains cross-validated, per-song, and parameter-selection results.

## Verification

All Python tests passed, including eight rewritten vocal-rule tests covering acceptance, rate bounds, onset trimming, bounded offset extension that stops at the next proposal, inactive estimates, uncertain flags, unresolved rows, and deterministic level computation.

## Next Steps

Requalification requires recordings unseen by this development, scored once by an isolated evaluation with the frozen pipeline. Further development should target long-line absorption, which dominates the remaining large errors, and the songs with the most unresolved lines. Japanese automatic alignment remains unevaluated.

Neither automatic synchronization, release readiness, nor native iOS 27 Music fidelity is established.
