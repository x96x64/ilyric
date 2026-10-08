# iLyric Bounded Enhanced-LRC Timing Integration

## Disposition and Scope

Retain the experimental import with qualifications. Explicit segment boundaries now drive deterministic progressive appearance without changing paragraph focus, whole-paragraph shaping, supplied audio, or version-1 projects. Version 2 selects the input dialect explicitly. Production `ilyric`, the writer, historical scenes, reports, and reference profiles remain unchanged. Native Music fidelity and general multilingual timing support remain unvalidated.

The empirical reference remains reported iPhone 16/iOS 27.0.1, build **Unknown**, with Default Display Zoom, Text Size 4/7 counting the smallest as 1/7, Bold Text/Reduce Motion/Reduce Transparency/Increase Contrast off, Light appearance, and English system and Music languages. This gate imports user-supplied timing; it adds no native physical measurement.

## Dialect Selection and Input Model

The [subset contract and invocations](enhanced-lrc-subset.md) were recorded before parser implementation. Primary documentation and source inspection established a credible angle-bracket boundary convention: [usersync](https://github.com/iamjrmh/usersync#output-format) documents paragraph and inline timestamps with terminal boundaries; [LDDC](https://github.com/chenmozhijin/LDDC/blob/main/LDDC/core/parser/lrc.py) assigns the next boundary as the preceding segment end, and its [converter](https://github.com/chenmozhijin/LDDC/blob/main/LDDC/core/converter/lrc.py) emits explicit ends. [AMLL](https://github.com/amll-dev/applemusic-like-lyrics/blob/main/packages/lyric/src/formats/lrc/parser.ts) supports broader syntax and final-end inference. These implementations differ in trimming, repeated starts, extension handling, and incomplete-end policies. They do not establish a universal enhanced-LRC standard. No implementation code was copied.

The selected subset requires an explicit first and terminal boundary on every timed physical line. Adjacent boundaries define positive absolute media-time intervals. The existing local `|` continuation remains an explicit iLyric extension; each constituent line must provide timing. Ordinary rows, metadata, offsets, duplicates, gaps, resource limits, and sorting delegate to the existing LRC parser. Ambiguous repeated paragraph starts with inline timing, incomplete/duplicate/nonmonotonic boundaries, mixed timed/untimed continuations, and intervals beyond paragraph or audio end fail before export. Literal angle brackets are reserved in enhanced input.

`TimedSegment` retains immutable UTF-16 ranges and normalized rational boundaries. `LyricEntry` retains source-line and supplied-break provenance. LRC and project offsets shift every supplied boundary exactly. No frame rounding, word segmentation, inferred final duration, or fine-grained timing from ordinary LRC is introduced. The limits are 64 KiB, 64 expanded paragraph/gap events, fewer than 500 UTF-16 units and at most four supplied or rendered lines per paragraph, 128 segments per paragraph, 512 per file, and ten minutes. Early prefix/continuation guards bound pathological inputs.

## Unicode and Shaped Support

Removing only timestamp syntax preserves spaces, punctuation, NFD combining sequences, emoji joiners, and variation selectors. Segment ranges must align with extended graphemes in the complete reconstructed text. Whole-paragraph Core Text layout separately verifies shaped-cluster boundaries. Unsupported boundaries are rejected rather than expanded, normalized, or reshaped. Right-to-left timed runs remain unqualified.

A timed range may span automatic wrapping. Its already-shaped support is partitioned at layout lines, retaining one source interval and cumulative typographic advance. The sweep traverses those fragments in source order. Explicit separators carry no ink or independent timing. Cached masks are cropped for storage; typography, fallback, advances, baselines, and wrapping are unchanged. Source semantics behind S04/S05 observed breaks remain unresolved.

Stress testing exposed a specific color-glyph limitation: timed-run and complete-line emoji rasters differed within the color-glyph regions, including 2,238/1,876 alpha-support pixels in the tested Latin/Japanese base styles. This is a direct synthetic diagnostic, not native-reference evidence. Public font traits now reject color-glyph progressive support before export, including disabled mode's preparation check. Parsing still preserves those sequences; ordinary LRC retains its previous complete-line path. No broad emoji-rendering qualification is claimed.

The tested system font permitted a grapheme-valid split inside the ligature-prone word `office`; that observation does not establish universal font behavior. A synthetic cluster map tests mandatory rejection independently of that local font resolution. Fonts remain system-resolved provenance, not identified native iPhone Music fonts.

## Presentation and Configuration

Version 2 requires `inputs.lyricsFormat` and permits `timing.highlighting`. Version 1 retains its strict field set and ordinary interpretation. Unsupported formats, modes, versions, types, fields, and assets fail during preparation. Relative paths, metadata, artwork, visibility, audio duration, output settings, diagnostics, and refusal behavior retain the prior contract. The direct command adds only explicit format/mode selection; project commands receive no overrides.

Focus still follows paragraph events and half-open intervals. Segment completion never schedules departure. Before a segment its support is dim; during it a spatial operation visualizes the supplied interval; afterward it stays complete. Explicit gaps remove focus under the inherited policy. Disabled mode retains and validates timing while reproducing the ordinary static paragraph raster, focus, progress, and interface state.

Latin uses a synthetic hard wipe. Japanese reuses the softened-mask mechanism with synthetic width 0.25 advance, interval scale 1, exact endpoint mapping, dim/completed values 0.42/1, and zero vertical amplitude. These are visualization choices, not fitted native settings. The historical measured Japanese softened progression and bounded vertical treatment are unchanged. Latin's cached inactive blur blends into timed active support using its inherited focus treatment; this blend is a synthetic rule. No blur kernels or shaping are rebuilt per output frame.

Inherited base sizes 104.25/103.25, line advances 125.5/123, and focus response 0.081 seconds remain experimental reconstruction parameters. Layout stays at 1179×2556; the distinct 1180-column recording geometry remains empirical evidence. Uniform `contain` maps to 1080×1920. Media/output clocks retain the local workflow's explicit identity mapping; no native onset semantics are inferred.

## Multiline and Audiovisual Evidence

The original fixture supplies ten timed spans across Latin and Japanese two-line paragraphs and one automatically wrapped paragraph, with a +125-ms offset and explicit gap. Focus occurs at 0.625, 4.5, and 7 seconds; the gap starts at 3.25 seconds. Both multiline paragraphs complete before departure. There is no diagnostic flash or substitute audio in normal output.

Localized decoded comparisons use disabled white support to select interiors. Values below are encoded RGB proxies after the same FFmpeg conversion, not physical luminance or measured alpha.

| Second Line | Sample Times | Mean Proxy on a 0–255 Scale | Completed Bright Fraction |
| --- | --- | --- | --- |
| Latin | 2.1, 2.4, 2.9, 3.15 s | 150.528, 184.383, 233.275, 251.924 | Below 5% initially; above 99% finally |
| Japanese | 5.6, 6.15, 6.6, 6.95 s | 150.738, 186.615, 223.134, 251.375 | 0% initially; 100% finally |

All selected frames retain a completed first line while the second progresses. Rational state tests separately establish exact non-frame-aligned boundaries and focus independence. Eight decoded enabled/disabled pairs were visually inspected: both-line progression, the completed states, and three-line automatic wrapping are coherent. Placeholder controls, static materials, qualified inactive appearance, and the synthetic wipes remain visible limitations. This is sampled inspection, not continuous human fidelity review.

Enabled/disabled project exports and the direct command pass independent validation: 1080×1920 H.264, 60/1 fps, 601 decoded frames, 10.016667 seconds, limited-range Rec.709, time base 1/600, and every video presentation timestamp. Supplied audio decodes to 480,144 samples; 656 silent samples pad output. Mono 48-kHz AAC starts at zero and ends with video. Priming is 2,112 samples; trailing decoded padding is 416; endpoint trimming yields 480,800 samples. Content correlation is approximately 0.999921, best diagnostic lag zero, and six marker errors zero at 1-ms analysis resolution. Codec/sample identity is not claimed.

## Performance and Verification

Isolated optimized runs used Apple M4, macOS 27.0.1, Swift 6.4, macOS SDK 27, and FFmpeg 8.1.2. Public standard-library tests used Python 3.9.6; numerical reference checks used the existing Python 3.12 runtime. Raw equality is qualified to this environment.

| Workload, 601 Frames | Export Time | Effective FPS | Peak RSS |
| --- | ---: | ---: | ---: |
| Identical ordinary project before integration | 20.162 s | 29.808 | 417.14 MiB |
| Identical ordinary project after integration | 19.897 s | 30.206 | 417.19 MiB |
| Same enhanced project, enabled | 22.797 s | 26.363 | 407.48 MiB |
| Same enhanced project, disabled | 18.279 s | 32.880 | 396.52 MiB |

These single runs establish no speedup. The enabled/disabled comparison exposes approximately 24.7% additional export time for timed appearance in this fixture; ordinary-input changes show no material regression. Raster work remains dominant. No ten-minute throughput or maximum-input memory claim is made. Overlapping test/export runs were excluded from this table.

All 53 Swift and 70 Python tests pass. Release builds and deterministic probes preserve ordinary input, version-1 configuration, Latin/Japanese geometry, appearance, motion, composition, and export regressions. New checks cover syntax, offsets, ordering, duplicates, duration conflicts, Unicode, cluster policy, limits, wrapped and explicit-break progression, event endpoints, disabled equivalence, fresh/reordered raw rasters, project compatibility, and complete media output. Fourteen CLI refusal cases exercise pre-export errors. The ligature probe and color-glyph discrepancy informed the retained support policy.

V01–V03 and V09/V10 source hashes remain unchanged. Existing private Latin measurements reproduce their baseline; twenty archived Japanese appearance, coverage, and state/layout records remain byte-identical. These are nonregression checks, not new physical fits. Originals, transcriptions, masks, and source-bearing diagnostics remain ignored.

A fresh checkout of implementation commit `0904edc` without private inputs passed 27 check groups, including all public tests, original scene exports, ordinary LRC, version-1 projects, and enabled/disabled enhanced-LRC exports. Thirteen private commands explicitly reported unavailable inputs. The checkout remained clean apart from ignored generated outputs. These results and sanitized measurements are recorded in [version-1 integration evidence](enhanced-lrc-data/v1/validation.json). No private media, font files, credentials, or personal paths enter the new commits. Historical reports, profiles, attribution backups, production rendering, and audio conversion are preserved.

## Remaining Limits and Next Gate

Go for the bounded enhanced-input workflow; no-go for native Music fidelity or universal timed-text support. The dialect requires explicit final ends, rejects ambiguous/unsupported extensions and unqualified shaped support, and preserves line-only input as line-level. Latin wipe behavior and supplied-Japanese interval mapping are synthetic, not native appearance calibrations.

The next narrow gate should be a documented TTML timing subset with explicit paragraph/span intervals and breaks, retaining the same exact timing and shaping policies. It can address richer local interchange without acquisition or inferred alignment. Lyrics Translation correspondence remains a separate deferred gate; lawful provider acquisition, materials, SF Symbols permissions, generalized customization, and `adapt` remain unimplemented. Color-glyph progression requires a separate complete-run raster diagnostic before qualification, not silent fragment reshaping.
