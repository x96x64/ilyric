# Roadmap to the Stable Release

## Purpose and Status

October 11, 2026. This roadmap carries the project from the current state to the stable release. It records the maintainer's decisions, the remaining work in order, where each task can run, and the points at which the maintainer must confirm before work proceeds. Agents working in cloud sessions must follow it together with `AGENTS.md`; they must not act beyond a confirmation point without the maintainer's explicit approval in the conversation.

### Current State

- **Video generation** is considered sufficient by the maintainer after the ninth Man in the Mirror video. It covers the measured focus lead, word fill with lift and sustained-word emphasis, background vocals, the title marquee, control auto-hide, gap slots, and the recalibrated artwork background. Reports from [First Complete Real-Song Video](reports/first-real-song-video.md) through [Gap Slot Collapse](reports/gap-slot-collapse.md) record the measurements.
- **Alignment** runs natively on macOS without Python or FFmpeg, as recorded in [Native Alignment Pipeline](reports/native-alignment-pipeline.md) and [Native Model Installation and Decoding](reports/native-model-installation.md). It reproduces the Python reference on a complete recording and exports word-timed TTML byte-identically from the same alignment.
- **Export throughput** is about 1.2 times real time with parallel rendering ([Playback Smoothness, Fill Lead, and Control Transition](reports/playback-smoothness-and-fill-lead.md)).
- **The `ilyrics` command** provides `render`, `align`, `models`, and `doctor`, replacing the rendering and alignment probes; the probes used by private reference validation remain as developer tools.

### Decisions in Force

1. The release proceeds in three stages: an experimental source release, a public preview once English automatic synchronization is qualified, and a stable release once the visual preset is qualified.
2. The license is Apache-2.0.
3. Faithful reproduction of the iOS 27 Music Lyrics screen is a goal equal to synchronization.
4. The first public release supports English automatic synchronization; Japanese follows in the next release.
5. Distribution is native macOS (Swift and Core ML), not a Python setup.
6. SF Symbols are resolved at runtime and never bundled; public media use original icons.
7. The HTDemucs checkpoint is never redistributed. iLyrics downloads it from Meta's host on first use, verifies its SHA-256, and rebuilds the Core ML weights locally. The wav2vec2 weights (Apache-2.0) are installed the same way from Hugging Face.
8. The maintainer does not perform manual annotation; evaluation uses public human-annotated data, cross-validation, and isolated scoring.
9. Commits carry the Claude co-author trailer when Claude contributes; history is not rewritten.
10. (Added October 11, 2026.) The command design in [Command-Line Interface](command-line-interface.md) is approved. Control icons are always SF Symbols, resolved at runtime, with no option to disable them; the original icon set remains internal for tests and public media.
11. (Added October 11, 2026.) The public preview is distributed through Homebrew, npm, and pip; the npm and pip packages are thin installers for the native macOS binary.
12. (Added October 12, 2026.) The product is renamed from iLyric to iLyrics, the command from `ilyric` to `ilyrics`, and the repository to `x96x64/ilyrics`, before any package is published. Version 0.1.0 and historical records keep the former name.
13. (Added October 12, 2026.) The maintainer approved the public preview on the [third qualification](reports/third-preview-qualification-results.md): every pooled criterion was met and only the per-recording criterion was not, by three of 80 recordings, one of them a since-fixed text defect. Publication of each channel still requires the maintainer's confirmation.

## Where Work Can Run

| Work | Requires the Maintainer's Mac | Cloud Session |
| --- | --- | --- |
| Swift code, documentation, repository organization | No; verify through GitHub Actions on macOS | Yes |
| Core ML conversion, template building, model parity | Yes: reference conversions and the pinned checkpoints | No |
| Private recordings, reference captures, rendered videos | Yes: `reference-private/` and `artifacts/` are local and ignored | No |
| Public-data evaluation (downloads within the approved ceiling) | Optional | Yes, with download approval |
| Releases, tags, publishing | Maintainer confirmation | Prepare only |

Cloud sessions run on Linux. Swift targets that import Apple frameworks cannot be built there; changes must be verified by pushing to a branch and reading the macOS CI result. `AlignmentCore` uses only Foundation and its tests can run anywhere Swift runs.

## Stage 1: Experimental Source Release

1. **Single command.** Replace the probes with one `ilyrics` executable modeled on established tools (ripgrep, fd, bat, GitHub CLI, FFmpeg, yt-dlp): `ilyrics render AUDIO LYRICS -o VIDEO` with automatic alignment, plus subcommands for alignment only, export only, model installation, and diagnostics. Options include presentation features enabled by default where rights permit, `--jobs`, deterministic CPU inference by default, and an explicit opt-in for faster non-reproducible inference. Lyrics normalization moves into Swift: parenthesized phrases become background vocals, section labels are dropped, and paragraphs are split to at most four lines.
2. **Remaining defects** from the first real-song video: stereo audio output instead of mono; direct high-resolution Apple Lossless input; explicit reporting of unresolved and placed lines; peak memory reduction in the native pipeline (currently 3.6 GB).
3. **Model distribution.** Host the weightless templates (about 3.6 MB for HTDemucs, 1 MB for wav2vec2) as release assets or in the repository, with Apache-2.0 notices for wav2vec2 and a statement that the Demucs checkpoint is downloaded from its publisher.
4. **README and documentation.** Rewrite the README for users: what iLyrics is, installation, a quick start, the command reference, model downloads and rights, limitations, and acknowledgments (Codex and Claude). Consolidate developer documentation and keep historical reports as records. All titles and headings use MLA title case.
5. **Repository organization.** Remove or archive superseded spike targets and probes in a dedicated cleanup milestone, keep CI green, and audit history, ignored files, and untracked files before publication.

**Progress (October 11, 2026).** Items 1 to 5 are complete except the final publication audit: the command is implemented and verified on the development recording; stereo output, direct 96-kHz Apple Lossless input, and placement reporting are fixed; peak memory fell from 5.4 GB to 1.6 GB for alignment and 3.0 GB for a complete render; the templates are distributed in the repository after removing checkpoint-derived inline values ([Model Template Distribution](reports/model-template-distribution.md)); the README is rewritten with a generated demonstration image; and the reports are indexed in [Documentation](README.md).

**Confirmation point 1:** the maintainer approved the command design on October 11, 2026, and reviews the README, the repository state, and the license notices before any release tag. No tag or release is created without explicit approval.

## Stage 2: Public Preview

1. **Unseen requalification.** Select English recordings never used in development, with public human annotations where possible, and score them once with the frozen native pipeline in an isolated session that cannot see references during preparation. Report line placement, onset and offset errors, word onset errors, and unresolved lines against the M2 conditions ([M2 Qualification Procedure](reports/m2-qualification-procedure.md)).
2. **Failure analysis without tuning on the test set.** Improvements found afterwards are developed on development data and require a new unseen set.
3. **Performance.** Reduce export and alignment time where measurements show a clear bottleneck; GPU inference remains opt-in until it is reproducible.
4. **Packaging.** A signed command-line distribution through Homebrew, npm, and pip, the latter two as thin installers of the native macOS binary; first-run model installation with progress reporting; and failure messages that state the exact recovery step.

**Progress (October 11, 2026).** Version 0.1.0 was released as the experimental source release with packaged assets, the distribution channels are prepared ([Distribution](distribution.md)), and the first unseen qualification was run: synchronization does not yet qualify, because 16.5% of lines remain unresolved and one long recording failed, although only 0.9% were misplaced ([Preview Qualification Results](reports/preview-qualification-results.md)). The next gate revises the acceptance rules and bounds long-recording alignment on development data, then requires a new unseen set.

**Confirmation point 2:** the maintainer approves the unseen recording set and any downloads before scoring, approves the qualification report, and approves the preview release.

## Stage 3: Stable Release

1. **Visual preset qualification.** Define acceptance thresholds against the iPhone 16 reference captures (timing of focus, fill, and controls; background statistics; typography geometry) and verify them with a reproducible private procedure that reports only sanitized numbers.
2. **Japanese planning.** Prepare the Japanese alignment track for the following release without delaying the stable English release.
3. **Release engineering.** Versioning, changelog, reproducible builds, and a support statement.

**Confirmation point 3:** the maintainer approves the visual qualification results and the stable release.

## Working Rules for Cloud Sessions

- Read `AGENTS.md`, this roadmap, and the reports it links before changing code.
- Work on a branch, keep commits atomic and conventional, write formal English documentation, and add the Claude co-author trailer.
- Report progress to the maintainer in Japanese at each completed step and at every confirmation point; wait for approval where this roadmap requires it.
- Never add private recordings, lyrics, captures, model weights, or converted models with weights to Git; ask before any download.
- Do not create releases, tags, or public announcements without explicit approval.
