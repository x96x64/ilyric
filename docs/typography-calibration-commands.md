# Typography Calibration Commands

These commands exercise an internal validation probe. They do not configure the production renderer or establish native font identity. Run them from the repository root on macOS with the Swift toolchain. Public tests use only independently supplied synthetic text.

## Public Verification

```sh
swift build -c release --product ReferenceProbe
./scripts/test.sh
python3 -m unittest discover -s Tests/reference_validation -v
python3 scripts/reference_validation/check_probe.py
python3 scripts/reference_validation/check_typography.py
```

The probe integration checks write ignored synthetic outputs under `artifacts/`. Python unit and integration checks require only the standard library. The Swift test wrapper supplies the Testing framework paths when required by the selected Command Line Tools.

## Private Calibration

The private workflow additionally requires NumPy and Pillow. Use a Python environment containing those dependencies. No package installation or network access occurs during analysis.

```sh
git check-ignore -v reference-private/typography-cases.json reference-private/analysis/typography-calibration/current/results.json
python3 scripts/reference_validation/calibrate.py --reproduce-baseline
python3 scripts/reference_validation/calibrate.py
```

The reproduction command reads the existing private `cases.json` and compares the four archived typography cases against `docs/reference-data/v1/results.json`. It reports `reproduced` or `different`; a discrepancy exits with status 1 and requires investigation before extending calibration. Exact reproduction is environment-specific.

Calibration reads `reference-private/typography-cases.json`. Each alphanumeric case identifier maps to:

- `file`: screenshot filename within the private `screenshots/` directory.
- `text`: manually supplied whole-paragraph text; explicit newlines are comparison constraints, not proof of source authorship.
- `observedLines`: independently inspected line structure, retained separately from the probe input.
- `roi`: native-pixel `[left, top, right, bottom]` measurement region.
- `group`: `latin`, `japanese`, `mixed`, or `sing-static` for this experiment.
- `structure`: `automatic` or `observed-breaks`, describing the tested input construction.
- `alignment`: optional `left` or `right` observation.
- `alternateTexts`: optional private transcription alternatives for an ambiguous glyph.

Private case files and all output images and numerical diagnostics remain ignored. The command verifies the private root, rejects paths escaping it, and refuses tracked private material. Neither command exports results into public documentation. Public numerical evidence requires a separate review and explicit selection.

Absent private inputs produce JSON with `status: unavailable` and a specific reason, with exit status 0. Missing probe binaries also produce `unavailable`. Malformed or inconsistent supplied cases are errors, not silently skipped measurements. Missing optional image dependencies are installation errors only when private analysis is requested with available inputs.

## Probe Parameters and Interpretation

`ReferenceProbe` accepts its existing input and output paths beneath either `reference-private/` or `artifacts/`. The optional `fontSelection` values are `symbolic-bold` and `emphasized`; the default retains the previous public system-font selection. `language` is an optional UI-font language hint. `opticalSize` accepts `auto`, `none`, or a positive numeric string through the public Core Text descriptor attribute. `weight` uses the public normalized weight trait from −1 to 1. These are experimental controls, not native Music settings.

Per-line results distinguish UTF-16 source ranges, typographic widths excluding trailing whitespace, drawing origins, baselines, ascent/descent/leading, baseline-relative glyph-path bounds, input break kinds, and resolved run metrics. Glyph-path bounds use Core Text's y-up coordinates; rendered images and reference ink bounds use top-left, y-down native pixels. All paragraphs share one Core Text typesetter. Timing units and highlighted words are never shaped independently.

Selection requires the observed line structure and minimizes equally weighted per-case mean squared ink-width error. Leave-one-case-out results retain all tied candidates and their held-out wrapping outcomes. Incorrect wrapping is reported separately; a missing held-out RMSE is not a zero error. Mask comparisons register individual lines within ±5 pixels after ink-origin alignment and report translations and boundary hits. These registrations diagnose shape differences; they do not establish a shared scene layout.
