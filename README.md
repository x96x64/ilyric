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

The [S09 continuation report](docs/s09-typography-validation.md) supports a shared experimental Japanese base-size candidate across repeated S08/S09 observations. Relative vertical treatment during progressive appearance remains unresolved; complete state-controlled typography and native fidelity are not validated.
