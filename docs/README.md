# Documentation

## Current Documents

- [Command-Line Interface](command-line-interface.md): commands, options, and environment variables
- [Roadmap to the Stable Release](roadmap-to-stable.md): decisions in force, remaining work, and confirmation points
- [Distribution](distribution.md): release archive and the Homebrew, npm, and pip channels for the preview
- [SF Symbols and System Font Rights Assessment](sf-symbols-rights-assessment.md): the runtime-only symbol policy
- [Technical Planning Study](planning-study.md): the original architectural baseline, preserved verbatim

## Engineering Reports

The reports below record measurements, decisions, and their limitations in the order the work was done. They are historical records: later reports supersede earlier conclusions where they say so, and they are not revised afterwards. Commands in older reports refer to development probes that were removed after commit `9670573`, when the `ilyric` command replaced them.

### Planning and Decisions

- 2026-10-08 — [Product Requirements](reports/product-requirements.md)
- 2026-10-09 — [Deferred Documentation Cleanup](reports/deferred-documentation-cleanup.md)
- 2026-10-09 — [Evaluation Resource Policy](reports/evaluation-resource-policy.md)
- 2026-10-09 — [Implementation Readiness and Open-Source Release Plan](reports/implementation-release-readiness.md)
- 2026-10-09 — [Release and Fidelity Decisions](reports/release-and-fidelity-decisions.md)
- 2026-10-11 — [Model Template Distribution](reports/model-template-distribution.md)

### Architecture and Rendering

- 2026-10-07 — [Architecture Spike](reports/architecture-spike.md)
- 2026-10-08 — [First Measured Full-Screen Lyrics Composition](reports/full-screen-composition.md)
- 2026-10-08 — [State-Controlled Inactive-Lyric Appearance](reports/inactive-appearance.md)
- 2026-10-08 — [First Measured Lyrics Motion and Composition Slice](reports/motion-composition.md)
- 2026-10-09 — [Artwork-Derived Dynamic Background](reports/artwork-background.md)
- 2026-10-09 — [Artwork Background Motion](reports/artwork-background-motion.md)
- 2026-10-09 — [Runtime Control Symbols](reports/control-symbols.md)
- 2026-10-10 — [Control Auto-Hide](reports/control-auto-hide.md)
- 2026-10-10 — [First Complete Real-Song Video](reports/first-real-song-video.md)
- 2026-10-10 — [Instrumental-Gap Indicator and Pause State](reports/gap-indicator.md)
- 2026-10-10 — [Lyrics Motion Timing and Stagger](reports/lyrics-motion-timing.md)
- 2026-10-10 — [Reference Clock Correction and Word Motion](reports/reference-clock-and-word-motion.md)
- 2026-10-10 — [Title Marquee](reports/title-marquee.md)
- 2026-10-11 — [Artwork Background Calibration](reports/artwork-background-calibration.md)
- 2026-10-11 — [Background Vocals](reports/background-vocals.md)
- 2026-10-11 — [Gap Slot Collapse](reports/gap-slot-collapse.md)
- 2026-10-11 — [Playback Smoothness, Fill Lead, and Control Transition](reports/playback-smoothness-and-fill-lead.md)
- 2026-10-11 — [Word Fill Continuity and Emphasis Selection](reports/word-fill-continuity.md)
- 2026-10-11 — [Word Fill Smoothing](reports/word-fill-smoothing.md)

### Typography and Reference Validation

- 2026-10-07 — [Physical-Reference Validation](reports/physical-reference-validation.md)
- 2026-10-07 — [Native-Space Typography Calibration](reports/typography-calibration.md)
- 2026-10-08 — [Common-Origin Glyph-Outline Validation](reports/glyph-outline-validation.md)
- 2026-10-08 — [Latin Glyph-Outline Motion Validation](reports/latin-outline-motion.md)
- 2026-10-08 — [Measured Latin Typography Integration](reports/latin-typography-integration.md)
- 2026-10-08 — [First Measured Japanese Lyrics Slice](reports/lyrics-slice.md)
- 2026-10-08 — [Progressive Appearance Calibration](reports/progressive-appearance.md)
- 2026-10-08 — [S09 State-Controlled Typography Validation](reports/s09-typography-validation.md)
- 2026-10-08 — [State-Controlled Japanese Typography Refinement](reports/state-controlled-typography.md)

### Lyrics Input

- 2026-10-08 — [Bounded Enhanced-LRC Timing Integration](reports/enhanced-lrc-integration.md)
- 2026-10-08 — [Experimental Enhanced-LRC Subset](reports/enhanced-lrc-subset.md)
- 2026-10-08 — [Experimental Project Format](reports/experimental-project-format.md)
- 2026-10-08 — [Experimental Local Input Integration](reports/local-input-integration.md)
- 2026-10-08 — [Experimental Local Input Contract](reports/local-input-subset.md)
- 2026-10-08 — [Lyrics Acquisition Feasibility Study](reports/lyrics-acquisition-feasibility.md)
- 2026-10-08 — [Versioned Experimental Project Configuration](reports/project-configuration.md)
- 2026-10-08 — [Bounded TTML Timing Integration](reports/ttml-integration.md)
- 2026-10-08 — [Experimental TTML Subset](reports/ttml-subset.md)
- 2026-10-09 — [Apple Music Local Lyrics Cache Feasibility](reports/apple-music-local-cache-feasibility.md)

### Synchronization Research

- 2026-10-08 — [Singing-Alignment Refinement](reports/alignment-refinement.md)
- 2026-10-08 — [Automatic Singing Alignment Experiment](reports/automatic-alignment.md)
- 2026-10-08 — [Checkpoint Permission and Annotation Preparation](reports/checkpoint-permission-annotation-preparation.md)
- 2026-10-08 — [Independent Acoustic Coverage Validation](reports/independent-acoustic-coverage.md)
- 2026-10-08 — [Singing-Aware Vocal Activity Evaluation](reports/singing-vocal-activity.md)
- 2026-10-08 — [veracity Evaluation Procedure](reports/veracity-evaluation-procedure.md)
- 2026-10-08 — [veracity Evaluation Readiness](reports/veracity-evaluation-readiness.md)
- 2026-10-09 — [Audio-Derived Correspondence Evaluation](reports/audio-derived-correspondence-evaluation.md)
- 2026-10-09 — [Audio-Derived Correspondence Preparation](reports/audio-derived-correspondence-preparation.md)
- 2026-10-09 — [Evaluation Storage and Vocal Annotation Readiness](reports/evaluation-storage-annotation-readiness.md)
- 2026-10-09 — [Local veracity Inference Validation](reports/local-veracity-inference.md)
- 2026-10-09 — [M2 Qualification Procedure](reports/m2-qualification-procedure.md)
- 2026-10-09 — [Review-First Full-Song Alignment Prototype](reports/review-first-full-song.md)
- 2026-10-09 — [Segment-Level Anchor Comparison](reports/segment-level-anchor-comparison.md)
- 2026-10-09 — [Complete-Sequence CTC Alignment on Separated Vocals](reports/separated-vocal-ctc-alignment.md)
- 2026-10-09 — [Bounded TIFA Passage-Candidate Search](reports/tifa-passage-search.md)
- 2026-10-09 — [Vocal-Activity Boundary and Duration Rules](reports/vocal-activity-rules.md)
- 2026-10-09 — [Vocal Annotation Intake](reports/vocal-annotation-intake.md)
- 2026-10-09 — [Vocal Separation Before Recognition](reports/vocal-separation-recognition.md)
- 2026-10-10 — [M2 Locked Evaluation](reports/m2-locked-evaluation.md)
- 2026-10-10 — [Separated-Vocal Acceptance and Boundary Rules](reports/separated-vocal-acceptance.md)
- 2026-10-10 — [Word-Level Alignment](reports/word-level-alignment.md)
- 2026-10-11 — [Word Confidence Fallback](reports/word-confidence-fallback.md)
- 2026-10-11 — [Preview Qualification Procedure](reports/preview-qualification-procedure.md)

### Native Pipeline

- 2026-10-11 — [Core ML Port Feasibility](reports/core-ml-port-feasibility.md)
- 2026-10-11 — [Native Alignment Pipeline](reports/native-alignment-pipeline.md)
- 2026-10-11 — [Native Model Installation and Decoding](reports/native-model-installation.md)

### Historical Developer Commands

- 2026-10-07 — [Reference-Validation Commands](reports/reference-validation-commands.md)
- 2026-10-07 — [Running the iLyric Architecture Spike](reports/spike-commands.md)
- 2026-10-07 — [Typography Calibration Commands](reports/typography-calibration-commands.md)
- 2026-10-08 — [Acoustic Coverage Diagnostic Commands](reports/acoustic-coverage-commands.md)
- 2026-10-08 — [Experimental Alignment Preparation](reports/alignment-commands.md)
- 2026-10-08 — [Alignment Refinement Commands](reports/alignment-refinement-commands.md)
- 2026-10-08 — [Progressive Appearance Commands](reports/appearance-commands.md)
- 2026-10-08 — [Full-Screen Lyrics Experiment Commands](reports/full-screen-commands.md)
- 2026-10-08 — [Glyph-Outline Validation Commands](reports/glyph-outline-commands.md)
- 2026-10-08 — [Inactive-Appearance Commands](reports/inactive-appearance-commands.md)
- 2026-10-08 — [Latin Typography Integration Commands](reports/latin-integration-commands.md)
- 2026-10-08 — [Latin Outline Diagnostic Commands](reports/latin-outline-commands.md)
- 2026-10-08 — [Local Input Experiment Commands](reports/local-input-commands.md)
- 2026-10-08 — [Experimental Lyrics Slice Commands](reports/lyrics-slice-commands.md)
- 2026-10-08 — [Motion and Composition Commands](reports/motion-composition-commands.md)
- 2026-10-08 — [S09 Typography Validation Commands](reports/s09-typography-commands.md)
- 2026-10-08 — [State-Controlled Typography Commands](reports/state-controlled-typography-commands.md)
- 2026-10-08 — [CPJKU veracity Final Permission Inquiry](reports/veracity-final-permission-inquiry.md)
- 2026-10-08 — [CPJKU veracity Checkpoint Permission Inquiry](reports/veracity-permission-inquiry.md)
- 2026-10-09 — [Experimental Full-Song Preparation Commands](reports/full-song-commands.md)
- 2026-10-09 — [Experimental TIFA Passage-Search Commands](reports/tifa-passage-commands.md)

## Data

Numerical profiles, fitted parameters, and fixtures referenced by the reports are kept beside them: `alignment-data/`, `reference-data/`, `enhanced-lrc-data/`, `local-input-data/`, `project-configuration-data/`, and `ttml-data/`. They contain sanitized measurements only. `media/` holds documentation images generated by the `DocumentationMedia` target from the public-domain lyrics in `fixtures/demo/`, synthetic timing, and silent audio.
