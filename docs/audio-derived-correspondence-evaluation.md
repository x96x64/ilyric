# Audio-Derived Correspondence Evaluation

## Outcome and Scope

October 9, 2026. **M1 does not pass.** The approved multilingual Whisper small experiment generated useful coarse passage evidence, but failed the prospective 90% correct-region candidate-availability requirement on every recording. Bounded English CTC refinement retained only nineteen of 140 line estimates, compared with 53 in the frozen complete-sequence CTC baseline. Reliable automatic synchronization remains incomplete; advancement to M2 is not justified.

Implementation commit `fa354bc` contains the acoustic adapter and public tests. This report continues the [model-free preparation](audio-derived-correspondence-preparation.md) and preserves the seven milestones in the [release plan](implementation-release-readiness.md). The production CLI, Swift renderer, project schemas, LRC/TTML importers, audiovisual exporter, TIFA/veracity experiments, pronunciation overrides, and correction format are unchanged. No automatic acceptance, timestamp repair, source-text replacement, software-license selection, release, or model redistribution occurred.

## Approved Provisioning and Identity

The maintainer authorized only the previously pinned multilingual checkpoint, CPU source subset, and isolated CMake wheel, with 560,000,000 additional transfer bytes and 2,000,000,000 additional peak allocated bytes. Cumulative ceilings are now 2,100,000,000 download bytes and 17,000,000,000 allocated bytes. The [current resource policy](evaluation-resource-policy.md) records this authorization; the older proposal remains historical evidence.

All 202 source files passed their Git-blob identities, and the wheel/checkpoint passed their exact sizes and SHA-256 hashes. Payload transfer totaled **547,272,273 bytes**. The [provisioning record](alignment-data/v11/provisioning.json) includes the resulting executable hash. Identities remain:

- `whisper.cpp`: `d1be6fde11ac6e0407606b4e42fe72d34add8037`.
- Multilingual `ggml-small.bin`: distribution revision `5359861c739e955e79d9a303bcbc70fb988958b1`, SHA-256 `1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b`.
- CMake 3.31.6 universal2 wheel: SHA-256 `da9d4fd9abd571fd016ddb27da0428b10277010b23bb21e3678f8b9e96e1686e`.

The isolated Release build used Apple Clang, Make, two jobs, static libraries, CPU Accelerate, and no Metal, Core ML, CUDA, OpenMP, curl, server, or optional downloaded backend. Initial configuration exposed an unprovisioned optional BLAS backend; disabling that backend completed the approved CPU build without acquiring another source file. CPU Accelerate remains enabled. Configuration/build and Whisper subprocesses denied network access. A duplicated host prefix in the local provisioning script caused two HTTP 404 responses before correction; checkpoint selection did not change. The build's incidental Git version string identifies the containing checkout, so source-blob identities and the explicit upstream revision, rather than that string, establish provenance.

The previously inspected MIT declarations for Whisper code/weights and whisper.cpp, Apache-2.0 CMake packaging, and BSD-3-Clause CMake implementation remain the applicable documented software evidence. Preserve their component notices before any distribution. These declarations do not authorize evaluation-recording, lyric, training-data, or generated-video redistribution. TIFA's restricted weights and checkpoint-uncertain veracity remain optional research assets. Apache-2.0 is still only a candidate for iLyric's unselected software license.

## Implemented Acoustic Stage

`prepare_audio_correspondence.py` is an isolated experimental preparation command. It hashes the original audio and authoritative text before processing and verifies them afterward. It verifies the pinned checkpoint and existing CTC assets, refuses existing output directories, retains raw outputs privately, and never downloads dependencies. Missing dependencies return exit 3; invalid input or inference failure returns exit 2; completed review-required preparation returns exit 0. Public tests require no models.

Audio decoding reuses the established mono 48-kHz PCM16 path and SciPy polyphase conversion to 16 kHz. Source duration derives from decoded samples; over-ten-minute input fails rather than being silently truncated. Whisper receives automatically generated 30-second windows at 26-second strides. Every request resets context, uses explicit English, four CPU threads, greedy single-candidate decoding, zero temperature with fallback disabled, no translation, no lyric prompt, and no prior-text context. Full JSON retains token scores, recognized text, and raw boundaries. Word-split output uses upstream `max_len=1` and `split_on_word`; these heuristic timestamps are not independently established word onsets.

The adapter converts valid source-relative boundaries exactly to the existing 100-Hz anchor grid. This is timestamp representation, not a claim of ten-millisecond acoustic accuracy. Empty text, zero/reversed/out-of-window intervals, malformed fields, and unsupported controls remain indexed rejection evidence linked to saved raw JSON. They are not clamped, interpolated, or silently assigned times. Nonlexical annotations and nonchronological recognition receive uncertainty labels. Original lyric occurrences and display text are unchanged.

The model-free matcher, candidate thresholds, overlap ownership, chronological frontier, skip behavior, and ambiguity test are unchanged. Only provisionally supported regions receive CTC refinement. Each region is padded by one second on either side, starts on the source-relative 20-ms CTC grid, and remains within the existing 30-second limit. Local authoritative text is forced only inside that region. Existing acoustic/greedy diagnostics remain active; censored boundaries, refinement outside the anchor, and overlapping estimates remain unresolved. Rejected proposals are retained. Speech-model support and Whisper agreement are not calibrated correctness probabilities.

The existing full-song artifact preserves proposals, null unresolved estimates, correspondence decisions, model identities, and pending review. Explicit corrections preserve the original estimate and remain reusable through the existing review/TTML path without inference. No coarse anchor is exported as a final timing estimate merely because matching succeeded. Automatically generated word, syllable, mora, or character synchronization is not established; Japanese automatic full-song alignment remains unevaluated.

```sh
artifacts/alignment/venv/bin/python scripts/prepare_audio_correspondence.py \
  --audio artifacts/private-song/source.wav \
  --lyrics artifacts/private-song/lyrics.txt \
  --runtime artifacts/audio-correspondence/approved/build/bin/whisper-cli \
  --model artifacts/audio-correspondence/approved/ggml-small.bin \
  --ctc artifacts/alignment/models/wav2vec2 \
  --work artifacts/private-song/audio-derived-result
```

These paths describe separately provisioned local research assets, not a public installer. The command does not access references or accept reference-derived windows.

## Frozen Comparison and Measured Results

Original audio/text identities were reverified against the three existing English complete-recording inputs. The previous preparation gate reproduced all three CTC artifacts exactly after excluding measurements: 140 proposals, 53 supported, 87 unresolved, and eleven raw reference-nonoverlap conflicts. Those artifacts and their annotations remain unchanged. EN-F01 was evaluated first. No decoding, matching, or refinement parameters were tuned after its first result. Six implementation files and all parameters were [hashed and frozen](alignment-data/v11/frozen-policy.json) before EN-F02/03. These familiar regression recordings are evaluation holdouts for this change, not new singers or population validation.

References entered scoring only. Correct-region availability below means an eligible candidate overlaps the corresponding reference interval; this necessary temporal screen does not independently verify the sung words. Wrong-chorus screening counts nonoverlapping selected regions that overlap another identically written reference occurrence. It cannot detect every linguistically wrong but temporally plausible match.

| Case | Lines | Available Correct Regions | Supported Coarse Regions | Unresolved After CTC | CTC Baseline Unresolved | Final Estimates |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| EN-F01 | 26 | 19/26 (73.1%) | 18 | 23 | 24 | 3 |
| EN-F02 | 72 | 43/72 (59.7%) | 40 | 62 | 50 | 10 |
| EN-F03 | 42 | 31/42 (73.8%) | 23 | 36 | 13 | 6 |

All 81 selected coarse regions and all 81 raw local CTC proposals overlapped their corresponding references. No additional supported temporal displacement or wrong-repeated-reference overlap was observed among the nineteen retained estimates. This does not offset missing coverage: 121/140 final occurrences remain unresolved, versus 87/140 previously. Even before refinement, EN-F03 had nineteen unresolved regions versus thirteen baseline unresolved estimates. Increased coarse coverage on two recordings is not verified timing improvement.

| Case | Retained Timing Denominator | Onset Median / p95 / Maximum (ms) | Offset Median / p95 / Maximum (ms) | Onset / Offset Errors >500 ms |
| --- | ---: | --- | --- | --- |
| EN-F01 | 3 | 27.8 / 40.5 / 41.9 | 287.7 / 393.5 / 405.3 | 0 / 0 |
| EN-F02 | 10 | 98.4 / 975.7 / 1,099.8 | 247.2 / 903.1 / 1,330.5 | 2 / 1 |
| EN-F03 | 6 | 378.5 / 1,331.5 / 1,468.0 | 242.2 / 358.4 / 363.8 | 3 / 0 |

These errors compare supplied line annotations, not independently verified vocal-activity boundaries or desired highlight endpoints. They are conditional on support filtering. Aggregate errors for all 81 raw proposals, coarse regions, counts, and performance appear in the [numerical record](alignment-data/v11/evaluation.json). No real-song manual correction or correction-effort study occurred; 121 unresolved lines do not establish a manageable user workflow.

## Failure Localization

The experiment separates four limitations:

1. **Recognition and temporal coverage:** 47 occurrences lacked eligible correct-region candidates. Of these, 46 lacked even a raw correct-region candidate before overlap deduplication. Saved recognition contained 73 nonempty zero-duration segments and eleven nonempty beyond-window segments across the three songs. Retaining raw text prevents evidence loss, but the adapter correctly refused to manufacture their timing.
2. **Window ownership:** post-selection single-window analysis, without central ownership, found correct-region candidates for two, three, and two otherwise missing occurrences. This diagnoses a bounded ownership loss; it is not a new operational policy or a tuned result.
3. **Lexical recognition:** a separate diagnostic tested saved raw recognized text inside reference-overlapping 30-second windows without using heuristic word times. Only 2/7, 14/29, and 2/11 missing occurrences met the unchanged lexical criterion there. The remaining 29 lacked that raw lexical support. These reference-selected contexts are diagnostic only and cannot be used as production anchors. Timing conversion alone therefore cannot establish 90% coverage.
4. **Boundary refinement:** weak CTC acoustic/greedy agreement, censored boundaries, and residual endpoint errors rejected most selected regions. Changing chronological ranking alone would not repair these failures. Some retained estimates still exceed one second of onset error.

No evidence justifies relaxing thresholds, forcing skipped choruses, or interpolating through omissions. Repeated EN-F01 execution produced identical anchor, correspondence, and prepared-artifact JSON after excluding runtime measurements. Deterministic failure is reproducible, not accurate by definition.

## Performance and Verification

Measurements used Apple M4, 16 GiB, macOS 27.0.1, isolated Python 3.12.14, Torch 2.8.0, Transformers 4.57.1, NumPy 2.5.3, SciPy 1.18.1, and SoundFile 0.14.0. No global package changed. Model initialization repeats in each bounded Whisper process; the public runtime record separates load, mel, encode, decode, and other upstream timers.

| Case | Complete Process (s) | Whisper Windows (s) | Matching (s) | CTC Refinement (s) | Parent / Maximum Child Peak RSS (GB) |
| --- | ---: | ---: | ---: | ---: | --- |
| EN-F01 | 34.650 | 28.125 | 0.018 | 2.645 | 1.288 / 0.671 |
| EN-F02 | 45.156 | 32.549 | 0.109 | 8.538 | 1.206 / 0.671 |
| EN-F03 | 55.242 | 46.889 | 0.092 | 3.471 | 1.407 / 0.671 |

Parent and maximum-child high-water marks are measured separately, not as a simultaneous process-tree peak. Their sum is a conservative upper bound, not a measured combined peak. Load-time totals were 0.995, 1.171, and 1.490 seconds; preprocessing took 0.760–1.114 seconds and CTC initialization 2.423–3.047 seconds. Concurrent verification may influence timings; no performance improvement or comparative speed claim is made.

All 172 Python tests passed, including nine new tests for conversion, rejection, exact grids, nonmutation, missing dependencies, bounded refinement, overlap abstention, and correction provenance. All 61 Swift tests passed on rerun and in a fresh public-source checkout. The first working-tree run recorded one existing TTML raw-raster equality failure during concurrent verification; the unchanged rerun and fresh checkout passed. Its cause is not established, and no renderer code was changed to conceal it. Optimized builds and sequential/shuffled/repeated/fresh-renderer raw BGRA checks passed in both checkouts.

The original synthetic preparation/correction/TTML/export check passed in both checkouts: 1080×1920, 60 fps, H.264/AAC, 601 frames, 10.016667 seconds, valid presentation timestamps, audio correlation 0.999919, zero measured lag, and six zero-error markers. AAC priming/padding were 2,112/416 samples. This validates software and container synchronization after explicit synthetic corrections, not real-singing accuracy. The fresh checkout contained no private recordings or model weights. Public source/dependency-unavailable tests required no network access.

## Resources, Preservation, and Next Gate

The [complete inventory](alignment-data/v11/resources.json) began at **14,619,537,408 bytes** and reached **15,921,377,280 bytes** at the recorded verification snapshot: an additional **1,301,839,872 bytes**, within the 2-GB task and 17-GB cumulative limits. This includes the complete artifacts/private-reference/main-build trees and nine retained verification checkouts; the additional fresh checkout is charged under artifacts. Intermediate configuration, build, and inference checks remained below the limits; the recorded maximum is an observed allocation, not continuous filesystem telemetry. No historical assets or checkouts were deleted or excluded.

The current transfer planning charge is 548,272,273 bytes, comprising measured payload plus a conservative 1-MB allowance for metadata/transport diagnostics. Added to the historical 1.516-GB charge, cumulative planned usage is **2,064,272,273 bytes**, below 2.1 GB. Historical traffic remains an estimate, not a reconstructed exact ledger. Private recordings, lyrics, raw recognition, checkpoint files, and generated media remain ignored. Public evidence contains only code, original synthetic tests, hashes, and sanitized aggregate measurements. The obsolete unsent permission inquiries remain unchanged.

**Next single implementation task:** conduct one bounded segment-level anchor comparison with the same pinned Whisper small checkpoint and fixed automatic windows, beginning with EN-F01's missing lexical coverage. Preserve recognized text when heuristic word timestamps are unusable, but assign only explicitly uncertain enclosing segment regions; do not invent word boundaries. Compare raw lexical availability, ownership loss, and final candidate coverage separately before considering a matcher change. Freeze that single change before EN-F02/03. The present diagnostic suggests recoverable representation loss, but also recognition omissions that such a change may not solve. If lexical coverage remains inadequate, report that result rather than repeating ranking adjustments. No additional model provisioning or broad survey is justified by this gate.

M1 remains a no-go for complete-song qualification. M2, efficient correction, canonical visual refinement, supported CLI integration, and open-source release qualification retain their existing dependencies. Neither automatic synchronization, production readiness, nor native iOS 27 Music fidelity is established.
