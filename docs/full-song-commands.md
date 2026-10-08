# Experimental Full-Song Preparation Commands

## Scope and Inputs

This isolated personal-use experiment produces review-required English line timing for complete 25-ms–600-second recordings. It is not a stable public CLI or an unattended singing aligner. The [engineering report](review-first-full-song.md) documents poor coverage and correspondence failures. Production `ilyric`, the existing excerpt commands, and versioned renderer projects are unchanged.

Supply a local audio file of at most 256 MiB, complete UTF-8 lyrics of at most 64 KiB, and the already provisioned pinned English wav2vec2 model. No network access or model download occurs. The isolated environment requires the existing Torch, Transformers, NumPy, SciPy, SoundFile, and FFmpeg dependencies. Missing assets return exit 3; invalid input or failed processing returns exit 2; structural preparation returns exit 0 without acoustic acceptance. Diagnostics use standard error and the result summary uses standard output. Output files must be new, in an existing ignored directory.

Blank lines delimit paragraphs; single newlines are explicit within-paragraph breaks. Limits remain 64 paragraphs, 499 UTF-16 units/four explicit lines per paragraph, and 6,000 CTC labels. Preserve the supplied lyric occurrence order, including every repeated chorus. Do not supply timing labels or reference clip boundaries. ASCII English letters and contractions are supported for alignment; original punctuation/case/curly apostrophes remain in display text. Unsupported Japanese, accents, numeric pronunciation, and symbols fail explicitly. Existing Japanese pronunciation overrides belong to the separate unchanged excerpt workflow.

## Estimate and Inspect

The following commands are templates using locally supplied files:

```sh
mkdir -p artifacts/personal-song
artifacts/alignment/venv/bin/python scripts/align_full_song.py align \
  --audio path/to/complete-recording.wav \
  --lyrics path/to/complete-untimed-lyrics.txt \
  --model artifacts/alignment/models/wav2vec2 \
  --output artifacts/personal-song/estimated.json

python3 scripts/align_full_song.py validate artifacts/personal-song/estimated.json
```

The source is never overwritten. Temporary decoded audio is confined to a temporary directory beside the output and removed on completion/failure. Inference uses 30-second windows with four-second overlap and central score ownership, followed by bounded global ordered CTC correspondence. Longer audio is not passed into a short-excerpt worker. Repeated text has distinct IDs. Unsupported correspondence retains a raw `proposal` but a null `estimate`; `flags` and uncalibrated `quality` explain the review requirement. Every line remains pending. Unassigned audio intervals in the summary are unknown, not verified instrumental regions.

## Review and Correct Without Inference

Inspect the artifact against the complete original audio. Create a separate UTF-8 JSON decisions file. Each decision identifies the original integer line ID and a meaningful note. An omitted `interval_us` explicitly accepts a supported estimate; an explicit two-integer interval records a manual correction. This example illustrates syntax, not actual acoustic review:

```json
[
  {"line": 0, "note": "Estimated boundaries checked against the original audio"},
  {"line": 1, "interval_us": [12500123, 14760000], "note": "Boundaries corrected after listening"}
]
```

```sh
python3 scripts/align_full_song.py review artifacts/personal-song/estimated.json \
  --decisions artifacts/personal-song/decisions.json \
  --output artifacts/personal-song/reviewed-1.json
```

Batch decisions require 1–256 distinct IDs and preserve all original proposals, source text, and model evidence. Corrections carry `manually_corrected` provenance and review history. Use the previous reviewed artifact for subsequent decisions. No model is imported during review. A null estimate cannot be accepted without explicit bounds. Invalid overlap, out-of-order timing, or bounds outside the original duration are rejected rather than repaired. Decimal display precision does not improve the model’s 20-ms effective resolution.

## Prepare and Render

```sh
python3 scripts/align_full_song.py export artifacts/personal-song/reviewed-final.json \
  --audio path/to/complete-recording.wav \
  --output artifacts/personal-song/prepared.ttml

.build/release/LyricsInputProbe render \
  --lyrics artifacts/personal-song/prepared.ttml --format ttml --highlighting disabled \
  --audio path/to/complete-recording.wav --output artifacts/personal-song/video.mp4
```

Export requires the exact original audio SHA-256 and reviewed effective intervals for every occurrence. It does not drop unresolved text. The existing TTML subset preserves paragraphs and explicit breaks, with line-level focus and no invented word timing. Internal line gaps retain paragraph focus; between-paragraph gaps and trailing audio follow the existing scene policy. Keep the provenance artifact beside TTML. A version-3 experimental project can reference the same TTML without new fields. Rendering remains offline, deterministic, and independent of acoustic inference.

## Public Verification and Private Scoring

```sh
python3 -m unittest discover -s Tests/reference_validation -q
scripts/test.sh
swift build -c release
python3 scripts/check_full_song.py artifacts/full-song-public-example
```

The last command generates original audio and synthetic acoustic scores, then reviews, corrects, exports, and validates a 75-second video. It does not run a pretrained model or demonstrate singing accuracy. Optional real-recording scoring uses `scripts/evaluate_full_song.py PRIVATE-MANIFEST.json`. The manifest is a list of case objects containing a neutral `id`, relative `artifact` path, and `lines` with exact `text` and integer `interval_us` references. It must remain ignored. The evaluator reports aggregate timing errors and temporal correspondence conflicts without exporting lyric text. Reference times must never enter the inference or candidate-selection stage.
