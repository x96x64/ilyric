# iLyric Experimental Project Format

## Status and Format Selection

Version 1 is a bounded developer experiment, not the finalized public project format or a stable API. Strict UTF-8 JSON uses Foundation parsing without third-party dependencies. JSON offers native decoding, explicit types, and established editor support. TOML permits comments but would add a parser dependency; YAML introduces implicit-type and broader syntax concerns. Neither provides a demonstrated advantage for this small immutable input record. JSON comments, trailing commas, BOMs, duplicate decoded keys, and nesting beyond 16 levels are rejected.

Every object rejects unknown fields; unsupported versions, null values, invalid types, missing required fields, and unsupported policies fail before export. Version numbers and numerical settings require integers, not Booleans. No automatic migration is provided. Future incompatible changes require another explicit version and a documented decision on migration or refusal. Version-1 compatibility is experimental and has not been qualified across OS/font/codec environments.

## Supported Fields and Defaults

| Field | Contract |
| --- | --- |
| `version` | Required integer `1` |
| `inputs.audio`, `inputs.lyrics` | Required nonempty local paths; existing local audio and LRC contracts apply |
| `inputs.artwork` | Optional local static image path; omission retains original generated artwork |
| `metadata.title`, `metadata.artist` | Optional supplied strings; defaults `Local Lyrics` and `Supplied Recording`; 1–80 UTF-16 units, no control characters |
| `timing.offsetMilliseconds` | Optional signed integer, default zero, within ±600000 ms; added to already validated LRC timing |
| `timing.durationPolicy` | Only `audio-pad-frame`; default and inherited audio-endpoint policy |
| `output.width`, `output.height`, `output.fps` | Only 1080, 1920, and 60 respectively; these are also the defaults |
| `output.videoCodec`, `output.audioCodec`, `output.delivery` | Only `h264`, `aac`, and `contain`; defaults identical |
| `visibility.artwork`, `metadata`, `progress`, `transport`, `volume`, `bottom`, `handle` | Independent Boolean component groups, default true |
| `visibility.translation` | Boolean, default false; existing placeholder control only, not translated lyric display |
| `visibility.sing` | `hidden` (default), `compact`, or `expanded`; existing control geometry only, no vocal or timing functionality |

All sections except `version` and `inputs` may be omitted. Supplied empty objects select defaults. Null is never equivalent to omission. Metadata preserves Unicode sequences without normalization. It does not override lyric text or infer metadata from audio or online services. Header typography and clipping retain their provisional qualification.

Project files are limited to 64 KiB. Paths are limited to 4096 UTF-8 bytes without control characters. Relative paths resolve against the project file's directory, including normalized `.` and `..`; they do not resolve against the rendering process's working directory. Absolute paths remain absolute. No tilde, environment-variable, shell, or URL expansion occurs. Paths are standardized lexically without canonicalizing symlinks. Final-component symbolic links, including a link used as the project file, fail the regular-file requirement. Parent-directory links follow filesystem traversal; the project is not an asset-containment sandbox. Missing, inaccessible, nonregular, or excessive inputs fail validation. Public examples contain no machine-specific absolute paths.

## Timing, Output, and Visibility

Precedence is internal defaults, then explicit project fields. The output destination is a required CLI argument and is not a schema field; it resolves against the caller's working directory. There are no appearance or timing CLI overrides. No ambient configuration or network lookup is consulted.

Positive project offsets delay lyrics; negative offsets advance them. The parser first validates the LRC's own offset, then the project offset is added exactly as rational milliseconds. Every resulting event must remain within 0–600 seconds and strictly before decoded audio end. Project offsets neither shift nor replace audio. Audio duration, final hold, explicit gaps, mono conversion, sample-rate conversion, AAC priming, and subframe silent padding retain the [local-input contract](local-input-subset.md). No trimming or audio-offset policy is added.

Ordinary LRC provides paragraph/line timing only. A `|` continuation supplies a visible explicit break without acquiring independent highlight timing. Both supplied lines are shaped together and share focus; no word, character, or second-line interval is inferred. The input schema does not resolve historical native source-break uncertainties.

Visibility masks existing component snapshots. Hidden nodes retain their bounds, ordering, clipping, media state, and lyric geometry. For scenes with authored visibility events, a disabled static group always stays hidden; an enabled group permits the event's visibility. Enabling a group does not override an event that hides it. Local projects use one initial control state: translation and Sing inputs select placeholder visibility, while the other groups mask the existing lower controls. No time-dependent interface schedule is added to the schema.

Rendering retains 1179×2556 native layout and uniform `contain` into 1080×1920. The distinct 1180-column physical recordings remain separate empirical geometry. `cover`, `adapt`, other frame rates/sizes/codecs, fine-grained synchronization, translation tracks, and configurable materials are explicitly unsupported here.

## Artwork Validation

ImageIO accepts one decodable static image, at most 16 MiB, 4096 pixels per side, and 8,388,608 source pixels. PNG and JPEG are tested; other installed decoders are not broadly qualified. Multi-image/animated sources are rejected. EXIF orientation is applied, and decoding is bounded to a 1024-pixel thumbnail. Embedded color interpretation is honored in an explicit sRGB raster destination; unprofiled files use ImageIO's interpretation and have no calibrated-color guarantee. Source dimensions and ImageIO-reported profile presence are recorded as provenance; the latter is not an independent embedded-ICC inspection.

The cached image is center-covered into the existing 216×216 artwork bounds. This may crop nonsquare artwork and never changes lyric or header geometry. The static background palette remains independent of supplied artwork; native artwork-derived materials are deferred. No proprietary image or font is bundled.

## Invocation and Reproducible Example

```sh
swift build -c release
python3 scripts/generate_project_example.py artifacts/project-example
.build/release/LyricsInputProbe project \
  --project artifacts/project-example/project.json \
  --output artifacts/project-example/lyrics.mp4
python3 scripts/validate_local_input.py \
  artifacts/project-example/lyrics.mp4 artifacts/project-example/source.wav 601
```

The generator requires a new destination. It copies the original [project template](../fixtures/project/project.json) and LRC, then generates original stereo audio and an original color-tagged PNG locally. Relative input paths work when invoked from another directory. The template exercises supplied Latin/Japanese multiline paragraphs, a gap, both offset sources (+100 and +25 ms), metadata, hidden volume/bottom controls, and a final hold. No generated binary assets enter source history.

`LyricsInputProbe render --lyrics FILE --audio FILE --output FILE.mp4` remains available unchanged. Both modes refuse existing destinations and require a writable existing output directory. Errors and LRC diagnostics use stderr; completion emits one JSON result on stdout. Exit statuses remain 0 for completion/help, 2 for usage/input/preparation errors, and 1 for export failure. Preparation includes artwork, audio, timing, and paragraph-layout validation before starting the atomic writer.

Public verification includes `./scripts/test.sh`, `python3 -m unittest discover -s Tests/reference_validation -v`, and `python3 scripts/check_project.py`. The last command renders and validates the full original project from a different working directory and checks strict refusal paths.

## Complete Multiline Demonstration

The historical six-second benchmark is retained. Its Japanese appearance events continue after focus leaves at second 3; this is an authored fixture limitation, not missing second-line renderer coverage. A separate eight-second fixture keeps Japanese focus through second 6 and preserves its original glyph events, geometry, and softened appearance. Both lines complete before departure. These are independently authored demonstration timings, not native synchronization.

```sh
.build/release/LyricsScreenProbe video-inactive-progression artifacts/progression.mp4
python3 scripts/validate_media.py artifacts/progression.mp4 1080 1920 480
.build/release/LyricsScreenProbe native-inactive-progression 23 4 artifacts/progression-complete.png
```

Unlike normal project output, this diagnostic scene retains the existing audiovisual markers and synthetic audio. It is not evidence that ordinary LRC contains character timing or that every multiline paragraph requires separate line intervals.
