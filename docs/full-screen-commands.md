# Full-Screen Lyrics Experiment Commands

## Rendering the Synthetic Scene

Run from the repository root. Use new output files under ignored `artifacts/`.

```sh
swift build -c release
mkdir -p artifacts/screen-example
.build/release/LyricsScreenProbe native 3 2 artifacts/screen-example/native.png
.build/release/LyricsScreenProbe still 13 12 artifacts/screen-example/delivery.png
/usr/bin/time -l .build/release/LyricsScreenProbe video artifacts/screen-example/lyrics.mp4
```

`native` renders the 1179×2556 synthetic fixture without a delivery transform. `still` renders 1080×1920 using uniform `contain`. Numerator and denominator supply an explicit rational timestamp. `video` exports six seconds at exactly 60 fps with synthetic audio. This is an experimental developer target, not a stable public command or input schema. Existing `ilyric` and slice/composition invocations remain unchanged.

The fixture uses original artwork, metadata, and lyrics, measured component positions, inherited experimental typography and motion, a provisional fade, and a static original background. Optional-control events exercise visibility only; they do not reproduce Sing behavior. A diagnostic audiovisual flash is separate from native UI content.

## Public Verification

```sh
./scripts/test.sh
python3 -m unittest discover -s Tests/reference_validation -v
python3 scripts/reference_validation/check_screen.py
python3 scripts/validate_media.py artifacts/screen-example/lyrics.mp4 1080 1920 360
```

Run the existing probe, typography, outline, slice, appearance, Latin, motion, and Latin-outline checks as documented in their command files. Some existing checks require NumPy and Pillow. The screen check itself verifies separate-process PNG equality and component bounds using only the standard Python library and the release probe.

## Private Placement Comparison

```sh
python3 scripts/reference_validation/screen_validation.py
```

The optional private command requires the existing screenshot inventory, NumPy, Pillow, and the release probe. It verifies ignore policy, source hashes, and capture dimensions; interprets embedded color profiles; compares component layout to archived measurements; and writes source-bearing overlays only under ignored `reference-private/analysis/full-screen/`. Missing principal inputs return JSON `status: unavailable` before importing numerical dependencies. Integrity failures remain explicit errors.

Slider masks that touch their extraction window are unreliable. The command does not infer layout changes from contaminated support or equate a zero constraint error with native fidelity. Public v11 evidence is reviewed separately; the command does not publish private output automatically.
