# Changelog

All notable changes to iLyric are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-10-11

The first experimental source release. English synchronization and the visual preset are not yet qualified for a public preview.

### Added

- `ilyric render` renders a 1080 × 1920, 60-frame-per-second Lyrics video from a recording and plain, TTML, LRC, or Enhanced LRC lyrics, with the measured focus motion, word fill, background vocals, instrumental-gap indicators, title marquee, artwork-derived background, and auto-hiding controls.
- `ilyric align` synchronizes plain lyrics to a recording natively with HTDemucs vocal separation and wav2vec 2.0 forced alignment through Core ML, and writes word-timed TTML with a JSON report.
- `ilyric models` installs, reports, and removes the alignment models, rebuilt locally from the publishers' pinned files and the weightless templates in `share/ilyric/templates`.
- `ilyric doctor` checks the environment and states a recovery step for each problem.
- Lyrics normalization for plain text: section labels, parenthesized background vocals, and balanced paragraph splitting.
- Stereo audio output, direct high-resolution Apple Lossless input, and placeholder artwork for recordings without a cover.

[0.1.0]: https://github.com/x96x64/ilyric/releases/tag/v0.1.0
