# Audio-Derived Correspondence Preparation

## Status and Approval Boundary

October 9, 2026. The first model-free portion of M1 in the [release plan](implementation-release-readiness.md) is implemented. It accepts saved, explicitly audio-only lexical evidence, preserves authoritative lyric occurrences, generates bounded candidates, and reconciles chronological alternatives with skips and abstention. **Whisper has not been provisioned or executed. Its correspondence accuracy and M1 acceptance remain unevaluated.** Bounded CTC refinement of selected anchors is pending the approved acoustic stage; coarse regions never become final timing estimates.

The existing production CLI, project schemas, Swift renderer, timing importers, TIFA/veracity implementations, pronunciation overrides, and review/export behavior remain unchanged. No software license is selected. Restricted research weights are not dependencies of the new model-free path.

## Implemented Evidence and Matching

`alignment/audio_anchors.py` defines strict `ilyric-audio-anchors-1` records. Required fields are `format`, `audio` (original SHA-256 and integer `duration_us`), `language`, `timebase_hz`, `resolution_ticks`, `provenance`, and `observations`. Provenance records producer/model identities, source revision, weight hash, synthetic versus audio-only origin, and explicit false declarations for lyric prompting, previous-text context, and translation. These declarations document producer behavior; they cannot independently prove how an external artifact was generated.

Each uniquely identified observation retains exact recognized text, its automatic window ID, source-relative begin/end ticks, and explicit uncertainty labels. The timebase must convert exactly to integer microseconds; timestamps are never rounded to video frames. Effective model resolution is separate from numerical representation. Overlaps remain in raw evidence. Unknown fields, invalid identities, duplicate IDs, unsupported language, unsafe text controls, out-of-window intervals, and nonintegral timing are rejected. The narrow matcher supports the existing English letters/contractions subset, not Japanese automatic alignment.

The existing 30-second/26-second-stride window plan determines central ownership by exact midpoint comparisons. Raw overlapping-window observations are preserved, but duplicate windows cannot accumulate votes. English lexical filtering preserves local UTF-16 ranges, original punctuation, and curly apostrophes in source text. Unsupported recognition spans and spans carrying uncertainty are retained with exclusion reasons; they are not silently rewritten into supported words. No new linguistic word timing is synthesized: words inside one recognized span inherit that span's coarse region, not independently estimated boundaries.

For each source line, semi-global word edit alignment permits unmatched audio prefixes/suffixes and penalizes insertions, deletions, and substitutions. Candidate eligibility requires at least two exact word matches and edit cost no greater than 30% of source word count. Single-word lines therefore remain unresolved in this initial experiment. Regions exceeding 25 seconds or containing an internal recognized-span gap over three seconds are excluded. One optimum per endpoint is retained; this is a bounded generator, not an exhaustive search. Overlapping regional alternatives remain diagnostic records but do not receive separate votes.

The unchanged chronological frontier algorithm selects a maximum-utility path with optional skips. Utility is 100 times exact matches minus 100 times edits, an engineering ranking score, not a correctness probability. Every supplied occurrence has its own ID, including identical choruses. Alternatives are recomputed while excluding the selected physical region for that occurrence; an objective margin below ten marks ambiguity. A complete forced path is not required. Supported, ambiguous, skipped, and unresolved states remain distinct. A supported state denotes provisional lexical ranking only.

Limits include 600 seconds, 64 source paragraphs, existing text/line limits, 10,000 observations/tokens, 65,536 recognized characters, 120 words per source line, twenty million edit cells, 4,000 candidates, and a conservative one-hundred-million comparison-work bound for alternative reconciliation. Limit violations fail explicitly rather than truncating candidates or returning partial success. The saved result contains raw anchors, their hash, source ranges, candidate/rejection evidence, competing paths, unassigned observations, and unassigned audio regions. Unassigned audio is not classified as silence, instruments, or missing lyrics.

Diagnostics distinguish unsupported/uncertain recognition, missing candidate coverage, chronological conflict, competing occurrence paths, and pending boundary refinement. Missing coverage alone cannot distinguish recognition error from an absent lyric passage. The separate post-selection evaluator compares candidate availability, selected reference overlap, wrong-repeat overlap, unresolved counts, and coarse-region boundary errors. Reference annotations never enter operational matching. Temporal overlap is necessary evidence, not proof that the correct words were sung.

`review_artifact` creates the existing reviewed full-song representation with all effective estimates null. It hashes the correspondence evidence and preserves source identity. Synthetic corrections demonstrate compatibility, but manual timing of every line is not the intended workflow. After approved inference, bounded English CTC refinement must supply independently diagnosed timing proposals; it must not relabel coarse anchor edges as accurate acoustic boundaries.

## Reproduced Baseline and Verification

All three complete-recording CTC runs were regenerated using the existing pinned model and original audio/text identities. Saved JSON matches the frozen passage-search baseline exactly after excluding measurements. An initial in-memory comparison differed only because JSON arrays and Python range tuples had different container types; comparison of serialized artifacts confirmed no acoustic or proposal drift. The [sanitized record](alignment-data/v10/baseline.json) contains all denominators and error summaries.

| Case | Supported / Unresolved Lines | Raw Reference-Nonoverlap Conflicts | Rerun Time (s) |
| --- | ---: | ---: | ---: |
| EN-F01 | 2 / 24 | 8 | 9.685 |
| EN-F02 | 22 / 50 | 2 | 8.961 |
| EN-F03 | 29 / 13 | 1 | 8.706 |

Totals remain 140 proposals, 53 provisionally supported, 87 unresolved, and eleven raw temporal conflicts. Three sequential inferences shared one process; cumulative peak RSS rose from 1.887 to 2.324 to 2.727 decimal GB. These are not independent per-song memory measurements. Concurrent Swift verification may affect runtime. No performance improvement or new correspondence accuracy is claimed.

The [verification record](alignment-data/v10/verification.json) records implementation `a70002b` and Unicode validation correction `6d949f2`. The working suite passed 163 Python tests, including seventeen new model-free tests, and all 61 Swift tests. Tests cover exact grids, range/source preservation, repeated occurrences, skips, extra text, gaps, local ambiguity resolved by neighboring context, unsupported recognition, schema/resource refusal, order-independent semantic matching, missing optional assets, scoring isolation, and correction reuse. The optimized build and sequential/shuffled/repeated/fresh-renderer raw BGRA determinism passed. A fresh source-only snapshot without private assets passed the Python suite; a separate fresh Swift build is deferred to the requested provisioning/storage allowance. Swift implementation and package files are unchanged.

An original synthetic preparation/correction/export check produced 601 frames at 1080×1920 and 60 fps, lasting 10.016667 seconds, through the existing H.264/AAC path. All presentation timestamps passed; audio-content correlation was 0.999919, measured lag was zero, and all six marker errors were zero. AAC priming/padding remained 2,112/416 samples. The four coarse regions required explicit synthetic corrections, including a non-frame-aligned 123-microsecond boundary. This verifies correction and container behavior, not automatic singing alignment. The initial sandboxed audio decoder failed to start; normal AVFoundation access resolved that environmental restriction without application changes.

## Experimental Commands

The original fixture in `fixtures/audio-anchors/` contains synthetic recognition, not a model prediction. Its placeholder audio hash is bound to newly generated original audio by the check:

```sh
python3 -m unittest discover -s Tests/reference_validation -q
python3 scripts/check_audio_anchors.py artifacts/original-anchor-proof
```

For an independently prepared anchor record and its exact local source recording:

```sh
python3 scripts/match_audio_anchors.py \
  --anchors artifacts/private-song/anchors.json \
  --lyrics artifacts/private-song/lyrics.txt \
  --audio artifacts/private-song/source.wav \
  --output artifacts/private-song/correspondence.json \
  --review-output artifacts/private-song/pending-review.json
```

The command validates the original audio hash, refuses existing output files, and performs no inference or network access. JSON summaries go to stdout; errors go to stderr. Exit 0 indicates structural completion with review required, 2 invalid input, and 3 unavailable input. The read-only optional-runtime preflight verifies the checkpoint identity but does not authenticate an arbitrary executable's build provenance. No inference command is implemented before provisioning approval.

## Pinned Provisioning Proposal

The [machine-readable proposal](alignment-data/v10/provisioning.json) records exact artifact identities and the 202-file source selection. Its status is **proposed, not authorized**. Public metadata was inspected on October 9, 2026; model/package payloads were not downloaded.

| Artifact | Identity | Exact Payload Bytes |
| --- | --- | ---: |
| Multilingual `ggml-small.bin` | `ggerganov/whisper.cpp`, revision `5359861c739e955e79d9a303bcbc70fb988958b1`; SHA-256 `1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b` | 487,601,967 |
| CPU build source | `ggml-org/whisper.cpp`, revision `d1be6fde11ac6e0407606b4e42fe72d34add8037`; 202 Git-blob identities listed in the proposal | 12,445,968 |
| Isolated CMake 3.31.6 universal2 wheel | SHA-256 `da9d4fd9abd571fd016ddb27da0428b10277010b23bb21e3678f8b9e96e1686e` | 47,224,338 |
| Total payload | Excludes transport metadata and retry overhead | **547,272,273** |

[The model distribution](https://huggingface.co/ggerganov/whisper.cpp/tree/5359861c739e955e79d9a303bcbc70fb988958b1) declares MIT; upstream Whisper explicitly distinguishes its MIT code and weights in the release-plan sources. [Pinned runtime source](https://github.com/ggml-org/whisper.cpp/tree/d1be6fde11ac6e0407606b4e42fe72d34add8037) is MIT with embedded dependency notices. [CMake package metadata](https://pypi.org/pypi/cmake/3.31.6/json) declares Apache-2.0 for the packaging project; [CMake itself](https://cmake.org/licensing/) is BSD-3-Clause with separately noticed bundled components. Preserve notices and verify payload hashes after approved transfer. These licenses do not license evaluation recordings, lyrics, or training-corpus redistribution. No TIFA or veracity weights enter the default proposal.

CMake is unavailable on the current command path. Version 3.31.6 accommodates the pinned source's older minimum-policy declaration without requiring a global installation. Use an isolated extraction/environment, Apple Clang and Make, a CPU-only Release build of `whisper-cli`, and at most two build jobs. Disable Metal, Core ML, CUDA, other accelerators, OpenMP, curl, SDL, server, upstream tests, and optional fetched backends; retain CPU Accelerate. The selected source excludes unneeded accelerator implementations, models, recordings, and example images. Verify that configuration performs no downloads; missing source requirements must be resolved within the approved artifact list or returned for clarification.

The current environment is macOS 27.0.1 arm64 with the previously documented Apple M4/16-GiB configuration and existing isolated Python 3.12.14/CTC dependencies. The runtime documents Apple Silicon CPU support and approximately 852 MB memory for `small`; local initialization, inference, and peak process-tree memory remain unmeasured. The public [runtime instructions](https://github.com/ggml-org/whisper.cpp/blob/d1be6fde11ac6e0407606b4e42fe72d34add8037/README.md) are compatibility evidence, not a successful local build.

The proposed additional transfer cap is **560,000,000 bytes**. Proposed additional peak allocated storage is **2,000,000,000 bytes**, including the checkpoint and retained wheel; allowances of 220 MiB for CMake extraction, 256 MiB for source/build outputs, 160 MiB for serial analysis/diagnostics, and 512 MiB for fresh public-checkout verification; and remaining margin. These are conservative allocation bounds, not measured installed sizes. Stop before exceeding either cap; do not delete historical assets. No other models, datasets, global packages, or services are included.

## Resource Accounting and Next Decision

The comprehensive starting allocation was 14,603,735,040 bytes. After baseline reruns and synthetic verification, the recorded allocation was 14,619,537,408 bytes, with approximately 39.936 decimal GB of filesystem space available. The established scope includes all artifacts, private references, the main build, and nine retained verification checkouts. The new source-only verification snapshot is included under artifacts. No historical roots or assets were removed.

The current ceilings remain 15,000,000,000 allocated bytes and 2,000,000,000 cumulative download bytes. Exact historical traffic remains unknown; retain the prior 1.514-GB conservative charge plus a 2-MB allowance for this gate's public source/metadata inspection, totaling 1.516 decimal GB before any provisioning. This is a planning charge, not an exact transfer ledger.

The concrete request is to authorize only the listed provisioning/build/evaluation scope, increase the cumulative download ceiling to **2,100,000,000 bytes**, and increase the comprehensive storage ceiling to **17,000,000,000 bytes**, while enforcing the additional caps above. Current allocation plus the additional 2-GB cap remains below 17 GB. Personal-use intent and permissive upstream licenses do not substitute for this resource approval.

**M1 decision: no-go for advancement to complete-song qualification; acoustic evidence is pending, not failed.** No Whisper candidate-availability rate, wrong-chorus count, timing accuracy, runtime, or memory result exists. After approval, verify/build the pinned assets, implement audio-only bounded inference and CTC refinement, develop only on EN-F01, and evaluate unchanged parameters on EN-F02/03. Apply the frozen targets: at least 90% correct-region candidate availability per song, fewer unresolved occurrences than CTC, and no additional unflagged displacement. Separate missing recognition/candidate coverage from incorrect chronological selection and boundary failure. Stop for the smallest identified correction if these targets fail; do not tune evaluation recordings or promote coarse overlap to lexical proof.
