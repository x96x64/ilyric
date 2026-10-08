# iLyric

iLyric is an independent experimental offline renderer under development. Its intended visual reference is the native Music application on iPhone running iOS 27. Neither visual fidelity nor production readiness has been demonstrated.

iLyric is not affiliated with, endorsed by, or sponsored by Apple.

## Planning Baseline

The [technical planning study](docs/planning-study.md) is preserved verbatim as the architectural baseline. Its recommendations require experimental validation. Its historical placeholder executable is superseded by the established name `ilyric`; its proposed release features are not implemented commitments. The initial architecture spike uses a shorter, entirely synthetic fixture rather than the study’s proposed measured scene.

No software license has been selected. No proprietary media, extracted Apple assets, or font files are included.

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

## Deferred Product Requirements

The [product requirements](docs/product-requirements.md) distinguish long-term user-input, synchronization, customization, delivery, and iconography goals from implemented experiments. They do not establish supported input formats, a finalized public CLI, provider access, or symbol-export permissions.
