# S09 Typography Validation Commands

This internal continuation reuses `ReferenceProbe` and the existing state diagnostics. It measures an explicitly identified multiline paragraph, not arbitrary lyric correspondence or a native animation implementation.

## Public Verification

```sh
swift build -c release --product ReferenceProbe
./scripts/test.sh
python3 -m unittest discover -s Tests/reference_validation -v
python3 scripts/reference_validation/check_probe.py
python3 scripts/reference_validation/check_typography.py
```

The Python public suite uses the standard library. Probe checks use independently generated text. No private reference or network access is required.

## Private Validation

Use locally available FFmpeg/ffprobe and a Python environment with NumPy and Pillow. Run from the repository root:

```sh
git check-ignore -v reference-private/s09-state-cases.json reference-private/analysis/s09-state/current/results.json
git ls-files reference-private
python3 scripts/reference_validation/paragraph_typography.py
```

The tracked-file query must be empty. Missing private manifests, recordings, known text, or the release probe produce JSON `status: unavailable` before optional image dependencies are imported. Invalid supplied protocols, unsafe paths, decoding failures, inconsistent frame counts, and absent stable comparison support remain errors. `measured` describes completed diagnostics, not fidelity acceptance.

The private manifest contains `version` and `recordings`. Each neutral alphanumeric ID identifies a source filename, manually verified `correspondence`, reported capture conditions, and `measurement`. The latter contains:

- `case`: an existing known-text case in private `typography-cases.json`.
- `pts_range`: inclusive original integer timestamps.
- `crop` and `search_roi`: native extraction bounds and crop-local search bounds.
- `width_ranges`: ordered broad support ranges, one per observed line.
- `advance_range`: permissible adjacent ink-top distances for identifying the paragraph.
- `landmark_cells_x`: inspected per-line cell boundaries; these measure existing glyphs without independently shaping them.
- `phase_pts`: exact observed timestamps named `sharp_dim`, `first_line_completed`, and `late`, selected by inspecting the source sequence. These labels describe observed appearance, not source lyric timing.

All expected lines must have unambiguous support. Multiple matches and incomplete cell masks are unavailable observations. The geometry vector includes every line's horizontal position, ink top, and width. It does not establish stability of glyph height, brightness, blur, or the complete native state. Preserve the diagnostic limitations of each criterion.

Outputs, hashes, original PTS, source metadata, known text, rendered candidates, masks, and decoded crops remain under ignored `reference-private/analysis/s09-state/current/`. Repeated runs replace only generated diagnostics. Source files are never modified. No public evidence is written automatically.

## Interpretation

Frames are decoded with passthrough scheduling and the source time base. Display P3 screenshots and Rec.709 recordings retain their distinct provenance; new comparisons use color-managed sRGB extraction. Measurements remain in native capture pixels.

Parameter selection uses equal recording weights and requires observed line structure. Historical S08 recording-level squared losses are imported from immutable v3 numerical evidence; new S09 repetitions are held out individually. Fixed-candidate predictions, threshold failures, and boundary sensitivity remain separate from a combined fit.

`paragraph_phases.py` supplements the main analysis with fixed-candidate phase comparisons. Individual line registration is accompanied by one common paragraph translation so that line-advance discrepancies remain visible. Sharp-phase spacing and relative vertical landmarks supplement the deliberately weak first-detectable comparison. None identifies native font settings, uniform geometric scaling, or an Apple implementation.

The new protocol uses luminance cutoff 100 as its baseline because the previous gate demonstrated loss of dim S09 support at 145 after color conversion. Cutoffs 80, 125, and 145 remain sensitivity checks; an incomplete high-cutoff mask cannot win parameter selection. This protocol difference is explicit, not a revision of historical measurements.
