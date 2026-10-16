# Scoped Prepublication Verification

## Baseline and Scope

The inspected repository is `x96x64/ilyrics`. The initial clean checkout was on `work` at `17752d93e29d0a6fcff2a83985ee5b546567ff7e`. GitHub's connected commit lookup for `main` returned that same commit. No newer main commit was observed at the initial lookup. The task branch is `fix/scoped-prepublication-verification`, based on that exact commit. Repository `AGENTS.md` was read. The adjacent `homebrew-tap` repository was not modified or inspected internally.

The only production change addresses the demonstrated fill/focus boundary calculation in `Sources/LyricsInputMac/LocalScene.swift`. The maintainer explicitly selected presentation-only compression and advancement while preserving source singing/alignment timing, TTML, and focus events. No version, release date, tag, publication workflow, approval gate, credential, dependency, platform architecture, or unrelated visual parameter was changed.

The correction, regression tests, and Unreleased entry are committed as `efb98b53e107bcbc11f4d6bfd8bde9dddb3298bb` (`fix(lyrics): bound presentation fill by the next focus deadline`). A separate documentation commit records this report. The ordinary task-branch push failed at the configured proxy connection; no remote branch, draft PR, or patch-head CI result was established. Main remained at the base commit in the final read-only connector lookup. Local commits and an exported patch provide the reviewable handoff. No release or package publication was invoked.

## Fill Boundary Reproduction and Correction

The previous calculation limited `stop` to the next-focus deadline, then computed `max(begin + 1 ms, stop)`. This second operation could exceed the deadline. A synthetic rational calculation reproduced the defect before the source edit. These results are arithmetic evidence, not execution of Swift, acoustic measurements, or reference-device measurements.

For a next-line onset of 5.100 s, a preceding line onset of zero, and a focus lead of 0.900 s, the deadline is 4.200 s. Source ends are 4.300 s unless otherwise indicated.

| Presentation Start | Previous End | Corrected Start | Corrected End |
| --- | --- | --- | --- |
| 4.198 s | 4.200 s | 4.198 s | 4.200 s |
| 4.1995 s | 4.2005 s | 4.1995 s | 4.200 s |
| 4.200 s | 4.201 s | 4.199 s | 4.200 s |
| 4.202 s | 4.203 s | 4.199 s | 4.200 s |

A supplied interval from 4.1995 to 4.19975 s also previously ended at 4.2005 s because of the existing 1 ms floor; its corrected presentation interval ends at 4.200 s. The source interval remains unchanged. A normal interval from 1 to 2 s remains unchanged.

The correction caps the final presentation end after the existing minimum-duration calculation. An earlier presentation start is preserved. A start at or beyond that end moves to at most 1 ms before the deadline, bounded by zero. The 1 ms value reuses the existing fallback duration; no new reference parameter is introduced. Close to zero, the available interval can be shorter: a synthetic span at 0.00015–0.0002 s before a 0.0001 s focus deadline becomes a presentation interval of 0–0.0001 s. Under the existing valid-input contracts, each computed next-focus deadline is strictly positive, because it lies after the nonnegative preceding onset.

This changes only presentation intervals that would otherwise overrun an existing deadline. It does not change source entries, source ranges, paragraph intervals, parser output, TTML bytes, focus events, scrolling, opacity, blur, or the measured fill/focus leads. Intervals without a deadline retain their prior behavior.

Four new parameterized or ordinary tests in `DenseFocusTests.swift` cover Latin/Japanese TTML boundaries, dense LRC with zero/measured fill lead, a late Japanese span near zero, and unchanged bounded fill with a supplied instrumental gap. Assertions cover nonnegative positive intervals, completion by the deadline, unchanged source entries and paragraph timing, exact focus boundaries, range preservation, and reverse-order evaluation. Existing simultaneous distinct LRC onsets and overlapping TTML paragraphs remain rejected. These new tests have not been compiled or executed in Cloud.

The independent arithmetic reproduction can be repeated without Swift:

```sh
python3 - <<'PY'
from fractions import Fraction as F
d = F(21, 5)
for start in [F(2099, 500), F(8399, 2000), d, F(2101, 500)]:
    old_end = max(start + F(1, 1000), min(F(43, 10), d))
    a, b = start, old_end
    if b > d:
        b = d
        if a >= b:
            a = max(F(0), b - F(1, 1000))
    assert F(0) <= a < b <= d
    print(start, old_end, a, b)
PY
```

## CI and Crash Evidence

- [CI 38821236406](https://github.com/x96x64/ilyrics/actions/runs/38821236406), at the unchanged base commit, completed successfully. Full Swift job logs report 209 tests across the selected suites; Python logs report 213 public validation tests and six release-guard tests. Build and formatting steps passed. These results predate this patch.
- The full Swift log contains one actual VideoLayoutTests run, no actual signal-retry warning, and no emitted crash-report group. Echoed diagnostic shell code is not evidence of an executed warning or crash report. The final crash-report step was skipped because the job succeeded. The existing retry and diagnostic coverage are unchanged.
- [CI 38736369400](https://github.com/x96x64/ilyrics/actions/runs/38736369400), at `5402931be9ab096f226729380d940616ff163d39`, records `CommandSafetyTests.untaggedAudioRendersAndHeaderOptionsAreCheckedFirst` returning child status 11 after Reading Audio, Separating Vocals skip, and Aligning Lyrics skip. The log does not establish a stack or capture the child's termination reason. The handoff identifies this as SIGSEGV; the preserved log alone records status 11. It remains distinct from the checkpoint SIGTRAP and has no demonstrated causal correction.
- Both inspected Swift jobs used macOS 26.6.2 (25G83), Xcode 26.6 (17F113), and Swift 6.3.3, targeting arm64. A deployment target label of macOS 14 in test output is not execution on macOS 14.
- The cancelled documentation-head run 38820710696 is not classified as a product defect. The existing Node.js action-runtime deprecation warning is unrelated and unchanged.

The original synthetic crash reproducer remains:

```sh
swift build --build-tests
swift test --disable-xctest --filter LyricsInputTests.CommandSafetyTests/untaggedAudioRendersAndHeaderOptionsAreCheckedFirst
```

That test generates a one-second 48 kHz mono tone and two supplied LRC lines at 0.10 and 0.60 s, then runs the debug `ilyrics render` command. On failure, preserve its complete stderr, termination reason/status, and the matching `ilyrics` or `swiftpm-testing-helper` diagnostic report. A passing rerun does not resolve the original failure.

## Bounded Review of Other Authorized Paths

| Area | Source and Existing Evidence | Remaining Limit |
| --- | --- | --- |
| Output preservation | `Options.swift` rechecks the destination, uses exclusive rename without force, rejects directories/input aliases, and cleans staged text files. Align and Render use those helpers. Existing output/command safety tests passed in base CI. | No new native integration run; no broader filesystem guarantee. |
| Model acquisition and transactions | Downloads verify SHA-256 before replacement. Installation stages separately, locks mutation, recovers journals, and restores the marker last. Existing model safety/transaction tests passed in base CI. | Actual rebuild, concurrent consumption during removal, external filesystems, power-loss durability, and macOS 14 remain unqualified. The prior production-body SIGKILL harness was not rerun here. |
| Checkpoint archive | Existing central/local header and entry bounds remain intact; malformed ZIP regression coverage is preserved. | Tensor shape products and storage indexing remain a source-review concern without a new native failing reproduction. No parser expansion or speculative hardening was performed. |
| Focus, fill appearance, and scrolling | `InactiveTreatment` has a 0.15 s fitted transition; Latin timed ink is blended separately from cached inactive support. Subpixel interpolation and scrolling remain separate mechanisms. | Reference disagreement cannot be established from source alone. No white-hold or blur workaround was added. |
| Gradient and intro dots | The existing word-motion edge and fitted gap parameters are preserved. Gap scale remains sinusoidal, with separate fill/visibility and focus ownership. | Final expansion/settling and gradient matching require the missing native captures and temporal comparisons. |
| Reels paragraphs | Paragraph construction rejects more than eight shaped rows; viewport clipping and overflow scrolling occur after layout. Existing safe-area tests preserve text and timing through adaptation. | Long content clipping and row rejection must be measured separately on macOS. No splitting, shrinking, or new row limit. |
| Japanese alignment | Latin units are interpolated around Japanese acoustic labels. Proposal extension can shorten the prior line. Recognition's existing experimental acceptance behavior, fallback interpolation, TTML export, and presentation leads are separate stages. | No audio, manual timing, or private reference corpus is available. No acoustic or Japanese accuracy claim; the prior five-song evaluation remains only partly reviewed. |
| PNG artwork | ImageIO checks byte/dimension/frame bounds and decodes into premultiplied sRGB. Existing audit tests cover malformed signatures, transparent PNG, and 8193-pixel rejection; project tests cover decoding/resource limits. These passed in base CI. Explicit artwork errors propagate; embedded artwork errors warn and retain placeholder fallback. | No new ImageIO execution. Truncation inside a valid PNG's image data and alpha appearance examples remain pending. No compositing policy change. |

`JapaneseInstallTests` returns without rebuilding when its two private-input environment variables are absent. A reported test pass therefore does not establish that the optional rebuild body ran. No private inputs or captures were read, reconstructed, or uploaded in this task. The `reference-private/` directory was absent.

## Cloud Commands and Results

Cloud ran Linux 6.18.44 x86_64, Python 3.12.14, NumPy 2.3.5, and Pillow 12.3.0. The latter differs from CI's pinned Pillow 12.0.0; no dependency was changed. Swift, Apple frameworks, Core ML, and `codesign` were unavailable.

| Command or Check | Result |
| --- | --- |
| `python3 -m unittest discover -s Tests/packaging` | Six passed; repeated after the edit, no registry access. |
| `python3 -m unittest discover -s Tests/reference_validation` | 213 passed; repeated after the edit, public suite only. |
| Synthetic rational Cartesian check | 112 combinations satisfied nonnegative start, positive duration, and final end at/before deadline; 20 already-bounded intervals were unchanged, 92 overruns corrected. This checks the arithmetic, not Swift execution. |
| Python AST parsing of both packaging Python scripts | Passed. |
| `sh -n packaging/package.sh` | Passed. |
| `git diff --check` | Passed before commit. |
| New Swift tests, Swift formatting, release build, native render | Unavailable; Swift and Apple frameworks absent. |
| Isolated package build/install | Unavailable for actual product qualification: no macOS executable or signing tool. No synthetic binary substituted and no incompatible platform forced. |
| `git ls-remote origin refs/heads/main`; task-branch push dry run and actual push | Failed connecting to the configured proxy at port 8080. GitHub read-only connector lookups established the initial and final observed main base. |

## macOS Follow-Up Before Integration

Run from the review branch on macOS; retain the exact resulting commit and environment alongside each result:

```sh
sw_vers
xcodebuild -version
swift --version
swift format lint --strict --recursive Sources Tests Package.swift
swift build -c release
swift build --build-tests
swift test --disable-xctest --filter LyricsInputTests.InputTests
swift test --disable-xctest --filter LyricsInputTests.InputAuditTests
swift test --disable-xctest --filter LyricsInputTests.ProjectTests
swift test --disable-xctest --filter LyricsInputTests.TTMLTests
swift test --disable-xctest --filter LyricsInputTests.CommandSafetyTests
swift test --disable-xctest --filter LyricsInputTests.OutputSafetyTests
swift test --disable-xctest --filter AlignmentMacTests
swift test --disable-xctest --filter LyricsScreenTests
swift test --disable-xctest --filter LyricsInputTests.ProgressionTests
swift test --disable-xctest --no-parallel --filter LyricsInputTests.AudioSceneTests
swift test --disable-xctest --filter LyricsInputTests.VideoLayoutTests
swift test --disable-xctest --filter TimelineTests
swift test --disable-xctest --filter ProgressDisplayTests
swift test --disable-xctest --filter AlignmentTests
```

Retain failed logs and crash reports without retrying them into a success claim. Repeat relevant qualification on macOS 14; newer systems do not establish minimum-OS compatibility. Exercise truncated valid PNGs through ImageIO and confirm explicit-error versus embedded-warning behavior without assuming all truncations have identical decoder behavior.

Use only maintainer-owned audio and manual timing for Japanese stage comparisons. First render manually timed English-led Japanese lines, preserving visible characters, and compare source TTML with presentation snapshots. Then compare acoustic proposals, estimates, interpolation, and exported TTML against the same manual boundaries. Separate line focus, fill, opacity, blur, and scrolling errors. Review each song independently.

For visual comparisons, verify ignore behavior for `reference-private/` before processing authorized captures. Retain native Music on iPhone running reported iOS 27 as the target, with the documented iPhone 16 / reported iOS 27.0.1 provenance and unknown exact build until verified. Compare just before/at/after focus boundaries, dense lines, gaps, gradient fronts, and final dot settling using existing measured parameters. Keep all protected captures and derivatives ignored.

After a native release build, `packaging/package.sh` may be exercised with the existing version in an isolated temporary destination, followed by isolated local archive/npm/wheel installation on macOS arm64. Do not upload packages, create tags, invoke the Release workflow, or approve deployment environments. Inspect complete CI logs on the resulting review head before main integration.

## Release Grouping

A patch release grouping is a candidate for the completed safety guards and this presentation defect correction after native verification. A minor grouping would require separately approved behavioral scope; none is introduced here. No final version or release date is assigned. Visual reference work, Japanese accuracy, crash root cause, minimum-OS qualification, and the remaining model/PNG integration checks stay open and must not be described as completed by this change.
