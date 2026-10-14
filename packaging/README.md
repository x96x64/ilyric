# iLyrics

[![CI](https://github.com/x96x64/ilyrics/actions/workflows/ci.yml/badge.svg)](https://github.com/x96x64/ilyrics/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/x96x64/ilyrics/blob/main/LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://github.com/x96x64/ilyrics#requirements)

iLyrics renders lyrics videos that reproduce the Lyrics screen of the Music app on iPhone, and synchronizes plain lyrics to a recording automatically. It runs entirely on your Mac: vocal separation and speech recognition run through Core ML, and no network service is involved after the one-time model installation.

This package installs the native `ilyrics` command for macOS on Apple silicon. It contains no JavaScript or Python code beyond what is needed to place the binary on your `PATH`.

```bash
ilyrics render song.m4a lyrics.txt -o video.mp4
```

<p align="center">
  <img src="https://raw.githubusercontent.com/x96x64/ilyrics/main/docs/media/demo.png" alt="Three full-width frames of a rendered Lyrics video: the first line filling while the playback controls are visible, the next line filling word by word, and the instrumental-gap indicator" width="720">
</p>

> **Note:** English synchronization was evaluated on 80 unseen recordings, and the visual preset was measured against unseen screen recordings of the Music app; known limitations are listed in the [full README](https://github.com/x96x64/ilyrics#limitations). iLyrics is not affiliated with, endorsed by, or sponsored by Apple.

## Features

- **Automatic synchronization.** Plain text lyrics, including numbers such as 40 or 3:00, are aligned line by line and word by word against a separated vocal stem; lines without reliable timing are placed rather than aligned, and are reported.
- **A faithful Lyrics screen.** Focus motion, word fill, instrumental-gap indicators, a scrolling title, an artwork-derived background, and auto-hiding controls, measured from the Music app on iOS 27 and adapted to fill a full 9:16 video.
- **Supplied timing.** TTML, LRC, and Enhanced LRC files are rendered as supplied.
- **Clear progress and errors.** Each stage is shown on one line with a progress bar, and problems name the file, line, and character to fix.
- **High-resolution audio.** AAC, MP3, WAV, AIFF, and Apple Lossless up to 384 kHz.
- **Deterministic and local.** Every frame is a pure function of its timestamp, and recordings, lyrics, and videos never leave your Mac.

## Requirements

- macOS 14 or later on Apple silicon
- About 600 MB of disk space for the alignment models

## Installation

```bash
npm install -g ilyrics        # npm
pipx install ilyrics          # pip (or: pip install ilyrics)
brew install x96x64/tap/ilyrics
```

Then check the environment and install the alignment models, about 460 MB downloaded once from their publishers and rebuilt on your Mac:

```bash
ilyrics doctor
ilyrics models install
```

To update, run `npm install -g ilyrics@latest`, `pipx upgrade ilyrics` (or `pip install --upgrade ilyrics`), or `brew update && brew upgrade ilyrics`; `ilyrics doctor` shows the installed version and its update command.

## Usage

```bash
# Align plain lyrics and render a video
ilyrics render song.m4a lyrics.txt -o video.mp4

# Render supplied timing as is
ilyrics render song.m4a lyrics.ttml -o video.mp4

# Only align, writing word-timed TTML and a JSON report
ilyrics align song.m4a lyrics.txt -o lyrics.ttml --report report.json
```

The title, artist, and artwork are read from the audio file's metadata. Common options:

| Option | Meaning |
| --- | --- |
| `--title TEXT`, `--artist TEXT`, `--artwork FILE` | Override the header and artwork |
| `--background artwork\|static` | Artwork-derived or static background |
| `--controls auto-hide\|visible` | Hide the lower controls after playback starts, or keep them |
| `--safe-area none\|reels` | Keep the header, lyrics, and controls inside the width that Instagram Reels shows |
| `-j, --jobs N` | Parallel rendering workers |
| `--fast` | GPU and Neural Engine inference; faster but not reproducible |
| `--force` | Replace an existing output |

Plain lyrics are UTF-8 text with one sung line per line and blank lines between sections. Section labels such as `[Chorus]` are ignored. Parenthesized backing choruses are experimental and unsupported; leave them out of plain lyrics. See the [command reference](https://github.com/x96x64/ilyrics/blob/main/docs/command-line-interface.md) for every option.

## Rights

Control icons are SF Symbols, resolved at render time from your Mac and never bundled. Apple's terms do not expressly permit their use in exported videos, so you are responsible for how you publish the videos you create, and for holding the rights to the recordings, lyrics, and artwork you render.

## Links

- [Source and full README](https://github.com/x96x64/ilyrics)
- [Releases and changelog](https://github.com/x96x64/ilyrics/releases)
- [Issues](https://github.com/x96x64/ilyrics/issues)

## License

Apache License, Version 2.0. The alignment models are downloaded from their publishers under their own licenses: [Demucs](https://github.com/facebookresearch/demucs) (MIT) and [wav2vec 2.0](https://huggingface.co/facebook/wav2vec2-base-960h) (Apache-2.0).
