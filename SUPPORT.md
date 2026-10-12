# Support

## Supported Versions

Only the latest release receives fixes. Releases follow [Semantic Versioning](https://semver.org/): from 1.0.0, a change that breaks the command-line options, the lyrics input syntax, or the report formats `ilyrics-alignment-report-1` and `ilyrics-render-report-1` requires a new major version. The rendered appearance is not part of this guarantee; it may change in any release that brings it closer to the native screen, and such changes are listed in the [changelog](CHANGELOG.md).

## Supported Platforms

| Component | Supported |
| --- | --- |
| Operating system | macOS 14 or later |
| Processor | Apple silicon; packaged binaries are built for arm64 only |
| Installation | Homebrew, npm, pip, or a source build with a Swift 6 toolchain |
| Synchronization | English lyrics; Japanese is planned for the release after 1.0 |
| Visual target | The Music app on iPhone 16 running iOS 27, light appearance, default text size |

Release binaries are built by the repository's `release.yml` workflow from the tagged source on GitHub-hosted macOS runners. The alignment models are downloaded from their publishers and verified by SHA-256 on first use.

## Getting Help

1. Run `ilyrics doctor` and follow the recovery step it states.
2. Read [Troubleshooting](README.md#troubleshooting) and [Limitations](README.md#limitations).
3. If the problem remains, open an issue at <https://github.com/x96x64/ilyrics/issues> with the output of `ilyrics --version` and `ilyrics doctor`, the command you ran, and, for an alignment problem, the report written by `--report`. Do not attach recordings or lyrics you are not allowed to share.

## Out of Scope

Questions about the Music app, Apple Music subscriptions, protected (DRM) audio, the rights to publish rendered videos, and the reproduction of other apps' lyrics screens are outside the project's support.
