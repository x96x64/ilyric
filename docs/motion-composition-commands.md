# iLyric Motion and Composition Commands

## Experimental Output

Run from the repository root. Outputs must be new files in an existing directory under ignored `artifacts/`.

```sh
swift build -c release
mkdir -p artifacts/composition-example
.build/release/LyricsCompositionProbe still 13 12 artifacts/composition-example/moving.png
.build/release/LyricsCompositionProbe video artifacts/composition-example/lyrics.mp4
```

The still uses an explicit rational timestamp. The video contains the fixed six-second original fixture at 1080×1920 and exactly 60 fps, with synthetic audio. Both use uniform `contain` from a 1179×2556 native-coordinate composition. This invocation is an internal experiment, not a stable CLI or public project schema. It does not load commercial text, media, or an external project file. `ilyric` and all previous slice invocations remain available unchanged.

The fixture has three paragraphs, two focus transitions, static Latin appearance, and the existing Japanese softened appearance. Focus timing, clipping, paragraph spacing, inactive opacity, and background are synthetic. The critical-response time constant is a qualified fitted reconstruction parameter. No native Music fidelity is implied.

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
python3 scripts/reference_validation/check_motion.py
python3 scripts/validate_media.py artifacts/composition-example/lyrics.mp4 1080 1920 360
```

The outline, slice, appearance, Latin, and motion integration checks require NumPy and Pillow where used. Run the slice check before the appearance check. Unit tests use redistributable synthetic inputs. `check_motion.py` verifies synthetic fitting, Swift/Python analytic agreement, repeated PNG equality, and animated output differences. The media check validates decoded timestamps, duration, color declarations, audio trimming, and shared diagnostic audiovisual markers. Codec metrics remain separate from native-reference fidelity.

## Private Motion Comparison

```sh
python3 scripts/reference_validation/motion_composition.py
python3 scripts/reference_validation/latin_validation.py
python3 scripts/reference_validation/latin_integration.py
```

The motion command requires the preserved private V01–V03 manifest, original recordings, archived frame lists, and archived motion-fit results under `reference-private/analysis/`. It verifies ignore policy, establishes or checks a local SHA-256 inventory, decodes originals without changing them, reproduces the archived trajectory and fits, measures anchor sensitivity, and evaluates reverse-recording holdouts. Actual PTS use the verified 1/600-second time base. Source mappings, hashes, decoded derivatives, and detailed outputs remain private.

Without principal private inputs, commands return explicit JSON `unavailable` states before loading optional image dependencies. Inconsistent supplied evidence, unsafe paths, or failed integrity checks remain errors. The motion script is specific to the inspected transition, not automatic event discovery. Public numerical records require separate review; the script does not publish them.

See [Motion and Composition Slice](motion-composition.md) for measured limitations and synthetic semantics.
