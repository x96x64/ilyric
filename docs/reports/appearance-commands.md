# iLyric Progressive Appearance Commands

## Experimental Rendering

Build all release targets, then render the original synthetic fixture with the optional softened appearance:

```sh
swift build -c release
.build/release/LyricsSliceProbe synthetic-soft 7 4 artifacts/appearance-example
```

`synthetic` retains the prior hard-wipe behavior. Both invocations retain the same typography, explicit break, cluster mapping, native canvas, and vertical treatment. `ilyric` is unchanged. Output remains transparent sRGB appearance/coverage PNGs and state JSON; composite appearance over a neutral background for inspection.

Explicit experimental JSON inputs may add `appearance` with `intervalScale`, `phaseOffset`, `softness`, and `completedOpacity`. Omission preserves the old behavior. The synthetic example uses 3, 0, 1, and 0.981, with dim opacity 0.438. These are provisional reconstruction choices. Source intervals remain explicit rational inputs; they are not inferred native lyric timestamps. A missing event stays upcoming.

The softened fraction is `smoothstep(clamp(0.5 + ((phase - phaseOffset) / intervalScale + 0.5 - position) / softness))`. `phase` is elapsed time relative to the supplied interval midpoint, divided by its duration. `position` is measured across the already-shaped source range. The cubic smoothstep is `v²(3 − 2v)`. Appearance multiplies cached glyph support without changing its layout or vertical placement.

## Public Verification

```sh
./scripts/test.sh
python3 -m unittest discover -s Tests/reference_validation -v
python3 scripts/reference_validation/check_probe.py
python3 scripts/reference_validation/check_typography.py
python3 scripts/reference_validation/check_outline.py
python3 scripts/reference_validation/check_slice.py
python3 scripts/reference_validation/check_appearance.py
```

The last three commands require NumPy and Pillow. Run `check_slice.py` before `check_appearance.py`; the latter reuses its original synthetic input. It checks fitting on synthetic observations, temporal holdouts, unavailable support, Swift/Python raster agreement, and repeatability. Swift tests additionally cover raw raster equality in random timestamp order and unchanged coverage under the new appearance model.

## Private Calibration

```sh
python3 scripts/reference_validation/slice_validation.py
python3 scripts/reference_validation/appearance_validation.py
```

The first command reproduces the historical geometry/appearance baseline. The second checks original source hashes, uses existing actual-PTS extractions and private event annotations, compares three appearance models in both recording directions, evaluates sensitivity, and checks the selected candidate in the actual Swift raster backend. Missing principal inputs return explicit `unavailable` output before optional numerical dependencies are imported. Inconsistent or damaged diagnostics remain errors.

All detailed inputs, renderings, measurements, and comparisons remain under ignored `reference-private/analysis/appearance/`. This command does not publish them. Only reviewed, sanitized numerical records may be copied into versioned evidence. The [appearance-calibration report](progressive-appearance.md) defines the color interpretation, measurements, holdouts, and limitations.
