# Opening Interlude Marker Correction

## Outcome and Scope

October 13, 2026. An original synthetic introduction reproduced the opening interlude marker compositing over the first lyric through the normal `ilyrics render` command. The correction establishes the opening slot at the initial focus position and ends the opening marker's presentation ownership when the first lyric takes focus. Existing rational timestamps and focus events determine both behaviors.

The completed More button, backing-vocal alignment, output fitting, typography, and non-opening gap behavior are unchanged. Completed reports are preserved. This work is development verification, not independent visual qualification.

## Reproduction and Preserved Evidence

The pre-change executable rendered an independently generated 12-second, 48-kHz, mono, 16-bit WAV containing a 220-Hz tone with peak amplitude 2,000 sample units. This is synthetic instrumental media, not a vocal synchronization reference. The original synthetic fixture supplies two lyric paragraphs in LRC format, with onsets at 6.00 and 9.00 seconds following a six-second opening gap.

The executable was built with the previously successful local command:

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache" \
swift build --disable-sandbox --build-system native -c release --product ilyrics
```

The normal rendering command used the existing default gap, focus, control, and runtime symbol settings:

```sh
.build/arm64-apple-macosx/release/ilyrics render \
  artifacts/opening-gap/original-introduction.wav \
  artifacts/opening-gap/original-introduction.lrc \
  -o artifacts/opening-gap/before.mp4 \
  --title 'Original Introduction' --artist 'Synthetic Fixture' \
  --background static --jobs 2 \
  --report artifacts/opening-gap/before-export.json
```

At 5.6 seconds, all three dots visibly composited over the beginning of the first lyric. An additional 0.1-second crop showed the opening layout beginning compressed. At three seconds the marker and following dim lyric were separated. These observations were preserved before production code changed, together with the original inputs, full video, export metrics, and logs in ignored local artifacts. No commercial recording, proprietary reference text, or private capture was required to reproduce the defect.

The initial regression run against unchanged production code failed with 15 issues: eight opening-position issues and seven handoff-state or raster issues. Its random-access and control-isolation test passed. The failure evidence remains locally preserved.

## Verification Criteria

Before implementation, verification required an established opening slot, separation of marker and first-lyric ink during the introduction and handoff, correct visibility at exact transition boundaries, repeated and out-of-order snapshot and raster equality, and unchanged existing controls including More. No new pixel mask, viewport boundary, or arbitrary displacement was permitted as a correction.

## Root Cause and Correction

The supplied opening media gap occupies [0, 6) seconds. The existing 0.9-second focus lead moves focus to the first lyric at 5.1 seconds, while the lyric becomes active at six seconds. These are fixture-derived rational timestamps, not measurements of native Music behavior.

Three existing mechanisms disagreed at the opening. The first hold event initialized scrolling at the first paragraph's reserved position, although a later ordered event at the same timestamp gave focus to the opening gap. Gap openness also began at zero, moving the first paragraph through an introduction slot that should already exist. Finally, the marker remained eligible for its entire supplied media interval after focus had moved to the first lyric. The closing slot's anchor compensation kept the marker near the focused row while the lyric moved into that row. The renderer subsequently drew the marker after the paragraphs, producing the observed mixture.

The correction in `LyricsComposition` resolves an opening gap's initial target from the effective ordered event at time zero and starts that existing slot fully open. Its subsequent closing motion retains the existing critically damped mechanism. Opening-marker state intersects the supplied media interval with current gap focus ownership; it becomes absent at the first-lyric focus event. The six-second supplied gap, lyric onsets, focus lead, dot fill values before departure, pulse, and appearance parameters are retained.

For this fixture, the marker center remains at native y = 760 during the introduction, and the first paragraph's existing baseline anchor is 791.25 + 226 = 1017.25 pixels. Before correction, the time-zero marker center was 534 and the first baseline was 565.25. These are deterministic renderer values using existing constants. No new native geometry is inferred from them.

The presentation handoff is half-open: the marker remains eligible one microsecond before 5.1 seconds and is absent exactly at 5.1 seconds. The initial fade still begins at zero visibility. No wall-clock state, previous-frame dependence, new event, clipping change, or compositing mask is introduced. The correction is restricted to gaps beginning at media time zero; later gaps retain their existing behavior.

## Permitted Reference Evidence and Uncertainty

Only development recording V12 was inspected for native lyric-region evidence. Inspected crops at capture times 1, 16, 24, 26, 26.5, and 28 seconds showed a mid-song instrumental marker, a separated following dim paragraph, and its subsequent focused appearance without dots. This is an observation about an internal gap, not a measurement of a song-opening introduction.

At 24 seconds, bright-dot thresholding in a fixed search region produced aggregate half-open ink bounds [87, 261) × [741, 781), centered vertically at 761 native recording pixels. The threshold was the region's 20th-percentile average encoded RGB level plus 70. This corroborates the existing focused-row estimate without refitting it. Dots were visible at 24 seconds and absent in the 26-second crop; these coarse samples do not establish the precise native handoff or fade duration.

Coordinates above use a top-left origin in decoded recording pixels. Renderer coordinates retain the existing 1179 × 2556 canvas; Core Graphics converts to its bottom-left drawing origin, and exported pixels use the existing 1080 × 1920 fitting. No layout preset or aspect-ratio change was made.

The reference device remains the reported iPhone 16 running iOS 27.0.1, exact build Unknown. Native opening-slot initialization and its precise marker departure were not directly measured. Starting with an established slot and relinquishing marker ownership at first-lyric focus are disclosed implementation decisions supported by the synthetic defect and permitted internal-gap observations. No independently measured native opening fade is claimed.

N01–N06, IMG_0334–IMG_0339, N08 outside its authorized title region, and N09–N10 remained unused. N08 was not opened at all. The completed visual qualification report was read solely for historical context. Reference classifications were not changed. Private crops and measurements remain in ignored private storage; this report contains no protected reference text, images, or private paths.

## Tests and Export Results

Three original-fixture regression tests cover opening geometry, marker-free first-lyric compositing, exact boundaries, unchanged supplied fill state, repeated and out-of-order evaluation, fresh-renderer equality, and control isolation. The tests reside in an extension of `AudioSceneTests` so the existing CI filter includes them. Public test fixtures use the original icon set; the normal local command retains runtime symbols. CI and environment configuration files were not modified.

The full Swift command was:

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

The final full-suite run passed all 129 tests in 27 suites in 67.305 seconds, including the three new tests in the existing CI-covered suite. The focused post-fix regression also passed all three tests. These Command Line Tools settings are process-local and are not committed.

The corrected production command repeated the reproduction with `after.mp4` and `after-export.json` output names. The 5.6-second crop shows the first lyric without dots. Both videos passed local FFmpeg/FFprobe checks: 1080 × 1920, 720 decoded frames, 60/1 fps, 12-second video and audio duration, every presentation timestamp, and 576,000 trimmed mono audio samples. Decoded audio was identical before and after; its correlation with the supplied tone was 0.9999885 outside the endpoint windows. A periodic tone does not independently establish absolute acoustic delay, so no vocal synchronization accuracy is claimed.

Header pixels including More and the visible lower-control region are identical in the original-fixture gap-enabled and gap-disabled comparisons. Existing More, gap, timeline, layout, and input checks passed in the full run. Raster equality is limited to the local environment and is not asserted across installed font or symbol versions.

On the maintainer's Apple M4 Mac with 16 GB memory, macOS 27.0.1, and Apple Swift 6.4, the optimized two-worker exports took 11.04 seconds before and 11.92 seconds after correction. Maximum resident sets were approximately 420 and 421 MB; peak memory footprints were approximately 495 and 499 MB. These are short synthetic checks with different concurrent test workloads, not a controlled throughput-regression benchmark. `git diff --check` passed.

## Publication Status

After staged-diff review, code and tests were committed as `4d0f1b9` — `fix(render): separate opening interlude markers from lyrics` — with the required Codex co-author trailer. The explicitly permitted early normal push to `origin/main` succeeded. [GitHub Actions run 38322924618](https://github.com/x96x64/ilyrics/actions/runs/38322924618) passed both Swift and Python jobs; its logs confirm that all three opening-gap regressions passed within `AudioSceneTests`.

This report remains an uncommitted draft requiring explicit maintainer approval. The final documentation commit, normal push, and resulting CI verification will follow that approval. No tag, release, package publication, force push, or history rewrite was performed.
