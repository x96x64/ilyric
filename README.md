# iLyric

[![CI](https://github.com/x96x64/ilyric/actions/workflows/ci.yml/badge.svg)](https://github.com/x96x64/ilyric/actions/workflows/ci.yml)

iLyric is an independent experimental offline renderer under development. Its intended visual reference is the native Music application on iPhone running iOS 27. Neither visual fidelity nor production readiness has been demonstrated.

iLyric is not affiliated with, endorsed by, or sponsored by Apple.

## Planning Baseline

The [technical planning study](docs/planning-study.md) is preserved verbatim as the architectural baseline. Its recommendations require experimental validation. Its historical placeholder executable is superseded by the established name `ilyric`; its proposed release features are not implemented commitments. The initial architecture spike uses a shorter, entirely synthetic fixture rather than the study’s proposed measured scene.

iLyric source code is licensed under the [Apache License, Version 2.0](LICENSE). No proprietary media, extracted Apple assets, or font files are included; models, recordings, lyrics, and generated videos are subject to their own terms.

## Implementation and Release Planning

The [implementation-readiness and release plan](docs/implementation-release-readiness.md) records the intended transition to a supported open-source command-line product maintained by one person. It recommends audio-derived passage correspondence, bounded alignment, and measured complete-song qualification before broad visual expansion. License selection, reliable automatic synchronization, supported installation, and release qualification remain incomplete; no new implementation or license is introduced by the study.

## Audio-Derived Correspondence Preparation

The [preparation report](docs/audio-derived-correspondence-preparation.md) records model-free anchor matching, repeated-occurrence handling, baseline reproduction, and a pinned provisioning proposal. Whisper inference, bounded refinement, and acoustic M1 qualification remain pending approval; coarse anchors are not final timing estimates.

## Architecture Spike

The repository contains a deliberately narrow Swift Package prototype with a synthetic scene. See the [architecture-spike report](docs/architecture-spike.md) for measured results and limitations, and [developer experiment commands](docs/spike-commands.md) for reproduction.

## Physical-Reference Validation

The [physical-reference validation report](docs/physical-reference-validation.md) records initial measurements from private iPhone 16 references, typography discrepancies, motion fits, and unresolved questions. Public validation code and numerical results supplement the synthetic spike. Source captures remain private and are not required by the public test suite.

## Typography Calibration

The [native-space typography report](docs/typography-calibration.md) records shared-model fits, wrapping sensitivity, and unresolved Japanese state differences. Candidate parameters remain in validation tooling; a shared cross-script model and native typography fidelity are not yet established.

## State-Controlled Typography

The [Japanese state-control report](docs/state-controlled-typography.md) records repeated S08 geometry, state-dependent spacing evidence, and the missing S09 recording correspondence. Candidate parameters remain experimental; the shared Japanese model is not yet validated.

## S09 Typography Continuation

The [S09 continuation report](docs/s09-typography-validation.md) supports a shared experimental Japanese base-size candidate across repeated S08/S09 observations. At that gate, relative vertical treatment during progressive appearance remained unresolved; complete state-controlled typography and native fidelity were not validated.

## Common-Origin Glyph Validation

The [glyph-outline report](docs/glyph-outline-validation.md) supports a bounded experimental vertical treatment over the shared Japanese base configuration. Reverse recording holdouts justify a first measured typography slice with explicit appearance-event inputs. Native implementation, generality, and full Music fidelity remain unestablished; production rendering is unchanged.

## Experimental Japanese Lyrics Slice

The [measured-slice report](docs/lyrics-slice.md) records a separate deterministic native-space paragraph renderer and V09/V10 integration comparisons. Shared geometry is retained; progressive appearance remains provisional. [Developer commands](docs/lyrics-slice-commands.md) exercise an original synthetic fixture without private references. The existing `ilyric` scene and export path are unchanged.

## Progressive Appearance Calibration

The [appearance report](docs/progressive-appearance.md) records a shared softened progression candidate, reverse-recording holdouts, and unchanged Japanese geometry. The improvement remains experimental; native appearance and general timing fidelity are unvalidated. [Developer commands](docs/appearance-commands.md) preserve the prior hard-wipe path and provide an optional synthetic softened fixture.

## Experimental Latin Typography

The [Latin integration report](docs/latin-typography-integration.md) records a shared static configuration conditional on observed line structure, held-out geometry results, and Japanese nonregression. Native source breaks and automatic wrapping remain underidentified. [Developer commands](docs/latin-integration-commands.md) exercise original Latin fixtures without importing Japanese timing behavior.

## Experimental Motion and Composition

The [motion-composition report](docs/motion-composition.md) records a deterministic three-paragraph Latin/Japanese sequence, qualified English motion fits, and audiovisual validation. [Developer commands](docs/motion-composition-commands.md) produce original synthetic stills and a six-second video. Native timing, clipping, inactive treatment, and full-screen fidelity remain unvalidated.

## Latin Outline Motion Diagnostic

The [Latin outline report](docs/latin-outline-motion.md) separates common movement, relative residuals, appearance-support bias, and phase sensitivity. The bounded experiment retains the existing renderer and recommends a measured full-screen composition with explicit uncertainty. [Diagnostic commands](docs/latin-outline-commands.md) keep reference-dependent analysis private.

## Experimental Full-Screen Lyrics Composition

The [full-screen report](docs/full-screen-composition.md) records measured component placement around the existing lyric composition, deterministic native-space rendering, and audiovisual export. Original artwork and controls, a provisional fade, and a static background remain qualified approximations. [Developer commands](docs/full-screen-commands.md) render the synthetic scene without private references. Native Music fidelity remains unvalidated.

## Experimental Inactive Appearance

The [inactive-appearance report](docs/inactive-appearance.md) records the benchmark timeline audit, held-out Latin blur/contrast diagnostics, and an opt-in cached appearance treatment. Geometry, Japanese appearance, and the original benchmark path remain unchanged. [Developer commands](docs/inactive-appearance-commands.md) separate synthetic verification from private calibration. Native fidelity remains unvalidated.

## Experimental Local Input

The [local-input report](docs/local-input-integration.md) records a bounded path from supplied UTF-8 LRC and unprotected local audio to a complete experimental Lyrics video. The [input contract](docs/local-input-subset.md) and [developer commands](docs/local-input-commands.md) define exact line timing, multiline constraints, audio conversion, and resource limits. This path does not provide fine-grained synchronization, a finalized public CLI, or native Music fidelity.

## Experimental Project Configuration

The [configuration report](docs/project-configuration.md) records strict version-1 JSON preparation, supplied artwork/metadata, exact offsets, independent component visibility, and the separate complete-multiline demonstration. The [format contract and commands](docs/experimental-project-format.md) define the bounded experimental interface and original example generator. Ordinary LRC remains line-level; that gate left translated lyric display and fine-grained timing import deferred. Production `ilyric` behavior is unchanged.

## Experimental Enhanced-LRC Timing

The [timing integration report](docs/enhanced-lrc-integration.md) records exact supplied segment boundaries, whole-paragraph shaping, complete multiline progression, and version-2 format selection. The [subset and commands](docs/enhanced-lrc-subset.md) define supported syntax, Unicode/cluster restrictions, and enabled/disabled behavior. Ordinary LRC and version-1 projects remain compatible; color-glyph progression and native fidelity remain unqualified.

## Experimental TTML Timing

The [TTML integration report](docs/ttml-integration.md) records exact parent-relative paragraph/span intervals, explicit paragraph ends, multiline progression, and version-3 selection. The [subset and commands](docs/ttml-subset.md) define namespace, whitespace, XML safety, and compatibility limits. Versions 1 and 2 retain their prior contracts. This bounded importer does not implement TTML styling, provider-specific lyric profiles, or native Music fidelity.

## Lyrics Acquisition Feasibility

The [acquisition study](docs/lyrics-acquisition-feasibility.md) compares documented providers, content-use permissions, recording matching, local correction, and optional alignment. It recommends offline preparation and provenance before conditional provider lookup. API access does not establish permission to export lyrics into videos. No acquisition client, alignment system, or project-schema change is implemented by this study.

The [local Music cache feasibility report](docs/apple-music-local-cache-feasibility.md) distinguishes response-body reading from signed-request replay, records the limited local metadata inspection, and documents why cache integration remains unqualified. Legitimately supplied timing can avoid inference for matching recordings; acoustic alignment remains the fallback.

## Experimental Automatic Singing Alignment

The [alignment report](docs/automatic-alignment.md) evaluates a speech CTC baseline and a singing-specific model against licensed English/Japanese recordings. The [preparation commands](docs/alignment-commands.md) provide optional offline inference, preserved source mapping, reviewed corrections, and line-level TTML for the existing renderer. Model dependencies are separate from public tests. Accuracy, coverage, licensing, and the 60-second context limit prevent qualification for unattended or complete-song use; mandatory automatic synchronization remains incomplete.

## Singing-Alignment Refinement

The [refinement report](docs/alignment-refinement.md) reproduces the archived baseline, recovers two Japanese cases through explicit source-preserving pronunciation hypotheses, and evaluates English endpoint and incorrect-text controls. The [refinement commands](docs/alignment-refinement-commands.md) document optional overrides. Endpoint repair and automatic score-based acceptance remain unqualified; full-song synchronization remains blocked by measured correspondence and failure-detection limits.

## Deferred Product Requirements

The [product requirements](docs/product-requirements.md) distinguish long-term user-input, synchronization, customization, delivery, and iconography goals from implemented experiments. They do not establish supported input formats, a finalized public CLI, provider access, or symbol-export permissions.

## Independent Acoustic Coverage Validation

The [coverage report](docs/independent-acoustic-coverage.md) compares audio-only CTC evidence and a spectral proxy against reserved mismatch controls. The [diagnostic commands](docs/acoustic-coverage-commands.md) preserve input artifacts and mandatory review. Limited incremental detections do not establish reliable lyric correspondence; automatic acceptance and full-song synchronization remain unqualified.

## Singing-Aware Activity Evaluation

The [singing-activity report](docs/singing-vocal-activity.md) reproduces the frozen activity baselines and records a bounded candidate screen. Checkpoint-specific licensing and independently verified additional-singer annotations remain unresolved; no new model was provisioned or evaluated. The prospective protocol preserves mandatory review and does not qualify automatic full-song synchronization.

## Checkpoint Permission and Evaluation Readiness

The [veracity readiness assessment](docs/veracity-evaluation-readiness.md) records checkpoint permission, native dependency metadata, cumulative resources, and missing independent activity annotations. The [conditional evaluation procedure](docs/veracity-evaluation-procedure.md) and [unsent permission inquiry](docs/veracity-permission-inquiry.md) define the remaining preparation steps. Those historical gates did not provision or execute the model. The local-inference update below records subsequent authorization and execution; automatic synchronization remains incomplete.

The [permission and annotation preparation update](docs/checkpoint-permission-annotation-preparation.md) identifies the verified institutional contact, final unsent inquiry, minimum missing recording, and independent human annotation steps. That gate required further user action before provisioning; the later local-research scope is recorded below.

## Local veracity Inference Validation

The [local inference report](docs/local-veracity-inference.md) supersedes the procedural provisioning restriction above for explicitly authorized personal, noncommercial exploratory research. The pinned CPU diagnostic is executable and reproducible; checkpoint-specific licensing scope and independent vocal-activity accuracy remain unresolved. No developer contact is required by this workflow. The [deferred documentation cleanup](docs/deferred-documentation-cleanup.md) preserves the obsolete unsent inquiries until a dedicated cleanup milestone. Automatic acceptance and full-song synchronization remain disabled.

## Evaluation Resources

The [current resource policy](docs/evaluation-resource-policy.md) charges complete evaluation storage against the approved 15-GB ceiling. [Optional vocal-annotation intake](docs/vocal-annotation-intake.md) supports the independent research protocol; [readiness findings](docs/evaluation-storage-annotation-readiness.md) distinguish that protocol from personal review-first development.

## Personal Full-Song Preparation

The [review-first full-song prototype](docs/review-first-full-song.md) processes complete recordings through bounded English CTC windows. [Experimental commands](docs/full-song-commands.md) preserve unresolved occurrences and require explicit review before TTML export. Current measured coverage is insufficient to complete mandatory automatic synchronization.

## Bounded TIFA Passage Search

The [passage-search report](docs/tifa-passage-search.md) evaluates automatic overlapping candidates and chronological reconciliation against the frozen complete-song CTC results. Explicit skip and ambiguity states preserve reviewability, but TIFA support does not establish lyric correspondence. The separate [experimental commands](docs/tifa-passage-commands.md) preserve the existing renderer and correction workflow. Automatic synchronization remains incomplete.

## Audio-Derived Correspondence Evaluation

The [bounded Whisper evaluation](docs/audio-derived-correspondence-evaluation.md) records failed M1 coverage criteria, reproducible offline preparation, and the next narrowly scoped corrective experiment. It does not establish automatic synchronization or release readiness.

## Segment-Level Anchor Comparison

The [segment-level comparison](docs/segment-level-anchor-comparison.md) retains native Whisper segment text when heuristic word timestamps are unusable. Correct-region availability remained below 90% on every recording, and recognized lexical content was unchanged; M1 remains a no-go. The report identifies vocal separation before recognition as the next single architectural change.

## Release and Fidelity Decisions

The [decision record](docs/release-and-fidelity-decisions.md) establishes automatic synchronization and native Music Lyrics screen reproduction as equal primary objectives, selects Apache-2.0 for source code, and defines staged releases with parallel synchronization and visual-fidelity tracks. The [SF Symbols rights assessment](docs/sf-symbols-rights-assessment.md) records that exported-video use is not expressly licensed and defines a runtime-only policy.

## Vocal Separation Before Recognition

The [separation report](docs/vocal-separation-recognition.md) evaluates pinned Demucs vocal separation before Whisper recognition. Availability rose from 93 to 104 of 140 occurrences but remained below 90% on every recording, and lexical recognition coverage barely changed; M1 remains a no-go. Complete-sequence CTC alignment on separated vocals is the next single experiment.

## Complete-Sequence CTC Alignment on Separated Vocals

The [separated-vocal alignment report](docs/separated-vocal-ctc-alignment.md) aligns complete supplied lyrics to Demucs vocal stems. Retained estimates doubled from 53 to 106 of 140 occurrences and unresolved occurrences fell from 87 to 34; one unflagged short-line displacement prevents an M1 pass. Separated-vocal CTC is now the lead synchronization architecture, pending failure-detection and boundary work and a new locked evaluation set.

## Artwork-Derived Dynamic Background

The [background report](docs/artwork-background.md) records an opt-in deterministic reconstruction of the blurred, moving artwork-derived Lyrics background. Color, spatial structure, and vertical gradient generalize to held-out songs; motion remains provisional pending paused-playback captures.

## Vocal-Activity Boundary and Duration Rules

The [rules report](docs/vocal-activity-rules.md) withholds implausibly short estimates and trims leading vocal inactivity on separated stems. On the development recordings this removes the observed displacement and introductory-audio absorption; qualification on new locked recordings remains required.

## Runtime Control Symbols

The [control-symbol report](docs/control-symbols.md) records an opt-in runtime SF Symbols icon set fitted to reference screenshots; rendered ink bounds match the measured controls within two native pixels. Symbols are never bundled, and public fixtures continue to use original icons.
