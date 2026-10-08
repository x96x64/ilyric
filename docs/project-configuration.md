# iLyric Versioned Experimental Project Configuration

## Disposition and Evidence

**Retain experimental version 1 with qualifications.** A strict project file now prepares the existing local LRC/audio workflow with supplied metadata, optional artwork, exact additional lyric offsets, bounded output settings, and independent component visibility. Parsing remains separate from media decoding and rasterization. Historical scenes, production `ilyric`, the writer, typography, motion, and measured appearance parameters remain unchanged.

The empirical baseline remains reported iPhone 16/iOS 27.0.1, build **Unknown**: Default Display Zoom; Text Size 4/7 counting the smallest as 1/7; Bold Text, Reduce Motion, Reduce Transparency, and Increase Contrast off; Light appearance; English system and Music languages. This integration adds no native measurements or fidelity claim. Source integrity and prior typography results were checked only for nonregression.

## Schema and Preparation

JSON was selected for native Foundation decoding, explicit types, editor support, and no added dependency. TOML's comments did not justify another parser; YAML's implicit types and broader syntax were unnecessary. The [format contract](experimental-project-format.md) defines every supported field, default, limit, and invocation. This is an experimental schema with explicit version `1`, not a finalized public project format or indefinite compatibility promise.

`ExperimentalProject` is an immutable domain record in `LyricsInputCore`, without a raster or media dependency. Foundation parses JSON; a bounded structural pass additionally checks strict grammar, duplicate decoded keys, and nesting. Unknown fields, unsupported versions, nulls, malformed types, and unsupported settings are errors. `PreparedProject` validates LRC, offsets, artwork, audio, duration, and complete paragraph layout before starting export. Existing parsers, audio conversion, composition, and atomic writing are reused.

Relative inputs resolve against the supplied project file's directory, with lexical `.`/`..` normalization; absolute paths remain absolute. The CLI output destination resolves against the caller's working directory. No ambient configuration, network retrieval, environment expansion, or new parameter overrides are added. Defaults yield to project fields. A path probe established that the existing regular-file checks refuse final-component symlinks; that restriction is documented and tested rather than claiming automatic target resolution.

## Timing, Visibility, and Artwork

Project offsets are exact integer milliseconds added after the LRC's own validated offset. Positive values delay lyrics. Combined events must remain nonnegative, within the bounded timeline, and strictly before decoded audio end. Audio determines duration and is padded by less than one output frame. Output remains 1080×1920, 60 fps, H.264/AAC, Rec.709, with uniform `contain` from 1179×2556; other policies are refused. The 1180-column recording reference remains distinct.

`ScreenVisibility` intersects static component-group permissions with authored visibility events. A disabled group stays hidden; enabled groups retain the event's own state. Artwork, metadata, progress, transport, volume, bottom controls, handle, and optional control geometry preserve their bounds, z-order, clipping, lyric snapshots, and media state. Local projects author a single initial interface state, with no visibility schedule inferred from lyrics. Translation and Sing settings expose existing placeholders, not functionality.

ImageIO validates one static image before export, within 16 MiB, 4096 pixels per side, and 8,388,608 source pixels. PNG and JPEG are tested. EXIF orientation is applied, decoding is bounded to 1024 pixels, and the result is rasterized into sRGB. ImageIO-reported profile presence is provenance, not independent ICC verification. The cached image is center-covered within the unchanged 216×216 artwork rectangle; nonsquare input can be cropped. The original static background is retained and does not derive a measured material from supplied artwork.

The original example supplies Latin/Japanese LRC, explicit continuation breaks, a gap, generated stereo audio, an original sRGB PNG, Unicode metadata, hidden volume/bottom groups, and a final hold. Its +100-ms LRC offset and +25-ms project offset reproduce the earlier +125-ms effective timeline. Generated assets and videos remain ignored.

## Multiline Progression Findings

The reported concern concerns paragraph highlighting before focus advances, independently of the previously diagnosed stationary tail. The original Japanese paragraph has nine first-line and eight second-line appearance ranges, shaped together with cluster-aligned support. Both lines receive valid events. At the historical focus departure, second 3, the first line is still completing and most second-line progression remains pending. The second line's first nominal interval begins at 3.15 seconds; the softened mask permits partial support before that interval, so nominal begin time is not an exact visible onset. No ignored second-line event or premature timeline termination was established.

Nominal first-line appearance intervals span 0.9–3.1 seconds; second-line intervals span 3.15–5.1 seconds. The existing softened operation extends full-support completion to approximately 3.6 and 5.6 seconds respectively. These are calculated properties of synthetic inputs, not measured native timing. A separate eight-second demonstration retains those events and geometry, but explicitly keeps Japanese focus from second 1 to second 6. At rational time 23/4, both lines are complete; departure begins at second 6. The original six-second fixture and its historical evidence are preserved.

Normal LRC projects remain line-level. A two-line paragraph has one supplied focus interval, with both shaped lines displayed together and no generated character wipe. A continuation boundary does not provide a second independent timing interval. Fine-grained progression requires explicit supplied timing in a later import gate; no synthetic character timing was manufactured here.

## Lyrics Translation Requirements

The product record now defines deferred Lyrics Translation as supplied translated-text display associated with original synchronized lyrics. It requires line correspondence, language identification, visibility, synchronized focus, and validated typography/spacing/appearance within the full-screen scene. Automatic translation generation and external retrieval are separate unestablished capabilities. Translation does not inherit original character or word timing.

Unsupported generalized screen/artwork/composition-transition requirements were reclassified. Independently justified lyric-focus and appearance animations remain. No translated-text renderer or reserved translation-track fields were introduced. Broader timing formats, lawful acquisition, dynamic materials, SF Symbols licensing/export rights, customization, and edge-to-edge adaptation remain deferred.

## Validation and Media Results

All **46 Swift tests** and **68 Python tests** pass. New tests cover schema versions, strict grammar and duplicate keys, nested unknown fields, missing/type-invalid values, UTF-8 and Unicode preservation, relative/absolute paths, exact offsets, artwork corruption/resource limits/orientation, visibility-event intersection, default-scene equivalence, reordered state/raw-raster equality, and second-line completion before departure. The complete project CLI check passes thirteen refusal cases; the unchanged local command passes WAV, AIFF, AAC, and twelve refusal cases. Invalid preparation leaves no partial video and preserves existing outputs.

Release builds, all existing deterministic probes, and original architecture-spike, slice, composition, full-screen, and local-input export checks pass. Private Latin integration retains its archived measurements; twenty Japanese phase renderings preserve byte-identical appearance, coverage, and state/layout records. V01–V03 and V09/V10 hashes remain unchanged. No new physical calibration or motion fit was performed.

| Measured Original Project Output | Result |
| --- | --- |
| Supplied events | 0.625, 2, 3.25 (gap), 4.5, 6, 7 seconds |
| Audio / explicit silent padding | 480,144 decoded samples / 656 samples |
| Video | 1080×1920 H.264, 60/1 fps, 601 decoded frames, 10.016667 s |
| Color / timestamps | Limited-range Rec.709; time base 1/600; every frame passes |
| Audio output | 48-kHz mono AAC, start zero, endpoint aligned with video |
| AAC priming / trailing decoded padding | 2,112 / 416 samples; 480,800 trimmed samples |
| Supplied-content correlation | Approximately 0.999921, gain-independent codec diagnostic |
| Six audio-marker errors | 0 ms at 1-ms analysis resolution |

The separate complete-progression video contains 480 frames over eight seconds with unchanged encoding, timestamps, and eight passing audiovisual markers. Its trimmed audio contains 384,000 samples, with 960 trailing decoded padding samples handled separately. Normal project output contains neither those diagnostic flashes nor substitute synthetic audio.

Five decoded project states at 0.7, 2.4, 3.3, 6.3, and 9.5 seconds were visually inspected. Supplied artwork/metadata, component hiding, both-line focus, the explicit gap, and final hold are coherent. Four demonstration frames show first-line progression, second-line progression, both lines complete at 5.75 seconds, and departure after second 6. This is sampled inspection, not continuous human fidelity assessment. Japanese inactive support remains sharper than Latin; placeholder icons, static materials, viewport fades, and header clipping retain their qualifications.

Initial test compilation required an explicit `Int64` frame index and closure predicates compatible with the installed Testing macros. An assertion at 5.5 seconds failed because softened support completes near 5.6 seconds; evaluating at 23/4 verifies completion without changing appearance parameters. The initial confined build failed on system module-cache access and reported an SDK/compiler diagnostic; the authorized build completed. Existing nonfatal linker search-path warnings remain. No failed run supplies the retained benchmark or media evidence.

A fresh public clone at implementation commit `0ffab71`, without `reference-private/`, passes the complete release build, all 46 Swift/68 Python tests, deterministic probes, original scenes, all tested local audio containers, the full example project, and the eight-second demonstration. Both new videos pass decoded audiovisual validation. All thirteen private-reference commands return explicit unavailable states. The clone remains clean apart from ignored generated outputs; 26 grouped checks complete successfully. Subsequent changes contain documentation and sanitized evidence only.

## Performance

An isolated optimized project export rendered **601 frames in 20.221 seconds**, or **29.722 effective fps**; raster work took **20.058 seconds**, process wall time **20.61 seconds**, and peak RSS **418.59 MiB**. Environment: Apple M4, macOS 27.0.1, Swift 6.4, macOS SDK 27, FFmpeg 8.1.2. Numerical evidence is preserved in [version-1 configuration validation](project-configuration-data/v1/validation.json).

The prior local-input fixture measured 20.216 seconds, 29.728 fps, and 413.47 MiB. Artwork, metadata, and visibility differ, so isolated runs do not establish improvement or a sustained regression. An earlier run overlapping verification measured 27.580 seconds and was excluded from the isolated benchmark. Raster composition remains the dominant measured cost; parsing/image preparation occur before the writer's export timer. No maximum-duration/event memory claim, new blur pipeline, per-frame lyric shaping, or backend optimization is made.

## Privacy, Limits, and Next Gate

Private sources and diagnostics remain ignored, with no tracked private material. Public changes contain original generators/fixtures, code, tests, documentation, and sanitized numerical results. Historical reports/profiles, original-history backups, human Git identities, and attribution conventions are preserved. No production renderer, export backend, release, tag, symbol asset, proprietary font, or license choice is changed.

**Go for retaining version 1 as a reproducible experimental input path.** The next narrow priority is a documented fine-grained timing import experiment using a specifically bounded enhanced-LRC dialect, explicit supplied timing provenance, cluster validation, and complete multiline progression tests. Configuration stabilization and translation correspondence/presentation remain distinct later decisions. Acquisition, materials, symbols, and `adapt` are not prerequisites for that bounded import gate. Native iOS 27 Music fidelity remains unvalidated.
