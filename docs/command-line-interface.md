# Command-Line Interface

## Status

October 11, 2026. Design approved by the maintainer. `render`, `align`, `models`, and `doctor` are implemented; distribution of the model templates is pending. The interface follows established tools such as ripgrep, fd, bat, GitHub CLI, Git, FFmpeg, and yt-dlp: one executable, verb subcommands, positional inputs, `-o` for the output, progress on standard error, and quiet machine-readable results on request.

## Synopsis

```
ilyric render AUDIO LYRICS -o VIDEO.mp4 [options]
ilyric align  AUDIO LYRICS -o LYRICS.ttml [options]
ilyric models install | status | remove
ilyric doctor
ilyric --help | --version
```

- `render` produces a Lyrics video. Untimed lyrics (`.txt`) are aligned automatically first; timed lyrics (`.ttml`, `.lrc`, Enhanced LRC) are used as supplied.
- `align` produces word-timed TTML from untimed lyrics without rendering.
- `models` installs, reports, or removes the alignment models in the user's model cache. `render` and `align` install missing models automatically on first use.
- `doctor` reports the macOS version, available compute units, SF Symbols availability, the model cache, and the toolchain, and states the recovery step for each problem.

Control icons are always SF Symbols, resolved at runtime; there is no icon option. If a symbol cannot be resolved, rendering stops with an error and `doctor` reports the cause. The original icon set remains internal, for tests and public media only.

## Lyrics Input

Untimed lyrics are plain UTF-8 text. Blank lines separate paragraphs. Lines consisting only of a bracketed section label, such as `[Chorus]`, are ignored. Parenthesized phrases become background vocals of their line; a line containing only parenthesized phrases attaches them to the preceding line. Paragraphs longer than four lines are split. Lines consisting only of vocables that the alignment cannot time are omitted unless `--keep-ad-libs` is given.

## Options

| Option | Commands | Meaning | Default |
| --- | --- | --- | --- |
| `-o, --output FILE` | render, align | Output file; never overwritten unless `--force` | Required |
| `--force` | render, align | Replace an existing output | Off |
| `--title TEXT`, `--artist TEXT` | render | Header text | From the audio file's metadata |
| `--artwork FILE` | render | Artwork image | Embedded artwork, else an original placeholder |
| `--background artwork\|static` | render | Background style | `artwork` |
| `--controls auto-hide\|visible` | render | Lower controls | `auto-hide` |
| `--no-marquee`, `--no-gaps` | render | Disable the title marquee or the instrumental-gap indicator | Enabled |
| `--keep-ad-libs` | render, align | Keep untimed vocable-only lines | Off |
| `-j, --jobs N` | render | Parallel rendering workers | Active processor count |
| `--fast` | render, align | GPU and Neural Engine inference; faster but not reproducible | Off: CPU, reproducible |
| `--report FILE` | render, align | JSON report of estimates, placements, and timings | None |
| `-q, --quiet` / `-v, --verbose` | all | Less or more progress output | Normal |

Exit status is 0 on success, 1 on a runtime failure, and 2 on a usage error. Error messages name the cause and the recovery step.

## Environment

| Variable | Meaning | Default |
| --- | --- | --- |
| `ILYRIC_MODELS` | Model cache directory | `~/Library/Application Support/iLyric/Models` |
| `ILYRIC_TEMPLATES` | Directory of the weightless model templates | `share/ilyric/templates` beside the executable's installation prefix |

The cache holds the compiled models (about 590 MB). Installation downloads about 460 MB of publisher files, verifies their pinned SHA-256 digests, rebuilds and self-tests both models, and deletes the downloads.

## Rights

SF Symbols are resolved at runtime from the user's Mac and never bundled, as recorded in [SF Symbols Rights Assessment](sf-symbols-rights-assessment.md). The README states that Apple's terms do not expressly license SF Symbols in exported videos; the command does not repeat this notice on every run. Model weights are downloaded from their publishers and rebuilt locally ([Native Model Installation and Decoding](native-model-installation.md)).
