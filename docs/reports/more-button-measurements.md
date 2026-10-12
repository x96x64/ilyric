# More Button Measurements and Verification

## Outcome and Scope

October 13, 2026. iLyrics renders the top-right More button through its existing screen component and rational-time rendering pipeline. Production rendering resolves `ellipsis` through public AppKit APIs at runtime. Publishable fixtures use a project-owned three-dot icon. No star button or functional menu is added. Interlude markers, vocal alignment, and the existing output layout are unchanged.

This report records development measurements and implementation checks. It does not establish new independent visual qualification. Completed reports and reference classifications remain unchanged.

## Sources and Reference Restrictions

Measurement used development recordings V01–V17 and N07, together with only the authorized upper title region of N08. The reference device is the reported iPhone 16 running iOS 27.0.1; its exact build remains Unknown. No device build was inferred from external information.

N01–N06, screenshots IMG_0334–IMG_0339, N08 outside its authorized title region, and N09–N10 were not opened, inspected, measured, compared, or used for tuning. The completed visual qualification report was read only for historical context. Ignore behavior was confirmed before processing. Reference crops, extracted pixels, detailed measurements, and machine-specific logs remain in ignored local storage. No protected reference content is included in this report.

## Coordinate Systems and Method

Measurements use decoded recording pixels with a top-left origin. Bounds are half-open. The inspected V17 and N07 video streams are 1180 × 2556 pixels with a nominal 60-fps rate and BT.709 color metadata. These encoded dimensions are not a new measurement of UIKit geometry. The existing renderer retains its 1179 × 2556 canvas and all existing output fitting. Core Graphics converts the measured top-left coordinates to its bottom-left coordinate system. The existing runtime symbol scale of three pixels per point is retained as a configuration assumption; the native UIKit point size was not measured.

FFmpeg 8.1.2 extracted RGB crops. Each V recording and N07 was sampled at nominal capture times 0.5, 2, 3.7, 3.9, 4.1, 8, 10, 12, and 20 seconds. N08 was sampled at 0.5, 8, 10, 12, and 20 seconds. Every N08 output was cropped directly to [312, 1178) × [338, 396); no full N08 frame was output or inspected. Wider title crops from V17 used only permitted development material.

Of 167 requested samples, 160 contained frames and all 160 showed three dots. Seven samples were unavailable because the recordings ended: V04 at 20 seconds; V05 and V06 at 12 and 20 seconds; and V07 and V08 at 20 seconds. No replacement references were used.

Within the More search region, ink was thresholded 70 encoded luminance levels above the local 20th-percentile background. Separated occupied column groups identified the three dots. Bright-interior RGB values were taken at the 90th percentile. Apparent opacity was estimated per channel as `(ink - background) / (255 - background)`. This is an encoded-value estimate, not a measurement of linear-light alpha or native material blending.

## Measurements and Observations

| Property | Finding | Evidence Classification |
| --- | --- | --- |
| Aggregate ink bounds | Left 1007; top 377–378; right 1063–1064; bottom 390 pixels | Development measurement; approximately ±1 pixel at each edge |
| Ink center | x = 1035–1035.5; y = 383.5–384 pixels | Derived from measured bounds |
| Ink dimensions | 56–57 pixels wide and 12–13 pixels high | Development measurement |
| Dot geometry | Approximately 12-pixel diameter, with approximately 22-pixel horizontal center spacing | Geometry estimate from separated ink groups |
| Bright-interior color | RGB ranges (255, 254–255, 255) in extracted encoded RGB | Development measurement; conversion and compression dependent |
| Apparent opacity | Median 1.0 in each channel; minimum channel estimate approximately 0.992 | Encoded-value estimate |
| Enclosing disc | No enclosing disc was visible in inspected crops | Observation; no native material decomposition |
| Title separation | The existing title clip ends at x = 977; measured More ink begins at x = 1007 | 30-pixel separation using the existing clip and new development measurements |
| Drawing order | The button is drawn above title and artist components | Implementation estimate; native order is not observable without intersection |

V17 title crops at rest and during scrolling show the title fading before the stationary dots. The authorized N08 title crops also show separated title and button ink. No title/button intersection was observed. The implementation therefore retains the existing title bounds, marquee displacement, delay, period, and fade mask. It does not introduce an additional title mask.

A separate 48-frame, nominal 60-fps V17 crop beginning at capture time 3.5 seconds retained identical More bounds [1007, 1063) × [378, 390) throughout. A lower pause-region check contained 8,196 pixels above encoded luminance 220 at capture times 3.5, 3.7, 3.79, and 3.85 seconds, and none at 4.1 seconds. This establishes persistence through the observable lower-control disappearance window; it does not refit the existing hide delay or transition. Capture time is not asserted to equal playback time.

## Implementation Decisions

The More component uses ink bounds (1007, 378, 56, 12), with center (1035, 384), and remains outside the lower-control transition group. It follows the existing metadata visibility mask. This mask association and foreground z-order are implementation choices, not measured native interactions.

The runtime configuration is `ellipsis`, 20 points, medium weight, opaque white, without a disc. A local public-API raster sweep over regular, medium, and semibold weights and sizes 17–23 points in half-point increments identified a matching 56 × 12-pixel medium-weight raster at 20 points. These settings fit the rendering Mac's symbol geometry; they do not identify the native iPhone's actual font configuration. The original icon uses three independently drawn circles and contains no copied Apple asset. The existing `doctor` symbol-availability check includes `ellipsis`.

No new event, wall-clock state, animation cache, or menu interaction is introduced. Explicit rational timestamps continue to determine immutable screen snapshots. Existing event ordering and half-open transition semantics are retained.

## Verification

Checks were selected before implementation: placement, title separation and drawing order, metadata masking, persistence across lower-control hiding, unchanged existing controls, and repeated and out-of-order timestamp evaluation. Three new tests cover these checks with original fixtures. The existing symbol-table test includes More. The existing marquee raster assertion now checks the empty gap before More rather than expecting the button region to remain empty.

Optimized before-and-after original-icon renders at 0, 2, and 5 seconds differ at exactly 396 pixels, all within [1007, 1063) × [378, 390). Every pixel outside that rectangle is unchanged. Additional tests compare button-enabled and button-omitted snapshots at rest, during lower-control hiding, and during title scrolling, and compare repeated and out-of-order renders with a fresh renderer. A local runtime-symbol render independently produced ink bounds [1007, 1063) × [378, 390). No symbol-derived golden image is published.

The optimized build command was:

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache" \
swift build --disable-sandbox --build-system native -c release --product LyricsScreenProbe
```

The initial default build encountered cache permissions, nested-sandbox restrictions, and a dSYM-generation failure. Repository-local caches and the local native build-system selection completed the build. The initial test command could not find `Testing`. The successful full-suite command, with the maintainer's Command Line Tools workaround and additional framework search paths, was:

```sh
DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/Library/Developer/Frameworks \
DYLD_LIBRARY_PATH=/Library/Developer/CommandLineTools/Library/Developer/usr/lib \
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache" \
swift test --disable-sandbox --build-system native --disable-xctest \
  -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing \
  -Xlinker -F/Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -L/Library/Developer/CommandLineTools/Library/Developer/usr/lib \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib
```

The final full-suite run passed all 126 tests in 27 suites in 82.352 seconds, including all three More tests. The first completed run passed the new More tests and failed one outdated marquee assertion; that assertion was corrected as described above. A sandboxed test run stalled and was stopped. Native-service access was required for the completed test and video-export runs. These environment settings are process-local and are not committed or added to GitHub Actions.

Rendering and media checks used:

```sh
.build/arm64-apple-macosx/release/LyricsScreenProbe native 2 1 artifacts/more-button/after-2.png
.build/arm64-apple-macosx/release/LyricsScreenProbe video artifacts/more-button/original-controls.mp4
python3 scripts/validate_media.py artifacts/more-button/original-controls.mp4 1080 1920 360
```

Media validation passed: 1080 × 1920, 360 decoded frames, 60/1 fps, six-second video and audio duration, all presentation timestamps, BT.709 metadata, 48-kHz mono synthetic audio, 288,000 trimmed samples, and expected audio and visual synchronization markers. All seven detected audio-marker errors were zero at the validator's 1-ms resolution. Representative decoded dot interiors remained approximately white, with channel values 251–255.

On an Apple M4 Mac with 16 GB memory, macOS 27.0.1, and Apple Swift 6.4, the optimized single-worker synthetic export took 20.48 seconds, or 17.57 fps. The process recorded a maximum resident set of approximately 450 MB and a peak memory footprint of approximately 225 MB. This is a short synthetic rendering check, not a representative production throughput benchmark or a comparative performance-regression measurement. Raw raster equality is established only within this local environment; installed fonts and symbols may differ elsewhere. `git diff --check` passed.

## Limitations

The physical touch-target dimensions, native UIKit point size and weight, exact native compositing, pressed states, menu behavior, and response to user interaction were not measured. Foreground order remains an estimate because permitted crops contain no title/button intersection. Persistence is supported by sampled development frames and the short disappearance window, rather than by exhaustive inspection of every frame or interaction. The device's exact iOS build remains Unknown. Existing title-marquee and other visual uncertainties remain as recorded in completed reports. No new independent qualification is claimed.
