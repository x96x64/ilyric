# iLyric Experimental Lyrics Slice Commands

## Scope

`LyricsSliceProbe` is a developer experiment, not a stable public CLI. The `ilyric` command and synthetic architecture-spike fixture are unchanged. Run commands from the repository root. The experiment requires macOS and the existing Swift toolchain.

## Synthetic Rendering

```sh
swift build -c release
.build/release/LyricsSliceProbe synthetic 0 1 artifacts/slice-early
.build/release/LyricsSliceProbe synthetic 3 1 artifacts/slice-middle
.build/release/LyricsSliceProbe synthetic 5 1 artifacts/slice-late
```

The integers specify an exact rational timestamp. Each directory receives `appearance.png`, `coverage.png`, and `state.json`. PNGs are transparent sRGB, 1179×2556 pixels. Composite them over a neutral background for visual inspection; viewers that discard alpha may display dim text as white. `coverage.png` deliberately excludes appearance opacity and clipping, preserving the evaluated vertical treatment.

The original two-line Japanese fixture and timing are independently generated. Its explicit separator exercises observed-break handling; it is not a transcription of Music lyrics. The default size, origin, line advance, amplitude, and time constant are experimental reconstruction choices documented in the report. The synthetic timing and dim opacity are not measurements of native behavior.

## Explicit Experimental Inputs

```sh
.build/release/LyricsSliceProbe artifacts/experiment.json 7 4 artifacts/experiment-frame
```

The internal JSON input is intentionally narrow and version-unstable. `SliceInput` in `LyricsSliceCore` defines its fields: text, capture width, break-evidence label, numeric reconstruction parameters, and ordered nonoverlapping UTF-16 appearance ranges. Every non-newline source unit must be covered. Appearance begin/end and vertical-event timestamps are independent rational inputs; absent events stay upcoming. Invalid intervals, automatic wrapping beyond the observed two lines, split shaped clusters, and cross-line ranges are rejected.

Capture width must be 1179 for screenshot-space output or 1180 for recording-space output; height is always 2556. Layout coordinates do not change with capture width. No output transform, safe-area model, or UIKit point conversion is implied.

Private inputs and outputs must remain together under ignored `reference-private/`; public synthetic experiments remain under ignored `artifacts/`. Symlink-resolved path checks prevent moving private input results into the public-artifact directory. Reference annotations are never embedded in renderer code.

## Verification

```sh
./scripts/test.sh
python3 -m unittest discover -s Tests/reference_validation -v
python3 scripts/reference_validation/check_probe.py
python3 scripts/reference_validation/check_typography.py
python3 scripts/reference_validation/check_outline.py
python3 scripts/reference_validation/check_slice.py
```

The last two checks require NumPy and Pillow. `check_slice.py` verifies that recomposed shaped glyph masks equal the unchanged whole-paragraph `ReferenceProbe` raster, that appearance does not alter base coverage, and that repeated separate processes produce identical output. Swift tests additionally compare raw raster bytes and immutable state in different timestamp orders and fresh renderer instances.

The unchanged export regression remains:

```sh
.build/release/ilyric determinism
.build/release/ilyric video artifacts/slice-spike-regression.mp4
python3 scripts/validate_media.py artifacts/slice-spike-regression.mp4
```

Graphics access must be available to the process; the current sandbox can prevent Core Image initialization. Do not interpret that environmental failure as a reason to alter the unchanged renderer.

## Private Comparison

```sh
python3 scripts/reference_validation/slice_validation.py
```

This command requires the existing S09 protocol, known text, V09/V10 originals, and completed S09 and glyph-outline diagnostics. Missing principal inputs produce explicit `unavailable` output. A damaged or inconsistent private diagnostic set is an error. The command verifies source hashes, uses the prior actual-PTS state annotations, freezes each v5 training fit, and evaluates the opposite recording without geometric retuning.

Native capture comparisons and all generated inputs, images, masks, and detailed results remain under `reference-private/analysis/lyrics-slice/`. The command does not publish results. Sanitized numerical publication requires a separate review. See the [measured-slice report](lyrics-slice.md) for evidence, error definitions, and limitations.
