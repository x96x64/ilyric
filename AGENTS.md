# iLyric Engineering Constraints

## Project Identity and Documentation

Use `iLyric` as the canonical product name and `ilyric` for the executable, repository, and suitable lowercase technical identifiers. Work in this repository; do not create a nested project directory. Preserve the planning-baseline commit.

Use MLA headline-style title case permanently for all English documentation titles, section headings, and subsection headings, including README, contributor guidance, architecture documents, command references, and future documentation. Preserve literal capitalization of iLyric, Apple product names, APIs, frameworks, languages, commands, filenames, options, packages, and code identifiers.

Model the README and command-line interface on established, widely used tools such as ripgrep, fd, bat, GitHub CLI, Git, FFmpeg, and yt-dlp. Keep commits atomic and conventional so that history remains reviewable; perform broad cleanup through ordinary commits in a dedicated milestone.

## Evidence and Architecture

Read `docs/planning-study.md` before architectural changes. Preserve its evidence classifications, qualifications, measurements, requirements, and go/no-go criteria. The supplied study is a historical baseline, not an instruction to implement its entire roadmap. Its placeholder name is superseded by `ilyric`. Validate architectural recommendations with working evidence.

The canonical visual target is native Music on iPhone running iOS 27. Apple Music on the web, macOS Music, previous iOS releases, and third-party replicas are not canonical references. Never represent unmeasured iOS 27 behavior as measured fact. Label synthetic constants and fixtures explicitly.

The production renderer must support deterministic arbitrary-timestamp evaluation. Keep domain and timeline logic independent from macOS backends. Evaluate explicit rational timestamps into immutable presentation snapshots. Wall-clock-driven animation, previous-frame dependence, live SwiftUI state, and Core Animation presentation state must never own the canonical offline timeline. Define simultaneous event ordering and half-open intervals.

## Scope and Rights

Keep the first spike narrow. Do not add production parsers, stabilized schemas, device presets, broad CLI surfaces, release packaging, or speculative abstractions. Use Core Text and ordinary Apple raster facilities or Core Image first; add Metal only for a demonstrated requirement or measured bottleneck.

Resolve SF Symbols and system fonts only at runtime through public APIs, as recorded in `docs/sf-symbols-rights-assessment.md`. Public fixtures, golden images, and documentation media must use the original icon set. Do not incorporate proprietary Apple Music assets, extracted icons, private frameworks, redistributed proprietary font files, commercial media, credentials, or private reference captures. Use original fixtures. Do not select a software license without a separate explicit decision.

## Verification and History

Test rational scheduling, timeline boundaries, event ordering, interrupted motion, random-access determinism, and layout. Validate decoded media dimensions, cadence, duration, audio timing, representative pixels, and memory/performance on an optimized build. Encoded-file byte equality is not required. Pin or report environment limitations for raw raster equality.

Keep generated outputs and machine-specific logs out of Git. Record sanitized benchmark hardware and toolchain context without hostnames, serial numbers, device identifiers, or personal paths. Review staged changes before concise conventional commits. Review all history, ignored files, and untracked files before publication. Publish only under the established repository name `ilyric`.

## Archival Writing and Reference Validation

All project documentation, engineering reports, commit messages, and completion reports must use precise, grammatical, formal English suitable for an archival engineering record. Describe technical changes, evidence, uncertainty, and consequences without conversational framing, promotional language, agent-centric narration, or unsupported claims. Keep conventional commit subjects specific and intelligible independently of the development conversation.

Preserve completed planning and architecture reports as historical records. Record subsequent findings in new reports. The empirical reference device for the next validation gate is iPhone 16 running reported iOS 27.0.1; its exact build is Unknown until verified on that device. Do not substitute externally researched build metadata or treat the earlier provisional iPhone 16 Pro canvas as measured geometry.

Keep original captures, extracted frames, reference text/audio, crops, overlays, and copyright-bearing derivatives under ignored `reference-private/`. Confirm ignore behavior before processing and audit every staged change before committing or pushing. Public profiles may contain sanitized numerical measurements, provenance, uncertainty, fitted parameters, and evidence classifications, but no private paths or protected source content. Reference validation must explicitly report unavailable inputs; the public synthetic suite must work without the private corpus, network access, or an Apple Music subscription.

## Commit Attribution

When Codex materially contributes to a commit, append `Co-authored-by: Codex <codex@openai.com>` after a blank line in the commit message. Apply this convention only when the contribution is supported by the work performed; do not add it automatically to unrelated or unassisted commits. Preserve the human author and committer identities.

GitHub recognizes this co-author identity as [@codex](https://github.com/codex), as verified on an [OpenAI repository commit](https://github.com/openai/codex/commit/db22c91e61cc80defa5bbafc22bd8a8c7672e5e1). Follow GitHub's [co-author trailer format](https://docs.github.com/en/pull-requests/how-tos/commit-changes/creating-a-commit-with-multiple-authors). Commit-level co-author recognition does not guarantee inclusion in the repository Contributors listing. Do not replace human authorship or create artificial commits to influence contributor statistics.

When Claude materially contributes to a commit, append `Co-Authored-By: Claude <noreply@anthropic.com>` under the same conditions; a model-specific display name such as `Claude Opus 5.5` may precede the address. That address resolves to the GitHub account [@claude](https://github.com/claude), as verified on October 9, 2026. Include both trailers when both agents contributed materially.

Historical attribution changes require explicit approval, a verified recoverable backup, preservation of original authors, committers, dates, messages, change sequence, and repository contents except for the approved attribution metadata, and an explicitly approved lease-protected remote update. Retain the original backup until its removal is authorized.
