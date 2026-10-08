# iLyric Independent Acoustic Coverage Validation

## Decision and Scope

**No-go for automatic full-song segmentation or unattended synchronization.** Independent acoustic evidence provides limited incremental information, but none of the tested diagnostics reliably verifies lyric correspondence. English audio-only lexical disagreement detects two newly reserved mismatches missed by TIFA's prior gate. It still misses eight of ten reserved English mismatches by itself and all three previously missed English controls. A spectral proxy confuses accompaniment with vocal coverage; CTC nonblank activity omits most annotated singing duration. No automatic acceptance, rejection, endpoint correction, or operational preparation gate is enabled.

The new Python commands are explicit research diagnostics. They read local audio/features and alignment artifacts, preserve estimates and corrections, and emit separate records. Swift rendering, pronunciation overrides, failed endpoint-repair policy, TTML preparation, project schemas, typography, appearance, focus motion, and export remain unchanged. All inference precedes rendering. The mandatory automatic-synchronization requirement remains incomplete; deferred visual and product work remains deferred. The interface reference remains iPhone 16, reported iOS 27.0.1, build **Unknown**. This experiment makes no native-fidelity claim.

## Baseline and Integrity

The repository began clean on `main` at `63c71b6`, equal to fetched `origin/main`. The requirements, alignment reports and commands, implementation, correction path, model sources, numerical evidence, tests, and relevant history were inspected. All fields in the archived 40-control evaluation reproduced exactly, including thresholds and confusion counts. Fresh inference also reproduced all units, line estimates, and agreement scores for the four TIFA misses and matched EN02. Eighteen pinned model assets, nine original recordings, and all 40 archived audio/text input pairs passed hash verification. Historical outputs and annotations were not overwritten. The [baseline record](alignment-data/v3/baseline.json) separates recomputed decisions from fresh inference.

The prior held-out TIFA gate detected 8/12 mismatches, leaving four unflagged: EN02 middle omission, incorrect repetition, early transcript termination, and JA03 middle omission. CTC detected 1/8. Neither flagged its small matched control set (three TIFA, two CTC). A “miss” means an experimental diagnostic did not flag a constructed mismatch; mandatory review still prevented unreviewed export.

Models and licenses remain pinned to the [original asset manifest](alignment-data/v1/model-assets.json): TIFA source `614a277d2580efe5e4b84faf4c34753dbc5a062c`, 1.0 ST weights; and `facebook/wav2vec2-base-960h` revision `22aad52d435eb6dbaf354bdad9b0da84ce7d6156`. TIFA has MIT source and CC BY-NC-SA 4.0 weights; commercial integration remains unresolved. The English speech checkpoint declares Apache-2.0. Corpus, lyric, model, and implementation permissions remain separate. No new downloads or environment installations occurred.

## Failure Classes and Reserved Controls

The [prospective protocol](alignment-data/v3/protocol.json) was fixed before acoustic extraction and threshold selection. These failure classes remain distinct:

| Class | Ground-Truth Basis and Diagnostic Limit |
| --- | --- |
| Omitted sung material | Remove supplied middle or final material while retaining the original audio; activity alone cannot identify the missing words |
| Extra supplied text | Insert a duplicate or substitute an original absent phrase; all returned intervals can still appear plausible |
| Repeated or misordered phrases | Duplicate or exchange supplied phrases; vocal presence cannot identify the correct occurrence |
| Unsupported extension | Compare independent annotated offsets with estimated or deliberately extended endpoints; absence of a reliable vocal boundary prevents automatic repair |
| Ordinary gaps | External word/non-pause-phone intervals identify reference gaps; those gaps are not necessarily acoustically silent |

Development uses EN01 and JA01, including matched and mismatched controls. Previously tested EN02, EN03, and JA03 are diagnostic reuse only. Four passages were reserved before selecting thresholds: EN04 and EN05 use annotated lines 4–6 of the retained EN02 and EN03 songs; JA04 and JA05 use the previously retained complete utterances. English crop margins use annotation midpoints to adjacent lines and a two-second maximum, not alignment predictions. The resulting 36 reserved model/input combinations contain matched, middle-omission, duplicate, absent-text, early-end, and misordered variants. Each English variant runs both aligners; Japanese variants run TIFA.

No new recording or singer was obtained. New passages and mutations are held out from feature/threshold development, but their source singers are already represented in the historical corpus. Pretraining independence remains unknown. Multiple mutations of one recording are correlated observations. The source references remain the externally human-annotated PJS/JamendoLyrics material documented in [automatic alignment](automatic-alignment.md); no new listening annotation or inter-annotator study is claimed.

English mutations follow the annotated lines. Japanese mutations follow the previously documented code-point-third construction, not asserted linguistic phrases. They establish omitted or extra source content but do not establish exact phoneme-to-character localization. Matched controls include repeated English lines, accompanied English singing, and sustained Japanese phone intervals. Overlapping singers and long instrumental passages remain unqualified. All mismatch controls are constructed; natural English timing errors are examined separately from text-mismatch classification.

## Independent Candidate Signals

Only two extraction mechanisms were used, with three diagnostic scores. The same audio feature record is reused unchanged across every supplied-text variant. No supplied text, forced path, annotation, or pronunciation override enters extraction.

1. **Spectral activity proxy:** 40-ms Hann windows at 10-ms steps on a separate 16-kHz analysis copy. Frames require spectral flatness below 0.3 and RMS above the clip's 90th percentile minus 30 dB, with an absolute floor. This fixed hypothesis identifies sufficiently strong, nonflat mixture sound, including instruments. It is not a singing detector.
2. **Audio-only CTC activity:** the pinned English speech model's unconstrained argmax frames, excluding special tokens and word separators, at its 20-ms grid. No forced transcript path is used. Blank frames can occur within sustained vowels; nonblank frames are not continuous vocal activity. Japanese application is an explicitly unqualified activity-transfer diagnostic, with no Japanese lexical claim.
3. **English lexical disagreement:** greedy decoding from those same audio-only logits, compared with the supplied text after existing punctuation/case filtering. Levenshtein distance is divided by the longer retained spelling length. Original display text is never replaced. This is auxiliary acoustic evidence, not a transcription product or a prerequisite that the user obtain a transcript.

For each activity proxy, the score is the larger of (a) the fraction of activity outside the union of estimated line intervals and (b) the fraction of estimated duration lacking proxy activity. Empty support produces unavailable evidence, not success. Principal comparison uses original estimates. An explicit diagnostic option can inspect corrected intervals without rerunning inference; corrections remain separate.

CTC evidence is independent of the selected text path but shares the checkpoint with the CTC baseline, so statistical independence is not claimed. It uses a different checkpoint from TIFA. Inspection of pinned TIFA `modules/forced_alignment.py` and `modules/backbones/jebf.py` shows joint token/audio processing; its existing frame/token scores are not a substitute for an independent audio-only detector. No unsupported empty-token inference was introduced.

Each score's threshold is fitted only on development controls: above the highest matched score, halfway to the lowest higher mismatch when one exists. Inseparable mismatches remain missed. Spectral thresholds are 0.186882/0.178067 for CTC/TIFA estimates; activity thresholds are 0.910020/0.916402. The English lexical threshold is 0.688581 for both. The frozen development record is identified by a digest and must match when scored. No threshold, feature, smoothing rule, or normalization was changed after reserved scoring. Combinations use a simple logical OR with the unchanged prior score/structural gate; unavailable evidence cannot override an existing review flag.

## Held-Out Detection

Tables use **TP** for a flagged mismatch, **FP** for a flagged matched-text control, **TN** for an unflagged matched control, and **FN** for an unflagged mismatch. These are correspondence labels; a matched transcript does not imply that every estimated timestamp is accurate. Flags do not authorize automatic rejection. Counts unavailable to a candidate are listed separately.

| Reserved Scope and Candidate | TP | FP | TN | FN | Unavailable |
| --- | ---: | ---: | ---: | ---: | ---: |
| TIFA, all four passages: prior gate | 15 | 0 | 4 | 5 | 0 |
| TIFA: spectral proxy alone | 1 | 0 | 4 | 12 | 7 |
| TIFA: CTC activity alone | 0 | 0 | 4 | 13 | 7 |
| TIFA: spectral OR prior gate | 16 | 0 | 4 | 4 | 0 |
| TIFA: activity OR prior gate | 15 | 0 | 4 | 5 | 0 |
| CTC, two English passages: prior gate | 3 | 0 | 2 | 7 | 0 |
| CTC: spectral proxy alone | 6 | 2 | 0 | 4 | 0 |
| CTC: CTC activity alone | 0 | 0 | 2 | 10 | 0 |

Seven TIFA negative outputs have no usable estimated-line union, so standalone activity comparison is unavailable; the structural gate still requires review. The spectral proxy adds one TIFA early-end detection, but on previously tested material it flags both matched English controls. It cannot be promoted based only on favorable new TIFA false-rejection counts. For CTC estimates it flags both reserved matched English controls, demonstrating substantial dependence on estimated interval coverage rather than stable vocal discrimination.

| Reserved English-Only Candidate | TP | FP | TN | FN |
| --- | ---: | ---: | ---: | ---: |
| Independent lexical evidence, either engine | 2 | 0 | 2 | 8 |
| TIFA prior gate | 5 | 0 | 2 | 5 |
| TIFA prior gate OR lexical evidence | 7 | 0 | 2 | 3 |
| CTC prior gate | 3 | 0 | 2 | 7 |
| CTC prior gate OR lexical evidence | 4 | 0 | 2 | 6 |

Lexical evidence identifies EN04's middle omission and misordering. Both are additional TIFA detections; one is additional for CTC. It detects neither reserved absent-text example, neither incorrect duplication, nor either early-end example. Both EN05 omission and misordering remain unflagged. Japanese lexical evidence is unavailable, not passed. Combining lexical evidence and the prior gate improves measured English TIFA recall from 50% to 70%, but three of ten mismatches remain missed.

The lexical-only recall is 20% (2/10), with a descriptive Wilson 95% interval of approximately 5.7%–51.0%. Zero false flags among two matched examples has an upper Wilson bound of approximately 65.8%. These intervals do not account for clustering by recording and must not be interpreted as population performance. Full per-class matrices, unavailable counts, scores, thresholds, and input identities appear in the [detection record](alignment-data/v3/detection.json).

For the four original TIFA misses, spectral evidence flags two EN02 cases, but also flags matched English material. CTC activity and English lexical evidence add no detections; JA03 lexical evaluation is unsupported. Matched English greedy spelling disagreement already ranges from 0.342 to 0.686. The resulting high development threshold leaves many realistically altered transcripts indistinguishable from speech-model errors on singing. Successful greedy output is not correct lyric recognition.

## Localization, Gaps, and Endpoints

Activity intervals were compared in unshifted audio coordinates with the union of independent English word intervals or Japanese non-pause phone intervals. This is a localization diagnostic, not newly annotated vocal-activity truth: word intervals include consonants and pauses, reverb may exceed phonetic offsets, and background singers are not separately labeled. No nearest-boundary registration hides discrepancies.

On reserved English passages, spectral activity has duration precision **0.756–0.865** and recall **0.994–1.000**, but marks **100%** of annotated gap duration active. On reserved Japanese utterances, precision is **0.876–0.898**, recall **0.981–0.984**, and gap activity **27.4%–53.1%**. The stronger gap contamination in mixed English audio supports the inference that mixture sound is insufficient evidence of omitted singing; it does not isolate a particular instrument or mixing cause.

Audio-only CTC activity has high reserved duration precision (**0.926–1.000**) but recall only **0.126–0.196**. Sparse token emissions miss most sustained/reference vocal support. Treating blanks as silence would therefore create unsupported endpoint and interval judgments. No missing lyric words or phonetic boundaries are inferred from these masks. The [localization record](alignment-data/v3/localization.json) records false-active and missed-reference microseconds, precision, recall, and gap contamination for every passage.

A separate post-scoring stress diagnostic extends independently annotated final endpoints by 250 ms where recording context permits (JA01, JA03, JA05). CTC marks the entire extension unsupported but also marks roughly 84%–86% of the correct line unsupported. Spectral absence covers only 20%–68% of those extensions. These constructed endpoint hypotheses neither modify artifacts nor train a new classifier. The natural English timing errors from the previous gate remain unchanged; clip-level spectral flags cannot identify their correct offsets. No endpoint repair or calibrated boundary-localization accuracy is established.

## Implementation and Reproduction

[Diagnostic commands](acoustic-coverage-commands.md) document optional local feature extraction, nonmutating comparison, and two-stage threshold evaluation. Source/audio identity, original estimates, corrections, history, unresolved regions, and Japanese overrides remain intact. Scores are diagnostic values, never correctness probabilities. A flagged region is a hypothesis for inspection; an unflagged result does not remove mandatory review.

The public code adds bounded integer interval operations, audio-only extraction using existing dependencies, strict input identity checks, development-only fitting, descriptive uncertainty intervals, and synthetic tests. Feature records contain acoustic-derived text and must remain private/ignored. Public evidence contains only neutral identifiers, hashes, scores, intervals/counts, and aggregate measurements. No provider client, model adapter framework, production CLI change, or acquisition path is introduced.

## Performance and Verification

Measurements used Apple M4, 16 GiB, macOS 27.0.1, isolated Python 3.12, PyTorch 2.8.0, Transformers 4.57.1, and four CPU threads. The [performance record](alignment-data/v3/performance.json) preserves exact dependencies and model provenance. Separate diagnostic processes took **2.749–3.321 seconds**, including imports, asset checks, decoding, and model loading. Measured CTC forward inference took **0.173–0.415 seconds**, model/processor initialization **0.026–0.054 seconds**, audio preprocessing **0.048–0.074 seconds**, and spectral extraction **3.2–9.2 ms**. Peak process RSS was **1,025–1,407 MiB**, including CTC; this is not standalone spectral memory. These are additional diagnostic costs, not alignment speed improvements. Audio features are extracted once and reused across text variants.

Repeated feature extraction produced identical semantic records after excluding measured runtime/memory fields. Repeated and randomly ordered diagnostic evaluation preserves identical records and original artifact contents. The [verification record](alignment-data/v3/validation.json) reports complete public suites, release and deterministic checks, TTML/preparation regression, fresh-checkout verification, resource inventory, and privacy audit. Public tests require no inference environment, model, singing corpus, network, or subscription. Missing optional inputs return explicit unavailable status.

All **61 Swift and 112 Python tests** passed, including 13 new coverage tests. Release builds, eight random-order reference-probe evaluations, repeated renderer determinism, and existing TTML enabled/disabled/direct-export checks passed, including 36 refusal checks. A fresh public-only checkout repeated both suites and the release build, with explicit unavailable results for private references and models. Its unchanged synthetic preparation path exported **601 frames at 1080×1920 and 60 fps**, H.264 limited-range Rec.709 and supplied mono 48-kHz AAC. All presentation timestamps and six audiovisual markers passed; audio correlation was approximately 0.999921 with zero measured lag. This validates software/media compatibility, not acoustic alignment. Continuing alignment assets, outputs, and three public checkout artifacts occupied approximately **4,270 MiB**, below the 6-GB ceiling; prior downloads remain approximately 1,065 MiB plus small metadata, with zero added downloads.

No correction-effort or user-review-time reduction was measured. Better detection of two controls cannot establish reduced manual burden. No new estimates were accepted or exported as accurate because of this diagnostic. Historical acoustic errors, pronunciation uncertainty, and review requirements remain in force.

## Next Mandatory Gate

**Do not proceed to automatic full-song segmentation.** The independent lexical signal contributes information beyond the prior forced-path scores, but not reliable coverage verification. Activity detection and verification of the correct words remain separate unsolved requirements. The research commands may assist inspection; none qualifies for automatic rejection or acceptance in preparation.

The smallest next experiment is one independently trained singing-aware vocal-activity candidate against these frozen mixture/CTC baselines, using newly reserved accompanied passages and manually verified vocal/nonvocal boundaries, including at least one additional singer. First verify a specific candidate's license, size, local inference compatibility, and cumulative resource budget; obtain approval before substantial downloads. Do not add a separator or another aligner by default. The current all-gap spectral activity and sparse CTC support justify testing a dedicated signal, but a positive activity result must not be presented as lexical correspondence. Retain the fixed English lexical diagnostic as a separate, qualified comparator for omitted/reordered content, and include new repeated/extra-text controls before any operational threshold.

Japanese ambiguous readings still require independent linguistic verification; selecting a reading by timestamp error is insufficient. English endpoint refinement remains disabled. A later full-song gate must use recordings longer than one minute, additional singers, repeated choruses, instrumental sections, and segmentation without reference-derived clip boundaries. A review-first full-song experiment is only justified after its residual correspondence risk and correction burden are explicitly bounded. Mandatory automatic synchronization remains incomplete.
