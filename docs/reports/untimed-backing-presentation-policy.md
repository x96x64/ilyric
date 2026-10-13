# Backing Vocal Presentation Without Independent Timing

October 13, 2026.

## Outcome and Scope

Backing text without an independently supplied interval is displayed beneath its associated lead only while that lead owns focus. It uses the existing dim ink and entry visibility treatment, with neither lead-synchronous fill nor lead-focus highlighting. It contributes no ink beneath unfocused paragraphs or during instrumental-gap focus. This is a maintainer-directed presentation policy, not measured native iOS 27 behavior. No new native-reference calibration or independent qualification was performed.

Commit `6dec14c` correctly disabled inherited fill but incorrectly made inherited backing text independent of focus visibility. The additive correction restores secondary visibility weighting and focus ownership without restoring premature fill. It changes secondary drawing and synthetic tests only. Timing provenance, TTML syntax, import/export, accepted lead timing, backing synchronization, Plan C, CTC, separation, activity detection, main rendering, and other controls remain unchanged. Completed reports were preserved; this report was still unapproved when revised.

## Timing Provenance and Visibility

The package-internal timing provenance introduced by `6dec14c` is unchanged. A backing span with its own begin and end or duration is explicit, including when its numeric interval equals its parent's interval. Untimed and partially specified spans retain inherited provenance. Project offsets and scene construction preserve that distinction without a serialized extension or alignment change. Explicit timing remains an input declaration, not proof of independent acoustic correctness.

Inherited fill progress remains zero. Secondary drawing now uses the existing visibility multiplier instead of a constant multiplier. In the normal calibrated render path, this is the existing inactive-treatment opacity multiplied by the existing blur-derived visibility factor. The secondary glyphs themselves are not newly blurred. Settled backing ink retains the existing unfilled opacity of 0.45. The existing 0.15-second ingress treatment controls entry; no new visual or animation constant was introduced.

Focus ownership is an additional strict gate for inherited cues. At handoff or gap focus, the old cue stops drawing at the exact event timestamp. The previous inactive treatment can retain a nonzero exit multiplier briefly after focus changes; inherited backing does not retain that residual ink because the maintainer explicitly requires absence beneath every unfocused line. Main-lyric exit treatment remains unchanged. The noncalibrated path retains its existing paragraph-opacity weighting and applies the same focus gate.

The extra offscreen-main drawing exception added by `6dec14c` was removed. Existing viewport clipping, fading, positions, wrapping, size ratio of 0.652, baseline offset of 138 internal pixels, and reserved secondary space of 56 internal pixels remain unchanged. Explicit cues retain their complete `6dec14c` drawing and fill behavior, including existing render-time fill compensation and visibility treatment. This correction does not extend TTML child containment or implement independent backing alignment.

## Before-Change Reproduction

Preserved original synthetic evidence from the preceding task demonstrates inherited fill progressing from 0.055 at 2 seconds to 0.305 at 3 seconds and 1 at 5.78 seconds, although the fixture's later backing audio marker occurs at 8–9 seconds. This is a timing-marker demonstration, not sung acoustic evidence. The preserved pre-policy renderer at `7ad4908` has the same secondary drawing implementation as the local v1.0.1 source. Source comparison identified the later More-button addition separately; whole-frame equality with the complete v1.0.1 release is not claimed.

Before the correction, a new original synthetic fixture was imported through the normal TTML parser, scene construction, and complete screen renderer at `6dec14c`. It contains four lead paragraphs with backing cues at 2–4, 4–6, 6–8, and 14–16 seconds. An opening-gap variant shifts the intervals to 6–8, 8–10, 10–12, and 18–20 seconds. Several focused and unfocused paragraphs are simultaneously visible. Generated alphabetic identifiers exercise main wrapping and longer secondary wrapping without reproducing lyric text in this report or storing lyric literals in tests.

Seven variants cover untimed, begin-only, end-only, duration-only, complete parent-equal, complete later-child, and opening-gap timing. Original 24-second stereo timing-tone media at 48 kHz supports normal video export. No real media or acoustic alignment was used. Input hashes, TTML, numerical traces, complete before-change PNG frames, videos, and logs remain in ignored private storage. Eight original input hashes remained unchanged.

The `6dec14c` regression appeared in all 200 inherited-variant full-frame samples. In the untimed fixture, unfocused backing contributed 4,761 pixels during first-lead focus, 11,022 pixels at the 3.10-second handoff, and 49,084 pixels during gap focus at 8 seconds. A preserved pre-policy render of the new fixture also confirmed inherited fill progress of 0.11 at 2 seconds and 0.61 at 3 seconds.

## Whole-Frame Verification

Criteria were recorded before production edits: zero inherited fill; zero inherited backing ink from every unfocused paragraph across the complete frame; unchanged main-only and explicit-cue rasters; unchanged geometry and source counts; deterministic rational-time evaluation; and unchanged decoded media properties. Cropped checks were not used as the acceptance basis.

Seven variants were evaluated at 40 rational timestamps each, including focus entry, lead fill, handoff, gap exit, control hiding, and exact boundaries with adjacent microsecond samples. Complete frames containing all inherited cues were compared with complete frames containing only the focused cue. Each unfocused cue was also rendered in isolation against the complete main-only frame.

| Check | Result |
| --- | --- |
| Main-only before/after complete-frame equality | 280 of 280 |
| Explicit-timing before/after complete-frame equality | 80 of 80 |
| Inherited complete frames equal focused-only frames | 200 of 200 |
| Isolated unfocused inherited cues contributing zero pixels | 673 of 673 |
| Inherited cue progress equal to zero | 800 of 800 |
| Settled focused cue ink, bounds, and opacity unchanged | 86 of 86 |
| Repeated, out-of-order, and fresh-renderer comparisons | 98 before and 98 after |

Text lengths, cue counts, main counts, wrapping counts, origin positions, translations, and existing visibility weights were identical before and after. Four main and four backing cues were retained in every variant. Main-only equality covers main fill, the More control, interlude, header, and other controls in the sampled frames.

The first cue contributes no pixels at its exact 1.10-second focus onset because its existing entry multiplier begins at zero. At 1.125 seconds, estimated peak apparent opacity is approximately 0.018; at 1.25 seconds it reaches approximately 0.453 and remains dim during lead fill. At 3.099999 seconds it remains visible; at 3.10 and 3.100001 seconds it contributes zero pixels after handoff. No inherited ink remains at 8 seconds or the adjacent gap-boundary samples.

Settled first-cue ink retains the inclusive bounding box x = 97–474 and y = 1004–1067 in the 1179 × 2556 internal raster. Its main paragraph wraps to two lines. Apparent opacity is a quantized raster estimate; its small difference from nominal 0.45 is not a new constant or native Music measurement.

## Tests and Media Checks

The release build passed with `swift build --disable-sandbox --build-system native -c release --product ilyrics` in 6.99 seconds. The complete Swift suite passed 142 tests in 28 suites in 192.281 seconds using `swift test --disable-sandbox --build-system native --disable-xctest` with the previously established local Command Line Tools discovery and runtime settings. These settings remain in ignored local logs and were not added to Git or CI.

Synthetic regressions cover every unfocused cue across complete frames, adjacent lead paragraphs, opening and interior gaps, inherited partial timing, exact focus boundaries, both calibrated and noncalibrated drawing, retained text/order, zero fill, and repeated reversed timestamp evaluation. Existing explicit-timing provenance, explicit fill endpoints, project offsets, More, interlude, main rendering, timeline, alignment, and fallback tests passed. Public test rendering uses project-owned icons and requires no private corpus or network access.

All 213 relevant Python tests passed with `python3 -m unittest discover -s Tests/reference_validation` in 4.935 seconds. Verification used Apple M4 hardware with 16 GB memory, macOS 27.0.1, Swift 6.4, Python 3.12.14, NumPy 2.3.5, Pillow 12.3.0, and FFmpeg 8.1.2.

Both normal command-line exports decoded to 1,440 H.264 frames at 1080 × 1920 and 60 fps over 24 seconds, with zero initial presentation offset and stereo 48-kHz AAC audio. Maximum measured cadence rounding error was approximately 0.667 microseconds. Input/output left-channel correlation was approximately 0.99999955, with zero measured lag at 62.5-microsecond resolution. Decoder padding of 960 samples was excluded from the declared-duration comparison.

Seven corrected decoded full frames were compared with matching lossless output-frame references. Predefined codec tolerances were mean absolute eight-bit channel error below 3 and full-frame PSNR above 34 dB. Maximum observed mean absolute error was 1.757, and minimum PSNR was 40.846 dB. The first diagnostic reference incorrectly used sRGB; matching the exporter's ITU-R BT.709 context corrected that reference-only mismatch without production changes. Private command-line output retained public runtime symbol loading. Encoded byte equality was not required.

Two-worker exports took 30.152 seconds before and 42.462 seconds after, corresponding to 47.759 and 33.912 effective frames per second. Corrected export maximum resident memory was 499,662,848 bytes, approximately 476.5 MiB. Builds, the expanded Swift suite, and raster probes ran concurrently; these single-run throughput figures cannot establish a performance regression or improvement. Long-recording performance and cross-machine raw raster equality were not qualified.

## Limitations and Publication Status

Backing text remains associated with its lead's existing geometry and can be clipped or faded by the viewport. Its absence outside lead focus is intentional. This policy does not identify actual backing-vocal sung intervals, resolve repeated or overlapping phrases, or guarantee acoustic correctness of supplied explicit timestamps. Main timing and alignment implementations were unchanged, and no real-data accepted-line comparison was rerun.

No visual captures, JamendoLyrics recordings, maintainer example files, consumed qualification data, held-out materials, or model weights were accessed. V01–V17, N01–N10, and IMG_0334–IMG_0339 remained unused. Reference classifications were unchanged. No download, tag, release, publication, force push, or history rewrite was performed.

The complete staged correction was reviewed for scope and private material before additive commit `617966f66413b2c30d4b073fcc820dd6fc173a2c`, `fix(render): restrict inherited backing ink to lead focus`, with the required Codex co-author trailer. It follows `6dec14c52d119b295ba11282814efb170471891c`, `fix(render): keep inherited backing vocals unfilled`; neither commit was amended. Only secondary drawing and synthetic tests are included in the correction commit. This revised report remains uncommitted pending explicit maintainer approval. Main is two commits ahead of the local origin tracking reference. No push or new GitHub Actions run has occurred; Swift and Python CI verification remains pending the approved documentation commit and normal push.
