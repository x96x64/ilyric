# Experimental TIFA Passage-Search Commands

## Status and Inputs

This is an explicit research comparison with the existing full-song CTC path, not its replacement. All candidate timings require review. TIFA support scores and chronological agreement do not establish that the correct lyric occurrence was found. The EN-F01 development comparison produced newly support-qualified incorrect locations; the command must not be used for unattended acceptance.

Use the existing isolated Python environment and pinned local TIFA assets. No download, installation, or network lookup occurs. Inputs are a local recording and complete untimed UTF-8 lyrics under the existing English full-song restrictions: ASCII English letters and contractions, at most 64 paragraphs, four explicit lines and 499 UTF-16 units per paragraph, and 6,000 normalized text labels. Blank lines identify paragraphs; repeated text retains distinct occurrence identities. Unsupported text fails explicitly. Japanese full-song alignment remains unavailable.

Audio is limited to 256 MiB and 25 milliseconds–600 seconds. The worker decodes a separate mono 48-kHz PCM16 analysis file. Originals remain unchanged. Output requires a new directory with an existing parent; use an ignored private location. Both output records contain supplied lyrics and private acoustic predictions and must not enter Git.

## Candidate Search

```sh
artifacts/alignment/venv/bin/python scripts/search_tifa_passages.py \
  --audio LOCAL_AUDIO \
  --lyrics LOCAL_UNTIMED_TEXT \
  --model artifacts/alignment/models/TIFA-1.0-ST \
  --tifa-source artifacts/alignment/vendor/openvpi-TIFA-614a277 \
  --output artifacts/NEW_PRIVATE_SEARCH
```

Fixed 30-second audio windows begin every 15 seconds and cover the complete recording. Each target paragraph is searched with one preceding and one following supplied paragraph, where present. Only central-paragraph timing is retained. At most 2,000 unique context/window evaluations are permitted. Oversized searches fail rather than silently omit candidates. Each request preserves the existing TIFA character, pronunciation-lattice, and duration limits.

`candidates.json` retains automatic window bounds, source and model identities, raw support scores, candidate intervals, rejected alternatives, context omissions, global selection, and runtime. `estimated.json` uses the existing experimental full-song review artifact with a separate TIFA engine identity and a 10-ms model grid. It is not a new renderer project format. Standard output reports the review-required result; progress and actionable diagnostics use standard error. Exit 3 indicates unavailable local assets; exit 2 indicates invalid input or failed preparation; exit 0 does not mean acoustic correctness.

The four correspondence states are provisional `supported`, `ambiguous`, `skipped`, and `unresolved`. A supported candidate passed fixed uncalibrated ranking checks. An ambiguous candidate has a competing global path within the documented margin. A skipped passage had eligible candidates but none was selected chronologically. An unresolved passage had no eligible candidate. Neither skip state means that the words are demonstrably absent from the recording. Ambiguous, skipped, and unresolved occurrences have no effective timing estimate.

## Review and Preparation

Use the unchanged [full-song review and export commands](full-song-commands.md). Review decisions identify source-line occurrence IDs, not text substrings. Accepting a provisional estimate requires an explicit note. Unresolved or ambiguous occurrences require explicit corrected bounds before complete export. Original estimates, alternatives, and source text remain available; corrections do not require inference to be repeated.

The existing TTML preparation path emits paragraph timing and authored breaks. It does not convert these line proposals into word or character synchronization. All lines must be reviewed and ordered before complete export. The Swift renderer never invokes TIFA or accesses the network.

## Deterministic Public Verification

```sh
python3 -m unittest discover -s Tests/reference_validation
python3 scripts/check_passage_search.py artifacts/NEW_SYNTHETIC_EXPORT
```

The second command requires the existing release-built `LyricsInputProbe` and audiovisual validation dependencies. It uses original synthetic audio and deterministic candidate records, without downloaded models or private references. It tests repeat identity, review, exact correction, TTML reload, and audiovisual export; it is not a singing evaluation.

For the private frozen three-recording comparison:

```sh
python3 scripts/evaluate_passage_search.py \
  artifacts/full-song/reference-manifest.json \
  artifacts/full-song/final \
  artifacts/passage-search/final
```

The evaluator reads annotations only after candidate generation. Missing private annotations return an explicit unavailable result. Scoring cannot choose model inputs, alter thresholds, or approve a proposal.
