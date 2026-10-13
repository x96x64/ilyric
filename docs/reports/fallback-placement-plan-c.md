# Plan C for Unsupported Boundary Fallback Placement

## Outcome and Scope

October 13, 2026. The revised Plan C passed all preimplementation gates and was implemented as a correction to fallback placement. Four of 31 existing timed fallback paragraphs move across the 21 approved development recordings; 27 remain unchanged. Fresh CPU alignment runs match the private projection exactly. All 894 accepted rows and their TTML paragraphs remain identical, and all five previously omitted rows retain their complete JSON values.

The correction changes only the placement intervals supplied for eligible unresolved boundary runs. TTML format, lyric order, glyph style, rendering, backing-vocal handling, CTC, separation, activity detection, v2/v3 acceptance, accepted acoustic estimates, and model weights remain unchanged. Historical reports remain unchanged. Earlier private drafts are excluded from the proposed documentation commit.

## Development Inputs and Classification

The corpus contains the twenty previously observed English JamendoLyrics recordings and the maintainer-approved example: 21 recordings in total. EN-F01–EN-F03 are existing aliases within the twenty; EN-J01–EN-J14 and three former Set A identities complete the approved list. Former Set A is development-only. The identity manifest and audio hashes were audited without adding the aliases as extra recordings. All twenty source-audio hashes and both example-original hashes remain unchanged.

Existing private copies and baselines were reused. The example's previously prepared private alignment copy was retained; no numeric-token or audio-format enhancement was implemented. Generated inputs, TTML, JSON reports, activity traces, videos, decoded media, and machine-specific logs remain in ignored private storage. No source lyrics, protected media, personal paths, or private reference derivatives are included in the public changes.

No consumed MUSDB18 test or training material, JamendoLyrics++ qualification material, other held-out material, unclassified recording, or out-of-scope visual capture was accessed. No recordings, models, or test dependencies were downloaded. The visual recordings V01–V17 and N01–N10 and screenshots IMG_0334–IMG_0339 remained unused. These results are development evidence and mechanical regression checks, not independent qualification.

## Reproduction Before the Change

The existing fallback algorithm spreads unresolved runs between accepted anchors and allocates at most 2.5 seconds per line at an opening or closing boundary. These allocations are supplied placements rather than acoustic estimates. They previously had no activity-guided relocation step.

Both saved synthetic cases were rerun through the unchanged release alignment command before production editing. Their TTML reproduced byte-for-byte, and all line-report values matched the saved evidence. The leading placement was 5.620001–8.120000 seconds; the trailing placement was 4.200001–6.700000 seconds. The original synthetic construction supplies no suitable independent vocal region for either unresolved target. Detected attacks and tails intersect the accepted lead intervals. The revised policy deliberately retains both placements without shortening, including their existing presentation during silence.

Reported intervals use the existing audio-relative microsecond coordinate system, with zero at the start of the decoded recording and half-open begin/end intervals.

The two existing positive synthetic cases were reused. Their target vocal surrogates begin after silent gaps and provide sufficiently long later activity components. They were generated locally using pitch-transformed, tempo-expanded synthetic voices. They exercise placement mechanics and are not natural human singing recordings. Their complete private inputs and evidence remain preserved; source text is not reproduced here.

| Synthetic Case | Baseline Fallback (s) | Actual Fallback (s) | Selected Activity Component (s) | Shift (s) |
| --- | --- | --- | --- | ---: |
| Saved Leading | 5.620001–8.120000 | 5.620001–8.120000 | None Suitable | 0 |
| Saved Trailing | 4.200001–6.700000 | 4.200001–6.700000 | None Suitable | 0 |
| Active Leading | 17.580001–20.080000 | 8.520001–11.020000 | 8.520000–18.080000 | −9.060 |
| Active Trailing | 3.800001–6.300000 | 12.520001–15.020000 | 12.520000–18.580000 | +8.720 |

Both positive placements lie wholly within their selected components and the generated target-vocal regions. Their accepted lead intervals are unchanged. Activity boundaries are numerical observations from the existing detector; they do not establish the complete sung interval or the identity of the supplied words.

## Placement Rule and Implementation

Calculate the original fallback intervals first. Consider only leading and trailing unresolved runs with an accepted anchor. Keep anchored interior runs and entirely anchorless runs unchanged. Protect an entire run containing an already omitted row or a backing-vocal attachment; this preserves omitted JSON values and inherited backing-vocal timing.

Reuse the existing separated-stem activity calculation: 20-ms RMS frames, the 99th-percentile reference, and a strict level greater than reference minus 30 dB. The calculation's −120-dB numerical floor supplies no useful hint. No threshold, detector, separation, recognition, or acceptance rule was modified. Vocal activity is a placement hint, not proof that a particular lyric was sung.

For a trailing run, select the first complete activity component beginning at or after the previous accepted end and lying within the audio duration. For a leading run, select the last complete component ending at or before the next accepted onset. Components crossing an accepted anchor are not independently available regions. Select by time before testing capacity; an unsuitable nearest component never triggers a search farther away.

Require capacity for the run's complete existing span and its existing one-microsecond boundary guard. Reject a component intersecting any accepted interval. If the run already fits the nearest component, retain it. Otherwise, translate every interval by the same integer number of microseconds, beginning one microsecond after the component's start. Preserve every duration, gap, and textual position. No accepted interval or audio boundary is crossed. Missing or unsuitable activity retains the original placement without shortening.

The pure placement function operates on immutable accepted rows and returns only a revised fallback dictionary. The command computes the existing activity hint after acoustic acceptance and supplies protected identifiers for omitted rows and backing attachments. The existing TTML exporter and report schema receive that dictionary without format changes. The placement console message no longer describes every placement as occurring between neighbours.

## Projection and Actual Development Impact

The baseline contains 930 main-line report rows: 894 aligned, 31 placed, and five omitted. All 21 recordings were included in the projection and fresh post-change alignment. Existing activity traces from the six recordings with eligible boundary runs supplied the preimplementation hints; the other fifteen cannot move under this rule. Projection outputs were verified before production editing, including TTML import and the normal scene construction.

| Recording | Moved Timed Fallbacks | Unchanged Timed Fallbacks | Shifts (s) |
| --- | ---: | ---: | --- |
| EN-F01 | 0 | 0 | — |
| EN-F02 | 0 | 0 | — |
| EN-F03 | 0 | 0 | — |
| EN-J01 | 0 | 3 | — |
| EN-J02 | 0 | 0 | — |
| EN-J03 | 0 | 0 | — |
| EN-J04 | 0 | 2 | — |
| EN-J05 | 0 | 1 | — |
| EN-J06 | 0 | 1 | — |
| EN-J07 | 0 | 0 | — |
| EN-J08 | 1 | 6 | −3.580 |
| EN-J09 | 0 | 2 | — |
| EN-J10 | 0 | 0 | — |
| EN-J11 | 0 | 2 | — |
| EN-J12 | 0 | 7 | — |
| EN-J13 | 0 | 0 | — |
| EN-J14 | 0 | 0 | — |
| Set-A-01 | 0 | 1 | — |
| Set-A-02 | 0 | 0 | — |
| Set-A-03 | 3 | 2 | +1.280 Each |
| Example | 0 | 0 | — |
| Total | 4 | 27 | — |

The individual movements are EN-J08 row 1, from 54.660001–57.160000 to 51.080001–53.580000 seconds; and Set-A-03 rows 44–46, from 215.620001–218.120000, 218.120001–220.620000, and 220.620001–223.120000 to 216.900001–219.400000, 219.400001–221.900000, and 221.900001–224.400000 seconds, respectively.

The maximum absolute development shift is 3.580 seconds. Including the positive synthetic cases, the maximum is 9.060 seconds. No evaluated shift exceeds the required ten-second gate. The rule itself does not introduce a general ten-second cap for unevaluated recordings; that gate establishes the observed development impact.

Nearest components of 0.020, 0.080, and 0.100 seconds prevent relocation in Set-A-01, EN-J09, and the leading Set-A-03 run, respectively. Longer, farther components are not searched. The EN-J11 boundary run remains unchanged because it contains an omitted row. No previously omitted row is restored, retimed, or otherwise modified.

Actual and projected line-report values match exactly for all 21 recordings and four synthetic cases. Actual TTML matches each projection byte-for-byte. Unresolved remains 36 of 930 rows, including the five existing omissions: a pooled increase of 0.000 percentage points and a zero increase for every recording. No placement is promoted to acoustic acceptance. The maintainer's example has 62 accepted rows and no timed fallback, and remains unchanged.

## TTML, Rendering, and Accepted-Line Preservation

The command's fallback dictionary supplies both report intervals and the existing TTML exporter. The normal untimed rendering path imports the exported TTML directly. The importer preserves paragraph source order, validates nonoverlapping timing, and passes every imported line to the normal scene. The renderer does not reconstruct omitted text from an alignment report.

All 925 pre-existing timed development paragraphs survive, with zero lost or reordered text. Only begin and end attributes of the four moved fallback paragraphs change; namespaces, other attributes, paragraph bodies, child timing, and text remain intact. Every field of the 894 accepted report rows is identical, including status, interval, proposals, flags, background values, and word estimates. Their TTML paragraphs are byte-identical. The five omitted report rows are also identical in full; their pre-existing omission from TTML remains unchanged.

Before and actual TTML imports and normal scenes were checked for all 21 recordings and four synthetic cases, preserving 933 imported entries in total. Every paragraph's glyph input and style matched. The six relocated development or synthetic paragraphs passed static glyph-raster and header-pixel comparisons, including the More button, and acquired their expected focus. Existing control states matched at visible, auto-hide boundary, repeated, and out-of-order timestamps.

Public regressions use numerical text identifiers and project-owned icons. They verify presence, order, accepted paragraph timing, exact activity capacity, onset and end boundaries, whole-run spacing, omitted and backing protections, activity absence, unsuitable nearest components, and deterministic snapshots and rasters. No renderer source was changed.

Focus, scrolling, and derived gap chronology naturally follow the revised placement. The existing 0.90-second focus lead remains in effect, so an activity-contained TTML interval does not imply that focus starts at the same acoustic timestamp. Static fallback fill treatment, fonts, colours, motion profiles, control visibility, and the completed More button retain their existing implementation and style. The renderer's existing final-line hold also remains unchanged.

## Verification and Environment

Verification used an Apple M4 system with 16 GB memory, macOS 27.0.1, Apple Swift 6.4, and installed CPU inference models. Python validation used Python 3.12.14, NumPy 2.3.5, and Pillow 12.3.0. Media inspection used FFmpeg and FFprobe 8.1.2. The existing CI configuration pins Pillow 12.0.0; it was not changed, and no package was downloaded to alter the local environment.

The release product build passed with the established local module-cache settings:

```sh
swift build --disable-sandbox --build-system native -c release --product ilyrics
```

The full Swift suite passed: 136 tests in 28 suites. The Command Line Tools discovery and runtime workaround established during the More-button task was applied locally. Its environment settings and additional toolchain arguments remain in ignored logs and were not added to source configuration, Git, or CI. The test invocation used this base command with those local arguments:

```sh
swift test --disable-sandbox --build-system native --disable-xctest
```

All 213 public Python validation tests passed:

```sh
python -m unittest discover -s Tests/reference_validation
```

The two positive fixtures also passed the normal untimed video export, matching the projected alignment rows. Each export contains H.264 video at 1080×1920 and 60 fps, 1,440 decoded frames over 24 seconds, and 48-kHz AAC audio with matching container duration and zero start timestamps. Maximum decoded frame-spacing error is approximately 0.667 microseconds.

Decoded audio comparison over the container's presented interval found zero peak lag at 62.5-microsecond resolution. Correlations were 0.999990 for the leading fixture and 0.999992 for the trailing fixture. FFmpeg emitted 960 additional silent AAC padding samples after the declared 24-second interval; those samples were excluded from the presented-interval comparison. No audio-format correction was made.

An isolated optimized benchmark evaluated 12,000 activity frames and 80 rows 1,000 times, confirming identical results throughout. Mean placement time was 11.16 microseconds per evaluation, with a maximum resident set size of 6,275,072 bytes, approximately 6.0 MiB. This measures the placement helper alone, not separation, recognition, repeated activity calculation, or video rendering. The benchmark ran while development alignment was in progress; no dedicated idle-machine capacity benchmark was performed. Raster equality is local-environment evidence rather than a cross-platform guarantee.

## Limitations and Publication Status

Activity can reflect another phrase, a different singer, or instrumental leakage. No independent textual assignment was established for the four development relocations. The synthetic cases verify the mechanics of relocation into known generated vocal regions; they do not establish natural-singing performance. Unsupported placements can still occupy silence when the nearest component is absent, too short, or protected. This is the explicitly approved retention policy.

No new independent qualification was performed, and no consumed qualification corpus was reused as fresh evidence. These checks do not establish an improvement over the previously reported English placement baseline. A complete video export of every development recording was not performed; all recordings received fresh alignment, TTML preservation, import, and normal-scene checks, while full media exports covered the two positive synthetic cases.

The code and tests are recorded in `3a19a7c42704a187429a299b22d4b4cb831556f5`, `fix(align): relocate boundary fallbacks to nearest activity`, with the required Codex co-author trailer. The complete staged diff was reviewed and contained only the intended source changes, test dependency, and regressions. This report remains an uncommitted documentation draft requiring explicit approval. No earlier private draft is being committed. The final normal push and resulting Swift and Python GitHub Actions verification remain pending documentation approval. No tags, releases, package publications, force pushes, or history rewriting occurred.
