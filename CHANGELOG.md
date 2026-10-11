# Changelog

All notable changes to iLyrics are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.2.0] - 2026-10-12

The public preview. English synchronization was qualified on 80 unseen recordings under the revised criteria, with the per-recording criterion narrowly not met; the maintainer approved the preview on that basis.

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

[Unreleased]: https://github.com/x96x64/ilyrics/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/x96x64/ilyrics/releases/tag/v0.2.0
[0.1.0]: https://github.com/x96x64/ilyrics/releases/tag/v0.1.0
