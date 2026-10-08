# iLyric Experimental Enhanced-LRC Subset

## Dialect and Compatibility

The selected dialect uses `[mm:ss.xxx]` paragraph starts and `<mm:ss.xxx>` inline boundaries. This convention is documented by [usersync](https://github.com/iamjrmh/usersync#output-format) and implemented by [LDDC's parser](https://github.com/chenmozhijin/LDDC/blob/main/LDDC/core/parser/lrc.py) and [converter](https://github.com/chenmozhijin/LDDC/blob/main/LDDC/core/converter/lrc.py). A boundary starts the following text and ends the preceding text. A trailing boundary explicitly ends the final segment. These are conventions, not a universally standardized format.

[AMLL's parser](https://github.com/amll-dev/applemusic-like-lyrics/blob/main/packages/lyric/src/formats/lrc/parser.ts) additionally accepts square-bracket inline timing, inferred final ends, translations, and other extensions. LDDC also handles another square-bracket word-timing format. Those extensions and inference policies are not implemented. Source implementations were inspected for syntax and semantics; no implementation code was copied.

The ordinary LRC parser and version-1 project contract remain unchanged. Enhanced input is explicitly selected; there is no content-based format autodetection. Untimed paragraphs within an enhanced file retain ordinary line-level behavior.

## Text and Timing Contract

```text
[offset:125]
[00:00.500]<00:00.600>Paper <00:01.000>skies.<00:01.500>
|<00:01.600>Blue <00:02.000>marks.<00:02.500>
[00:03.000]
```

Each timed physical line starts immediately with an inline boundary and ends with an explicit terminal boundary. Text between boundaries is preserved byte-for-byte after UTF-8 decoding; no spaces, punctuation, or Unicode sequences are trimmed or normalized. Empty text between boundaries, literal angle brackets in enhanced input, malformed or missing boundaries, and more than one paragraph timestamp on a timed entry are errors. There is no escape syntax. Square brackets in timed text are reserved and rejected. Supplying spaces before the first boundary or after the terminal boundary is an error, rather than silently discarding them.

Timestamps use the ordinary subset's two-or-more minute digits, two second digits below 60, and optional one-to-three decimal digits. Boundaries are absolute media times, not relative offsets or durations. Every segment has a positive half-open interval between adjacent boundaries. They must increase strictly within each physical line. A continuation's first boundary must be at or after the preceding terminal boundary; this permits an explicitly supplied interval between lines. No durations are inferred. All boundaries receive the same exact LRC and project offsets as paragraph focus.

The existing local `|` continuation supplies a newline inside one paragraph. This is an iLyric extension, not an enhanced-LRC standard. A timed paragraph must time every physical line; mixed timed and untimed continuations are rejected. Newlines have no ink or independent timing. Concatenating segment text with the supplied newline separators reproduces the complete displayed paragraph. Adjacent timestamped entries remain separate paragraphs.

Segment starts cannot precede paragraph focus. Ends cannot exceed the next paragraph or gap event, or the audio endpoint for the final paragraph. Completion exactly at the next event/audio endpoint is accepted. Duplicate paragraph entries require byte-identical text and identical segment ranges/times; conflicting duplicates fail. Ordinary repeated-timestamp entries remain supported; repeated paragraph timestamps with inline timing are rejected as ambiguous. Unsorted paragraph events retain ordinary chronological sorting. Fine-grained boundaries themselves are never sorted or repaired.

Limits remain 64 KiB UTF-8, 64 expanded paragraph/gap events, fewer than 500 UTF-16 units and four supplied/rendered lines per paragraph, and ten minutes. Additional limits are 128 segments per paragraph and 512 segments per file. Unsupported tags and metadata retain the ordinary contract.

## Unicode, Shaping, and Presentation

Source ranges use UTF-16 offsets for Core Text interoperability. Segment boundaries must also be Swift extended-grapheme boundaries in the complete reconstructed paragraph. Combining sequences, variation selectors, and emoji joiner sequences must remain intact. Grapheme validity does not establish glyph-cluster validity: layout separately rejects a boundary inside a shaped ligature or cluster, and unsupported right-to-left visual support. Color-glyph runs are explicitly rejected: Unicode stress testing found that isolated timed-run raster support did not reproduce complete-line color-emoji pixels. Ordinary LRC still preserves and renders text through the previous path. This is a progressive-rendering limitation, not a UTF-8 or grapheme rejection. The same validation applies when highlighting is disabled. There is no cluster expansion, word segmentation, fragment reshaping, or claim of universal multilingual support.

The paragraph is typeset as a whole once. A timed segment may cross automatically wrapped lines; cached shaped support is partitioned by rendered line and swept in source order using cumulative typographic advance. Focus remains governed exclusively by paragraph events. Before a segment it is dim; during it the supplied interval drives a synthetic spatial progression; after its end it is complete. Between supplied intervals the preceding support stays complete and upcoming support stays dim. A gap removes focus under the inherited policy. There is no inferred word or character timing.

Latin uses a hard spatial wipe. Japanese uses the existing softened-mask mechanism with a bounded synthetic interval mapping that reaches its endpoints at the supplied boundaries. Neither imports the measured Japanese crossing-interval expansion or vertical-event treatment into local input. Geometry, font candidates, line advances, and focus motion remain unchanged. These input appearance policies are synthetic visualization choices, not measured native lyric timing.

## Selection and Invocation

Version-2 experimental JSON adds required `inputs.lyricsFormat`, either `lrc` or `enhanced-lrc`, and optional `timing.highlighting`, either `enabled` (default) or `disabled`. Other fields and defaults retain version 1. Version 1 rejects the new fields and continues to use ordinary LRC. Explicit `highlighting` is rejected for `lyricsFormat: "lrc"`; an omitted setting has no appearance effect for untimed paragraphs. No migration or stable-schema promise is made.

```sh
.build/release/LyricsInputProbe render --lyrics FILE.lrc --audio FILE.wav \
  --format enhanced-lrc --highlighting enabled --output FILE.mp4
.build/release/LyricsInputProbe project --project FILE.json --output FILE.mp4
```

The direct command defaults to `lrc`; `--highlighting` requires explicit `--format enhanced-lrc`. Projects receive no CLI overrides. Disabled mode retains and validates supplied segment data while rendering exactly the inherited static line-level presentation. Audio decoding, duration, offset, visibility, artwork, 1080×1920/60-fps H.264/AAC output, uniform `contain`, error streams, refusal behavior, and atomic export remain unchanged.

## Original Example and Verification

```sh
swift build -c release
python3 scripts/generate_enhanced_example.py artifacts/enhanced-example
.build/release/LyricsInputProbe project \
  --project artifacts/enhanced-example/project.json \
  --output artifacts/enhanced-example/lyrics.mp4
python3 scripts/validate_local_input.py \
  artifacts/enhanced-example/lyrics.mp4 artifacts/enhanced-example/source.wav 601
python3 scripts/check_enhanced_input.py
```

The generator requires a new directory. Its original Latin and Japanese paragraphs supply complete two-line progression, an explicit gap, a nonzero offset, and an automatically wrapped segment. The separate Unicode fixture exercises intact combining marks, emoji joiners, variation selectors, punctuation, and a ligature-prone word; it does not qualify general multilingual appearance. Generated artwork, audio, and video remain ignored.

The integration check exports enabled and disabled projects plus the direct command, verifies all frame timestamps and supplied audio, checks localized decoded second-line progression in both scripts, and refuses fourteen invalid inputs/options before export. Swift tests separately establish exact intervals, cluster policy, complete coverage, focus independence, disabled raster equivalence, and repeated/reordered evaluation. Cached Latin inactive blur remains isolated from controls; its blend into timed support is a synthetic presentation rule. Japanese inactive treatment retains its previous qualification.

Version-2 projects preserve the existing relative-path, metadata, artwork, visibility, output, and duration fields. A minimal project is:

```json
{
  "version": 2,
  "inputs": {
    "audio": "source.wav",
    "lyrics": "lines.lrc",
    "lyricsFormat": "enhanced-lrc"
  },
  "timing": {
    "highlighting": "enabled"
  }
}
```

Strict unknown-field, duplicate-key, type, version, resource, and missing-file checks apply before the writer starts. The historical [version-1 contract](experimental-project-format.md) remains authoritative for version 1. Audio longer than the final terminal boundary retains the paragraph's completed appearance through its inherited interval; an explicit gap ends focus. Fine-grained ends beyond audio or the next paragraph are errors. Timing never changes audio start, silence padding, or codec behavior.
