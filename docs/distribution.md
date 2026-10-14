# Distribution

## Status

October 11, 2026. Design for the public preview (Stage 2 of the [roadmap](roadmap-to-stable.md)), implemented for version 0.2.0 and used for every release since; see [Publication](#publication). The maintainer decided that the preview is distributed through Homebrew, npm, and pip, the latter two as thin installers of the native macOS binary. On October 12, 2026, after the rename from iLyric, the name `ilyrics` was unregistered on npm, PyPI, and Homebrew.

## Release Archive

Every release tag builds one archive on GitHub Actions and attaches it to the GitHub Release:

```
ilyrics-VERSION-macos-arm64.tar.gz
├── bin/ilyrics
└── share/ilyrics/templates/…
```

The layout matches the command's template lookup, which searches `share/ilyrics/templates` in the executable's installation prefix. The archive's SHA-256 is published with the release. The preview supports Apple silicon and macOS 14 or later; Intel support requires a universal build and is deferred.

The binary is unsigned until the maintainer provides an Apple Developer ID for signing and notarization. Unsigned binaries installed by Homebrew, npm, or pip are not quarantined by Gatekeeper because they are not downloaded by a browser; a binary downloaded manually from the release page must be cleared with `xattr -d com.apple.quarantine`.

## Channels

| Channel | Package | Mechanism |
| --- | --- | --- |
| Homebrew | Tap `x96x64/homebrew-tap`, formula `ilyrics` | Builds from the tagged source with `swift build -c release`, as Homebrew does for other Swift command-line tools, and installs `bin/ilyrics` and `share/ilyrics/templates`. `brew install x96x64/tap/ilyrics`. |
| npm | `ilyrics` | Contains the release archive's files for `darwin`/`arm64` (`os` and `cpu` fields) and exposes `ilyrics` through `bin`; no install script runs. `npm install -g ilyrics`. |
| pip | `ilyrics` | A platform wheel (`macosx_14_0_arm64`) containing the same files, with a console entry point that executes the binary, as tools such as Ruff distribute native binaries. `pip install ilyrics` or `pipx install ilyrics`. |

All three install the same binary and templates. The alignment models are installed by `ilyrics models install` or on first use, as with a source build; no package contains model weights.

## Publication

Version 0.2.0 was published on October 12, 2026, through all three channels, and version 1.0.0, the stable release, on the same day. Version 1.1.0 was published on October 14, 2026. PyPI and npm use trusted publishing from the `release.yml` workflow in the protected environments `pypi` and `npm`, which require the maintainer's approval; npm's first publication used a short-lived token, which was replaced by trusted publishing and deleted.

## Maintainer Actions

Publishing requires credentials that only the maintainer holds: an npm account with an access token, a PyPI account with a trusted-publisher configuration for this repository, and creation of the `homebrew-tap` repository. Each first publication is a confirmation point under the roadmap.
