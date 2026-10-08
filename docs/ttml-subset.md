# iLyric Experimental TTML Subset

## Specification and Selection

This bounded importer uses the content and media-time semantics of the [W3C TTML2 Recommendation, 8 November 2018](https://www.w3.org/TR/2018/REC-ttml2-20181108/), sections 8 and 12. It is not a complete TTML processor, standardized profile, IMSC implementation, or Apple lyric dialect. [Timed Text Toolkit's verifier](https://github.com/skynav/ttt/blob/master/ttt-ttv/src/main/java/com/skynav/ttv/verifier/ttml/TTML1TimingVerifier.java) distinguishes coordinate, duration, and container validation. [AMLL's parser](https://github.com/amll-dev/applemusic-like-lyrics/blob/main/packages/ttml/src/parser.ts) includes provider extensions and millisecond rounding. Those extensions, trimming, and rounding are not adopted; no source code is copied.

Select `--format ttml` explicitly. Experimental project version 3 adds `inputs.lyricsFormat: "ttml"`; versions 1 and 2 retain their documented format sets and strict fields. Version 3 otherwise retains version-2 fields, defaults, and validation. `timing.highlighting` or the direct `--highlighting` selects `enabled` or `disabled` for enhanced-LRC or TTML. No automatic format detection occurs.

## Structure, Text, and XML Safety

Require UTF-8 XML 1.0 within 64 KiB, with namespace `http://www.w3.org/ns/ttml`. Require exactly `tt/body/div`, followed by 1–64 `p` elements. Prefixes may vary. Each `p` contains either text and `br`, or explicitly timed direct `span` elements and `br`. Spans contain text and optional `br`; nested spans and mixed untimed text/timed spans are rejected. Empty `p` is an explicit gap. Empty or whitespace-only spans and empty visible lines are rejected.

The root must specify `xml:space="preserve"`; descendants inherit it and may repeat `preserve`, but cannot use `default`. Decoded spaces, punctuation, Unicode sequences, and character references remain unchanged without normalization. XML line-ending and attribute normalization follows XML 1.0. Tabs and text-node line breaks within lyric content are rejected; use `br` for an explicit break. Formatting whitespace outside paragraphs is noncontent. Every `br` inserts one newline with supplied-break provenance, distinct from automatic wrapping. Comments are noncontent; CDATA is supported as text. `xml:id` and `xml:lang` are bounded informational attributes, not styling or translation; IDs must be unique and use the bounded ASCII name subset `[A-Za-z_][A-Za-z0-9_.-]*` within 80 characters. Language identifiers are bounded ASCII informational tokens; no language matching or full BCP 47 validation is implemented. No document metadata, styling, regions, ruby, writing modes, animation, embedded media, or extension attributes are silently ignored.

Use a bounded XML parser with namespace processing, external entity resolution disabled, an external-resolution policy of `never`, and a refusing resolution delegate. Reject all DTD/entity declaration tokens before parsing, including tokens in comments or CDATA. Reject processing instructions, external resources, non-UTF-8 declarations, and unsupported namespaces/elements/attributes. Numeric and five predefined XML character references are allowed. No network or resource retrieval is performed. Limits are depth 6, 1024 elements, 64 paragraphs/gaps, fewer than 500 UTF-16 units and at most four supplied/rendered lines per paragraph, 128 spans per paragraph, 512 spans per document, and ten minutes. Violations abort parsing; no recursive unbounded tree is built.

## Exact Timing and Presentation

Media time starts at zero; `ttp:timeBase="media"` may be specified on the root. Only parallel containers (`timeContainer="par"`, or omitted) are supported. `body` and `div` may omit begin (zero relative to parent) and end (inherit the parent's bound). Paragraphs and spans require explicit `begin` and either `end` or `dur`. Supplying both `end` and `dur` is rejected even if consistent; this narrower rule avoids implementing TTML's minimum-duration resolution. Zero, negative, missing, overlapping, or out-of-order paragraph/span intervals are rejected. No interval is sorted, clipped, repaired, or inferred from text.

Both `begin` and `end` are coordinates relative to the parent's begin; `dur` is a duration from the element's begin. Supported expressions are `hh:mm:ss[.fraction]` (hours at least two digits, minutes/seconds exactly two and below 60) and nonnegative decimal offset values with `h`, `m`, `s`, or `ms`. Fractions permit 1–6 digits. Values and resolved intervals must remain within 0–600 seconds; all arithmetic is rational. Frames, ticks, wall-clock, SMPTE, leap seconds, indefinite values, and timing-rate parameters are unsupported. Children must fit fully inside their parent; inherited container bounds are constraints, not supplied segment timing.

Paragraph focus owns its explicit half-open interval. Before its begin and after its end there is no focus unless another paragraph begins. The scroll target is retained during gaps under the existing synthetic policy. Span completion never advances focus. Before a span its support is dim, during it the existing script-aware visualization progresses, and afterward it stays complete until paragraph departure. This persistence is a Lyrics reconstruction policy, not TTML subtitle removal semantics. Untimed paragraphs remain line-level. Timed spans must cover the complete displayed text except explicit newline separators; meaningful inter-span spaces must belong to a timed span. Source intervals may cross renderer wraps or explicit breaks without fragment shaping.

Project offsets shift paragraph and span boundaries exactly. Starts must precede the audio endpoint; ends may equal it but cannot exceed it. Audio continues through its full inherited duration, with less than one frame of explicit silent padding. TTML ends terminate focus rather than holding to the next paragraph as ordinary LRC does. Disabled highlighting retains and validates timing while using static paragraph appearance and the same explicit focus intervals.

Extended grapheme and shaped-cluster boundaries are validated separately. The existing whole-paragraph Core Text policy rejects split ligatures/clusters, timed right-to-left runs, and color-glyph progression, including disabled preparation. No automatic word segmentation, source normalization, fragment reshaping, or native font identity is inferred.

## Example and Commands

```xml
<tt xmlns="http://www.w3.org/ns/ttml" xml:space="preserve">
  <body><div>
    <p begin="0.625s" end="3.25s"><span begin="0.101s" end="1.274s">Paper skies.</span><br/><span begin="1.503s" dur="0.998s">Blue marks.</span></p>
    <p begin="3.25s" end="4.5s"/>
    <p begin="4.5s" end="7s">青い点を二つ置く<br/>紙の空に丸を描く</p>
  </div></body>
</tt>
```

```sh
swift build -c release
python3 scripts/generate_ttml_example.py artifacts/ttml-example
.build/release/LyricsInputProbe project --project artifacts/ttml-example/project.json --output artifacts/ttml-example/lyrics.mp4
.build/release/LyricsInputProbe render --lyrics FILE.ttml --audio FILE.wav --format ttml --highlighting enabled --output FILE.mp4
python3 scripts/check_ttml_input.py
```

The example generator uses original text, artwork, and audio. Output remains 1080×1920, 60 fps, H.264/AAC, uniform `contain`. Production `ilyric`, audio decoding, writer behavior, ordinary LRC, enhanced-LRC, and historical scenes remain unchanged. No stable schema or comprehensive TTML compatibility is promised.
