# iLyric Inactive-Appearance Commands

## Experimental Rendering

```sh
swift build -c release
mkdir -p artifacts/inactive-example
.build/release/LyricsScreenProbe timeline
.build/release/LyricsScreenProbe native-inactive 61 20 artifacts/inactive-example/native.png
.build/release/LyricsScreenProbe still-inactive 61 20 artifacts/inactive-example/delivery.png
.build/release/LyricsScreenProbe video-inactive artifacts/inactive-example/lyrics.mp4
```

Use new output filenames. The suffix enables the qualified Latin-only inactive treatment; existing `native`, `still`, and `video` commands retain the archived fixture. Both paths keep the same geometry, focus events, optional-control changes, and audiovisual diagnostic flashes. The stationary tail and abrupt optional-control changes are authored fixture behavior. These commands are experimental developer tools, not a stable public CLI.

The treatment caches isolated Latin paragraph tiles, applies bounded blur and contrast, and evaluates a 0.15-second smooth transition from explicit focus events. Outgoing symmetry and interrupted-transition continuity are synthetic contracts. Japanese appearance remains unchanged. See the [report](inactive-appearance.md) for measurement limitations.

## Public Verification

```sh
./scripts/test.sh
python3 -m unittest discover -s Tests/reference_validation -v
python3 scripts/reference_validation/check_inactive.py artifacts/inactive-example/lyrics.mp4
python3 scripts/validate_media.py artifacts/inactive-example/lyrics.mp4 1080 1920 360
```

The optional video audit requires FFmpeg and NumPy; without a video argument, the check uses the Python standard library and release probe. It verifies all 360 presentation states and separate-process PNG equality. The decoded audit checks localized control-region changes rather than whole-screen similarity. Two encoded levels are a diagnostic change detector, not a native fidelity requirement. Existing probe, typography, appearance, motion, screen, and export checks remain applicable.

## Private Calibration

```sh
python3 scripts/reference_validation/inactive_validation.py
```

NumPy, Pillow, FFmpeg, the original V01–V03 inventory, and the established Latin outline workflow outputs are required. Missing principal inputs return JSON `status: unavailable`; integrity failures remain errors. The command verifies original hashes and presentation timestamps and reproduces the color-managed native crops before fitting. It uses archived common translation without local realignment. Derived rasters and observations remain under ignored `reference-private/analysis/inactive/`.

The shared V01 sharp template is an inherited diagnostic reference, not an independently held-out glyph template. Only appearance parameter selection is held out. Results use nonlinear sRGB contrast proxies after explicit full-range Rec.709 interpretation, not measured opacity or physical luminance. Public numerical evidence is reviewed separately; the command does not publish private files automatically.
