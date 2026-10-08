# iLyric Latin Typography Integration Commands

## Experimental Rendering

```sh
swift build -c release
.build/release/LyricsSliceProbe synthetic-latin 7 3 artifacts/latin-example
```

The command renders an original static Latin paragraph at the specified rational timestamp. It remains an internal experiment, not a stable public CLI. `synthetic` and `synthetic-soft` preserve the Japanese fixtures; `ilyric` is unchanged.

Explicit internal inputs may set `paragraphStyle` to `latinStatic`. This style accepts one to four rendered lines, explicit newlines or automatic wrapping, empty appearance events, zero vertical amplitude, and no progressive-appearance configuration. Whole-paragraph Core Text shaping precedes line rasterization. Source ranges and `breakKind` distinguish `observed-explicit`, `automatic`, and `end`. Observed newlines do not establish native source-authored structure.

The synthetic profile uses fitted size 104.25, the retained width prior 987, and rounded origin/advance values (96, 687) and 125.5. Static opacity uses the existing `dimOpacity` field, set to one by default. Japanese timing parameters are not transferred. Full-precision private fits are evaluated separately. The input representation is not a finalized project schema.

## Public Verification

```sh
./scripts/test.sh
python3 -m unittest discover -s Tests/reference_validation -v
python3 scripts/reference_validation/check_probe.py
python3 scripts/reference_validation/check_typography.py
python3 scripts/reference_validation/check_outline.py
python3 scripts/reference_validation/check_slice.py
python3 scripts/reference_validation/check_appearance.py
python3 scripts/reference_validation/check_latin.py
```

The final four checks require NumPy and Pillow. Run the slice check before the appearance check. The Latin check independently renders original single-line, explicit-break, automatic-wrap, punctuation, kerning-sensitive, ligature-capable, and combining-character fixtures. It compares source ranges and complete alpha rasters against the unchanged whole-paragraph `ReferenceProbe`, then checks repeated and reordered timestamps. Its integer-advance fixture isolates shaping equality from the inherited integer placement convention.

## Private Calibration and Integration

```sh
python3 scripts/reference_validation/latin_validation.py
python3 scripts/reference_validation/latin_integration.py
```

These commands require the existing private S02, S03, S04B, and S05 cases. S04B denotes the observed-break comparison of screenshot S04. The first command verifies screenshot availability, geometry, and ICC profiles, establishes or checks a private SHA-256 inventory, reproduces archived comparisons, and evaluates size/width/structure variants and exclusions. New comparisons convert Display P3 to sRGB; historical reproduction retains the original encoded-channel method.

The integration command checks the stable calibration selection and source hashes, fits a shared paragraph origin/advance, renders the complete set and each held-out case, and emits common-origin scores and diagnostic registration separately. Detailed inputs, renderings, and results remain under ignored `reference-private/analysis/latin/`. Neither command publishes protected content. Missing principal inputs return explicit `unavailable` results before image dependencies are imported. Damaged or inconsistent supplied data remain errors.

See the [Latin integration report](latin-typography-integration.md) for the conditional scope, source-structure ambiguity, evidence classifications, and measurements.
