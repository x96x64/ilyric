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

## Deferred Product Requirements

The [product requirements](docs/product-requirements.md) distinguish long-term user-input, synchronization, customization, delivery, and iconography goals from implemented experiments. They do not establish supported input formats, a finalized public CLI, provider access, or symbol-export permissions.
