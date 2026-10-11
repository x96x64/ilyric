# iLyric Acoustic Coverage Diagnostic Commands

## Status and Inputs

The [coverage report](independent-acoustic-coverage.md) documents failed and partially informative candidates. These commands are research tools, not an acceptance gate. Keep the existing [reviewed preparation path](alignment-commands.md), pronunciation overrides, and endpoint behavior unchanged. No command modifies an input artifact, lyrics, pronunciation, or timing. Every estimate still requires review before TTML export.

Feature extraction requires the already provisioned optional Python environment, pinned local English CTC assets, and FFmpeg described in the alignment report. It downloads nothing and blocks Python network connections. Model, source, and recording rights remain separate. Missing local inputs or dependencies return `unavailable` and exit 3; invalid input returns exit 2. Successful diagnostic execution does not establish acoustic accuracy.

## Extract Audio-Only Evidence

```sh
artifacts/alignment/venv/bin/python scripts/coverage_features.py \
  --audio artifacts/input/recording.wav \
  --model artifacts/alignment/models/wav2vec2 \
  --output artifacts/input/acoustic-features.json
```

The output directory must already exist. Existing outputs are refused. Limits remain 256 MiB and 60 seconds of input audio; a separate temporary mono analysis copy is removed afterward. The extractor checks all pinned CTC asset hashes before inference. It uses fixed spectral settings and unconstrained CTC output, without a supplied transcript. Features include original audio identity, duration, integer-microsecond activity intervals, private greedy spelling, model/dependency provenance, and separately labeled runtime measurements.

**Feature output may contain acoustic-derived copyrighted text and must remain ignored.** It is neither a replacement transcript nor shareable public evidence by default. The speech model is English; Japanese lexical comparison is explicitly unavailable. Japanese activity measurements do not establish Japanese model support. Timing grids are 10/20 ms; integer serialization does not establish microsecond acoustic accuracy.

## Inspect Without Repairing

```sh
python3 scripts/diagnose_acoustic_coverage.py \
  artifacts/input/estimated.json artifacts/input/acoustic-features.json \
  --output artifacts/input/coverage-diagnostic.json
```

Original audio identities and durations must agree. Feature input is limited to 2 MiB; existing alignment validation remains applicable. By default, comparison uses original estimates. `--use-corrections` selects recorded corrections where present, allowing a corrected artifact to be inspected without rerunning inference. Neither mode changes provenance, review state, or export eligibility.

Output contains source/audio/artifact/semantic-feature hashes, unresolved line IDs, two asymmetric activity-disagreement scores, suspicious proxy intervals, English lexical disagreement where supported, and limitations. Runtime fields are excluded from the semantic-feature digest. Scores are not calibrated probabilities. “Unexplained activity” can be an instrument; “unsupported estimate” can be a sustained vowel with sparse CTC emissions. A missing score is unavailable evidence, never a passed test. No exact omitted lyric text or missing-word localization is inferred.

## Freeze and Evaluate Private Controls

```sh
python3 scripts/evaluate_acoustic_coverage.py freeze \
  artifacts/input/control-manifest.json --output artifacts/input/frozen.json
python3 scripts/evaluate_acoustic_coverage.py score \
  artifacts/input/control-manifest.json --frozen artifacts/input/frozen.json \
  --output artifacts/input/evaluation.json
```

The private manifest is a list of at most 128 objects with exactly `case`, `variant`, `role`, `artifact`, and `features`. Neutral case IDs use `ENnn` or `JAnn`. Paths resolve relative to the manifest. Roles are `development`, `diagnostic-reuse`, or `reserved`; variants are `matched`, `omit_middle`, `duplicate`, `absent`, `early_end`, or `misordered`. Labels must be established independently through documented control construction, not guessed from model output.

Freeze reads only development cases and requires matched/mismatched controls for both historical engines. Score never refits and verifies the development-input digest. Feature settings and controls must be reserved before final testing. The evaluator preserves the historically fitted TIFA/CTC score thresholds for comparison, reports each independent candidate separately, and evaluates a simple OR with the prior gate. An existing review flag remains true when independent evidence is unavailable; otherwise unavailable evidence remains unavailable. Flags are experimental decisions, not authorization for automatic rejection or export.

Confusion tables use mismatch detection as the positive class and report unavailable counts separately. Wilson intervals are descriptive; repeated mutations of a recording violate independence assumptions for population inference. All current mismatch examples are constructed. Evaluation output contains neutral identifiers and numerical evidence, but any publication still requires an explicit privacy review.

## Public Verification

```sh
python3 -m unittest discover -s Tests/reference_validation -v
./scripts/test.sh
swift build -c release
python3 scripts/check_alignment.py artifacts/coverage-public-check
```

Public tests use original text and deterministic interval/model-output fixtures. They require no model downloads, private recordings, or subscriptions. Missing optional evaluation inputs are not successful accuracy tests. The synthetic preparation export verifies unchanged TTML/audio/rendering behavior; it does not measure singing accuracy.
