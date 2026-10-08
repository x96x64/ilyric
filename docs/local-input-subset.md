# iLyric Experimental Local Input Contract

## Scope and Invocation

This contract defines the first bounded local-input experiment. It is not a finalized project schema or stable public CLI. `LyricsInputProbe render --lyrics FILE.lrc --audio FILE --output FILE.mp4` renders the experimental full-screen scene without network access. The production `ilyric` commands remain unchanged. Existing output files are refused; the parent directory must exist. Diagnostics go to stderr, one JSON result goes to stdout. Exit statuses are 0 for completion/help, 2 for input/usage errors, and 1 for rendering/export failure.

## Supported LRC Subset

Input is strict UTF-8, optionally with a leading UTF-8 BOM. LF and CRLF delimit physical lines. Text after timestamp tags is preserved without trimming or Unicode normalization. Control characters other than tab and line delimiters are rejected.

- Timestamps are `[mm:ss]` or `[mm:ss.f]`, with two or more minute digits, two second digits in 00–59, and one to three fractional digits. Fractional digits represent decimal seconds exactly. Times are stored as integer milliseconds and normalized rational values, never rounded to video frames.
- Multiple leading timestamps expand into separate events with identical paragraph content. Out-of-order events are sorted by exact time with a diagnostic. Byte-identical text at duplicate timestamps is deduplicated with a diagnostic; conflicting text at the same timestamp is rejected.
- A single standalone `[offset:SIGNED_INTEGER]` supplies milliseconds. Positive offsets delay lyrics; negative offsets advance them. Negative effective times are rejected. The offset applies to every event regardless of its position in the file.
- Standalone `ar`, `ti`, `al`, `by`, `re`, and `ve` metadata tags are recognized and ignored with diagnostics. They do not query metadata services or change the synthetic artwork/title/artist defaults. Other tags and enhanced-LRC angle-bracket timing constructs are rejected.
- Empty physical lines are ignored. A timestamp with no following text explicitly begins an instrumental gap. Whitespace-only text is rejected rather than treated as an invisible paragraph.
- A physical line beginning with `|` extends the immediately preceding timestamped paragraph with an explicit newline and the exact text following `|`. This **local extension** supplies multiline structure; it is not ordinary LRC semantics. It applies to all timestamps on that entry. Empty continuation lines, continuations after gaps or metadata, and more than four supplied lines are rejected. Adjacent timestamped entries remain separate paragraphs.

Supplied explicit boundaries are recorded separately from automatic Core Text wrapping. Neither is asserted to be verified native source-authored structure. Each nonempty paragraph is shaped as a whole. Line timing does not provide word, syllable, or character timing; no fine-grained highlight events are inferred.

## Clocks, Focus, and Duration

Output and audio time start at zero and advance together. Effective lyric media time is the supplied timestamp plus the LRC offset. Focus changes at that exact time and persists through the half-open interval ending at the next event. Before the first event and during empty events there is no focused paragraph; nearby inactive paragraphs may remain visible. Gaps retain the previous scroll target. Nonempty events compile the existing analytic focus response. This is an experimental presentation rule, not measured native timing semantics.

Decoded audio presentation duration determines output length. An event at or beyond the audio endpoint is rejected; lyrics never extend or truncate audio silently. The final event holds until that endpoint. Leading/trailing source silence is preserved. Output is padded with silence to the next 60-fps boundary, by less than one frame; no trimming option is provided.

## Audio and Output Policy

Only readable, unprotected local files with one audio track are accepted. Public AVFoundation decoding preserves source-rate signed 16-bit PCM, then a separately flushed AVAudioConverter converts it to 48-kHz mono PCM; multichannel sources beyond stereo are rejected. Stereo uses an explicit equal-weight arithmetic mean of both channels (integer division toward zero). Opposite-phase content can cancel; stereo preservation is deferred. Source rates must be integral and within 8–96 kHz. The existing writer re-encodes PCM as mono AAC at 128 kb/s alongside 1080×1920 H.264 at exactly 60 fps with Rec.709 metadata. Codec copying is not promised. Decode support depends on the installed macOS codecs; the engineering report lists tested containers and formats.

Decoded timestamps are checked on the 48-kHz source-rate sample lattice, then mapped to 48 kHz. Leading presentation gaps are filled with silence; overlaps, unexplained discontinuities, and duration discrepancies are errors. Source codec priming and container endpoints are interpreted by AVFoundation; export priming and trailing AAC padding are evaluated separately during validation. Protected streams and DRM circumvention are unsupported.

Native 1179×2556 layout uses uniform `contain`; the distinct 1180-pixel reference-recording canvas is unchanged. Static paragraph appearance is used for both scripts. Japanese line-only input has no inferred progressive appearance or bounded glyph-treatment events. Latin inactive treatment retains its experimental blur/contrast model. Optional controls remain hidden, lower controls remain visible, and audiovisual test flashes are disabled.

## Resource Bounds

Limits are 64 KiB of LRC, 64 expanded events, 499 UTF-16 units and four supplied/rendered lines per paragraph, 256 MiB of source audio, stereo or mono, and ten minutes of decoded audio. At least one nonempty paragraph is required. Every entry must fit these bounds before export. Already-shaped paragraph masks are cached; only visible paragraphs are rasterized and at most six inactive tile sets are retained. These limits bound this experiment, not the eventual product's capacity.
