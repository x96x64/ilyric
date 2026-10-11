# iLyrics

[![CI](https://github.com/x96x64/ilyrics/actions/workflows/ci.yml/badge.svg)](https://github.com/x96x64/ilyrics/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](#requirements)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org)
[![Core ML](https://img.shields.io/badge/Core%20ML-inference-34C759?logo=apple&logoColor=white)](https://developer.apple.com/documentation/coreml)
[![AVFoundation](https://img.shields.io/badge/AVFoundation-media-5856D6?logo=apple&logoColor=white)](https://developer.apple.com/documentation/avfoundation)
[![Core Text](https://img.shields.io/badge/Core%20Text-typography-8E8E93?logo=apple&logoColor=white)](https://developer.apple.com/documentation/coretext)
[![Core Image](https://img.shields.io/badge/Core%20Image-background-FF9500?logo=apple&logoColor=white)](https://developer.apple.com/documentation/coreimage)
[![Metal](https://img.shields.io/badge/Metal-scaling-8A8A8A?logo=apple&logoColor=white)](https://developer.apple.com/metal/)
[![Accelerate](https://img.shields.io/badge/Accelerate-signal%20processing-007AFF?logo=apple&logoColor=white)](https://developer.apple.com/documentation/accelerate)
[![Demucs](https://img.shields.io/badge/Demucs-vocal%20separation-0467DF?logo=meta&logoColor=white)](https://github.com/facebookresearch/demucs)
[![wav2vec 2.0](https://img.shields.io/badge/wav2vec%202.0-speech%20recognition-FFD21E?logo=huggingface&logoColor=black)](https://huggingface.co/facebook/wav2vec2-base-960h)
[![Python](https://img.shields.io/badge/Python-model%20templates-3776AB?logo=python&logoColor=white)](scripts)

iLyrics renders lyrics videos that reproduce the Lyrics screen of the Music app on iPhone, and synchronizes plain lyrics to a recording automatically. It runs entirely on your Mac: vocal separation and speech recognition run through Core ML, frames are drawn with Core Text and Core Graphics, and no network service is involved after the one-time model installation.

```bash
ilyrics render song.m4a lyrics.txt -o video.mp4
```

<p align="center">
  <img src="docs/media/demo.png" alt="Three frames of a rendered Lyrics video of Twinkle, Twinkle, Little Star: the first line filling while the playback controls are visible, the next line filling word by word after the controls have hidden, and the instrumental-gap indicator" width="720">
</p>

> [!IMPORTANT]
> iLyrics is an experimental source release. English synchronization and the visual preset have not yet been qualified for a public preview, and command-line options may change before the stable release. iLyrics is not affiliated with, endorsed by, or sponsored by Apple.

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Lyrics Input](#lyrics-input)
- [Reviewing an Alignment](#reviewing-an-alignment)
- [How It Works](#how-it-works)
- [Performance](#performance)
- [Troubleshooting](#troubleshooting)
- [SF Symbols and Rights](#sf-symbols-and-rights)
- [Limitations](#limitations)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Acknowledgments](#acknowledgments)
- [License](#license)

## Features

- **Automatic synchronization.** Plain text lyrics are aligned line by line and word by word against a separated vocal stem. Lines without reliable timing are placed between their neighbours rather than guessed, and every placement is reported.
- **A faithful Lyrics screen.** Focus motion, word fill with a gentle lift, emphasis of sustained final words, background vocals beneath their line, instrumental-gap indicators, a scrolling title, an artwork-derived background, and controls that hide after playback starts. Each behavior was measured from reference recordings of the Music app on iPhone running iOS 27.
- **Deterministic output.** Every frame is a pure function of its timestamp, so any frame can be rendered independently and in parallel. The default CPU inference reproduces the same alignment on every run.
- **Supplied timing.** TTML, LRC, and Enhanced LRC files are rendered exactly as supplied, without alignment.
- **Local and private.** Recordings, lyrics, and videos never leave your Mac; the only network access is the model download.

## Requirements

- macOS 14 or later
- A Swift 6 toolchain (Xcode or the Command Line Tools) to build from source
- About 600 MB of disk space for the alignment models, and 8 GB of memory or more for complete songs

## Installation

### From Source

```bash
git clone https://github.com/x96x64/ilyrics.git
cd ilyrics
swift build -c release
sudo install -m 755 .build/release/ilyrics /usr/local/bin/ilyrics
sudo mkdir -p /usr/local/share/ilyrics
sudo cp -R share/ilyrics/templates /usr/local/share/ilyrics/
```

The second and third commands install the weightless model templates beside the executable. Running `.build/release/ilyrics` directly from the checkout needs no installation step.

Homebrew, npm, and pip packages will be added for the public preview. The npm and pip packages will install the same native macOS binary.

### Alignment Models

The first `render` or `align` of plain text installs the alignment models automatically. To install them in advance:

```bash
ilyrics models install
```

Installation downloads about 460 MB from the publishers: the [HTDemucs](https://github.com/facebookresearch/demucs) checkpoint from Meta and the [wav2vec 2.0](https://huggingface.co/facebook/wav2vec2-base-960h) weights from Hugging Face. iLyrics verifies each file against a pinned SHA-256 digest, rebuilds the Core ML models on your Mac from weightless templates in this repository, runs a self-test, and deletes the downloads. The installed models occupy about 590 MB in `~/Library/Application Support/iLyrics/Models`. iLyrics does not redistribute either set of weights.

```bash
ilyrics models status   # show the cache location and state
ilyrics models remove   # delete the installed models
```

## Quick Start

```bash
# 1. Check the environment
ilyrics doctor

# 2. Render a video from a recording and plain lyrics
ilyrics render "Paper Skies.m4a" paper-skies.txt -o paper-skies.mp4
```

iLyrics reports each step on standard error: model installation on first use, alignment, any lines it could not time, and rendering progress. The finished video is a 1080 × 1920 H.264 file at 60 frames per second with AAC audio, ready for phones and social platforms.

## Usage

```
ilyrics render AUDIO LYRICS -o VIDEO.mp4 [options]
ilyrics align  AUDIO LYRICS -o LYRICS.ttml [options]
ilyrics models install | status | remove
ilyrics doctor
```

`render` produces a video. Plain text lyrics (`.txt`) are aligned first; timed lyrics (`.ttml`, `.lrc`) are used as supplied. `align` stops after synchronization and writes word-timed TTML, which you can inspect, correct, and render later. The title, artist, and artwork are read from the audio file's metadata; `--title`, `--artist`, and `--artwork` override them, and a placeholder is drawn when no artwork is available.

| Option | Commands | Meaning | Default |
| --- | --- | --- | --- |
| `-o, --output FILE` | render, align | Output file | Required |
| `--force` | render, align | Replace an existing output | Off |
| `--title TEXT`, `--artist TEXT` | render | Header text | From the audio file |
| `--artwork FILE` | render | Artwork image | Embedded artwork |
| `--background artwork\|static` | render | Artwork-derived or static background | `artwork` |
| `--controls auto-hide\|visible` | render | Lower controls | `auto-hide` |
| `--no-marquee` | render | Keep an overflowing title static | Scrolling |
| `--no-gaps` | render | Omit instrumental-gap indicators | Shown |
| `--keep-ad-libs` | render, align | Keep vocable-only lines that cannot be timed | Omitted |
| `-j, --jobs N` | render | Parallel rendering workers | Processor count |
| `--fast` | render, align | GPU and Neural Engine inference | CPU |
| `--report FILE` | render, align | JSON report of alignment and export | None |
| `-q, --quiet`, `-v, --verbose` | all | Less or more progress output | Normal |

Exit status is 0 on success, 1 on a runtime failure, and 2 on a usage error. See [Command-Line Interface](docs/command-line-interface.md) for the complete reference and environment variables.

### Examples

```bash
# Align only, then review the report before rendering
ilyrics align song.m4a lyrics.txt -o lyrics.ttml --report report.json
ilyrics render song.m4a lyrics.ttml -o video.mp4

# Supply header text and artwork explicitly
ilyrics render song.wav lyrics.txt -o video.mp4 --title "Paper Skies" --artist "The Harbour Lights" --artwork cover.jpg

# Keep the controls on screen and use a static background
ilyrics render song.m4a lyrics.ttml -o video.mp4 --controls visible --background static

# Faster alignment on the GPU and Neural Engine, at the cost of reproducibility
ilyrics render song.m4a lyrics.txt -o video.mp4 --fast
```

## Lyrics Input

### Plain Text

Plain lyrics are UTF-8 text with one sung line per line and blank lines between sections, as they appear in most lyrics sources.

```text
[Verse 1]
Paper skies above the harbour
Lanterns drifting (drifting) out to sea

[Chorus]
Hold the light (hold the light)
(Hold it now)
```

- Section labels in brackets, such as `[Chorus]`, are ignored.
- Parenthesized phrases are shown as background vocals beneath their line. A line consisting only of parenthesized phrases belongs to the line above.
- Lines without letters, such as `...`, are ignored.
- Sections longer than four lines are split into balanced groups; a six-line verse becomes two groups of three.
- Lines that consist only of vocables, such as "ooh" or "na-na-na", are omitted when they cannot be timed. Pass `--keep-ad-libs` to keep them in place.

The lyrics must match what is sung, in order. Repeated choruses should be written out in full rather than abbreviated as "Chorus ×2".

### Timed Lyrics

| Format | Extension | Timing |
| --- | --- | --- |
| TTML | `.ttml` | Line and word spans, including `ttm:role="x-bg"` background vocals |
| Enhanced LRC | `.lrc` with `<mm:ss.xx>` word tags | Line and word |
| LRC | `.lrc` | Line |

Timed lyrics are used exactly as supplied. Word timing produces word-by-word fill; line timing fills each line steadily.

### Audio

Any unprotected audio file that AVFoundation can decode is accepted, including AAC, Apple Lossless up to 96 kHz, MP3, WAV, and AIFF. Recordings must be mono or stereo and at most twenty minutes long. Stereo sources keep stereo audio in the video.

## Reviewing an Alignment

Automatic synchronization is reliable for most lines, but not all. iLyrics never invents word timing it cannot support:

- **Aligned** lines have line and word timing derived from the vocal stem.
- **Placed** lines lacked reliable evidence and are spread evenly between their aligned neighbours; they fill steadily instead of word by word.
- **Omitted** lines are untimed vocable-only lines, unless `--keep-ad-libs` is given.

The summary line states how many lines fell into each group, and `--report FILE` writes every line's status, interval, word intervals, and reasons as JSON. To correct a result, edit the TTML written by `align` and render it as supplied timing.

## How It Works

1. **Decoding.** AVFoundation decodes the recording and resamples it at mastering quality.
2. **Vocal separation.** HTDemucs isolates the vocals. The network runs through Core ML; the spectrogram, its inverse, and resampling are implemented with Accelerate.
3. **Recognition.** wav2vec 2.0 produces character probabilities for every 20 ms of the vocal stem.
4. **Forced alignment.** A complete-sequence CTC alignment places every character of the lyrics, and words and lines are derived from it. Vocal-activity rules refine line boundaries and reject implausible results.
5. **Rendering.** The aligned lyrics are evaluated at exact rational timestamps into immutable screen snapshots, drawn with Core Text and Core Graphics, and encoded by parallel workers with AVFoundation.

The native pipeline reproduces the original Python research implementation exactly on a complete recording. The design and its measurements are recorded in [Native Alignment Pipeline](docs/reports/native-alignment-pipeline.md).

## Performance

Measured on an Apple M4 (10 cores) with a 5 min 19 s recording decoded from 96-kHz Apple Lossless:

| Step | Time |
| --- | ---: |
| Decoding | 7 s |
| Vocal separation | 42 s |
| Recognition and alignment | 12 s |
| Rendering and encoding (19,122 frames) | 5 min 27 s |
| **Complete `render` of plain lyrics** | **6 min 56 s** |

Peak memory was 1.6 GB during alignment and 3.0 GB for the complete `render`. Rendering scales with processor cores; use `--jobs` to limit it. `--fast` shortens separation and recognition but may change results slightly between runs.

## Troubleshooting

Run `ilyrics doctor` first; it checks each requirement and states the recovery step for any problem.

| Message | Remedy |
| --- | --- |
| `model templates were not found` | Run iLyrics from the cloned repository or an installed package, or set `ILYRICS_TEMPLATES`. |
| `model download failed` | Check the network connection and run `ilyrics models install` again; verified downloads are reused. |
| `the lyrics cannot be aligned` | Remove unsupported symbols, or split sections that exceed the stated limit. |
| `Protected audio is unsupported` | Use a file you own without DRM; streamed Apple Music downloads cannot be read. |
| `... already exists` | Choose another output or pass `--force`. |

## SF Symbols and Rights

Control icons are SF Symbols, resolved at render time from the Mac running iLyrics; iLyrics never bundles or redistributes them. Apple's [SF Symbols license](https://developer.apple.com/support/terms/) does not expressly permit their use in exported videos, so you are responsible for how you use and publish the videos you create. The demonstration image above shows SF Symbols rendered the same way; the original icon set in this repository is used for tests. See [SF Symbols Rights Assessment](docs/sf-symbols-rights-assessment.md).

The demonstration uses "The Star" by Jane Taylor (1806), which is in the public domain, with synthetic timing and no recording.

You are likewise responsible for holding the rights to the recordings, lyrics, and artwork you render. iLyrics does not download lyrics or audio.

## Limitations

- Automatic synchronization supports English. Japanese is planned for the release after the stable release.
- Rendering targets the iPhone portrait screen at 1080 × 1920 and 60 frames per second.
- The visual target is the Music app on iOS 27. Its behavior has been measured from private reference recordings, but fidelity has not yet been qualified against acceptance thresholds.
- Translations, the Sing mode, and landscape layouts are not rendered.

## Documentation

- [Command-Line Interface](docs/command-line-interface.md): commands, options, and environment variables
- [Roadmap to the Stable Release](docs/roadmap-to-stable.md): remaining work and release stages
- [Native Alignment Pipeline](docs/reports/native-alignment-pipeline.md) and [Native Model Installation and Decoding](docs/reports/native-model-installation.md)
- [Model Template Distribution](docs/reports/model-template-distribution.md): what the repository's model templates contain
- [Documentation Index](docs/README.md): every engineering report by topic, in chronological order

## Contributing

Issues and pull requests are welcome. Before submitting a change:

```bash
swift build
swift test
```

The public test suite uses only original synthetic fixtures and needs neither the network nor private recordings. Read [AGENTS.md](AGENTS.md) for the engineering constraints, including determinism, evidence classification, and the rules for private reference material. Commits follow [Conventional Commits](https://www.conventionalcommits.org/).

## Acknowledgments

iLyrics was developed with [Codex](https://openai.com/codex) by OpenAI and [Claude](https://claude.ai) by Anthropic, credited as co-authors in the commit history. It builds on [Demucs](https://github.com/facebookresearch/demucs) by Meta AI Research (MIT License) and [wav2vec 2.0](https://huggingface.co/facebook/wav2vec2-base-960h) by Meta AI (Apache License 2.0).

## License

iLyrics is licensed under the [Apache License, Version 2.0](LICENSE). The alignment models are downloaded from their publishers under their own licenses.
