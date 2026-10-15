# Lyrics Input Formats

This reference describes the input accepted by iLyrics 1.2.0. The experimental specifications under `reports/` preserve earlier parser contracts and probe commands; use this document with the current `ilyrics` command.

## Format Selection and Language Support

`render` selects TTML for `.ttml` and LRC for `.lrc`, case-insensitively. An LRC file containing angle-bracket timestamps is parsed as Enhanced LRC. Use `.txt` for plain lyrics, which are aligned automatically. `align` takes plain lyrics and writes TTML; it is not a timed-format converter.

English automatic synchronization is supported. Japanese support, including the display of supplied Japanese timing, remains deferred; Japanese and other languages are currently targeted as v1.3.0. Experimental parsing or rendering capability does not establish support. These plans do not guarantee a release date or feature delivery. See [Support](../SUPPORT.md).

## Plain Text

Write UTF-8 text with one sung lead line per line, blank lines between sections, and the complete sung sequence in order. Repeat refrains in full. `[Verse]` and `[Chorus]` labels are ignored. Lines containing neither letters nor digits are ignored; supported numeric lyrics such as `1, 2, 3, 4` are retained. See the [README](../README.md#plain-text) for numbers, songwriter credits, and duet markers.

Backing choruses remain experimental, unverified, and unsupported. Exclude both parenthesized backing phrases and standalone backing-only lines. Ordinary lead-sung refrains and vocables remain permitted. The existing syntax remains accepted; the [support policy](../SUPPORT.md#backing-choruses-and-vocables) describes its interpretation, warnings, and limitations.

Normalization splits sections into balanced groups of at most four lines and fewer than 500 UTF-16 code units. A single line that exceeds the text or display limits must be shortened by the user. The normalized text is limited to 64 KiB and 256 paragraphs. Alignment also limits the complete text to 12,000 CTC labels, including word separators and expanded numeric forms. Adding blank lines does not reduce this whole-song limit.

## LRC

```text
[00:00.500]Paper skies
[00:03.000]Morning light
[00:06.000]
```

Each timestamp starts a paragraph; an empty timestamped entry starts a gap. A paragraph lasts until the next event, or the audio endpoint for the last entry. Timestamps use two or more minute digits, two second digits below 60, and optionally one to three decimal places. Repeated timestamps on one entry repeat that text. Out-of-order events are sorted; conflicting text at the same effective time is rejected.

One `[offset:N]` tag shifts all events by the signed integer number of milliseconds, within ±600,000 ms. Effective times must remain within the audio. The metadata tags `ar`, `ti`, `al`, `by`, `re`, and `ve` are accepted and ignored; the header comes from audio metadata or CLI options. Other metadata tags are rejected. A line beginning with `|` continues the preceding paragraph on a new displayed line; this is an iLyrics extension.

## Enhanced LRC

```text
[00:00.500]<00:00.500>Paper <00:01.500>skies<00:02.500>
[00:03.000]<00:03.000>Morning <00:04.500>light<00:05.500>
[00:06.000]
```

Every timed physical line must start with an angle-bracket boundary and end with an explicit terminal boundary. A boundary ends the preceding segment and starts the next. These times are absolute media times, not offsets from the paragraph start. Preserve spaces inside the segments, as after `Paper` above. Boundaries must increase strictly; missing final boundaries, square-bracket word timing, and mixed timed/untimed continuations within one paragraph are rejected. No final word duration is inferred.

Word intervals must fit between the paragraph start and the next event or audio endpoint. `|` continuations are supported when every physical line in that timed paragraph has complete timing. Segment boundaries must not split a grapheme or shaped text cluster. Timed color-glyph and unsupported right-to-left runs are rejected. This is a bounded dialect, not support for every Enhanced-LRC extension.

## TTML

```xml
<tt xmlns="http://www.w3.org/ns/ttml" xml:space="preserve">
  <body><div>
    <p begin="0.5s" end="2.5s"><span begin="0s" end="1s">Paper </span><span begin="1s" end="2s">skies</span></p>
    <p begin="3s" end="5.5s">Morning light</p>
  </div></body>
</tt>
```

The importer accepts a bounded content-and-timing subset, not arbitrary TTML presentation documents or every provider's lyric dialect:

- Require UTF-8 XML, the TTML namespace above, `xml:space="preserve"` on the root, and one `tt/body/div` hierarchy containing `p` elements. An XML declaration, if present, must declare XML 1.0 and UTF-8 if it names an encoding.
- Paragraphs contain text and optional `br`, or timed direct `span` elements and optional `br`. In a timed paragraph, all displayed text, including spaces, must belong to spans. Do not indent or insert line breaks between spans inside a paragraph; use `br` for displayed line breaks. Nested spans are unsupported.
- Each paragraph and lead span requires `begin` and exactly one of `end` or `dur`. Both `begin` and `end` are relative to the parent's beginning. In the example, the first span runs from 0.5 to 1.5 seconds of the audio. `dur` is a duration from the element's own beginning.
- Supported times are `hh:mm:ss[.fraction]` and decimal offsets using `h`, `m`, `s`, or `ms`, with at most six decimal places. Only media time and parallel containers are supported. Frame, tick, wall-clock, and sequential-container timing are unsupported.
- Paragraphs and lead spans must be in order, have positive duration, and not overlap their peers. Children must fit inside their parents. No invalid timing is silently repaired. Empty paragraphs are explicit gaps; paragraph ends end focus.
- Bounded `xml:id` and `xml:lang` attributes are accepted as information. `ttm:agent="v2"` on a paragraph selects the second singer. One `span` with `ttm:role="x-bg"` per paragraph is accepted for the existing experimental backing-vocal feature; this does not change its unsupported status. The `ttm` namespace is `http://www.w3.org/ns/ttml#metadata`.
- Styling, regions, ruby, translation-specific extensions, external resources, DTDs, entity declarations, and unsupported elements or attributes are rejected. Supplied timing controls the iLyrics presentation; it does not reproduce arbitrary TTML styling.

## Limits and Timing Validation

| Input | Limit |
| --- | --- |
| LRC, Enhanced LRC, or TTML file | 64 KiB of UTF-8 |
| Expanded LRC events or TTML paragraphs/gaps | 256 |
| Text per paragraph | Fewer than 500 UTF-16 code units; at most four supplied lines |
| Display layout | At most eight rendered rows per paragraph |
| Enhanced-LRC segments | 128 per paragraph; 512 per file |
| TTML lead spans | 128 per paragraph; 1,536 per file |
| TTML XML structure | At most 4,096 elements and six levels |
| TTML backing text | One nonempty line, fewer than 300 UTF-16 code units |
| Audio | Mono or stereo; at most twenty minutes and 2 GiB; see [Audio](../README.md#audio) |

All event starts must precede the decoded audio endpoint; explicit interval ends may equal it but cannot exceed it. Automatic alignment needs at least one second of non-silent audio. Supplied timing skips model installation and automatic alignment. See [Reviewing and Correcting an Alignment](reviewing-alignment.md) for manual timing changes.
