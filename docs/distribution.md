# Distribution

## Status

October 11, 2026. Design for the public preview (Stage 2 of the [roadmap](roadmap-to-stable.md)); not yet implemented. The maintainer decided that the preview is distributed through Homebrew, npm, and pip, the latter two as thin installers of the native macOS binary. On this date the name `ilyric` was unregistered on npm, PyPI, and Homebrew.

## Release Archive

Every release tag builds one archive on GitHub Actions and attaches it to the GitHub Release:

```
ilyric-VERSION-macos-arm64.tar.gz
├── bin/ilyric
└── share/ilyric/templates/…
```

The layout matches the command's template lookup, which searches `share/ilyric/templates` in the executable's installation prefix. The archive's SHA-256 is published with the release. The preview supports Apple silicon and macOS 14 or later; Intel support requires a universal build and is deferred.

The binary is unsigned until the maintainer provides an Apple Developer ID for signing and notarization. Unsigned binaries installed by Homebrew, npm, or pip are not quarantined by Gatekeeper because they are not downloaded by a browser; a binary downloaded manually from the release page must be cleared with `xattr -d com.apple.quarantine`.

## Channels

| Channel | Package | Mechanism |
| --- | --- | --- |
| Homebrew | Tap `x96x64/homebrew-tap`, formula `ilyric` | Builds from the tagged source with `swift build -c release`, as Homebrew does for other Swift command-line tools, and installs `bin/ilyric` and `share/ilyric/templates`. `brew install x96x64/tap/ilyric`. |
| npm | `ilyric` | Contains the release archive's files for `darwin`/`arm64` (`os` and `cpu` fields) and exposes `ilyric` through `bin`; no install script runs. `npm install -g ilyric`. |
| pip | `ilyric` | A platform wheel (`macosx_14_0_arm64`) containing the same files, with a console entry point that executes the binary, as tools such as Ruff distribute native binaries. `pip install ilyric` or `pipx install ilyric`. |

All three install the same binary and templates. The alignment models are installed by `ilyric models install` or on first use, as with a source build; no package contains model weights.

## Maintainer Actions

Publishing requires credentials that only the maintainer holds: an npm account with an access token, a PyPI account with a trusted-publisher configuration for this repository, and creation of the `homebrew-tap` repository. Each first publication is a confirmation point under the roadmap.
