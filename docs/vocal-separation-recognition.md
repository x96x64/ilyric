# Vocal Separation Before Recognition

## Outcome and Scope

October 9, 2026. **A1 does not pass M1.** Separating vocals with the pinned Demucs `htdemucs` checkpoint before audio-only Whisper recognition raised correct-region availability from 93 to 104 of 140 occurrences, but every recording remained below the 90% threshold. Raw lexical coverage barely changed: occurrences without any raw lexical support fell only from 29 to 26. Bounded CTC refinement retained sixteen estimates, against nineteen for mixture-input Whisper anchors and 53 for the frozen complete-sequence CTC baseline.

The result localizes the limitation further. Removing accompaniment does not make Whisper `small` recognize substantially more sung lyrics. Audio-only recognition coverage, not accompaniment interference with recognition, is the dominant constraint of the anchor architecture. This report follows the [segment-level comparison](segment-level-anchor-comparison.md) and the [release and fidelity decisions](release-and-fidelity-decisions.md). The production CLI, Swift renderer, project schemas, importers, exporter, and correction format are unchanged.

## Provisioning

The maintainer raised the cumulative download ceiling to 2,200,000,000 bytes and the storage ceiling to 18,000,000,000 bytes for this gate, as recorded in the [resource policy](evaluation-resource-policy.md). Only three artifacts were transferred, totaling 84,264,297 bytes; each matched its pinned SHA-256 value, as recorded in the [provisioning record](alignment-data/v13/provisioning.json):

- `htdemucs` checkpoint `955717e8-8726e21a.th`, 84,141,911 bytes, from Meta's Demucs distribution host. Demucs code is MIT-licensed; the checkpoint carries no separate license statement. Upstream documentation states training on MUSDB18-HQ plus 800 non-public songs. The checkpoint is not redistributed.
- `demucs` 4.1.0 and `julius` 0.2.8 wheels, both MIT-licensed, installed offline without dependency resolution into the existing isolated research environment. `lameenc`, `sphn`, and `torchaudio` were not required and were not installed.

The upstream `facebookresearch/demucs` repository was archived on January 1, 2025; the maintained fork published version 4.1.0. Licensing statements are documented claims, not legal advice.

## Implemented Change

`scripts/alignment/vocal_separation.py` verifies the checkpoint identity and package versions, decodes the original audio to 44.1-kHz stereo, applies the model on CPU with `shifts=0`, `split=True`, and `overlap=0.25`, and restores the input normalization. The vocal stem is averaged to mono, converted to 16 kHz by polyphase resampling, and aligned to the mixture's analysis sample count; a difference of more than two samples is rejected. `prepare_audio_correspondence.py --separator PATH` enables the stage.

Separated vocals change only the Whisper window input. CTC refinement continues to use the original mixture, so this experiment isolates recognition. Windows, decoding, matching, thresholds, and refinement are unchanged. Running EN-F01 without `--separator` reproduced the frozen anchors, correspondence, and prepared artifact exactly. Eight model-free tests cover optional activation, identity enforcement, policy, exact sample counts, downmixing, bounded length alignment, and preservation of the mixture for refinement.

EN-F01 served as development without parameter tuning. Seven implementation files and the separation policy were [hashed and frozen](alignment-data/v13/frozen-policy.json) before EN-F02 and EN-F03.

## Measured Results

References entered scoring only. Correct-region availability means that an eligible candidate overlaps the corresponding reference interval; it does not verify the sung words.

| Case | Lines | Mixture Availability | Separated Availability | Recovered / Lost | Supported Regions | Nonoverlap / Wrong Repeat | Final Estimates (Separated / Mixture / CTC) | Unresolved (Separated / CTC) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| EN-F01 | 26 | 19 (73.1%) | 19 (73.1%) | 4 / 4 | 18 | 0 / 0 | 3 / 3 / 2 | 23 / 24 |
| EN-F02 | 72 | 43 (59.7%) | 51 (70.8%) | 12 / 4 | 48 | 6 / 2 | 8 / 10 / 22 | 64 / 50 |
| EN-F03 | 42 | 31 (73.8%) | 34 (81.0%) | 3 / 0 | 28 | 0 / 0 | 5 / 6 / 29 | 37 / 13 |

In EN-F02, six selected regions failed to overlap their references, two of them overlapping another identical chorus occurrence. Bounded CTC rejected all six, so no retained estimate introduced a new nonoverlap. These selections nonetheless show that additional candidates also add wrong-occurrence risk.

| Case | Raw Lexical Tokens (Separated / Mixture) | Reference-Window Lexical Coverage (Separated / Mixture) | No Raw Lexical Support (Separated / Mixture) |
| --- | ---: | ---: | ---: |
| EN-F01 | 231 / 242 | 23 / 21 | 3 / 5 |
| EN-F02 | 507 / 488 | 57 / 57 | 15 / 15 |
| EN-F03 | 414 / 427 | 34 / 33 | 8 / 9 |

| Case | Retained Timing Denominator | Onset Median / p95 / Maximum (ms) | Offset Median / p95 / Maximum (ms) | Onset / Offset Errors >500 ms |
| --- | ---: | --- | --- | --- |
| EN-F01 | 3 | 27.8 / 40.5 / 41.9 | 287.7 / 375.5 / 385.3 | 0 / 0 |
| EN-F02 | 8 | 45.0 / 2,904.3 / 3,875.9 | 279.3 / 745.5 / 923.7 | 2 / 1 |
| EN-F03 | 5 | 165.1 / 1,297.2 / 1,468.0 | 295.1 / 1,073.8 / 1,078.9 | 2 / 2 |

These errors are conditional on support filtering and compare supplied line annotations. The [numerical record](alignment-data/v13/evaluation.json) contains complete counts, flags, and distributions.

## Performance and Verification

Separation took 109.4, 169.5, and 193.3 seconds of CPU time per recording; complete preparation took 161.8, 290.6, and 317.7 seconds. EN-F02 and EN-F03 ran concurrently with background-model fitting, so their timings are upper bounds rather than controlled measurements. Parent peak RSS was 2.30–2.48 GB, and the maximum Whisper child peak remained 0.67 GB; these are separate high-water marks.

All 194 Python tests passed in the working tree and in a fresh public checkout without models, private media, or network access. In that checkout, requesting separation without dependencies returned exit status 3. The comprehensive allocated inventory after the runs was 17,122,041,856 bytes, below the 18,000,000,000-byte ceiling. The [verification record](alignment-data/v13/verification.json) lists sanitized measurements.

## Decision and Next Gate

**M1 no-go. Further development of the Whisper `small` anchor architecture is not justified.** Neither timestamp representation nor accompaniment removal moved lexical recognition coverage materially, and the anchor path retains far fewer final estimates than complete-sequence CTC.

The release decisions named a bounded singing-specific aligner comparison as the step after a failed separation gate. The present evidence supports one cheaper experiment first. Complete-sequence CTC alignment does not depend on audio-only recognition coverage and previously produced the most supported estimates; its documented failures include accompaniment, drift, and endpoint absorption. **The next single step is complete-sequence and bounded CTC alignment on the separated vocals,** using the already provisioned models and no new downloads, evaluated under unchanged M1 criteria with EN-F01 development and frozen EN-F02/03 comparison. If it does not satisfy M1, the singing-specific aligner comparison follows.

Neither automatic synchronization, release readiness, nor native iOS 27 Music fidelity is established.
