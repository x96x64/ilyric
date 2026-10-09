# Release and Fidelity Decisions

## Status

October 9, 2026. This record documents maintainer decisions made after the [segment-level anchor comparison](segment-level-anchor-comparison.md). It supersedes the sequencing in the [implementation-readiness and release plan](implementation-release-readiness.md) where the two conflict; that plan remains preserved as a historical record. No decision below establishes synchronization accuracy, visual fidelity, or release readiness.

## Product Objectives

iLyric has two primary objectives of equal weight:

1. **Automatic synchronization** of user-supplied lyric text with the corresponding singing recording.
2. **Faithful reproduction of the native Music Lyrics screen** on iPhone running iOS 27, including the artwork-derived dynamic background, lyric blur and appearance, interface materials, controls and symbols, typography, and motion.

The earlier rule that visual implementation resumes only after M2 and an M3 round-trip is withdrawn. Synchronization and visual fidelity proceed as independent tracks with separate evidence gates.

## Release Stages

The maintainer selected all three stages defined by the release plan, in order:

| Stage | Entry Condition |
| --- | --- |
| Experimental source release | Apache-2.0 license, notices, contribution guidance, model-free continuous integration, and a publication audit |
| Public preview | Qualified English automatic line synchronization with correction-to-export (Track A through A3), the background, control, and lyric-appearance gates (B1, B2, and B4), and the supported command-line interface |
| Stable release | All Track B gates within the declared visual scope, release qualification, clean installation, notices, and a software bill of materials |

## Software License

The maintainer selected **Apache-2.0** for iLyric source code. This resolves the license decision in milestone M0. Third-party model, dependency, and content rights remain separate obligations.

## Track A: Synchronization

| Gate | Scope |
| --- | --- |
| A1 | One permissively licensed vocal-separation stage before audio-only recognition, evaluated under unchanged M1 criteria. If it fails, the next single step is a bounded comparison with one singing-specific aligner. |
| A2 (M2) | Complete-song English qualification on a locked set with newly supplied recordings and blinded maintainer annotation |
| A3 (M3) | Efficient correction and complete export, with measured correction effort |

Model provisioning, downloads, and storage beyond the current ceilings require explicit approval with exact artifact identities and sizes.

## Track B: Visual Fidelity

| Gate | Scope |
| --- | --- |
| B1 | Artwork-derived dynamic background: color extraction, gradient structure, blur, and temporal variation, including repeatability across playback |
| B2 | Controls and symbols: runtime SF Symbols under the [rights assessment](sf-symbols-rights-assessment.md), with measured size, weight, opacity, and states |
| B3 | Interface materials behind controls and sliders |
| B4 | Lyric appearance: Japanese and mixed-script inactive blur, Latin progressive highlighting, and automatic wrapping |
| B5 | States and transitions: instrumental-gap indicator, pause and resume, seeking, and song end |
| B6 | Apple Music Sing presentation with supplied fine timing |
| B7 | System-chrome approximations, edge-to-edge `adapt`, Lyrics Translation display, and customization |

Each gate freezes reference states, comparison regions, and acceptance thresholds before fitting, reserves held-out captures, and keeps the public suite independent of private media. Pixel identity is not a criterion; geometry, appearance, and motion are qualified separately against measured device repeatability. Reconstructed materials are iLyric models, not Apple's private implementation. Metal remains subject to a measured requirement.

The maintainer can supply additional captures from the reference iPhone 16 under the recorded settings. Each gate specifies its required captures beforehand. The exact iOS build remains Unknown until read on that device.

## Repository Conventions

- All documentation titles and headings use MLA headline-style title case, as required by `AGENTS.md`; an automated check will enforce this.
- The README and command-line interface follow conventions of established tools such as ripgrep, fd, bat, GitHub CLI, Git, FFmpeg, and yt-dlp: a concise README with installation, usage, and documentation links, and conventional subcommands, help, version, exit statuses, and stream separation.
- Commits remain atomic and conventional so that history is reviewable. A later dedicated cleanup milestone will consolidate documentation and naming through ordinary commits. Rewriting published history requires separate explicit approval under `AGENTS.md`.
- Commits with material contribution from Claude carry a `Co-Authored-By: Claude <noreply@anthropic.com>` trailer; the address resolves to the GitHub account @claude. Contribution guidance acknowledges Codex and Claude. Historical commits are not rewritten for this purpose.
