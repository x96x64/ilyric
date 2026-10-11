# Vocal Annotation Intake

## Optional Research Scope and Human Requirements

This optional research utility retains the historical two-participant protocol. It is not a prerequisite for the single-developer personal product or its review-first full-song prototype. Single-user usability review must be described as such, without claiming independent acoustic ground truth.

This read-only utility checks a bounded research intake profile of the existing version-1 [annotation representation](veracity-evaluation-procedure.md#independent-annotation-format-and-review). It does not change the renderer's project schema, certify human participation or rights, score detector accuracy, or freeze partitions. Missing records return unavailable. A successful structural check always returns `eligible_for_scoring: false` until the separate human and corpus audit is completed.

Supply one lawfully usable accompanied Japanese recording from a singer absent from the existing corpus. Record its exact source identity, actual performer group, permitted local processing/annotation/retention, and candidate-training overlap where known. Preserve the complete original recording. Existing English sources may provide new passages after performer and rights verification; isolated PJS material remains auxiliary. Related excerpts must remain in the same singer/source group.

Two distinct humans must first listen independently without text, word/phone labels, model predictions, or the other pass. Keep separate initial files. A later review compares both passes, retains disagreements and uncertainty, and resolves a disputed region only through listening-supported evidence. Never average endpoints to manufacture agreement. Follow the existing conventions for sung consonants, sustained vowels, backing/overlapping singing, humming, ad-libs, instruments, silence, breaths, spoken interjections, reverberation, and censored clip edges.

The eventual held-out corpus needs at least four accompanied 20–60-second passages from two distinct singers, including the additional Japanese singer, twenty clear uncensored onset/offset pairs, and ten reviewed nonvocal gaps. Development and validation each require separate singer groups and at least two passages. Actual singer independence and checkpoint-training overlap require a separate audit; source-role reservations are not frozen partitions.

## Completed Record Fields

Retain `format_version: 1`, `source_id`, `audio_sha256`, `sample_rate_hz`, `annotator`, `review_status`, and `intervals`. Complete the provenance required by the existing protocol with neutral `singer_group` and `permission_reference` identifiers, `language` (`en` or `ja`), an `accompanied` Boolean, `source_total_samples`, and half-open `source_start_sample`/`source_end_sample` bounds in the original decoded sample coordinate system. Separately verify the declared sample rate and decoded frame count before freezing; the utility verifies audio bytes, not codec decoding or recording permissions.

Prefer `timing_unit: samples`, `duration_samples` equal to the source excerpt length, and positive integer `annotation_resolution` in samples. Interval coordinates are excerpt-relative; original coordinates equal `source_start_sample` plus the interval coordinate. Native times remain rational with denominator `sample_rate_hz`. The alternate `timing_unit: microseconds` uses `duration_us` and integer microsecond resolution; duration must agree with source-sample bounds within one microsecond. Mixed-unit duration or interval fields are rejected. No timing conversion, rounding, normalization, or annotation rewriting occurs.

For singing, use `onset_earliest_sample`, `onset_latest_sample`, `offset_earliest_sample`, and `offset_latest_sample`, or the corresponding `_us` fields. The certain core lies between latest onset and earliest offset. Optional `censored` contains Boolean `onset` and `offset`; a censored boundary must touch its excerpt edge. Instrumental, silence, breath, spoken-interjection, ambiguous-reverberation, and unresolved regions use `start_sample`/`end_sample` or `_us`. Unannotated gaps and uncertain boundaries remain unknown; overlapping envelopes require a single appropriate overlapping-singer/unknown region rather than conflicting positive and negative labels.

Initial records declare `review_status: independent_pass` and `independence` with Boolean `audio_only: true`, `consulted_predictions: false`, and `consulted_other_pass: false`. These are human assertions, not machine-verified facts. A reviewed record declares `review_status: reviewed`, a distinct `reviewer`, and `initial_passes_sha256` containing both unchanged initial-file hashes. Both initial files must be supplied for link validation. Differing interval lists require a separate `disagreements` list. Each entry contains bounds in the reviewed record's units, `disposition` (`unresolved` or `resolved_by_listening`), and a neutral `evidence_reference`. Unresolved support must remain wholly unknown. Structural validation cannot establish whether every disagreement was recorded faithfully; that requires human review.

Optional `classification`, `notes`, interval `tags`, and interval `review` preserve research context. Unknown fields, invalid UTF-8, duplicate JSON keys, nonfinite values, invalid identities, unsupported versions/labels, reversed/out-of-bounds intervals, same-participant review, and inconsistent pass identities are rejected. Bounds are 128 KiB per JSON record, 2,000 intervals/disagreements, 192-kHz declared sample rate, a 60-second excerpt, and a 512-MiB local source. No model, network, media decoding, or optional package is invoked.

## Read-Only Commands and Freeze Boundary

These templates are preparation instructions, not executed human-annotation claims:

```sh
python3 scripts/validate_vocal_annotations.py \
  --record reference-private/alignment-vad-preparation/source-01/A.json \
  --audio path/to/original-local-audio.wav

python3 scripts/validate_vocal_annotations.py \
  --record reference-private/alignment-vad-preparation/source-01/reviewed.json \
  --audio path/to/original-local-audio.wav \
  --pass-a reference-private/alignment-vad-preparation/source-01/A.json \
  --pass-b reference-private/alignment-vad-preparation/source-01/B.json
```

Output is a structural summary on standard output, including hashes, exact units, declared counts, and unknown support. Keep it private if saved. Missing files or review passes return JSON unavailable with exit 3; malformed or inconsistent input uses standard error and exit 2. Counts are declared annotations, not independently verified acoustic measurements.

Before scoring, humans must verify rights and source metadata, participant independence, all boundaries/gaps, disagreement preservation, required counts and strata, actual singer/source grouping, and untouched final-test passages. Then freeze source/passage/annotation/permission/protocol hashes and singer-separated roles before threshold selection or new candidate evaluation. Previously inspected historical excerpts remain audit/development evidence. Continue the existing default recipe and frozen spectral/CTC comparators only after this boundary. Activity support cannot establish lyric-text correspondence or the correct repeated occurrence.
