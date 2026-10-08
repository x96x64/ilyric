# Latin Outline Diagnostic Commands

These developer diagnostics are experimental and do not change the `ilyric` CLI. Run from the repository root. Existing [composition commands](motion-composition-commands.md) remain valid.

## Public Checks

```sh
swift build -c release
./scripts/test.sh
python3 -m unittest discover -s Tests/reference_validation -v
python3 scripts/reference_validation/check_latin_outline.py
```

The standalone outline check requires NumPy and Pillow in the selected Python environment. It uses independently generated geometric masks. The standard unittest suite remains independent of these optional numerical dependencies and the private corpus. Existing probe, typography, outline, slice, appearance, Latin, and motion checks should also be run.

## Private Reproduction

```sh
python3 scripts/reference_validation/motion_composition.py
python3 scripts/reference_validation/latin_outline.py
```

Use the established ignored private inventory and archived motion outputs. The outline command verifies original hashes, complete source PTS lists, and the reproduced archived fit before decoding. It requires FFmpeg, NumPy, and Pillow. Missing private inventory or recordings return JSON with `status: unavailable`; integrity mismatches fail explicitly.

The command writes numerical results, observations, controls, and native RGB working crops under ignored `reference-private/analysis/latin-outline/`. These working crops total approximately 1.3 GiB. Originals are neither overwritten nor transcoded in place. The private results contain reference-derived measurements; do not publish media or working crops. The committed v10 records are reviewed sanitized numerical evidence.
