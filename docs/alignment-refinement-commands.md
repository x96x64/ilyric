# iLyric Alignment Refinement Commands

## Status and Compatibility

The [refinement report](alignment-refinement.md) qualifies this extension to the existing [offline preparation workflow](alignment-commands.md). The models, isolated environment, 60-second bound, mandatory timing review, TTML conversion, and renderer are unchanged. No new model downloads are required. No automatic confidence-based acceptance or endpoint repair is enabled.

## Explicit Japanese Pronunciation

The optional `--pronunciations` argument accepts a separate UTF-8 JSON file, at most 64 KiB. It is supported only with `--engine tifa --language ja`. It supplies pronunciation hypotheses, not timing or replacement display text. Ordinary invocations without this argument retain their prior text conversion and estimates.

The version-1 override document has exactly these fields:

- `version`: integer `1`.
- `source_sha256`: SHA-256 of the original UTF-8 lyric file bytes, including its original line endings and optional BOM.
- `overrides`: 1–64 ordered, nonoverlapping ranges. Each has exactly `paragraph`, `start_utf16`, `length_utf16`, `text`, `reading`, and `note`.

Paragraph numbers are zero-based, following the existing blank-line separation policy. UTF-16 offsets address the complete displayed paragraph after file-delimiter handling. `text` must equal that exact range. A repeated phrase is selected by paragraph and range, never by an ambiguous text search. Ranges cannot cross explicit line breaks, split surrogate pairs or combining/variation sequences, or overlap. The supported range is deliberately restricted to contiguous Japanese text; this is not a general Unicode grapheme-segmentation API.

`reading` supplies at most 256 kana characters. NFC conversion applies only to this separate pronunciation string; the original display text remains unchanged. Kana is converted through the pinned local dictionary, with at most 64 complete alternatives. Empty readings, unsupported kana, unknown fields, duplicate JSON fields, invalid types, and source-identity mismatches fail explicitly. Each range requires a nonempty explanatory note. Phonemes, morae, words, characters, and rendered glyphs are not interchangeable.

The original [text fixture](../fixtures/alignment/pronunciation.txt) and [override fixture](../fixtures/alignment/pronunciation.json) demonstrate selection of the second occurrence. They do not include or claim corresponding singing audio. A user-supplied example invocation is:

```sh
artifacts/alignment/venv/bin/python scripts/align_lyrics.py align \
  --audio artifacts/input/recording.wav --lyrics artifacts/input/lyrics.txt \
  --engine tifa --language ja \
  --model artifacts/alignment/models/TIFA-1.0-ST \
  --tifa-source artifacts/alignment/vendor/openvpi-TIFA-614a277 \
  --pronunciations artifacts/input/pronunciations.json \
  --output artifacts/input/estimated.json
```

The worker generates internal PFML from validated ranges and local pronunciation conversion. It does not ingest arbitrary user PFML. Source text is retained as the ownership label even where the pronunciation converter omits a long-vowel mark. The artifact records the complete override document under engine provenance. For otherwise exact Japanese text coverage differing only by dropped long-vowel marks, `diagnostics` may contain an `unapplied_pronunciation_suggestion`. Its document can be reviewed and supplied in a later invocation; the worker never applies it silently. No suggestion is made for other text mismatches. The existing review, correction, validation, and export commands remain applicable; inference is not repeated during correction.

## Diagnostic Scores and Endpoints

New artifacts retain TIFA token agreement and mean aligned-span similarity, or English CTC forced-token log support. These are uncalibrated diagnostics, not probabilities of correct lyrics. A high score cannot establish complete transcript coverage. Structural completion and no unresolved units do not establish an accurate match.

The public `alignment.endpoints` module provides deterministic energy and review-threshold diagnostics for experiments. Its input is a separate mono 48-kHz PCM16 analysis copy of at most 60 seconds. Energy is whole-mixture RMS in 10-ms windows. It does not identify singing independently of instruments, alter source audio, or change artifact timing. The fitted thresholds and failed candidates belong to the numerical report; they are not default preparation policy.

Every estimated interval still requires explicit review before TTML export. A result marked `not_flagged` by an experimental diagnostic is not automatically accepted. Unresolved source support must remain unresolved or receive explicit recorded corrections.

## Public Verification

```sh
python3 -m unittest discover -s Tests/reference_validation -v
./scripts/test.sh
swift build -c release
python3 scripts/check_alignment.py artifacts/alignment-refinement/public-check
```

The deterministic suite requires no models, corpus, subscription, or network. Optional inference remains unavailable when local assets are missing; that outcome is not a passed accuracy evaluation. The synthetic preparation check verifies original text, corrections, exact timing, complete TTML rendering, supplied audio, and frame scheduling. Acoustic results require the separately provisioned licensed corpus described in the report.

The optional `scripts/evaluate_alignment_refinement.py MANIFEST` reads a private list of `case`, `variant`, `role`, and relative `result` paths. Neutral IDs use `ENnn` or `JAnn`; variants are `matched`, `omit_middle`, `duplicate`, `absent`, and `early_end`. Roles are `development` or `held-out`. It derives each threshold only from development positives and negatives, then reports both splits. Missing inputs return explicit `unavailable` status and exit 3. This evaluator does not execute a model or authorize automatic acceptance.
