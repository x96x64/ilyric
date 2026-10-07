# iLyric Glyph-Outline Validation Commands

## Public Checks

On macOS with the existing Swift toolchain:

```sh
swift build -c release --product ReferenceProbe
./scripts/test.sh
python3 -m unittest discover -s Tests/reference_validation -v
python3 scripts/reference_validation/check_probe.py
python3 scripts/reference_validation/check_typography.py
```

The additional synthetic support check requires Python with NumPy and Pillow:

```sh
python3 scripts/reference_validation/check_outline.py
```

These checks require no private captures, commercial text, subscription, or network access. The Python unit suite uses only the standard library. The numerical analysis runtime and versions are recorded in the report; exact floating-point coefficient equality is only an invariant within that runtime.

## Private Experiment

The existing private S09 protocol, known paragraph, original V09/V10 recordings, and prior S09 diagnostics are prerequisites. If those diagnostics are absent, reproduce them using [S09 Typography Validation Commands](s09-typography-commands.md). The new command explicitly reports `unavailable` when its principal private prerequisites are absent:

```sh
python3 scripts/reference_validation/glyph_outline.py
```

This command uses NumPy, Pillow, FFmpeg, FFprobe, and the release `ReferenceProbe`. It verifies the original SHA-256 values against the previous private inventory, decodes original PTS, and writes only below ignored `reference-private/analysis/glyph-outline/current/`. Source media are never overwritten. A partially damaged prior diagnostic set is an error requiring repair, not an absent-corpus result.

The experiment verifies pixel equality of six new extractions against the prior color-managed frames and exactly reproduces their historical common-origin comparisons. It analyzes 208 frames per recording for observed brightness crossings and ten inspected phases per recording for outline fits. Output includes phase PTS, crossing brackets, normalized-support measurements, common-origin predictions, reverse holdouts, edge residuals, appearance-only controls, and sensitivity variants.

The protocol is deliberately specific to the inspected S09 paragraph. Spatial windows are observation regions over an already shaped paragraph, not a parser, glyph-timing schema, or general segmentation system. Incomplete or ambiguous contour support is reported separately. No source transcription, mask, image, or private path is exported publicly by this command. Numerical publication requires a separate allowlist and staged-content review.

## Interpretation

`fixed` holds geometry fixed while normalization removes local background and column-wise contrast. `appearance` is an additional instantaneous-brightness-linked displacement proxy. `vertical` fits a shared bounded response to the elapsed time since an observed brightness crossing. The latter does not predict crossing times or identify native timing semantics. A missing crossing remains explicitly absent and receives the upcoming-state limit.

Each training recording supplies one origin correction, one line-advance correction, one amplitude, and one response time constant. Held-out geometry is not refitted. The mask score rounds predicted shifts to integer pixels; displacement RMSE compares continuous predictions with integer diagnostic registrations. No held-out glyph receives its independently registered displacement as a model parameter.

The [engineering report](glyph-outline-validation.md) and [v5 evidence](reference-data/v5/glyph-outline.json) define the measured scope and remaining limitations. Earlier reports and data remain unchanged.
