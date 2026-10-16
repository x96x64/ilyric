# Distribution

## Status

The current published release is v1.3.1, dated October 16, 2026. Version 1.3.2 is being prepared; its publication and release date remain pending. Distribution uses Homebrew, npm, and pip. The distribution design was established for the public preview on October 11, implemented for v0.2.0, and retained for subsequent releases; see [Publication](#publication). npm and pip contain the native macOS binary and model templates; Homebrew builds the tagged source locally.

## Release Archive

Every supported stable release tag builds one archive on GitHub Actions and attaches it to the GitHub Release:

```
ilyrics-VERSION-macos-arm64.tar.gz
├── bin/ilyrics
└── share/ilyrics/templates/…
```

The layout matches the command's template lookup, which searches `share/ilyrics/templates` in the executable's installation prefix. The archive's SHA-256 is published with the release. The released packages support Apple silicon and macOS 14 or later; Intel support requires a universal build and is deferred.

Packaged binaries are ad hoc-signed by `packaging/package.sh`. Apple Developer ID signing and notarization remain pending until the maintainer provides the required signing identity. Binaries installed by Homebrew, npm, or pip are not quarantined by Gatekeeper because they are not downloaded by a browser; a binary downloaded manually from the release page must be cleared with `xattr -d com.apple.quarantine`.

## Channels

| Channel | Package | Mechanism |
| --- | --- | --- |
| Homebrew | Tap `x96x64/homebrew-tap`, formula `ilyrics` | Builds from the tagged source with `swift build -c release`, as Homebrew does for other Swift command-line tools, and installs `bin/ilyrics` and `share/ilyrics/templates`. `brew install x96x64/tap/ilyrics`. |
| npm | `ilyrics` | Contains the release archive's files for `darwin`/`arm64` (`os` and `cpu` fields) and exposes `ilyrics` through `bin`; no install script runs. `npm install -g ilyrics`. |
| pip | `ilyrics` | A platform wheel (`macosx_14_0_arm64`) containing the same files, which installs the binary itself into the environment's scripts directory, as tools such as Ruff distribute native binaries. `pip install ilyrics` or `pipx install ilyrics`. |

npm and pip install the binary and templates of the release archive; Homebrew builds the same source on the user's Mac and installs the same files. The alignment models are installed by `ilyrics models install` or on first use, as with a source build; no package contains model weights.

## Publication

On October 12, 2026, after the rename from iLyric and before first publication, the name `ilyrics` was unregistered on npm, PyPI, and Homebrew.

Version 0.2.0 was published on October 12, 2026, through all three channels, and version 1.0.0, the stable release, on the same day. Version 1.1.0 was published on October 14, 2026, and versions 1.2.0 and 1.3.0 on October 15, 2026. Version 1.3.1 is dated October 16, 2026, and retains the same distribution channels. Version 1.3.2 is prepared for the same channels and has not yet been published. PyPI and npm use trusted publishing from the `release.yml` workflow in the protected environments `pypi` and `npm`, which require the maintainer's approval; npm's first publication used a short-lived token, which was replaced by trusted publishing and deleted.

## Maintainer Actions

Initial publication required setting up the npm and PyPI accounts, the trusted-publisher configuration, and the `homebrew-tap` repository; npm's initial access token was subsequently removed as recorded above. Current npm and PyPI publication uses the trusted-publishing workflow and its approval-protected environments. Releases, tags, and publication continue to require the maintainer's explicit approval under the roadmap; the completed initial setup does not authorize a future publication.

### Stable Release Guard

The release workflow validates an exact `vMAJOR.MINOR.PATCH` tag and an existing, published GitHub Release that is not marked as a prerelease before building, attaching, or publishing packages. Missing releases, draft releases, prerelease tags, build metadata, and mismatched release tags stop the workflow. The guard applies both to tag pushes and to manual runs, including runs that publish previously attached packages without rebuilding them. Each registry job rechecks the release state after environment approval and before downloading its packages. Its policy is loaded from `main`, like the packaging scripts, so historical stable tags remain eligible.

Prerelease packaging and registry publication are not supported by this workflow. A separate policy for version normalization and registry channels is required before release candidates can be distributed. The `npm` and `pypi` environments still require the maintainer's approval; the guard does not replace that approval or authorize publication. Offline guard tests run in CI and do not call publication APIs.
