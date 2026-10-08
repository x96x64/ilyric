# Apple Music Local Lyrics Cache Feasibility

## Decision and Evidence Boundary

October 9, 2026. **No-go for integrating Music cache acquisition into iLyric at this gate.** The historical cache paths exist and their main database is readable, but no matching lyric index entries were found in the limited view inspected. The separate write-ahead log and cached response bodies were not inspected. Consequently, neither current cache-wide absence nor successful TTML retrieval is established. Permission for conversion and standalone video export is also unestablished.

This is a bounded technical and rights assessment for one developer’s private, personal, noncommercial use. No adapter, converter, acquisition client, or rendering change was implemented. The existing supplied-file timing path remains available; acoustic correspondence remains a necessary fallback. No automatic synchronization or native iOS 27 fidelity claim follows. The macOS application is an input investigation, not the canonical visual reference.

## Inspected Implementations

The following public sources were pinned and inspected on October 9, 2026. Neither application nor its installation instructions were executed. Their MIT licenses govern software, not Apple service content or lyric rights.

| Repository and Revision | Source Findings and Limits |
| --- | --- |
| [Takpap/apple-music-lyrics](https://github.com/Takpap/apple-music-lyrics/tree/e402374f4d371d8709f6e091570b4a864e03b903), `e402374f4d371d8709f6e091570b4a864e03b903` | Swift 5.9 package, macOS 13 minimum, no external package dependency. The provider invokes SQLite read-only, searches `syllable-lyrics`, and reads inline or `fsCachedData` JSON responses. It also scans recent files. `syllableLyrics`/`ttmlLocalizations` are private response assumptions. The provider does not fetch missing lyrics. AppleScript supplies current-track metadata. |
| [rakei076/applyrx](https://github.com/rakei076/applyrx/tree/ccf17e81e48e006358a18647c5c3e281fe1ff47d), `ccf17e81e48e006358a18647c5c3e281fe1ff47d` | Python/PyObjC implementation. It copies the database and sidecars, decodes cached request headers, and replays a signed `ttmlLyrics` request through curl. Catalog matching also uses online iTunes lookup. This is not a purely local response-body reader. Request extraction and replay are excluded from this experiment. |

Takpap’s matcher uses normalized/transliterated metadata and duration scores, then selects a best candidate; it does not prove exact recording identity or require a unique catalog-ID match. Its parser collapses whitespace, uses floating-point times, and supplies missing endpoints. These policies cannot be adopted as lossless iLyric conversion. The private schema can change or contain stale entries. [Provider](https://github.com/Takpap/apple-music-lyrics/blob/e402374f4d371d8709f6e091570b4a864e03b903/Sources/AppleMusicLyrics/AppleMusicCacheLyricsProvider.swift), [parser](https://github.com/Takpap/apple-music-lyrics/blob/e402374f4d371d8709f6e091570b4a864e03b903/Sources/AppleMusicLyrics/AppleTTMLParser.swift).

Applyrx’s documented strict matching exceeds its inspected guarantee: the implementation permits duration agreement within two seconds plus title, artist, **or** a unique-duration fallback, and returns the first accepted candidate. Its basic parser flattens paragraph text and does not preserve span timing. Dependencies pin PyObjC 12.1 components, rich 14.3.3, requests 2.33.1, and py2app 0.28.10; none was installed. Claims of offline operation do not remove the observed request replay. [Matching implementation](https://github.com/rakei076/applyrx/blob/ccf17e81e48e006358a18647c5c3e281fe1ff47d/main.py), [cache/request implementation](https://github.com/rakei076/applyrx/blob/ccf17e81e48e006358a18647c5c3e281fe1ff47d/apple_music_ttml.py).

## Public Interfaces and Content Permissions

Apple’s public `Song.hasLyrics` is an availability Boolean. The inspected song-resource fields include catalog metadata, duration, ISRC, and availability, but no synchronized lyric text or timing. No supported retrieval endpoint was established by this review. The two repositories depend on undocumented Music internals; their operation does not establish an Apple-supported API. Apple’s TTML asset guide describes provider submission, not consumer retrieval. Sources accessed October 9, 2026: [MusicKit property](https://developer.apple.com/documentation/musickit/song/haslyrics), [song attributes](https://developer.apple.com/documentation/applemusicapi/songs/attributes-data.dictionary), [API overview](https://developer.apple.com/documentation/applemusicapi), [asset guide](https://help.apple.com/itc/videoaudioassetguide/en.lproj/static.html). Public documentation JSON was inspected where the documentation page required JavaScript; no catalog request was issued.

The current Japanese and U.S. Apple Media Services terms, section F, limit use to personal/noncommercial purposes, retain copyright-owner rights, restrict software-assisted scraping, copying, measurement, analysis, and monitoring of content/services, and prohibit circumvention. Personal scope alone therefore does not establish an exception for a cache converter. Account jurisdiction, any separately applicable authorization, and statutory exceptions were not determined. This is an engineering permission assessment, not legal advice. No categorical conclusion about every lawful personal use is asserted. Sources accessed October 9, 2026: [Japanese terms](https://www.apple.com/jp/legal/internet-services/itunes/jp/terms.html), [U.S. terms](https://www.apple.com/legal/internet-services/itunes/us/terms.html).

| Operation | Finding |
| --- | --- |
| Inspect the public software and license | Completed; MIT does not license cached lyrics |
| Inspect local filesystem/cache structure | Bounded ordinary-permission observation completed |
| Extract, retain, or transform lyric bodies | No applicable permission established; not performed |
| Embed lyrics in a private video | Separate unresolved permission; not inferred from playback access |
| Publish or redistribute lyrics, cache data, or videos | Not authorized or performed |
| Obtain/replay signed requests or bypass security | Excluded by task; not performed |

No rights inquiry was prepared or sent. The obsolete unsent inquiries remain deferred to their separate cleanup milestone.

## Observed Local Cache Structure

The inspected environment reports macOS 27.0.1 and Music 1.7, bundle build 1.7.0. Ordinary filesystem access found `~/Library/Caches/com.apple.Music/Cache.db` (3,784,704 bytes), a 1,388,472-byte WAL, a 32,768-byte shared-memory sidecar, and 295 regular files in `fsCachedData`.

One SQLite connection used `mode=ro&immutable=1`, without database copying, writable connections, checkpoints, journal changes, or request-blob selection. Only schema, counts, and aggregate candidate-storage lengths were queried. The main-database view contained 394 response rows and zero request-key matches for either `syllable-lyrics` or `ttmlLyrics`. No request keys, catalog identifiers, headers, lyric bodies, or filesystem-cache bodies were returned or retained. The expected response, blob, and receiver-data table names exist; schema resemblance alone does not establish usable lyrics.

**This was a limited main-file view, not a consistent inspection of the complete live cache.** Immutable access omits normal locking/change detection; an active database can invalidate its results, and the WAL was excluded. No claim that the user’s cache contains no lyrics is justified. Read-only WAL access and shared-memory behavior require separate care; this gate did not copy sidecars or broaden inspection to recover missing results. [SQLite URI behavior](https://www.sqlite.org/uri.html), [WAL behavior](https://www.sqlite.org/wal.html), accessed October 9, 2026.

Observed database, WAL, and shared-memory sizes and modification times remained unchanged between the initial and subsequent checks. No explicit metadata write occurred. The complete before/after metadata equality check nevertheless returned false; field-level deltas were not retained. Subsequent inspection showed a recent directory access time, consistent with enumeration, but did not isolate the cause. Therefore this experiment cannot claim zero metadata effects from ordinary filesystem reads. No attempt was made to restore timestamps or alter Music’s state. Future inspection requiring literal metadata immutability needs an authorized stable read-only snapshot; the live-cache method is not qualified for that guarantee.

Music was not launched, controlled, or asked to populate lyrics. No account data was decoded; no system protections were changed. Cache freshness, hidden response variants, actual timing granularity, matching recordings, and local TTML compatibility remain unverified. Conversion was not attempted because no usable, permitted local example was established.

## TTML Compatibility and Proposed Matching Boundary

The comparison below concerns documented/source-visible structures, not a retrieved local document. Apple’s published asset examples contain metadata, song-part divisions, speaker roles, and timed spans. Span size may represent words or smaller supplied text units; neither a `syllableLyrics` relationship name nor short span text establishes character timing.

| Possible Source Feature | Existing iLyric Contract and Required Decision |
| --- | --- |
| `head` metadata, multiple divisions, speaker/Apple extension attributes | Strict importer rejects them. A separately qualified converter must preserve or explicitly classify semantics, not strip them indiscriminately |
| Two-component clock values and apparently document-relative nested times | Current importer requires three-component clock values or supported decimal offsets, with parent-relative timing. Establish source semantics before exact rational rebasing; never add parent offsets blindly |
| Inter-span spaces, nested spans, translations, background vocals | Preserve complete displayed text and original ranges. Mixed untimed text, nested spans, and overlapping paragraphs currently fail; no flattening, translation substitution, or discarded singer is acceptable |
| Timed spans and explicit breaks | Retain supplied granularity and ends; validate grapheme boundaries and whole-paragraph shaped clusters. Never infer character timestamps or shape fragments independently |
| Long or complex songs | Existing limits remain: 64 KiB, 64 paragraph/gap intervals, 512 spans, ten minutes, fewer than 500 UTF-16 units/four lines per paragraph; failures remain explicit |

The [bounded TTML contract](ttml-subset.md), `LyricsInputCore/TTML.swift`, and reviewed preparation paths were inspected. External entities, DTDs, unsupported styling, invalid intervals, text loss, and shaped-cluster violations must remain refusals. No schema or parser relaxation is justified by the present evidence.

A future permitted intake should require an explicitly selected candidate and preserve its source identity privately. Compare catalog identifier where supplied, title, artist, album, edition, explicit/clean status, and duration; missing or conflicting evidence requires review. Multiple candidates remain ambiguous. Neither matching title nor a unique duration is sufficient. Catalog identity also cannot establish that local audio has the same master, edit, leading silence, speed, or offset.

Bind any prepared timing to the supplied audio hash and decoded duration. Review correspondence at the beginning, middle, ending, and repeated passages; record offsets or corrections separately without replacing original times. A constant offset cannot repair an edit or drift. Retain source format/hash, exact times and units, text-range mapping, conversion losses, permission evidence, and review/correction provenance in a private preparation sidecar. This is a proposed boundary, not a new public schema or implemented matcher.

## Alternatives and Next Gate

Legitimately supplied timing for a verified matching recording can eliminate alignment inference. It still requires format validation, recording correspondence, rights review, and correction where necessary. This study establishes no proportion of the personal collection for which that shortcut is available. Cache eviction, private schema changes, incomplete timing, recording differences, and unresolved permission prevent treating it as a dependable replacement for acoustic alignment.

LRCLIB remains only a documented secondary option. Its documentation describes metadata/duration lookup, application identification, line-synchronized LRC, and a separate `lyricsfile` representation. Duration tolerance is a matching heuristic, not synchronization proof. This gate issued no lyric/catalog request. The developer-terms page could not be retrieved by the research browser; no new export-rights conclusion supersedes the historical [acquisition study](lyrics-acquisition-feasibility.md). [Current API documentation](https://lrclib.net/docs), accessed October 9, 2026.

**Proceed with continued correspondence improvement, not Music cache integration.** The smallest implementation remains candidate-local, unforced CTC contradiction checks and missing-candidate diagnostics on the existing EN-F01 failure, preserving rejected TIFA results and review requirements. A timing-source milestone becomes justified only when one legitimately supplied synchronized file, its corresponding local recording, and permission for the intended processing are available. Then qualify a lossless conversion with synthetic ambiguity, malformed-input, unsupported-structure, and provenance tests. Neither cache population nor private-request replay is a prerequisite for personal iLyric development.

## Verification and Resource Accounting

The working repository passed all 146 Python tests, all 61 Swift tests through the established `scripts/test.sh` wrapper, the optimized release build, and sequential/shuffled/repeated/fresh-renderer raw BGRA equality. The initial direct `swift test` invocation encountered the known Testing-framework discovery problem; the existing wrapper resolved it without package or toolchain changes. Existing TTML, exact-time, correction, input, and rendering tests remain unchanged. No new executable functionality warrants new adapter tests.

A fresh source-only archive passed all 146 model-free Python tests without private assets. The retained public-only verification checkout had byte-identical content for all 160 implementation, fixture, test, script, and package files; it independently passed 61 Swift tests, 146 Python tests, the release build, and raw-frame determinism again. It contains neither private references nor the model environment. Reusing its build avoided another large checkout. Documentation links, whitespace checks, ignored-path checks, and the complete publication diff were reviewed. No affected application behavior justified repeating expensive audiovisual exports; earlier export evidence remains historical rather than a new result.

The initial comprehensive allocated-storage inventory was 14,396,669,952 bytes. After verification it was 14,603,550,720 bytes (14.604 decimal GB; 13.601 GiB), leaving 396,449,280 bytes under the unchanged 15,000,000,000-byte ceiling; filesystem free space was 40,468,480,000 bytes. The scope includes complete `artifacts/` (4,407,664,640 bytes), `reference-private/` (4,862,353,408), `.build/` (986,365,952), and all nine retained verification checkouts (4,347,166,720 combined). The public-only checkout rebuilt intermediate files; no historical assets were deleted or excluded. These are dated allocation snapshots, not a continuous peak measurement.

No models, dependencies, or recordings were downloaded. Retained public repository text totals 88,677 bytes; Apple public documentation JSON totals 52,658 bytes. Exact cumulative historical transfer remains unavailable. Retain the conservative 1.50-GB historical planning charge, the prior 12-MB provisioning cap, and a 1-MB allowance for this small source/documentation review: 1.513 decimal GB against the 2,000,000,000-byte ceiling, not a reconstructed transfer ledger. Browser and GitHub metadata traffic are not claimed as exactly measured.

Only this report, its README link, and the supplied-timing/fallback clarification in current product requirements change. No private source content, catalog IDs, credentials, third-party source, or diagnostic logs enter Git. Historical reports, models, recordings, alignment evidence, rendering behavior, and backup references remain unchanged.
