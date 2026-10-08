# Local veracity Inference Validation

## Decision and Scope

CPJKU veracity is technically executable on the existing Apple Silicon CPU environment. The pinned checkpoint loads safely; twelve synthetic preprocessing cases pass; nine historical singing excerpts produce reproducible exploratory predictions. **Independent vocal-activity accuracy remains unavailable. Automatic acceptance, rejection, endpoint repair, and full-song segmentation remain disabled.** Automatic synchronization remains mandatory and incomplete. No rendering, project-schema, pronunciation, correction, or audio-export behavior changed.

The starting clean `main` was `00f4a8f7da2a6d7cb014e59563466e8b66d8c6e6`, equal to fetched `origin/main`. This October 8–9, 2026 gate follows the historical [readiness](veracity-evaluation-readiness.md) and [annotation preparation](checkpoint-permission-annotation-preparation.md) records. It changes the authorized experimental scope, not their historical findings: preliminary local inference may proceed without presenting missing independent annotations as validated ground truth.

## Licensing and Authorized Provisioning

Public sources were inspected on October 8–9, 2026. The inspected [repository revision](https://github.com/CPJKU/veracity/tree/0983900f136173015f3c5d0b116be014edd33905), its [MIT notice](https://github.com/CPJKU/veracity/blob/0983900f136173015f3c5d0b116be014edd33905/LICENSE), public checkpoint distribution, and reproduction instructions support a reasonable interpretation permitting personal, noncommercial local evaluation. No applicable prohibition or separate restrictive checkpoint notice was identified. **Checkpoint-specific scope is not independently confirmed.** This interpretation does not establish permission for checkpoint redistribution or commercial integration and is not legal advice. The user declined developer contact; no inquiry was sent or further inquiry prepared. The two obsolete unsent documents remain intact under the [deferred cleanup item](deferred-documentation-cleanup.md).

Explicit provisioning approval covered the 7,433,173-byte checkpoint and 1,856,736-byte torchaudio wheel. Separate approval added the 262,736-byte historical DSP coefficient file within the same ceilings: **12 decimal MB new transfers and 640 MiB incremental peak storage**, comprising 128 MiB evaluation files and 512 MiB public-checkout verification. Continuing cumulative limits remain 2 decimal GB downloads and 6 decimal GB evaluation storage. Historical transfers remain approximate; the approved conservative planning charge is 1.50 GB, not a reconstructed exact ledger.

[Provisioning evidence](alignment-data/v6/provisioning.json) records verified byte counts and hashes. Known new response bodies total 9,582,382 bytes, including source and metadata; protocol overhead and earlier historical traffic are not an exact transfer ledger. No additional dataset, global package, developer contact, or model candidate was introduced. The wheel was installed without dependency resolution or cache into an ignored overlay. Its installed license is BSD-2-Clause. The copied veracity source retains MIT attribution; the historical resampy kernel retains ISC attribution. These notices do not select a project-wide iLyric license. TIFA code remains MIT and its existing weights remain CC BY-NC-SA 4.0; commercial suitability is unresolved.

## Checkpoint and Preprocessing Compatibility

The selected artifact is `dataset/jamendo/models/model_log_0mean/model.pt` at revision `0983900f136173015f3c5d0b116be014edd33905`, Git blob `6d8a4434482615b142e45b8220ff5a0462a9fee6`, SHA-256 `f09cd6a55c83c13640622ce67480443ce282e3124dd22fccee8a898bb2ba9dee`. Size and identity are checked before `torch.load(weights_only=True, map_location='cpu')`; all 54 state entries are tensors and strict loading succeeds. Unsafe pickle fallback is absent.

The adapter preserves the selected upstream model, custom 80-band `mel_orig` filter from 27.5 to 8,000 Hz, log floor, batch normalization, zero-mean first convolution, and evaluation mode. Only the obsolete global audio-backend selection call is removed from the attributed model source. Unused architectures remain upstream code, not supported adapter configurations. SoundFile decodes mono/stereo float32; stereo channels are averaged. No normalization, gain correction, separation, or audio rewriting is introduced.

The original recipe requires 22,050 Hz, magnitude STFT, a 1,024-sample periodic Hann window, 315-sample hop, centered reflection padding, and 57 zero-magnitude context frames at each end. Output chunks contain 140 predictions plus the complete 114-frame context. This bounds memory without cutting receptive fields.

Installed resampy 0.4.3 contains different `kaiser_best` coefficients from the historical 0.2.2 recipe. Using its similarly named filter would silently change preprocessing. The approved [0.2.2 coefficients and kernel](https://github.com/bmcfee/resampy/tree/0.2.2) preserve the original interpolation and librosa 0.8 floor-length/ceil-padding policy. Three fixed-noise comparisons against the original resampy core were byte-identical; only that reference loader's obsolete `pkg_resources` lookup was replaced with a local path. This verifies the resampling calculation, not every historical package combination or compressed-audio decoder.

[Optional synthetic checks](alignment-data/v6/synthetic-compatibility.json) cover silence, impulse, 440-Hz tone, and seeded noise at 22,050/44,100/48,000 Hz. Maximum magnitude-STFT discrepancy against an independent NumPy FFT was `7.63e-6`; maximum chunk/full-context score discrepancy was `2.52e-8`. Repeated chunk inference and postprocessing were identical. [Resampling comparisons](alignment-data/v6/resampling-compatibility.json) were byte-identical. Every synthetic case produced zero active duration after filtering; this is a narrow nonvocal smoke test, not instrument-mixture validation.

The documented threshold is strict `> 0.51` in float32. The upstream 56-frame filter uses the upper median, replicated edges, and left/right padding of 28/27 frames. It is not an averaged even-window median. Native timestamps remain exact multiples of `315/22050 = 1/70` seconds; half-open sample-and-hold intervals are clipped to analyzed audio. Scores are uncalibrated. Neither the grid nor decimal output establishes 14-ms acoustic boundary accuracy. No threshold or smoothing was fitted to these excerpts.

## Exploratory Predictions and Frozen Comparators

Eighteen historical model assets, nine original recording hashes, and the archived case-manifest identity passed verification. Fresh spectral/CTC extraction reproduced all nine semantic feature records, eighteen activity comparisons, and seventy-six control records. Runtime fields were excluded from equality. [Reproduction evidence](alignment-data/v6/baseline-reproduction.json) is separate from candidate results. Original recordings, annotations, and historical outputs remain unchanged.

The five English excerpts are accompanied; four Japanese excerpts are isolated PJS singing. Related excerpts share original recordings and are not additional singers. Performer independence and possible overlap with candidate training material are not newly established. Existing recording provenance supports the bounded local research described in prior records; no recording, lyric text, or annotation derivative is published. Candidate comparisons use the identical audio hashes and archived English-word/non-pause-Japanese-phone unions. Those unions are **not independently verified vocal/nonvocal boundaries**. The following percentages are proxy overlap, not recall, false-positive rate, instrumental accuracy, or held-out performance.

| Excerpt | veracity Union Coverage | veracity Outside-Union Activation | Spectral Coverage / Outside | CTC Coverage / Outside |
| --- | ---: | ---: | ---: | ---: |
| EN01 | 92.1% | 30.2% | 99.9% / 97.2% | 10.0% / 2.0% |
| EN02 | 100.0% | 41.5% | 99.5% / 99.7% | 13.9% / 2.3% |
| EN03 | 100.0% | 32.0% | 100.0% / 100.0% | 13.1% / 1.2% |
| EN04 | 91.7% | 95.2% | 99.4% / 100.0% | 12.6% / 3.1% |
| EN05 | 100.0% | 85.3% | 100.0% / 100.0% | 19.6% / 0.0% |
| JA01 | 100.0% | 18.7% | 98.8% / 14.6% | 14.0% / 0.0% |
| JA03 | 100.0% | 20.5% | 98.5% / 28.3% | 17.0% / 0.0% |
| JA04 | 100.0% | 18.4% | 98.4% / 27.4% | 14.5% / 0.0% |
| JA05 | 100.0% | 45.8% | 98.1% / 53.1% | 15.6% / 0.5% |

[Exact results](alignment-data/v6/exploratory.json) preserve all comparator values and source hashes. veracity covers substantially more of the supplied annotation unions than CTC activity, but remains active through most outside-union duration in EN04/EN05. This observation does not establish whether those regions contain instruments, reverberation, backing voices, or unannotated lead singing. Verified gap discrimination, boundary localization, confusion matrices, and incremental mismatch detection therefore remain unavailable. No lexical-score ensemble was fitted. Vocal activity cannot verify the sung words or the correct repeated occurrence.

## Experimental Invocation and Output

The worker requires preapproved local assets and never installs or downloads dependencies. Missing assets/dependencies report JSON `status: unavailable` with exit 3; invalid input or an existing destination fails with exit 2. Input is bounded to a complete mono/stereo excerpt of at most 60 seconds and 256 MiB. Rendering does not call this worker.

```sh
PYTHONPATH=artifacts/veracity-local/site artifacts/alignment/venv/bin/python \
  scripts/check_veracity.py \
  --checkpoint artifacts/veracity-local/downloads/model.pt \
  --filter artifacts/veracity-local/downloads/kaiser_best-0.2.2.npz

PYTHONPATH=artifacts/veracity-local/site artifacts/alignment/venv/bin/python \
  scripts/veracity_features.py --audio path/to/local-excerpt.wav \
  --checkpoint artifacts/veracity-local/downloads/model.pt \
  --filter artifacts/veracity-local/downloads/kaiser_best-0.2.2.npz \
  --output artifacts/veracity-local/new-diagnostic.json
```

The first command was executed on synthetic signals; the second template represents the executed invocation pattern, not a claim that its illustrative audio path exists. Keep outputs ignored. Raw scores, filtered scores, exact intervals, source SHA-256, model/filter identities, versions, and runtime measurements remain separate fields. A repeated EN04 process produced an identical semantic record after excluding measurements. The adapter receives no alignment artifact and cannot change text, pronunciation, timing provenance, or corrections. No diagnostic output authorizes acceptance or timestamp repair.

## Operational Measurements and Verification

The measured environment is Apple M4, 16 GiB, macOS 27.0.1, arm64, Python 3.12.14, torch/torchaudio 2.8.0, NumPy 2.5.3, SoundFile 0.14.0, and Numba 0.68.0. Inference uses four CPU threads, fixed seed, and deterministic algorithms. Installed modern librosa/resampy are not substituted for the selected historical filter/kernel.

Nine serial candidate processes took 1.274–1.590 seconds including process startup/exit. Internal dependency import took 0.449–0.461 seconds, model initialization 0.032–0.034, preprocessing 0.509–0.784, inference 0.049–0.103, and postprocessing 0.005–0.012. Internal total was 1.055–1.389 seconds; peak process RSS was 408–432 decimal MB (389–412 MiB). Preprocessing includes kernel/module initialization where applicable. These short-process measurements do not establish warm full-song throughput. The prior CTC/spectral extractor reported 2.744–4.108 seconds and 1,025–1,407 MiB, but different models and work are not a controlled speed comparison. Adding this optional diagnostic incurs its measured cost; it does not replace existing alignment inference.

The [verification record](alignment-data/v6/validation.json) records 61 Swift and 118 Python tests passing in both checkouts, both release builds, deterministic checks, and explicit missing-input results. Preparation and enabled/disabled/direct TTML regressions passed: 601 frames at 1080×1920 and 60 fps, H.264 limited-range Rec.709, supplied 48-kHz AAC, all video timestamps, six markers with zero measured error, and audio correlation approximately 0.999921 with zero lag. The public-only checkout also exported the synthetic reviewed-timing fixture; all 36 TTML refusal checks passed. Final evaluation allocation was 5,515,120,640 bytes (5.515 GB), with 538,275,840 bytes in the new diagnostic and verification roots, below their combined 640 MiB allowance. The diagnostic root occupied 49,889,280 bytes and the new public checkout 488,386,560 bytes, below their respective 128/512 MiB allocations. Nothing was deleted. These are allocated-storage snapshots, not a continuous peak-disk trace; final logs may add small amounts. The historical transfer uncertainty remains acknowledged under the approved planning charge. Synthetic media correctness does not establish acoustic accuracy. Public tests require no weights, private recordings, network, or subscription. Public source includes attributed implementation code and original tests; weights, filter data, raw score curves, private audio, and generated videos remain ignored.

## Next Gate

**Go for independently annotated short-excerpt evaluation; no-go for automatic full-song segmentation.** Retain the same checkpoint and default recipe. The smallest remaining experiment is the existing [annotation protocol](veracity-evaluation-procedure.md#independent-annotation-format-and-review): one additional lawfully supplied accompanied Japanese singer, independent human annotation and review by two participants, at least twenty clear onset/offset pairs and ten verified nonvocal gaps across the held-out set, and frozen singer-separated partitions before calibration. Because historical excerpts have now been inspected, they remain exploratory/development evidence rather than a newly untouched final test.

Apply the unchanged prospective metrics and acceptance criteria only to independently reviewed support. No new model survey, endpoint correction, full-song segmentation, or developer inquiry is required to prepare that experiment. Checkpoint-specific licensing uncertainty remains explicit, while unrelated product and visual requirements remain deferred.
