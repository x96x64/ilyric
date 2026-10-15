# Changelog

All notable changes to iLyrics are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/). Version targets stated in dated entries record the plans at the time of release; they do not establish the current support policy or a commitment to a later release.

## [Unreleased]

## [1.3.0] - Unreleased

Experimental Japanese synchronization and display, together with corrections to focus transitions, progressive fill, and the visibility of tall paragraphs. English remains the default alignment language; Japanese support has not undergone quantitative qualification, and other languages remain unsupported.

### Added

- Experimental synchronization of Japanese plain lyrics with `--language ja` in `render` and `align`. Kanji and kana known to the [ReazonSpeech](https://huggingface.co/reazon-research/japanese-wav2vec2-large-rs35kh) wav2vec 2.0 model receive character-level timing. Words containing characters outside its vocabulary use readings from the macOS tokenizer, and Latin words within Japanese lines receive estimated timing from neighbouring aligned units rather than direct recognition. The Japanese alignment report records `language` and the readings used.
- A Japanese recognition model installed on the first alignment of Japanese plain lyrics: approximately 1.3 GB of additional downloads and 1.2 GB of installed files. Existing English and separation models remain valid. Rendering supplied TTML, LRC, or Enhanced LRC timing does not require this model.
- Guides to the accepted input formats, alignment review and correction, and a reproducible rendering example using original fixtures and generated tones.

### Changed

- Japanese alignment accepts complete forced proposals even when they do not satisfy the acceptance checks used for English. Acceptance does not establish timing accuracy. A warning identifies the experimental status and known timing limitations; the [evaluation report](docs/reports/japanese-alignment.md) records the limited review evidence. Japanese typography, wrapping, and fill have not been compared with the native iPhone screen. This policy applies to Japanese alignment only.
- Documentation distinguishes current support from historical plans and clarifies input syntax, model installation, and the experimental status of backing choruses.

### Fixed

- For closely spaced lyric lines, the advance of focus before a line's onset is limited to half the interval between consecutive onsets, reducing premature focus transitions. This changes presentation timing rather than the underlying alignment.
- Lyrics with only line-level timing, including LRC and TTML paragraphs without timed word spans, receive progressive fill across the line instead of becoming fully white at once. This supplies a visual progression, not measured word timing.
- Tall paragraphs move upward as the fill progresses through their lower rows, keeping the filling row above the lower viewport fade, including while the controls are visible.
- Fill intervals are shortened when their end would extend beyond the next focus transition. Each interval retains a minimum duration of 1 ms; the adjustment changes displayed fill timing rather than the imported or aligned source timestamps.

## [1.2.0] - 2026-10-15

An option for Instagram Reels, together with fixes identified during a review of robustness, input handling, rendering, and distribution across the release. At the time of this release, Japanese and other languages were planned for 1.3.0.

### Added

- `render --safe-area reels` places the header, lyrics, and lower controls within an inset of 51 video pixels from each side, while the background fills the frame. The inset addresses the horizontal crop measured in one Instagram Reels screenshot on one iPhone; it does not account for interface overlays or establish the crop on other devices ([report](docs/reports/instagram-reels-safe-area.md)).
- `ilyrics doctor` begins with the installed version, the executable's location, and the command that updates it for the channel that installed it.
- Updating and Uninstalling sections in the README for Homebrew, npm, pip, and source builds.

### Changed

- Outputs and `--report` files are checked before any work: a folder, a path that names one of the inputs, or a missing or unwritable folder is an error, and `--report` replaces an existing file only with `--force`.
- Errors name files as they were given and print plain messages instead of internal error descriptions.
- A recording without an artist tag shows "Unknown Artist"; titles and artists from tags or file names are shortened to fit the header, and empty or overlong `--title` and `--artist` values are rejected before any work.
- Artwork up to 8192 pixels per side and 64 megapixels is accepted; unusable artwork embedded in the audio file is replaced by the placeholder with a warning.
- An interrupted command removes its partial output and exits with 128 plus the signal number.
- The Homebrew formula stops early with a clear message when the Swift toolchain is older than Swift 6.

### Fixed

- `render` no longer aborts on recordings above 192 kHz, up to the documented 384 kHz.
- `render` no longer fails on recordings without an artist tag, such as most WAV and AIFF files.
- `--force` no longer replaces a folder whose name ends in `.mp4`, and an output can no longer overwrite one of the inputs.
- `--report` no longer overwrites existing files, including the video just written.
- `models remove` no longer deletes anything in a folder without installed models, such as the current folder when `ILYRICS_MODELS` is empty.
- Some AAC files, such as those encoded by FFmpeg, no longer fail at random with a duration mismatch.
- A render suspended for more than 30 seconds no longer fails when resumed.
- Plain-lyrics lines made only of supported numbers, such as "1, 2, 3, 4", are no longer dropped, and an opening single quotation mark is no longer turned into an apostrophe.
- The instrumental-gap indicator ends when focus moves to the next line instead of overlapping it.
- Paragraphs too long for eight rows on screen are reported with their line numbers before alignment.
- Recordings shorter than one second or silent are reported by name before alignment, without preparing the models.
- `doctor` and `models status` report an invalid `ILYRICS_TEMPLATES` instead of stopping.

## [1.1.0] - 2026-10-14

Usability and screen-fidelity improvements identified through use after 1.0. At the time of this release, Japanese and other languages were planned for 1.2.0.

### Added

- Stage progress on standard error in the style of Homebrew: one line per stage with a bar and percentage where the amount of work is known, `done` or `skip` at the right edge, and a final `Generated FILE in DURATION` line. Plain lines are written to files, pipes, and CI logs.
- Numbers in plain lyrics are aligned as they are usually sung and displayed as written: cardinals, four-digit years, clock times, ordinals, and decades.
- High-resolution audio from 8 to 384 kHz, such as 176.4- and 192-kHz Apple Lossless, and audio files up to 2 GiB.
- The More (⋯) button at the top right of the screen.
- A warning when plain lyrics contain parenthesized backing choruses, which are experimental and unsupported.

### Changed

- Videos fill the full 9:16 frame with a layout adapted from the iPhone screen, instead of showing the iPhone screen between black side bars. In three paired measurements of one 12-second synthetic workload on an Apple M4, mean export time increased by 19.93%; this is not a general estimate for other recordings or hardware ([report](docs/reports/video-layout-adaptation.md)). The earlier native-layout qualification does not establish fidelity for the wider layout.
- Backing vocals without their own timing appear dim beneath the focused line, without being filled with it.
- Lines without reliable timing at the start or end of a song move into the nearest stretch of vocal activity when they fit there.
- Errors begin with `Error:` and name the problem precisely: an empty lyrics file, a lyric line and character that cannot be aligned, or an unsupported sample rate or channel count. Audio is checked before alignment starts.
- `--quiet` hides progress and notes but no longer hides warnings.
- The packaged binary is about 1 MB smaller.

### Fixed

- The instrumental-gap indicator at the start of a song no longer overlaps the first lyric line.
- Audio above 96 kHz no longer fails after alignment has finished.

## [1.0.1] - 2026-10-12

### Fixed

- The model templates are found when `ilyrics` is run by name through `PATH`, as Homebrew, npm, and pip install it; 1.0.0 found them only when it was run by its full path or with `ILYRICS_TEMPLATES` set.

## [1.0.0] - 2026-10-12

The first stable release. The visual preset was measured against six unseen screen recordings of the Music app on iPhone 16 running iOS 27; the controls meet the approved thresholds, and the other properties are released with the known differences stated in the [visual qualification results](docs/reports/visual-qualification-results.md). Command-line options, input syntax, and the report formats `ilyrics-alignment-report-1` and `ilyrics-render-report-1` are now stable and follow Semantic Versioning.

### Added

- Songwriter credits after the last line, from a `Written by:` line in plain lyrics or from `--credits`.
- Duets: a line beginning with `>`, or a TTML paragraph with `ttm:agent="v2"`, belongs to the second singer and is right-aligned.
- Plain lyrics containing accented Latin letters can be aligned; the letters are displayed as written.

### Changed

- The space between paragraphs is set from the native screen (200 px between single-line paragraphs, formerly 235.5 px).
- The background's lightness spread adapts to the artwork, and the header artwork has the native corner radius.
- When a recording has no cover, the placeholder's background carries its colours without showing its symbol.

### Fixed

- Plain lyrics may contain up to 256 paragraphs; the former limit was 64.
- Paragraphs whose long lines wrap to more than four lines no longer stop rendering; up to eight rendered lines are supported.

## [0.2.0] - 2026-10-12

The public preview. English synchronization was evaluated on 80 unseen recordings under the revised criteria. Every pooled criterion was met, but three recordings fell below the per-recording placement threshold of 80%, so the complete set of locked criteria was not met. The maintainer approved the preview with that limitation recorded.

### Added

- Homebrew, npm, and pip packages of the native binary for Apple silicon.

### Changed

- The project is renamed from iLyric to iLyrics: the command is `ilyrics`, the repository `x96x64/ilyrics`, the environment variables `ILYRICS_MODELS` and `ILYRICS_TEMPLATES`, the templates directory `share/ilyrics/templates`, the model cache `~/Library/Application Support/iLyrics/Models`, and the data-format identifiers of reports and model recipes (`ilyrics-alignment-report-1`, `ilyrics-render-report-1`, `ilyrics-weight-recipe-1`, `ilyrics-installed-models-1`). Models installed by 0.1.0 must be installed again.
- Alignment accepts lines framed by accepted neighbours (version 3 of the vocal rules), raising the share of timed lines.
- Recordings of up to twenty minutes are supported, and long recordings no longer exceed the alignment's trace bound.
- Alignment reports include each line's forced proposal, support, and similarity.

### Fixed

- Apostrophe variants such as U+02BC in plain lyrics no longer stop alignment.

## [0.1.0] - 2026-10-11

The first experimental source release. English synchronization and the visual preset are not yet qualified for a public preview.

### Added

- `ilyric render` renders a 1080 × 1920, 60-frame-per-second Lyrics video from a recording and plain, TTML, LRC, or Enhanced LRC lyrics, with the measured focus motion, word fill, background vocals, instrumental-gap indicators, title marquee, artwork-derived background, and auto-hiding controls.
- `ilyric align` synchronizes plain lyrics to a recording natively with HTDemucs vocal separation and wav2vec 2.0 forced alignment through Core ML, and writes word-timed TTML with a JSON report.
- `ilyric models` installs, reports, and removes the alignment models, rebuilt locally from the publishers' pinned files and the weightless templates in `share/ilyric/templates`.
- `ilyric doctor` checks the environment and states a recovery step for each problem.
- Lyrics normalization for plain text: section labels, parenthesized background vocals, and balanced paragraph splitting.
- Stereo audio output, direct high-resolution Apple Lossless input, and placeholder artwork for recordings without a cover.

[Unreleased]: https://github.com/x96x64/ilyrics/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/x96x64/ilyrics/releases/tag/v1.3.0
[1.2.0]: https://github.com/x96x64/ilyrics/releases/tag/v1.2.0
[1.1.0]: https://github.com/x96x64/ilyrics/releases/tag/v1.1.0
[1.0.1]: https://github.com/x96x64/ilyrics/releases/tag/v1.0.1
[1.0.0]: https://github.com/x96x64/ilyrics/releases/tag/v1.0.0
[0.2.0]: https://github.com/x96x64/ilyrics/releases/tag/v0.2.0
[0.1.0]: https://github.com/x96x64/ilyrics/releases/tag/v0.1.0
