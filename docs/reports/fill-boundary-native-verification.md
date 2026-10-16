# Fill Boundary Native Verification

## Scope and Evidence

This report records the macOS follow-up to `fill-boundary-counterexample-review.md` and supersedes its unresolved schedule, late-segment, and raster-endpoint findings for the synthetic cases described below. The earlier reports remain historical records. The source baseline is `17752d93e29d0a6fcff2a83985ee5b546567ff7e`. Verification used Apple silicon, macOS 27.0.1, and Apple Swift 6.4 with Command Line Tools. These are native macOS execution results, not measurements of the reference iPhone or a claim of visual equivalence to native Music.

All new fixtures contain original identifiers and generated silent PCM. The native frame fixtures use the original icon set. Generated verification files, raw logs, and isolated installation environments remain outside the committed source tree. No private recording or reference image was published.

## Reproduction and Correction

### Exact Generated Fractions

The four accepted TTML inputs `0.000001s`, `0.000003s`, `0.000999s`, and `0.000001ms` all produced `Timestamp bounds` on macOS after the initial deadline clamp and before the derived-time correction. The correction preserves exact package-generated fractions. The ordinary constructor, externally decoded values, and TTML parsing rules retain their existing limits. JSON cannot grant generated-value authority, and encoded generated values lose that authority when decoded as external input.

### Actual Focus Departure

The seven-test synthetic departure suite recorded ten expectation failures before the subsequent local correction; its ordinary-motion pixel control passed. The failing cases covered empty LRC entries, a following nonempty line whose led focus precedes an empty entry, sub-millisecond gap and explicit-release boundaries, the final audio endpoint, multiple late spans, and incomplete raster fill after the numerical endpoint.

Focus, gap, and release events are now compiled before paragraph appearance. The event times, orders, paragraph indices, and gap indices follow the preceding rules. A paragraph's presentation deadline is its actual next focus event, capped at the decoded audio endpoint. Empty entries do not receive an invented lyric lead. Gap and explicit-release events can impose an earlier deadline; a final held line cannot continue filling beyond the audio.

### Ordered Late Intervals

An interval already within the actual deadline remains unchanged unless it overlaps the fallback start needed for a later interval. When a suffix cannot fit, that affected suffix is assigned consecutive, equal rational intervals within the available time. The beginning of its first interval is retained when it precedes the deadline; otherwise the existing 1 ms fallback is used, bounded by zero. A preceding interval joins the suffix only if it would overlap that fallback. Earlier intervals remain exact. This is a bounded presentation fallback, not a reference-device measurement or an acoustic timing change.

For a positive focus residence, adjusted intervals remain positive, ordered, and within the deadline, including the synthetic near-zero example. A paragraph superseded by an opening gap at time zero has no positive residence; its existing schedule and unfocused appearance are retained rather than inventing a pre-zero interval. Source text ranges, segment count, original lyric timestamps, and TTML data remain intact. Only changed replacement values receive internal rational authority. A retained source-derived begin uses the ordinary validator even when its end changes. The independent review found a 1 ns retained begin that bypassed this distinction; macOS reproduced the unexpected acceptance before correction, and the final regression requires the original timestamp rejection.

An independently identified package-API case used focus lead `Time(1, 72_057_594_037_927_936)` and two supplied spans at 0.999–0.9995 s and 0.9995–1 s. The first allocation implementation trapped with signal 5 in the isolated native test process. Division now cancels common factors and checks every new integer product and sum before constructing fractions. If an equal subdivision is not representable, already supplied interior starts are used when they form an exact ordered allocation. Otherwise a descriptive input error replaces the trap; timestamps are not rounded. The reported extreme case now succeeds. The CLI's existing measured leads do not require this fallback.

### Visible Fill Completion

The native raster test confirmed that presentation progress of one did not establish full ink at focus departure: the existing centered moving average still incorporated the earlier unfilled portion. Its requested width is now tapered only when its future half-window would extend beyond actual departure. The width reaches zero at the deadline, preserving a continuous approach to complete fill. With the measured 0.12 s window, this adjustment is confined to the final 0.06 s before departure. It also applies to an uncompressed numerical interval when its existing smoothing would continue beyond departure; a 4.18–4.19 s interval before a 4.2 s departure retains those exact times while its boundary-adjacent pixels change. Full pixel identity is therefore asserted only outside this affected boundary behavior, not for every numerically uncompressed span. The fitted smoothing width, edge width, lift, and emphasis parameters are unchanged.

The isolated raster regression disables lift, emphasis scale, and glow only in its synthetic test fixture. At the deadline its raw glyph pixels equal the fully completed pixels 61 ms later, while an immediately earlier frame differs. An ordinary interval ending comfortably before departure remains pixel-identical to the preceding renderer at six sampled times. Existing English/Japanese random-access and fresh-renderer comparisons remain enabled.

The internal deadline is excluded from Codable input and output. External JSON cannot inject it. Canvas adaptation preserves the runtime value.

## Verification Results

- Initial Cloud correction plus the local native frame test: 214 Swift tests passed.
- Derived-fraction follow-up: 216 Swift tests passed; the focused input/core run passed 27 tests.
- Actual-departure correction: the focused run passed 35 tests and the subsequent full run passed 224 tests.
- Final provenance, overflow, adaptation, and zero-residence follow-up: the focused run passed 38 tests, including all preceding regressions. The full-suite run for this final candidate and the independent source re-review are in progress; no final-head CI result is claimed.
- Debug and optimized builds completed successfully. The ordinary debug executable was rebuilt for command tests that launch the repository's debug binary.
- Whole-repository Swift formatting lint and `git diff --check` passed before the final documentation update.
- The existing packaging script built the archive, npm package, and platform wheel using the unchanged `1.3.0` identifier solely for local installation checks. This does not designate or publish a new release. Offline npm installation and dependency-free, index-disabled pip installation succeeded in separate temporary prefixes. Both installed executables ran `doctor` successfully and resolved templates from their own installation prefixes.

The archive and isolated-install smoke tests preceded the final arithmetic and metadata follow-ups; their result qualifies the unchanged packaging and template lookup, not the later rendering code.

The local Swift Testing toolchain required explicitly loading its installed macro library for test compilation in an isolated scratch build. No dependency, package manifest, product behavior, or global toolchain configuration was changed to accommodate that issue.

## CI and Remaining Qualification

At the start of this follow-up, remote main remained `17752d9` and its latest CI was [38821236406](https://github.com/x96x64/ilyrics/actions/runs/38821236406), which passed. That result does not qualify the new patch head. The final verification update records any subsequent pull-request CI separately.

The historical child-process exit 11 remains without a captured root cause. Passing local command tests do not establish that the intermittent hosted-runner crash is fixed. Crash-report capture and signal diagnostics remain enabled.

The correction qualifies the listed synthetic timing and raster cases. It does not establish reference-device gradient matching, the intro indicator's final expansion and settling, general Japanese singing accuracy, or alignment of English-led Japanese lines. The optional private model-rebuild path, model consumption and durability, further malformed-image integration, and minimum-supported-macOS qualification also remain separate checks. Existing private material on the Mac was not treated as evidence without a specific comparison.

Homebrew-tap, dependency versions, external input rules, release workflows, and publication settings were not changed. No final release version or date is assigned, and no tag or release was created.
