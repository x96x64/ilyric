# iLyric Experimental Alignment Preparation

## Status and Input Contract

This optional developer workflow estimates timing from a local singing recording and its complete corresponding text. It is not a stable CLI, transcription service, licensed model distribution, or qualified automatic synchronization feature. Read the [experiment and measured limitations](automatic-alignment.md) before use. In particular, complete inputs longer than 60 seconds are rejected; full-song segmentation is not implemented.

Supply UTF-8 untimed text. Blank lines separate lyric paragraphs; single newlines within a paragraph are explicit display breaks. Leading/trailing empty file lines are structural; spaces and punctuation inside paragraphs remain unchanged. Original text, including BOM/CRLF, is retained in the artifact, while display delimiters use LF. Do not supply timestamp syntax or pronunciation labels as lyric text. English and Japanese are separate explicit invocation languages; mixed-language pronunciation is not qualified. Unsupported symbols and script/model mismatches fail explicitly.

The input limits are 64 KiB, 64 paragraphs, at most four supplied display lines per paragraph, fewer than 500 UTF-16 units per paragraph, at most 1,500 retained alignment characters/CTC labels, and 3,000 acoustic units. The Japanese pronunciation lattice is also bounded before model inference. The existing renderer independently checks automatic wrapping and shaped support. Audio must be a readable unprotected local file at most 256 MiB and 60 seconds; FFmpeg must decode it. No automatic cropping, verse selection, vocal separation, or inference from a streaming service is performed. Original audio is not overwritten. Inference uses a temporary analysis copy, not the renderer's audio backend.

## Optional Environment and Assets

Public tests use the Python standard library. Inference additionally requires a separately prepared Python 3.12 environment and FFmpeg. Do not install into the system Python. The evaluated package versions are in [evaluation-requirements.txt](alignment-data/v1/evaluation-requirements.txt); this is an environment record, not a guarantee for other operating systems or architectures. Review its dependency licenses before redistribution, including GPLv3 Praat-Parselmouth. iLyric does not bundle these dependencies or select a project license.

Provision assets explicitly after reviewing sizes and terms:

- English baseline: [facebook/wav2vec2-base-960h, pinned revision](https://huggingface.co/facebook/wav2vec2-base-960h/tree/22aad52d435eb6dbaf354bdad9b0da84ce7d6156), Apache-2.0 declaration. Obtain `model.safetensors` and the small JSON files listed in the asset manifest, approximately 378 MB in total.
- Singing candidate: [TIFA source revision](https://github.com/openvpi/TIFA/tree/614a277d2580efe5e4b84faf4c34753dbc5a062c), MIT code; [TIFA-1.0-ST release archive](https://github.com/openvpi/TIFA/releases/tag/v1.0.0), approximately 151 MB compressed, CC BY-NC-SA 4.0 model files. Preserve its configuration, dictionaries, and pronunciation assets together. No general commercial-use clearance is established.
- Japanese pronunciation: the evaluated local `unidic-lite` dictionary is selected explicitly. The worker does not request the much larger automatic UniDic download. Changing the dictionary is a new pronunciation experiment.

The [asset manifest](alignment-data/v1/model-assets.json) gives required names, sizes, and SHA-256 hashes. The worker refuses altered/missing model assets and a different TIFA Python source fingerprint before loading. All assets must remain in ignored local storage. Installation is an explicit preparation action; neither the alignment command nor rendering downloads models. Python network connection attempts during inference are refused. Third-party native-library behavior remains an environment dependency; the measured inference also ran under the network-restricted execution environment.

A possible isolated installation, after approval and license review, is:

```sh
python3.12 -m venv artifacts/alignment/venv
artifacts/alignment/venv/bin/python -m pip install --no-cache-dir \
  -r docs/alignment-data/v1/evaluation-requirements.txt
```

This command requires network access during installation. Do not run it as part of public tests or frame rendering. Keep model/source downloads separate and verify the manifest. The installation and weights consumed approximately 1,065 MiB of retained downloaded assets/wheels, plus small metadata in the recorded experiment, below its explicitly approved 2-GB ceiling; final evaluation storage was approximately 2.8 GiB before the fresh-checkout verification.

## Estimate, Review, and Prepare

Use new output filenames and an existing ignored output directory. The following paths are examples, not bundled model locations:

```sh
artifacts/alignment/venv/bin/python scripts/align_lyrics.py align \
  --audio artifacts/input/recording.wav --lyrics artifacts/input/lyrics.txt \
  --engine tifa --language ja \
  --model artifacts/alignment/models/TIFA-1.0-ST \
  --tifa-source artifacts/alignment/vendor/openvpi-TIFA-614a277 \
  --output artifacts/input/estimated.json
```

For the English speech baseline, use `--engine ctc --language en --model artifacts/alignment/models/wav2vec2` and omit `--tifa-source`. Both candidates consume the entire supplied excerpt without preassigned line timestamps. CPU inference uses four threads. A structurally valid result may contain unresolved regions and pending review; status `ok` is not acoustic acceptance.

The version-1 alignment artifact is separate from the versioned renderer project. It records source text/hash, display paragraphs, audio hash/duration, normalized text/ranges, model units, estimates, corrections, review notes, unresolved regions, and model/preprocessing provenance. Model steps are 10 ms for TIFA and 20 ms for CTC; integer microsecond serialization does not imply that accuracy. No per-character timing is inferred. Inspect/listen against the original audio before accepting estimates.

```sh
python3 scripts/align_lyrics.py validate artifacts/input/estimated.json
python3 scripts/align_lyrics.py review artifacts/input/estimated.json \
  --line 0 --begin 1.230 --end 4.560 --note 'Acoustic boundaries corrected' \
  --output artifacts/input/review-1.json
python3 scripts/align_lyrics.py review artifacts/input/review-1.json \
  --line 1 --note 'Estimated boundaries checked against supplied audio' \
  --output artifacts/input/review-2.json
```

Omitting both boundary arguments accepts an existing estimate; supplying both records a manual correction and preserves the estimate. Repeat for each line, using the preceding artifact as input. The JSON correction fields may be inspected, but the command is preferred because it maintains review history and interval validation. Original estimates are integrity-checked; edits belong in correction fields. Review notes are assertions, not a calibrated accuracy score. An unresolved model result requires correction of every line before export. Invalid overlap/order must be corrected explicitly. Nothing invokes inference during review.

```sh
python3 scripts/align_lyrics.py export artifacts/input/reviewed.json \
  --audio artifacts/input/recording.wav --output artifacts/input/prepared.ttml
.build/release/LyricsInputProbe render \
  --lyrics artifacts/input/prepared.ttml --format ttml --highlighting disabled \
  --audio artifacts/input/recording.wav --output artifacts/input/video.mp4
```

The audio identity must match the alignment artifact. Keep that artifact with the derived TTML: TTML itself does not carry the full model/correction provenance. This export is deliberately line-level. It preserves complete paragraphs and explicit breaks; it does not emit phonemes as display characters or qualify word highlighting. Paragraph ends use the final constituent line's end, so internal line gaps retain focus. Interparagraph gaps remove focus through the existing TTML policy. A version-3 project may reference this TTML using the existing `lyricsFormat: "ttml"` field; no schema additions are required.

The existing renderer retains `contain`, 1080×1920, 60-fps H.264/AAC behavior and exact rational sampling. Source/model preparation has no role in arbitrary-time frame evaluation. Output duration follows supplied audio, including final no-focus intervals and the documented subframe silence padding.

## Diagnostics and Reproduction

Preparation writes a compact JSON summary to stdout and diagnostics to stderr. Exit 0 means structural completion, 2 means invalid input/output or inference failure, and 3 means unavailable optional model/dependency. The command refuses existing output files. An absent model is an explicit unavailable result, not a passed accuracy test. Temporary transformed audio and inference files are confined to a temporary directory beside the requested output and removed on completion or failure.

```sh
python3 -m unittest discover -s Tests/reference_validation -v
./scripts/test.sh
swift build -c release
python3 scripts/check_alignment.py artifacts/alignment/public-example
```

The public check generates original text and synthetic audio, simulates alignment output, records a correction, prepares TTML, exports the complete video, and validates supplied audio and all frame timestamps. It tests software integration, not singing accuracy. Optional real-corpus evaluation requires separately provisioned, licensed corpus files; the [protocol](alignment-data/v1/protocol.json) and [measurements](alignment-data/v1/measurements.json) identify selection, split, hashes, and errors. Do not use private iPhone Music recordings as phonetic ground truth.

The optional `scripts/evaluate_alignment.py` accepts a private JSON manifest with case IDs, development/held-out roles, language, relative result paths, and independently annotated lines (`text`, `begin_us`, `end_us`). An `offset_censored` flag excludes a boundary defined by excerpt truncation. It scores original estimates rather than corrections and emits only IDs and numerical residuals. Preserve the private manifest and original annotations separately; the committed protocol and source hashes permit reconstruction without publishing lyric text.
