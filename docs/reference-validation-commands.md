# iLyric Reference-Validation Commands

These commands operate the internal validation experiment. They do not define a production CLI, project schema, installation procedure, or fidelity guarantee. The `ilyric` executable and architecture-spike commands remain unchanged.

## Public Checks

Run from the repository root on macOS with the Swift toolchain used by the spike:

```sh
./scripts/test.sh
python3 -m unittest discover -s Tests/reference_validation -v
swift build -c release --product ReferenceProbe
python3 scripts/reference_validation/check_probe.py
```

The Python tests and probe checks use only the standard library and independent synthetic text. The probe check compares Swift/Python fitted positions and repeated PNG bytes at arbitrary rational timestamps. Its files remain under ignored `artifacts/`.

## Private Inputs and Outputs

Before placing captures in the repository, confirm ignore behavior:

```sh
git check-ignore -v reference-private/screenshots/example.PNG reference-private/analysis/result.json
git ls-files reference-private
```

The second command must return no tracked paths. Originals belong under `reference-private/screenshots/` and `reference-private/recordings/`. Preserve their bytes, original timing, and ICC/stream metadata. Do not add the directory to Git or Git LFS.

The analysis command requires NumPy, Pillow, and locally available `ffmpeg`/`ffprobe` when private inputs exist. It performs no dependency installation or network access. Select a Python environment containing those packages, then run:

```sh
python3 scripts/reference_validation/analyze.py
```

For metadata inspection alone:

```sh
python3 scripts/reference_validation/analyze.py --metadata-only
```

Without private screenshots or recordings, the command prints an explicit JSON `unavailable` result and exits successfully before loading optional image dependencies. Missing known-text cases or a missing release probe produce a separate unavailable typography status. Invalid timing, unsafe paths, tracked private inputs, failed decoding, and other analysis errors remain failures rather than being silently skipped.

This is a corpus-specific study tool. S01–S10 and V01–V04 are assigned by filename order. The motion window, initial text anchor, inspected repeated-capture IDs, known control-visibility states, and regions of interest correspond to this report's corpus. Inspect new media and revise a separate study protocol before applying these selections elsewhere. The command does not discover arbitrary lyric states or certify a replacement corpus.

All outputs, including unfiltered metadata and filenames, are written only beneath `reference-private/analysis/`. The command checks Git ignore policy and rejects input paths escaping the private root. It does not publish results or generate public documentation. Public numerical data requires a separate reviewed allowlist; copying entire private JSON output is unsafe because some files contain source paths or text.

## Known-Text Cases

Private `reference-private/cases.json` maps alphanumeric case IDs to manually supplied text, a screenshot basename, a native-pixel region, and optional alignment. For example, an independently generated screenshot could use:

```json
{
  "SyntheticExample": {
    "file": "example.PNG",
    "text": "An original line\nAnother original line",
    "roi": [85, 690, 1095, 1080],
    "alignment": "left"
  }
}
```

Actual reference transcriptions remain private. Preserve an observed explicit break as a separate case from an unbroken transcription; a failed automatic wrap must remain visible in the record. Do not use an explicit break to claim that a native wrapping algorithm has been identified.

## Arbitrary-Time Reconstruction

`ReferenceProbe` is an internal Swift target. It accepts a private JSON input and an explicit output directory:

```sh
.build/release/ReferenceProbe reference-private/probe-input.json reference-private/analysis/probe
```

The probe also confines inputs and outputs to the same ignored directory: either `reference-private/` or `artifacts/`. Run it from the repository root.

Inputs include `text`, `width`, `size`, `lineAdvance`, `font` (`spike` or `system-bold`), and optional `alignment`. The spike branch exercises the unchanged `TextLayout`, including its original line advance; the candidate branch uses the requested advance. Both operate on complete paragraphs.

Optional `numerator`, `denominator`, and `motion` fields evaluate a fitted position at an exact rational timestamp. A motion record contains `model`, `onset`, `duration`, `offset`, and `amplitude`; supported diagnostic candidates are `hermite` and `critical`. `anchorOffset` registers the rendered paragraph to the measured anchor. These values are reconstruction parameters, never an assertion about Apple's implementation.

Outputs are `text.png`, `metrics.json`, and, when motion is supplied, `scene.png`. The latter uses an explicit 1179×2556 native-space canvas with x=96 as the fitted layout origin. Changing the timestamp never requires a previous frame. Supplied text determines whether these outputs are copyright-bearing; reference diagnostics must stay private regardless of file format.

## Numerical Records and Reproduction Limits

The versioned profile, sanitized result tables, and trajectory CSV are under `docs/reference-data/v1/`. CSV timestamps are original integer ticks at 1/600 second. The motion fit uses alternating training and holdout observations, a documented deterministic grid, and least-squares amplitude/offset. Cross-capture validation registers only the half-crossing phase and reports that registration explicitly.

Local masks compare known text after bounded registration; they do not measure font identity, true alpha, or calibrated luminance. Fourfold motion-region reduction limits transient precision. The material strip and contrast groups are deliberately simple diagnostics, not a reconstruction of the native material or highlighting pipeline.

The macOS font resolution, renderer raster output, capture decoder, and color handling are environment-sensitive. Report versions when rerunning. Do not promote these measurements, diagnostic bands, or the historical synthetic codec tolerances into final native-fidelity acceptance criteria.
