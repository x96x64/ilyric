# iLyric

[![CI](https://github.com/x96x64/ilyric/actions/workflows/ci.yml/badge.svg)](https://github.com/x96x64/ilyric/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/x96x64/ilyric/blob/main/LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://github.com/x96x64/ilyric#requirements)

iLyric renders lyrics videos that reproduce the Lyrics screen of the Music app on iPhone, and synchronizes plain lyrics to a recording automatically. It runs entirely on your Mac: vocal separation and speech recognition run through Core ML, and no network service is involved after the one-time model installation.

This package installs the native `ilyric` command for macOS on Apple silicon. It contains no JavaScript or Python code beyond what is needed to place the binary on your `PATH`.

```bash
ilyric render song.m4a lyrics.txt -o video.mp4
```

<p align="center">
  <img src="https://raw.githubusercontent.com/x96x64/ilyric/main/docs/media/demo.png" alt="Three frames of a rendered Lyrics video: the first line filling while the playback controls are visible, the next line filling word by word, and the instrumental-gap indicator" width="720">
</p>

> **Note:** iLyric is an experimental release. English synchronization and the visual preset have not yet been qualified, and options may change. iLyric is not affiliated with, endorsed by, or sponsored by Apple.

## Features

- **Automatic synchronization.** Plain text lyrics are aligned line by line and word by word against a separated vocal stem; lines without reliable timing are placed between their neighbours and reported.
- **A faithful Lyrics screen.** Focus motion, word fill, background vocals, instrumental-gap indicators, a scrolling title, an artwork-derived background, and auto-hiding controls, measured from the Music app on iOS 27.
- **Supplied timing.** TTML, LRC, and Enhanced LRC files are rendered as supplied.
- **Deterministic and local.** Every frame is a pure function of its timestamp, and recordings, lyrics, and videos never leave your Mac.

## Requirements

- macOS 14 or later on Apple silicon
- About 600 MB of disk space for the alignment models

## Installation

```bash
npm install -g ilyric        # npm
pipx install ilyric          # pip (or: pip install ilyric)
brew install x96x64/tap/ilyric
```

Then check the environment and install the alignment models, about 460 MB downloaded once from their publishers and rebuilt on your Mac:

```bash
ilyric doctor
ilyric models install
```

## Usage

```bash
# Align plain lyrics and render a video
ilyric render song.m4a lyrics.txt -o video.mp4

# Render supplied timing as is
ilyric render song.m4a lyrics.ttml -o video.mp4

# Only align, writing word-timed TTML and a JSON report
ilyric align song.m4a lyrics.txt -o lyrics.ttml --report report.json
```

The title, artist, and artwork are read from the audio file's metadata. Common options:

| Option | Meaning |
| --- | --- |
| `--title TEXT`, `--artist TEXT`, `--artwork FILE` | Override the header and artwork |
| `--background artwork\|static` | Artwork-derived or static background |
| `--controls auto-hide\|visible` | Hide the lower controls after playback starts, or keep them |
| `-j, --jobs N` | Parallel rendering workers |
| `--fast` | GPU and Neural Engine inference; faster but not reproducible |
| `--force` | Replace an existing output |

Plain lyrics are UTF-8 text with one sung line per line and blank lines between sections. Section labels such as `[Chorus]` are ignored, and parenthesized phrases are shown as background vocals. See the [command reference](https://github.com/x96x64/ilyric/blob/main/docs/command-line-interface.md) for every option.

## Rights

Control icons are SF Symbols, resolved at render time from your Mac and never bundled. Apple's terms do not expressly permit their use in exported videos, so you are responsible for how you publish the videos you create, and for holding the rights to the recordings, lyrics, and artwork you render.

## Links

- [Source and full README](https://github.com/x96x64/ilyric)
- [Releases and changelog](https://github.com/x96x64/ilyric/releases)
- [Issues](https://github.com/x96x64/ilyric/issues)

## License

Apache License, Version 2.0. The alignment models are downloaded from their publishers under their own licenses: [Demucs](https://github.com/facebookresearch/demucs) (MIT) and [wav2vec 2.0](https://huggingface.co/facebook/wav2vec2-base-960h) (Apache-2.0).
