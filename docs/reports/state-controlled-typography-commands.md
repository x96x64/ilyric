# State-Controlled Typography Commands

This internal validation workflow supplements historical calibration. It does not change the renderer, identify native fonts, or discover arbitrary lyric correspondence.

## Public Verification

Run from the repository root:

```sh
swift build -c release --product ReferenceProbe
./scripts/test.sh
python3 -m unittest discover -s Tests/reference_validation -v
python3 scripts/reference_validation/check_probe.py
python3 scripts/reference_validation/check_typography.py
```

Public unit and probe integration checks use synthetic text or numerical observations and require no private media. The existing Command Line Tools test wrapper supplies Swift Testing paths where necessary.

## Private Protocol

Use a Python environment with NumPy and Pillow and locally available FFmpeg/ffprobe. The workflow installs nothing and makes no network requests.

```sh
git check-ignore -v reference-private/state-typography-cases.json reference-private/analysis/state-typography/current/results.json
git ls-files reference-private
python3 scripts/reference_validation/state_typography.py
```

The tracked-file query must return no paths. All outputs remain under `reference-private/analysis/state-typography/current/`. Originals are read only. Source hashes, stream metadata, original integer PTS, packet flags, extracted frames, and numerical diagnostics are retained privately. The command does not write public profiles.

Private `state-typography-cases.json` contains `version`, `required_cases`, and `recordings`. Each neutral alphanumeric recording ID supplies a filename within `recordings/`, reported Sing metadata, and an explicitly inspected `correspondence` containing `case`, `status`, and `method`. Correspondence is a reviewed input, never an inference from filenames or a font-fit score. The known text and independently observed line structure remain in the existing private `typography-cases.json`.

For a recording selected for quantitative analysis, `measurement` supplies:

- `case`: the matching known-text case.
- `pts_range`: inclusive original integer presentation timestamps.
- `crop`: native `[left, top, right, bottom]` extraction bounds.
- `search_roi`: target-search bounds in the extracted crop.
- `width_range`: broad observed support bounds for separating the identified line from surrounding content.
- `landmark_cells_x`: inspected cell boundaries for corresponding glyph ink centroids, in crop coordinates.

These selections describe the inspected corpus. They are not rendering constants or automatic state recognition. This gate's quantitative comparison is single-line; matching another multiline recording requires an explicitly reviewed extension rather than silent truncation to its first line. Missing case correspondence remains visible even when other recordings are usable.

Absent manifests, recording files, known text, or release probe binaries produce an explicit JSON `unavailable` result. Unsafe paths, malformed inputs, failed decoding, non-increasing PTS, empty inspected intervals, and inconsistent frame counts remain errors. A completed analysis lacking a required observed case returns `measured_with_missing_correspondence`, not a successful fidelity result.

## Interpretation and Reproduction

Native recording intervals are preserved through explicit encoder time bases and passthrough frame scheduling. Decoded images pair with the original PTS list; nominal frame rate never determines measurement time. Repeated runs overwrite private working diagnostics, not source recordings. Source hashes are checked again after analysis.

Geometric stability bounds total span, not just adjacent-frame differences, and terminates across missing or ineligible observations. It does not infer native activation. The selected run excludes a 0.1-second boundary guard before fitting. Threshold and candidate-alpha variations remain separate results. Frame observations within one recording are correlated; equal recording weight and recording-level exclusion avoid treating them as independent experimental repetitions.

The recording-only fitted candidate is checked against the required screenshots afterward. P3 screenshots and Rec.709 video are converted to sRGB before these new comparisons. A fixed encoded-value luminance cutoff can reject dim glyphs after conversion; retain the cutoff sensitivity and inspect source support rather than interpreting every detected bound as complete text.

Landmark spacing fits distinguish translation from relative horizontal expansion. Held-out checks learn spacing from another recording and allow only translation registration on the excluded recording. They validate neither timing nor a native scale implementation. Mask comparisons use whole-paragraph probe output. The baseline remains a fitted proxy.

The workflow's initial publication was preceded by exact reproduction of the archived S08/S09 comparisons using the historical measurement method. Existing `calibrate.py --reproduce-baseline` remains available for the original four-case v1 check; do not confuse it with color-managed v3 measurements. Public evidence must be selected through a separate privacy review. Do not copy unfiltered private JSON, source text, filenames, or reference-derived images into the repository.
