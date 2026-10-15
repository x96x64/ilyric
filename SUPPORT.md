# Support

## Supported Versions

Only the latest release receives fixes. Releases follow [Semantic Versioning](https://semver.org/): from 1.0.0, a change that breaks the command-line options, the lyrics input syntax, or the report formats `ilyrics-alignment-report-1` and `ilyrics-render-report-1` requires a new major version. The rendered appearance is not part of this guarantee; it may change in any release that brings it closer to the native screen, and such changes are listed in the [changelog](CHANGELOG.md).

## Supported Platforms

| Component | Supported |
| --- | --- |
| Operating system | macOS 14 or later |
| Processor | Apple silicon; packaged binaries are built for arm64 only |
| Installation | Homebrew or a source build requires Swift 6; npm and pip contain a prebuilt native binary |
| Automatic synchronization | English lyrics |
| Supplied timing | The documented TTML, LRC, and Enhanced-LRC [subsets](docs/input-formats.md); Japanese display remains deferred |
| Visual target | The Music app on iPhone 16 running iOS 27, light appearance, default text size |

Japanese support, including both automatic synchronization and the display of supplied Japanese timing, remains deferred. Japanese and other languages are currently targeted as v1.3.0, without a guarantee of release dates or feature delivery. Experimental implementation remains available; this clarification does not remove it or broaden the supported scope.

Release binaries are built by the repository's `release.yml` workflow from the tagged source on GitHub-hosted macOS runners. The alignment models are downloaded from their publishers and verified by SHA-256 on first use.

## Backing Choruses and Vocables

Backing-chorus functionality is experimental, unverified, and unsupported. Users should not include backing choruses in `lyrics.txt`, whether written as parenthesized phrases or standalone chorus-only lines, including ordinary lines containing only a secondary chorus part. Ordinary lead-sung refrains and `[Chorus]` section headings remain permitted; section headings are ignored by parsing.

Backing cues have been observed to disappear late or unevenly. Predominantly chorus-only lines may align into subsequent non-singing audio. Neither issue is claimed to be fixed or verified against native iOS 27 behavior. The functionality remains implemented and reversible. Unsupported chorus inputs remain accepted, interpreted, and exported as before. This support classification does not change the v1.0.0 input-syntax or report-format stability promise, and no rendering or other output change is introduced.

A plain-text invocation emits one nonfatal stderr warning when existing parsing recognizes parenthesized backing phrases, including parentheses-only lines. It appears in every mode, including `--quiet`. It neither rejects input nor changes exit status. Ordinary chorus-only lines do not receive automatic vocal-role detection, and timed formats do not trigger the warning.

Vocable-only lines such as "ooh" and "na-na" remain usable. The [third English qualification](docs/reports/third-preview-qualification-results.md) aligned all nine observed vocable-only lines correctly, but this small sample was excluded from its main scored-line denominator. These results do not qualify backing choruses. Untimed vocables may be omitted; `--keep-ad-libs` retains them without guaranteeing accurate timing.

## Getting Help

1. Update to the latest release ([Updating](README.md#updating)); `ilyrics doctor` shows the installed version and the update command.
2. Run `ilyrics doctor` and follow the recovery step it states.
3. Read [Troubleshooting](README.md#troubleshooting) and [Limitations](README.md#limitations).
4. If the problem remains, open an issue at <https://github.com/x96x64/ilyrics/issues> with the output of `ilyrics --version` and `ilyrics doctor`, the command you ran, and, for an alignment problem, the report written by `--report`. Reports themselves can contain lyric text, backing text, discarded input lines, and the audio basename. Remove content you cannot share before attaching a report; do not attach recordings or lyrics you are not allowed to share. See [Reviewing an Alignment](docs/reviewing-alignment.md#render-reports-and-sharing).

## Out of Scope

Questions about the Music app, Apple Music subscriptions, protected (DRM) audio, the rights to publish rendered videos, and the reproduction of other apps' lyrics screens are outside the project's support.
