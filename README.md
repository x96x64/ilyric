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
> All pooled third-qualification criteria for English synchronization were met on 80 unseen recordings, but three recordings failed the per-recording placement threshold of 80%; the complete locked qualification criteria were not met ([results](docs/reports/third-preview-qualification-results.md)). The visual preset was measured against unseen screen recordings of the Music app; the remaining weaknesses and known differences are listed under [Limitations](#limitations). See [Support](SUPPORT.md) for what is covered. iLyrics is not affiliated with, endorsed by, or sponsored by Apple.

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

- **Automatic synchronization.** Plain text lyrics are aligned line by line and word by word against a separated vocal stem. Lines without accepted acoustic timing receive reported fallback placements. Interior runs retain neighbour-based fallback; only eligible boundary runs may relocate under [Plan C](#reviewing-an-alignment), using activity solely as a hint rather than acoustic acceptance.
- **A faithful Lyrics screen.** Focus motion, word fill with a gentle lift, emphasis of sustained final words, instrumental-gap indicators, a scrolling title, an artwork-derived background, and controls that hide after playback starts. These visual features are based on reference recordings of the Music app on iPhone running iOS 27, with the limitations stated below. Backing-chorus functionality remains implemented but is experimental, unverified, and unsupported.
- **Deterministic output.** Every frame is a pure function of its timestamp, so any frame can be rendered independently and in parallel. The default CPU inference reproduces the same alignment on every run.
- **Supplied timing.** TTML, LRC, and Enhanced LRC files are rendered exactly as supplied, without alignment.
- **Local and private.** Recordings, lyrics, and videos never leave your Mac; the only network access is the model download.

## Requirements

- macOS 14 or later
- A Swift 6 toolchain (Xcode or the Command Line Tools) to build from source
- About 600 MB of disk space for the alignment models, and 8 GB of memory or more for complete songs

## Installation

The packages install the same native binary for Apple silicon and need no Swift toolchain.

### Homebrew

```bash
brew install x96x64/tap/ilyrics
```

### npm

```bash
npm install -g ilyrics
```

### pip

```bash
pipx install ilyrics    # or: pip install ilyrics
```

### From Source

```bash
git clone https://github.com/x96x64/ilyrics.git
cd ilyrics
swift build -c release
sudo install -m 755 .build/release/ilyrics /usr/local/bin/ilyrics
sudo mkdir -p /usr/local/share/ilyrics
sudo cp -R share/ilyrics/templates /usr/local/share/ilyrics/
```

The `mkdir` command creates the shared data directory, and the `cp -R` command installs the weightless model templates there. Running `.build/release/ilyrics` directly from the checkout needs no installation step.

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

iLyrics reports its progress on standard error, one line per stage. In a terminal, the active stage is redrawn in place, with a bar and a percentage where the amount of work is known:

```text
==> [1/4] Reading audio                                              done
==> [2/4] Separating vocals   ##########################-----------  68.0%
```

When the command finishes:

```text
==> [1/4] Reading audio                                              done
==> [2/4] Separating vocals                                          done
==> [3/4] Aligning lyrics                                            done
==> [4/4] Rendering video                                            done
==> Generated paper-skies.mp4 in 5 minutes 9 seconds
```

In files, pipes, and CI logs, each finished stage is one plain line without a bar. Lyrics with supplied timing show the separation and alignment stages as `skip`. The finished video is a 1080 × 1920 H.264 file at 60 frames per second with AAC audio, ready for phones and social platforms.

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
| `--credits TEXT` | render | Songwriters shown after the last line | A `Written by:` line in the lyrics |
| `--artwork FILE` | render | Artwork image | Embedded artwork |
| `--background artwork\|static` | render | Artwork-derived or static background | `artwork` |
| `--controls auto-hide\|visible` | render | Lower controls | `auto-hide` |
| `--no-marquee` | render | Keep an overflowing title static | Scrolling |
| `--no-gaps` | render | Omit instrumental-gap indicators | Shown |
| `--keep-ad-libs` | render, align | Keep vocable-only lines that cannot be timed | Omitted |
| `-j, --jobs N` | render | Parallel rendering workers | Processor count |
| `--fast` | render, align | GPU and Neural Engine inference | CPU |
| `--report FILE` | render, align | JSON report of alignment and export | None |
| `-q, --quiet`, `-v, --verbose` | all | Only warnings and errors, or additional details | Progress and notes |

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

The following is an original non-chorus example:

```text
[Verse 1]
A compass rests beside the window
Morning gathers on the road

[Bridge]
Footsteps cross the empty station
Daylight reaches every stone
```

- Section labels in brackets, such as `[Chorus]`, are ignored.
- Do not include backing choruses in `lyrics.txt`, either as parenthesized phrases or as standalone chorus-only lines, even when written as ordinary lines. This functionality is experimental, unverified, and unsupported. Existing parenthesized input remains accepted: phrases are interpreted as backing vocals beneath their associated lead, and a parentheses-only line attaches to the preceding line. Interpretation and export are unchanged; this is a support restriction, not removal of input syntax.
- Lines without letters, such as `...`, are ignored.
- In a duet, a line beginning with `>` belongs to the second singer and is right-aligned, as the Music app shows it. TTML lyrics mark such paragraphs with `ttm:agent="v2"`.
- A line beginning with `Written by:` lists the songwriters. It is not sung; it is shown as "Written By: …" below the last line, as the Music app does.
- Sections longer than four lines are split into balanced groups; a six-line verse becomes two groups of three.
- Vocable-only lines, such as "ooh" or "na-na", remain usable. They may be omitted when reliable timing is unavailable. `--keep-ad-libs` retains them without guaranteeing accurate timing.

The lyrics must match the lead singer's sung sequence, in order. Ordinary lead-sung refrains remain permitted and should be repeated in full when sung again. A `[Chorus]` section label is also permitted and is ignored; neither a lead-sung refrain nor that label is a prohibited backing chorus.

Backing cues have been observed to disappear late or unevenly, and predominantly chorus-only lines can align into subsequent non-singing audio. These issues are not claimed to be fixed or to reproduce verified native iOS 27 behavior. Unsupported chorus inputs remain accepted, interpreted, and exported as before; no output change accompanies this support notice. Plain-text commands emit one nonfatal stderr warning when existing parsing recognizes parenthesized backing phrases, including parentheses-only lines. `--quiet` suppresses it; normal and verbose modes show it. Ordinary chorus-only lines cannot be identified reliably from text alone and do not trigger this warning. Timed formats do not trigger it.

In the [third English qualification](docs/reports/third-preview-qualification-results.md), all nine observed vocable-only lines were aligned correctly. This small sample was excluded from the main scored-line denominator and does not establish backing-chorus accuracy.

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
- **Placed** lines lack accepted acoustic timing and receive fallback intervals; they fill steadily rather than word by word. Interior unresolved runs retain their existing neighbour-based fallback.
- **Omitted** lines are untimed vocable-only lines, unless `--keep-ad-libs` is given.

At leading and trailing boundaries, [Plan C](docs/reports/fallback-placement-plan-c.md) considers only the nearest eligible activity component beside the accepted anchor: the last component before the next accepted onset for a leading run, or the first component after the preceding accepted end for a trailing run. An eligible run moves only if its complete existing span, including spacing and the boundary guard, fits that component without crossing accepted intervals or audio bounds. If the nearest component is unsuitable, the original fallback placement is retained without searching farther components. Runs already fitting that component, protected runs, and runs without accepted anchors also remain unchanged. Activity is a placement hint, not evidence that the particular words were sung, and relocation does not promote a placed line to acoustic acceptance.

A `Note:` line states how many lines have no word timing or were omitted, `--verbose` lists them, and `--report FILE` writes every line's status, interval, word intervals, and reasons as JSON. To correct a result, edit the TTML written by `align` and render it as supplied timing.

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

- Automatic synchronization supports English. Japanese and other languages are planned for a later release, currently targeted as v1.2.0.
- Backing choruses, including parenthesized phrases and standalone chorus-only lines written as ordinary lines, are experimental, unverified, and unsupported. Exclude them from `lyrics.txt`; lead-sung refrains, `[Chorus]` labels, and vocable-only lines remain permitted. See [Plain Text](#plain-text) for observed issues and unchanged compatibility.
- On 80 unseen recordings with manual word timing, 95.9% of lines were placed correctly, 0.5% were misplaced, and 3.6% were left untimed; three recordings fell below 80% ([qualification results](docs/reports/third-preview-qualification-results.md)). Accuracy is lower when several singers sing different words at once and for shouted or heavily processed vocals. Lines without accepted timing use fallback placements and fill steadily rather than word by word. Interior runs retain neighbour-based fallback; an eligible leading or trailing run may move only if its full existing span fits the nearest eligible activity component beside its accepted anchor. Otherwise its original placement remains; no farther component is searched. Activity is a hint, not proof of the supplied words or acoustic acceptance. See [Reviewing an Alignment](#reviewing-an-alignment).
- Rendering targets the iPhone portrait screen at 1080 × 1920 and 60 frames per second.
- The visual target is the Music app on iPhone 16 running iOS 27, in light appearance with the default text size. Against six unseen screen recordings, control positions and the auto-hide delay match within the approved thresholds; focus motion, word fill timing, title marquee timing, paragraph spacing, and most line wrapping are close; the known differences are the background's colour and contrast, inactive lines that are brighter than native, the timing of the instrumental-gap indicator, and some wrapped lines ([visual qualification results](docs/reports/visual-qualification-results.md)).
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
