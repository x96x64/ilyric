# iLyric veracity Evaluation Procedure

## Status and Preconditions

This is an implementation-ready **conditional procedure**, not an executed evaluation or a new public command contract. Its [readiness report](veracity-evaluation-readiness.md) and [versioned record](alignment-data/v5/readiness.json) identify unresolved prerequisites. No adapter or VAD evaluation harness currently exists. Do not execute inference until checkpoint scope, material permissions, independent labels, frozen partitions, preprocessing parity, and explicit provisioning approval are recorded.

Keep all audio, annotations, checkpoints, environment overlays, features, scores, logs, and diagnostic plots under ignored `artifacts/` or `reference-private/`. Retain originals read-only. Public records may contain aggregate counts, hashes and neutral source IDs; never publish lyric text, audio, private paths, or weights. Network access belongs only to explicitly approved preparation. Evaluation and rendering then remain offline and separate.

## Phase One: Resolve Permissions and Freeze Inputs

1. Obtain authorized clarification using the unsent inquiry. Record the authority, date, exact checkpoint, license scope, conditions, and measurement-publication permission. Do not send the inquiry without user authorization. Commercial use and redistribution remain separate questions.
2. Verify each original audio hash, recording license and version, permissible local processing/annotation, language, singer identity, source group, mixture/isolated status, and relation to checkpoint training. Unresolved training overlap excludes an item from an assertion of independent test generalization. Retain the eighteen historical model assets, nine original recordings, archived outputs, and comparator settings unchanged.
3. Reserve distinct recording/singer groups: existing EN01 development, EN02 validation, EN03 held-out, and an additional lawfully supplied Japanese accompanied singer held-out. Artist names do not prove distinct vocal performers. Related excerpts, alternate masters, and duplicate audio must share one group. Keep PJS as a separate auxiliary isolated-Japanese stratum. If singer independence fails, leave the partition unfilled instead of relabeling a related excerpt.
4. Select at least two passages per group, each 20–60 seconds, by listening without candidate or aligner output. Held-out material must include four accompanied passages, at least two distinct singers, twenty clear onset/offset pairs, and ten nonvocal gaps. Include sustained vowels, short phrases, pauses, reverberation and prominent instruments. Repeated correctly sung phrases and backing voices require separate tags. These are minimum experiment counts, not certification.
5. Complete independent annotation and review below. Freeze concrete full-audio and excerpt hashes, exact source-sample clip bounds, annotation hashes, permission record references, performer groups, roles, acoustic strata, and the protocol hash. Missing identities are blockers; source-role reservations are not a frozen manifest. Keep a signed/date-stamped private freeze record before any candidate inference. Development and validation cannot include held-out singers.

## Independent Annotation Format and Review

Use a research-only JSON record, not a project-schema extension. The [original synthetic example](alignment-data/v5/annotation-example.json) illustrates the representation; its null audio identity explicitly prevents treating it as measured evidence.

Each private record requires format version, source ID, complete audio SHA-256, sample rate, source-sample excerpt bounds, exact duration, annotator and reviewer identifiers, review status, interval list, and a permission/provenance reference. Preserve whole-recording coordinates alongside excerpt-relative coordinates. Use integer source samples or integer microseconds with stated annotation resolution; conversion must retain that effective precision. Intervals are half-open. Require monotone in-bounds intervals, valid uncertainty bands, no unsupported positive/negative overlap, and explicit unknown support wherever labels are absent. Do not fill unannotated regions as silence.

Annotate the earliest/latest plausible onset and earliest/latest plausible offset for every vocal interval. An onset includes audible sung consonants, not only vowel energy. An offset includes the final audible sung consonant or sustained vowel; it excludes a clearly separable room tail. Long sustained vowels remain vocal without creating extra intervals for vibrato. Record clipped edge intervals as censored and omit their artificial edge from boundary-error scoring.

| Label | Principal Interpretation |
| --- | --- |
| Lead singing | Positive sung production; tag sustained vowel and short phrase separately |
| Backing singing, overlapping singers | Positive with distinct role tags; not proof that lead lyric text is missing |
| Humming, sung ad-libs | Positive vocal production, separately stratified; no inferred words |
| Instrumental passage | Negative only after listening confirms no sung production, including prominent sustained instruments |
| Silence | Negative, separately stratified from instruments |
| Breath, spoken interjection | Unknown for principal singing scoring; report duration and labels separately |
| Ambiguous reverberation or disputed acoustic support | Unknown; preserve the entire unresolved time range |

The first annotator listens to the audio without transcripts, model predictions, TIFA/CTC intervals, scores, or candidate masks. Waveform and spectrogram are listening aids, not automatic truth. A second annotator first makes an independent pass and then reviews every held-out boundary, gap, and class label. Retain both annotations and the review record. Resolve only disagreements supported by listening; otherwise retain their union as uncertainty/unknown. Do not average disagreeing endpoints into false precision.

For each agreed interval, the certain vocal core is `[latest onset, earliest offset)` and permissive support is `[earliest onset, latest offset)`. Boundary bands and unresolved regions are unknown for principal scoring. Report unknown duration and the strict/permissive scoring sensitivity, including how uncertain reference intervals affect IoU. A region too ambiguous to provide a certain core does not count toward the twenty clear pairs. Do not use aligner word or phone unions to satisfy the count.

## Phase Two: Approve and Provision the Minimal Environment

The proposed transfer cap is 12 decimal MB and incremental peak-storage cap 320 MiB, within continuing 2 decimal GB/6 decimal GB ceilings. These caps require explicit approval after the preceding blockers resolve. Reinventory all retained evaluation assets and checkouts; acknowledge that historical download totals are approximate. Do not delete historical or unrelated files. Stop before an unplanned package, archive, or storage expansion.

Pin CPJKU revision `0983900f136173015f3c5d0b116be014edd33905` and checkpoint `dataset/jamendo/models/model_log_0mean/model.pt`, Git blob `6d8a4434482615b142e45b8220ff5a0462a9fee6`. After approval, acquire only this checkpoint, required source/configuration, and the exact torchaudio 2.8.0 arm64 CPython 3.12 wheel recorded in readiness evidence. Verify wheel SHA-256 and checkpoint size/Git blob against the pinned tree, then record checkpoint SHA-256. Do not clone the entire repository with ancillary weights or download Jamendo-VAD.

Keep the existing isolated Python 3.12.14/PyTorch 2.8.0 environment read-only. Install the verified wheel into a new ignored package overlay with dependency resolution disabled; explicitly control that subprocess's import path and package versions. This is a proposed isolated installation, not an executed command. If the plan requires a replacement runtime, source compilation, a new global package, or extra dependencies, stop and revise permission and resource estimates. Record installed license files and actual allocation.

Only in the subsequent implementation gate, add a minimal inference-only worker with synthetic tests. Avoid importing training, explanation, or separation workflows. Use CPU, four threads, fixed seed, evaluation mode, strict restricted state-dictionary loading and no network access. Do not enable an unsafe checkpoint loader if restricted loading fails. Verify imports and configuration before using any private audio.

Test synthetic impulse, tone, silence and fixed-noise inputs against documented preprocessing: mono float32, explicit `kaiser_best` resampling to 22,050 Hz, magnitude STFT (`power=1`), 1,024-sample window, 315-sample hop, centered Hann/reflection padding, custom `mel_orig` and log treatment, 115-frame context and documented edge padding. Pin all decoder/resampler/library versions. Inspect filter coefficients and numerical differences; stop on an unexplained drift. No claim of equivalence with the historical stack is presently established. Source-compatible execution may still need explicit, documented adaptation.

## Phase Three: Run Frozen Comparisons

First run the documented checkpoint recipe, including threshold 0.51 and 56-frame median filtering. Preserve raw native-grid scores as uncalibrated diagnostic values. Store the exact grid as `315/22050` seconds; do not repeatedly add a rounded microsecond step or round to 60-fps video frames. Record padding, timestamps, smoothing edge behavior and effective temporal support. A nominal 70-Hz grid is not a claim of 14-ms boundary accuracy.

A maximum bounded calibration grid remains thresholds 0.41/0.51/0.61 and smoothing 0/28/56 frames on development/validation only. No minimum-duration rule, recording-specific gain, phase registration or endpoint adjustment is permitted. Freeze the chosen recipe before held-out inference and report default and calibrated outputs separately. Fixed +/-6-dB, resampler and one AAC encode/decode sensitivity comparisons occur after primary scoring and cannot select held-out winners.

Rerun the frozen spectral/CTC feature extractor on the identical new excerpts using its existing model/configuration, without refitting. Compare all three to the same independently verified annotations. Historical English proxy results (spectral gap activation 100%, CTC vocal-duration recall approximately 13–20%) are motivation, not independent ground truth or a new detector result.

The following **existing command template has not been executed in this gate** and reproduces the separate archived lexical/mismatch comparator, not a new VAD evaluator:

```sh
python3 scripts/evaluate_acoustic_coverage.py score \
  artifacts/acoustic-coverage/manifest.json \
  --frozen artifacts/acoustic-coverage/frozen.json \
  --output artifacts/veracity-evaluation/lexical-reproduction.json
```

Create a new ignored output directory and never overwrite archived records. Future worker/VAD scoring invocations must be documented when implemented; the upstream dataset-specific prediction command is not yet a validated arbitrary-recording interface. Do not describe a planned command as a successful run.

## Metrics and Prospective Decision Rules

Preserve [the frozen prospective protocol](alignment-data/v4/protocol.json). On a common 10-ms center grid, compare exact timestamps to native predictions and exclude unknown reference centers. TP/FP/TN/FN refer only to singing/nonvocal classification. Precision is TP/(TP+FP), recall TP/(TP+FN), F1 2TP/(2TP+FP+FN), FPR FP/(FP+TN), and FNR FN/(FN+TP). Undefined denominators remain unavailable.

Report exact vocal-duration coverage separately from frame counts, per-gap active-duration fraction, and the number of gaps containing at least 100 ms activation. Separate silence, pauses and instrumental strata. Pair intervals one-to-one by maximum total overlap at IoU >=0.5, with chronological tie resolution; report unmatched references/predictions. A single merged interval cannot match several phrases. Boundary errors are distances outside annotated uncertainty bands, without phase fitting. Report onset and offset median absolute error, linearly interpolated p95, maximum and count above 500 ms for matched uncensored boundaries, alongside unmatched counts.

Unchanged prospective targets: precision, recall, F1, interval recall and vocal-duration coverage >=0.90; nonvocal FPR and instrumental-gap activation <=0.10; boundary median <=100 ms, p95 <=250 ms, at most 5% above 500 ms; warm runtime less than ten times audio duration; peak RSS below 4 GiB. Report failures by language, singer, accompaniment, sustained vocal/short phrase/pause and instrument-heavy condition. No aggregate may conceal a failed gap or new-singer stratum. Recording-cluster uncertainty estimates require enough independent recordings; correlated frames do not constitute independent trials.

Only after standalone scoring, compare detected vocal support with original alignment coverage and the frozen lexical decisions. Record incremental flags and false flags independently. Omitted lead lyrics, legitimate backing voices, humming and ad-libs may all cause unexplained activity; different words or repeated occurrences may have identical support. No lexical correctness conclusion follows from VAD alone. Keep automatic acceptance, rejection, repair and timestamp changes disabled regardless of aggregate performance in this small study.

## Records, Costs, and Exit Decision

Preserve input/configuration/checkpoint/dependency hashes, all annotation versions, freeze records, permission references, exact raw scores, intervals, metrics, localization, uncertainty masks, baseline comparisons, and output provenance. Estimated/supplied/corrected/unresolved timing remains unchanged. Repeated inference must produce equivalent semantic records; initialization, preprocessing, inference, postprocessing, total time, and peak RSS are separate operational measurements excluded from byte equality. Measure cold and repeated warm runs on the same workload, with explicit thread count and machine/runtime context. Reinventory peak temporary storage and cumulative transfers. Do not infer accuracy from video encoding.

Missing permission, input, annotation, dependency, or resource headroom must yield explicit blocked/unavailable status. A future approved implementation must have model-free public tests for exact grids, intervals, unknown support, pairing, missing dependencies and nonmutation. Do not add speculative production interfaces during this readiness task.

A favorable bounded result may justify only optional review-required acoustic flags and consideration of a later full-song experiment. A failed target retains the existing reviewed workflow. Full-song work would still require >1-minute recordings, new singers, repeated choruses and instrumental sections without reference-derived clip boundaries, plus lexical-correspondence safeguards. It is not authorized or complete here.
