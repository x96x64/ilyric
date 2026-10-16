# Exact Scalar Durations for Presentation

## Failure and Cause

The native report `fill-boundary-native-verification.md` recorded an unresolved package-API case with focus lead `Time(1, 144_115_188_075_855_872)`, supplied spans at 0.999–0.9995 s and 0.9995–1 s, and a following paragraph at 1 s. The allocation correction succeeded independently, but renderer initialization still trapped in the pre-existing `Time.-` path used by `ParagraphInput.evaluate`. The original consumer implementation reproduced signal 5 again before this correction. This report supersedes that specific unresolved initialization and sampled-rendering finding; it does not revise the historical results.

The requested duration can be meaningful as a scalar even when its exact rational denominator cannot fit in a `Time`. Subtracting 1999/2000 from the generated deadline requires the denominator 125 × 2^57, which exceeds Int64. Paragraph phase was evaluated during renderer initialization even when progress was already clamped outside the interval. Later focus and inactive-appearance evaluation also formed rational differences solely to convert them to scalar seconds.

## Correction and Preserved Contracts

The package-only `Time.seconds(since:)` operation preserves the preceding normalized arithmetic and Double result whenever its intermediate operations and normalized numerator are representable. Otherwise it computes the signed numerator difference and positive common denominator with two-word integer intermediates, then converts the quotient to Double. Each signed product has magnitude below 2^126, so the signed difference fits those two words. Signed magnitude conversion avoids cancellation between the high and low words. It also preserves a nonzero difference between distinct rational inputs whose individual Double values coincide.

Paragraph progress, phase, vertical age, focus response, and inactive treatment use this scalar operation. Existing rational comparisons still determine interval membership and exact completion boundaries. No source timestamp, TTML value, focus event, smoothing constant, external validator, Codable representation, public API, Time storage, or rational arithmetic operator changes. The correction requires no new dependency or minimum operating-system change; it uses existing fixed-width integer facilities rather than the newer Int128 runtime.

## Native Verification

Verification used Apple silicon, macOS 27.0.1, Apple Swift 6.4, and Command Line Tools. Fixtures use original text and generated silent PCM. Raw logs, arithmetic-oracle output, and generated frames remain outside Git.

- The original rendering consumers reproduced signal 5 with the strengthened native scene test before correction.
- The focused run passed 83 Swift tests: 11 timeline tests, 61 screen tests, and 11 departure tests. The extreme regression now initializes two renderers for both 1/2^56 and 1/2^57 focus leads, samples before, at, and after departure, and compares reordered full frames against a fresh renderer. Isolated complete-fill pixels disable lift, scale, and glow only in the fixture because those independent effects legitimately settle after departure.
- Ordinary scalar differences match the preceding normalized arithmetic bit for bit across 49 signed input pairs. Cancellation and Int64 boundary regressions remain separate assertions.
- An independent deterministic oracle compared 2,087 signed and boundary cases with Python Fraction subtraction followed by float conversion. The observed maximum error was two Double units in the last place. This is a measured result for those cases, not a universal correctly rounded guarantee.
- Debug and optimized builds, whole-repository Swift formatting, and the diff check passed.
- At report preparation, the complete supported Swift suite was still executing. Its subsequent result belongs in the pull-request verification record rather than a report-only follow-up commit.

The preceding main commit, `685fdd63f563475ac2b4d083d0e61022a1ab8d08`, passed CI run [38834308176](https://github.com/x96x64/ilyrics/actions/runs/38834308176): 228 Swift tests and 219 Python tests, with no emitted signal retry, unexpected-signal termination, or crash-report group in the reviewed Swift log. That result qualifies the preceding source, not this follow-up. Follow-up CI results belong in the pull-request verification record.

## Remaining Limits

This correction addresses scalar elapsed durations used in the demonstrated rendering path. Time storage and rational addition/subtraction remain bounded by their existing Int64 representation; arbitrary clock edits, rational shifts, or other parameter combinations are not thereby qualified. Scalar animation calculations still use Double. The tests establish the original extreme case and the specified arithmetic cases, not unrestricted arbitrary-precision rational timeline support.

The historical hosted-runner SIGSEGV remains without an established root cause. This deterministic SIGTRAP correction does not establish a fix for that separate intermittent failure. Reference-device gradient and introduction matching, Japanese acoustic accuracy, private model qualification, and minimum-supported-system runtime verification remain outside this correction. No release version or date is assigned, and no tag or publication is created.
