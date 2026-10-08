# iLyric Lyrics Acquisition Feasibility Study

## Decision and Scope

**Go for an offline preparation and timing-review milestone. Conditional go for a later, explicitly requested LRCLIB lookup experiment. No-go for unrestricted provider-to-video acquisition.** The primary architecture should accept legitimately supplied files, preserve provenance and permission evidence, validate compatibility and recording correspondence, and prepare immutable local inputs for the existing renderer. Provider lookup should be an optional preparation operation, never a rendering dependency.

LRCLIB provides the strongest initial technical opportunity: documented anonymous access, application identification, line synchronization, and a newer word/segment representation. Its API permission does not license the underlying lyrics. Musixmatch documents synchronized data, but its public API terms prohibit incorporating that data into new audiovisual works. LyricFind offers relevant commercial products without a publicly established agreement for this CLI. No synchronized-text retrieval endpoint was identified in the reviewed public Apple Music API or MusicKit documentation. These findings support continued local-input development without requiring a commercial acquisition agreement.

This is a research and architecture-planning record, accessed **8 October 2026**. It introduces no acquisition client, provider dependency, public schema, alignment implementation, credential, or rendering change. It is not legal advice. Contract interpretation, applicable copyright exceptions, territorial coverage, and disputed or commercial export permissions require provider clarification or qualified legal review. A user confirmation records a claim; it neither establishes ownership nor overrides a prohibition.

## Methodology and Existing Foundation

Evidence categories used below are **documented** provider/specification claims, **observed** public documentation or source behavior, **engineering inference**, **proposed requirements**, and **unknown**. Sources were official documentation, terms, specifications, repository code/licenses, and model cards. No authenticated API calls, catalog lyric lookups, audio uploads, model execution, or coverage sampling were performed. Documentation response examples were inspected for field structure; commercial text and source examples are not reproduced here. Availability, accuracy, and service latency have not been independently benchmarked.

The repository began clean on `main`, with local and remote HEAD at `5cf2f64`. The planning baseline, complete Git history including retained attribution backup, input models, commands, format contracts, and relevant tests were reviewed. Existing experimental JSON versions 1–3, supplied audio, ordinary LRC, enhanced LRC, and the bounded TTML2 importer remain authoritative. See the [local-input report](local-input-integration.md), [configuration report](project-configuration.md), [enhanced-LRC report](enhanced-lrc-integration.md), and [TTML report](ttml-integration.md).

`LyricEntry` retains exact `Time`, complete paragraph text, source-line and supplied-break information, segments, and optional explicit paragraph ends. `TimedSegment` retains UTF-16 ranges and rational start/end values. This is sufficient for supported local timing, but its provenance strings do not represent acquisition identity, permission scope, matching evidence, or conversion history. Those gaps belong in preparation records, not frame evaluation.

The physical reference remains native Music on iPhone 16, reported iOS 27.0.1, exact build **Unknown**. Default Display Zoom; Text Size 4/7 counting the smallest as 1/7; Bold Text, Reduce Motion, Reduce Transparency, and Increase Contrast off; Light appearance; English system and Music languages remain unchanged. This study adds no physical measurement and makes no native-fidelity claim.

## Provider Capabilities and Operational Constraints

### LRCLIB

The [official API documentation](https://lrclib.net/docs) describes unauthenticated reads: `/api/get`, `/api/get/{id}`, and `/api/search`. Metadata matching requires title and artist; album and duration improve discrimination. Its duration tolerance is ±2 seconds. Search returns at most 20 results without pagination. Responses include record ID, track/artist/album, duration, `instrumental`, `plainLyrics`, line-timed `syncedLyrics`, `hasWordSync`, and raw YAML `lyricsfile`. Word timing is in `lyricsfile`, not implied by legacy LRC.

Clients must identify the application through an accepted identification header. Documentation recommends sequential requests with 200–500-ms spacing; this is guidance, not a guaranteed quota. Honor `Retry-After` on throttling/overload and handle non-JSON errors. No fixed numeric request allowance, SLA, or ISRC lookup field was established. Automatic selection by `/api/get` is provider matching behavior, not verified correspondence to a local recording.

The [developer terms, version 2026-09-30](https://lrclib.net/developers/terms), permit registered API integration, including commercial applications, and retain anonymous access. They require responsible use and expressly separate API permission from third-party lyric rights. Registration verifies mailbox control, not ownership, security, or legal compliance. It does not guarantee additional capacity or availability. A printable application authorization is not a catalog-content license.

The [Lyricsfile draft specification](https://github.com/tranxuanthang/lyricsfile/blob/348cd04b9d002fac8f5f67694064605026f9d030/SPECIFICATION.md), linked from [LRCLIB's format page](https://lrclib.net/lyricsfile), defines integer milliseconds from audio start: `lines[].text/start_ms/end_ms` and optional `words[].text/start_ms/end_ms`. Ends are optional; lines and words may overlap. Segment text includes needed whitespace. `plain` is independent and may differ from synchronized text. This is word-or-segment data, not verified syllable or character timing.

The draft's [open questions](https://github.com/tranxuanthang/lyricsfile/blob/348cd04b9d002fac8f5f67694064605026f9d030/OPEN_QUESTIONS.md) leave offset application, missing ends, exact word-text consistency, containment, and compatibility unresolved. A future adapter must reject unsupported cases rather than use an older client concept document as a settled standard. The specification's public-domain dedication applies to its documentation, not lyrics encoded with it.

The [server architecture](https://github.com/tranxuanthang/lrclib/blob/05ad8590f6fc4d47a2d74e70f4915273df20f63c/ARCHITECTURE.md) describes contributions, revisions, and cached responses. A stable record ID does not freeze its returned content. Source documents also describe nullable historical Lyricsfile data, whereas the current site describes universal availability; deployment conformance was not tested. Preserve response/version hashes and handle missing fields explicitly. Community contribution and proof of work do not establish a contributor's copyright authority. Neither a per-record rights chain nor catalog-wide export permission was established.

### Musixmatch

[Current onboarding](https://docs.musixmatch.com/getting-started) covers individual developers and selected partners; normal API calls require a confidential `apikey`. [Enterprise authentication](https://docs.musixmatch.com/enterprises/authentication) separately documents OAuth 2.0. Consumer accounts, desktop-client tokens, and subscription access are not substitutes for an authorized integration.

The documented data surfaces distinguish:

| Surface | Verified Structure or Purpose | Qualification |
| --- | --- | --- |
| [Lyrics](https://docs.musixmatch.com/api-reference/lyrics-catalog/track-lyrics-get) | Plain lyric body and rights/display metadata | Text availability is not synchronization |
| [Subtitles](https://docs.musixmatch.com/api-reference/lyrics-catalog/track-subtitle-get) | `subtitle_body`, duration/language/copyright/tracking fields; selectable `lrc`, `dfxp`, or `mxm` representation | Line synchronization; returned DFXP is not automatically within iLyric's TTML subset |
| [Rich synchronization](https://docs.musixmatch.com/api-reference/lyrics-catalog/track-richsync-get) | `richsync_body` contains JSON with line `ts`, `te`, text `x`, and `l` entries containing text `c` and offset `o` | Fine-grained text offsets; examples contain words, spaces, and punctuation, not a guaranteed one-character or syllable clock |
| [Matching](https://docs.musixmatch.com/api-reference/lyrics-catalog/matcher-track-get) | Track identifiers and metadata; subtitle/richsync retrieval accepts provider IDs or ISRC and duration filters | Capability and entitlement depend on the supplied key/agreement |

Richsync examples express subordinate offsets within line timing, but do not supply independent end values for every text unit. Inferring those ends would be a documented conversion policy, not additional provider precision. Decimal tokens must be parsed exactly; availability flags do not guarantee unrestricted bodies.

[Implementation guidance](https://docs.musixmatch.com/implementation-guidelines) prefers ISRC, then metadata and duration. [Content restrictions](https://docs.musixmatch.com/content-restrictions) can suppress bodies by artist, track, or territory. [Display tracking](https://docs.musixmatch.com/lyrics-views-tracking) and the [launch checklist](https://docs.musixmatch.com/checklist) impose obligations including attribution and usage reporting. These mechanisms require a separately agreed solution for an offline video. Account call limits must be checked before integration. No applicable numeric quota, price, or entitlement for iLyric was verified; the pricing link returned unavailable during this review.

The [public API terms, updated 24 June 2025](https://about.musixmatch.com/apiterms), establish the decisive restriction: section 2.2.12 prohibits fixing the data into new audio or audiovisual works. Default use is noncommercial unless otherwise agreed; section 2.2.14 also requires prior written approval for specified AI/ML processing. Section 7.2 requires deletion on termination. Therefore conversion, caching, a user-owned API key, or an alignment tool cannot make the default service suitable for iLyric video generation. A written agreement expressly covering the proposed use is necessary. [Enterprise catalog feeds](https://docs.musixmatch.com/enterprises/catalog-feed/overview) document offline data access under contract; their existence does not authorize a self-serve application to reproduce it.

### Apple Music and MusicKit

Reviewed public [Apple Music API resources](https://developer.apple.com/documentation/applemusicapi), [song attributes](https://developer.apple.com/documentation/applemusicapi/songs/attributes-data.dictionary), and [MusicKit Song](https://developer.apple.com/documentation/musickit/song) document metadata, including duration and ISRC, and [`hasLyrics`](https://developer.apple.com/documentation/musickit/song/haslyrics) as an availability Boolean. No public synchronized lyric-text or timing retrieval endpoint was identified. This is a bounded documentation finding, not a claim about unpublished systems.

[Developer-token documentation](https://developer.apple.com/documentation/applemusicapi/generating-developer-tokens) establishes authenticated catalog access and throttling; subscriber authentication is a separate concern. Neither authorization nor playback access creates an undocumented lyric capability. Apple could be a separately qualified metadata source, but offers no established acquisition path for this gate.

[Provider submission guidance](https://itunespartner.apple.com/music/support/5218-submit-lyrics) and [iTunes Connect delivery guidance](https://itunespartner.apple.com/music/support/5267-deliver-song-lyrics-itunes-connect) concern authorized delivery of lyrics, including timed assets. Submission is not consumer retrieval or permission to reuse catalog lyrics. Private endpoints, traffic interception, application-data extraction, native-application automation for restricted recovery, and DRM circumvention are excluded.

### LyricFind

[Lyric Display](https://www.lyricfind.com/products/lyric-display) advertises static, line-synchronized, and word-synchronized products. It directs prospective integrations to commercial contact. No sufficiently detailed public response schema, credential procedure, matching contract, quota, or iLyric-compatible storage/export grant was established. These remain questions for the provider, not inferred features.

The separate [Videos product](https://www.lyricfind.com/products/videos) offers artist-facing lyric-video creation and business solutions. This establishes a relevant commercial discussion route, not authorization to export generic API results through iLyric. [Website terms](https://www.lyricfind.com/terms-and-conditions) govern that site and are not an API-content license. No integration is implementation-ready without delivery specifications and an applicable agreement.

Across these providers, the reviewed sources do not establish consistently available syllable timing or complete character-level timestamps. A short text segment or a character-offset representation is not evidence of that coverage. Granularity must be assessed from each authorized payload, separately from the provider's product label.

## Permission Analysis

Technical retrieval, provider contract, underlying lyric rights, audio rights, and software licensing are independent. The following matrix concerns this proposed workflow, not every possible licensed use. **Unresolved** means the reviewed material does not establish permission; it does not mean automatically forbidden. A contractual prohibition requires an applicable replacement authorization, not a confirmation checkbox.

| Operation | LRCLIB | Musixmatch Public API Terms | LyricFind | Apple Public Retrieval |
| --- | --- | --- | --- | --- |
| API integration in an independently distributed application | Documented API permission; identify client | Issued credentials, applicable agreement, and obligations | Agreement and specification unresolved | No lyric retrieval capability identified |
| Local lyric storage | Underlying rights remain unresolved | Subject to authorized scope; no permanent-export grant | Contract unresolved | Not established |
| Response caching | Responsible caching encouraged; not a content license | Retention/deletion and contract conditions require review | Contract unresolved | Not established |
| Format transformation | Content-processing rights unresolved | Export-oriented conversion is not an exception to restrictions | Contract unresolved | Not established |
| New or corrected timing data | Rights and permitted processing unresolved | AI-assisted use specifically restricted without approval; other derivatives require scope review | Contract unresolved | Not established |
| Embedding in a standalone video | Not granted by API permission | Prohibited by section 2.2.12 under reviewed terms | Separate video arrangement required | Not established |
| Publishing that video | Separate authorization unresolved | No grant for the prohibited incorporation | Territory/platform/distribution rights unresolved | Not established |
| Commercial output | Commercial API use does not grant content rights | Prior written authorization required | Commercial contract required | Not established |
| Bundling lyrics, caches, or credentials with source/binaries | Not authorized by software/API license | No general sublicense; keys confidential | Not established | Not established |

For user-supplied files, origin must be recorded without declaring all supplied material lawful. Original works, appropriately licensed material, or verified public-domain text with separately cleared recordings provide a minimum viable route. A purchase, streaming subscription, open database, attribution, or noncommercial intent alone does not establish every required use right. Rights to lyrics, the musical work, a particular recording, and artwork must be assessed separately for the intended output and jurisdiction. The [U.S. Copyright Office's composition/recording distinction](https://www.copyright.gov/register/pa-sr.html) provides one jurisdiction-specific explanation; it is not a worldwide export authorization.

Before a commercial provider gate, obtain written answers covering local retention and deletion; format conversion and correction; alignment/ML processing; standalone audiovisual fixation; private export versus public distribution; monetization; territories/platforms; attribution/reporting; content withdrawal; and distribution of a public CLI without an embedded secret. Record the actual agreement and permitted repertoire. No provider contact or agreement was obtained in this study.

## Open-Source Reuse and Maintenance

The following are observed repository snapshots, not endorsements or evidence of lyric rights. Dates are GitHub repository `pushed_at` dates in UTC, not release guarantees. All listed repositories were unarchived when checked. No code or dependency was adopted. iLyric has no selected software license; compatibility must be decided before copying or linking code, separately from content and model licensing.

| Project and Inspected Revision | Push Date; Code License | Reuse Assessment |
| --- | --- | --- |
| [LRCLIB](https://github.com/tranxuanthang/lrclib/tree/05ad8590f6fc4d47a2d74e70f4915273df20f63c) | 2026-08-07; MIT | Documented server behavior and revision/caching concepts; deployment may differ from source |
| [LRCGET](https://github.com/tranxuanthang/lrcget/tree/7538998f264e068c748280ac7b61262d2827fa8f) | 2026-09-05; MIT | Official client uses documented LRCLIB search/get operations; useful metadata-review and local-library precedent; do not inherit automatic selections or assume older format notes are normative |
| [syncedlyrics](https://github.com/moehmeni/syncedlyrics/tree/3c8a318d9a8df26855bdc3a5d23f7fd2b99ade2e) | 2024-07-28; MIT | LRCLIB adapter uses public endpoints; Musixmatch adapter instead uses a consumer desktop host/token flow. Do not adopt that route. README lists broken providers; first-result selection and implicit fallback are unsuitable defaults |
| [AMLL TTML Tool](https://github.com/amll-dev/amll-ttml-tool/tree/d4953b351ae073c1447464790fff17aa9bc1d807) | 2026-09-19; GPL-3.0 license file | Local timing/editing and format-conversion reference, not a license to acquire lyrics. Background vocals, duets, metadata, and extension formats exceed iLyric's subset; validate exported files. Prefer evaluating a separately installed editor over embedding its web/Tauri dependency stack |

Public interfaces and unofficial clients must be classified per adapter, not per project's popularity or software license. No unofficial route is recommended as a reliability fallback. Reuse the existing parsers and validators for conversion acceptance. Network libraries, YAML parsing, caches, and editor integrations should be added only for a bounded demonstrated need, with pinned dependencies and synthetic contract tests.

## Recording Identification and Synchronization

### Candidate Selection

The proposed procedure separates **identity confidence**, **alignment confidence**, and **permission status**. Do not combine them into a single score that can conceal a failed permission check.

1. Collect supplied title, artist, album/release, version qualifiers, language, explicit/clean status, optional legitimate ISRC/provider IDs, and decoded audio duration. Future local-tag inspection must distinguish embedded tags from user assertions. Retain original values; normalized search keys must not rewrite displayed lyric text.
2. Search only an explicitly selected provider. Display a bounded candidate list with IDs, release/version differences, duration deltas, available timing granularity, and restriction indicators. Title/artist similarity and popularity are ranking evidence, not sufficient selection rules.
3. Classify contradictory versions, languages, live/studio status, edits, clean/explicit variants, and unexplained duration differences as conflicts. A unique ISRC-supported candidate may be ranked strongly, but still requires recording-timing review. Missing album or variant evidence remains visible uncertainty. Do not assign calibrated probability percentages without a labeled evaluation corpus.
4. Require explicit selection when ambiguous; in noninteractive operation require a previously selected record and content hash or return an ambiguity diagnostic. Never silently use the provider's first result or substitute unsynchronized text.
5. Record the selected response revision/hash and the actual local audio identity. A file hash establishes byte identity, not musical identity; a separately versioned decoded-audio hash can support reproducibility across preparation runs but does not establish rights.

[IFPI's ISRC guidance](https://isrc.ifpi.org/faqs) distinguishes recordings from compositions and permits retention of ISRC across many remasters. The [ISRC Handbook, Annex A](https://isrc.ifpi.org/images/downloads/ISRC_Handbook.pdf), also distinguishes creative changes from certain silence, speed, and fade modifications. Consequently an ISRC is valuable matching evidence but not a sample-exact synchronization guarantee. LRCLIB's ±2-second tolerance is a provider search rule, not an iLyric acceptance threshold. No audio fingerprinting is required for the initial gate.

### Timing Review and Correction

Retrieval and alignment are different operations. Compare decoded duration with provider duration and the final supplied event; report leading/trailing silence and codec/container endpoint differences rather than silently trimming. Unknown duration conventions must remain unknown. Review audible anchors near the beginning, middle, and end, including repeated phrases and any edit boundary. Preserve occurrence identity instead of matching repeated text by string alone.

A roughly constant discrepancy is evidence for a proposed global offset; inconsistent discrepancies suggest drift, edits, missing verses, or a wrong recording. Report anchor residuals before and after a proposed offset. Require user review; do not silently time-stretch, discard events, or change text. Existing exact project offsets can represent a reviewed constant shift. Piecewise correction is future local editing, not an acquisition heuristic. Source timestamps, corrections, and review notes must remain distinct.

Fallback order is: a better permitted record; a supplied compatible synchronized file; manual correction/authoring using legitimately supplied text and audio; an explicitly qualified local alignment experiment. Missing synchronized data must not trigger restricted-service scraping. Insufficient fine timing may be downgraded to a separately generated, explicitly selected line-only artifact; do not erase the original timing or mislabel it as word synchronization.

## Optional Audio-Assisted Alignment

**Acquisition** obtains existing text/data; **transcription** estimates text from audio; **forced alignment** locates supplied text; **refinement** adjusts existing timestamps. None grants text or recording rights. For already supplied lyrics, alignment is the relevant optional operation; transcription should not silently replace the authoritative text.

| Tool | Documented Scope and Licensing | Japanese, Runtime, and Limitations |
| --- | --- | --- |
| [WhisperX](https://github.com/m-bain/whisperX/tree/771b4a14a9486f8fd5aef18ef49e35d639523dd3) | Speech transcription plus language-specific forced alignment; BSD-2-Clause code; pushed 2026-09-26 | Documents CPU operation including macOS and CUDA acceleration. Dependencies/models are substantial; no iLyric throughput measurement. Speech overlap and dictionary coverage are limitations, not solved singing behavior |
| [Montreal Forced Aligner](https://github.com/MontrealCorpusTools/Montreal-Forced-Aligner/tree/d2dc283bd79667e086b1f93050a1855349f63f1f) | Supplied transcript/dictionary/acoustic-model alignment, word/phone annotations; MIT code; pushed 2026-10-07 | Japanese model/dictionary available; separate Python/Conda/Kaldi-oriented environment. Local CPU workflow is feasible in principle, not benchmarked here; singing pronunciation, sustained vowels, accompaniment, and segmentation require validation |
| [SOFA](https://github.com/qiuqiao/SOFA/tree/9549c6a86d16019c817eefe4bb8183405da524cc) | Singing-oriented forced alignment, text-to-phoneme mapping, confidence and boundary evaluation; MIT code; pushed 2026-09-02 | Python/PyTorch and optional ONNX workflow; supplied checkpoints and dictionaries required. Default documented phoneme example is Mandarin-oriented. A ready, licensed Japanese checkpoint and validated mixed-song performance were not established |

WhisperX's [alignment source](https://github.com/m-bain/whisperX/blob/771b4a14a9486f8fd5aef18ef49e35d639523dd3/whisperx/alignment.py) selects a Japanese wav2vec2 model and contains interpolation of unaligned values. Its Japanese character-oriented handling is not proof of mora, syllable, or glyph-cluster accuracy. The [Japanese model card](https://huggingface.co/jonatasgrosman/wav2vec2-large-xlsr-53-japanese) declares Apache-2.0 and speech training; its 16-kHz input requirement belongs to a separate analysis copy, not the export audio pipeline. The [WhisperX paper](https://arxiv.org/abs/2303.00747) evaluates speech, not this project's singing corpus.

The [MFA Japanese model card](https://huggingface.co/MontrealCorpusTools/japanese_mfa) declares CC-BY-4.0 for the model and identifies speech use. It separately lists training datasets with varied restrictions; do not redistribute those datasets under the model's license or infer a singing guarantee. Dictionary, model, dependencies, and any derivative distribution require their own inventory. SOFA's code license likewise does not automatically cover independently supplied checkpoints or training material.

All three can be considered for local analysis after required artifacts are provisioned; installation and default model-loading paths may download resources. Offline operation therefore requires pinned artifact hashes, license review, disabled automatic retrieval, and a network-denied test. No candidate is adopted. GPU requirements, Apple-platform acceleration, memory, model coverage, and real-time performance must be measured for the selected configuration.

The smallest later alignment experiment should use original sung Latin/Japanese excerpts with manually reviewed boundaries, sustained syllables, silence, repeated phrases, and an overlapping-vocal failure case. Compare supplied line anchors plus manual refinement against one aligner, not a new benchmark platform. Report missing/extra units, median and high-percentile boundary error, worst residual, and manual correction effort. Model scores are not calibrated confidence. Store estimates and interpolation flags separately; review unresolved segments or retain coarser timing. No accuracy figure is asserted by this study.

## Interoperability With Existing Inputs

The [W3C TTML2 Recommendation](https://www.w3.org/TR/2018/REC-ttml2-20181108/) is broader than iLyric's [strict subset](ttml-subset.md). An extension-bearing editor export or Musixmatch DFXP result cannot simply be relabeled compatible TTML. Current [enhanced-LRC rules](enhanced-lrc-subset.md) also require explicit terminal boundaries; generic enhanced LRC is not universally interchangeable.

| Acquired Form | Preparation Requirement | Current Limitation |
| --- | --- | --- |
| Plain text | Preserve verbatim; request authorized timing input or reviewed alignment | No fine timing may be manufactured; no automatic text-only render timeline |
| Ordinary synchronized LRC | Run the existing parser; surface unsupported tags, repeated-event conflicts, gaps, offsets, and limits | Final hold/next-event semantics are presentation policy, not supplied ends |
| Lyricsfile | Validate version, safe bounded YAML, exact milliseconds, text equality, explicit intervals, and offset semantics | Missing ends, nonzero unresolved offset, overlap, equal boundaries, or text mismatch require refusal/review; no adapter exists |
| Richsync | Preserve decimal precision, line identity and text ranges; obtain an authorized contract and clarify offset/end semantics | No adapter; a derived segment end is not a provider-supplied end |
| Provider TTML/DFXP | Resolve supported namespace/timing/whitespace only; report all unsupported presentation semantics | Styling, ruby, agents/duets, overlapping vocals, and provider extensions exceed the current subset |
| Alignment/editor output | Preserve original text, map external indices to UTF-16, retain estimated/reviewed provenance | Phone/character boundaries may not align with graphemes or shaped clusters |

A proposed converter must preserve exact timing before any output sampling. Integer milliseconds map directly; decimal seconds require rational parsing. TTML accepts up to six fractional digits in its bounded expressions; enhanced LRC accepts milliseconds. Finer source precision must trigger a loss report or refusal, never silent rounding. Internal rational capacity does not make every serialization lossless.

Lyricsfile's unresolved cases are material, not cosmetic. For an initial conservative subset, accept only absent/zero global offset, ordered nonoverlapping positive intervals, explicit ends needed by the destination, and byte-equivalent reconstructed Unicode text. Refuse unknown fields that affect timing or structure; retain the original only when permitted. Reject aliases/custom tags and bound YAML size/depth/expansion if an adapter is later approved. Missing ends may instead lead to explicitly selected line-level behavior, preserving uncertainty; do not save inferred ends as supplied data.

Paragraph grouping is not recoverable merely from provider line arrays. Do not combine adjacent lines to imitate screenshots, split timed spans at renderer wraps, or assume plain and synchronized versions are interchangeable. Preserve explicit breaks separately from automatic wrapping. Repeated phrases retain separate occurrences. Whole-paragraph shaping and current rejection of split graphemes/ligatures, unsupported timed right-to-left support, and color-glyph progression remain mandatory, including disabled-highlight preparation.

The present 64-KiB input, 64-event, 128-segment-per-paragraph, 512-segment-total, four-line, fewer-than-500-UTF-16-unit paragraph, and ten-minute bounds can exclude ordinary commercial-length lyric files with many short lines. Preparation must report this before export. Raising limits requires a separate resource regression; truncation or opportunistic paragraph merging is unacceptable. No existing schema is modified by this proposal.

## Proposed Acquisition Boundary and User Workflow

The boundary is **explicit acquisition or local intake → candidate review → rights and timing validation → prepared local files → existing offline render**. Preparation may use network access only when requested. Raster evaluation receives immutable local content and rational times; it receives no provider session, retry policy, credential, or remote URL. This preserves deterministic rendering and allows visual-engineering gates to proceed independently.

### Preparation Record

Use a private, experimental sidecar proposal before considering a project-schema revision. Required information groups are:

| Group | Proposed Information |
| --- | --- |
| Source | Local/provider identity, record ID/revision, retrieval UTC time, API/document version, raw format and hash where retention is permitted |
| Recording | Supplied and provider metadata kept separately, optional ISRC, version/language qualifiers, audio hash, decoded duration/sample convention |
| Timing | Claimed and validated granularity, exact source time units, explicit versus inferred ends, paragraph/segment occurrence IDs, breaks, ranges, offsets |
| Transformation | Converter/version, source-to-output mapping, losses/refusals, text hash, reviewable corrections; never silently overwrite the source |
| Confidence | Match evidence and conflicts, alignment anchors/residuals, estimated or interpolated timing, reviewer decision and unresolved items |
| Permission | Separate statuses for retrieval, storage/cache, conversion, alignment, video embedding, publication, commercial use, and redistribution; evidence reference, scope/territory, expiry, attribution and deletion obligations |
| Reproduction | Prepared-file hashes, relevant tool/model versions, validation result, and compatible existing project/input version |

Statuses should distinguish documented permission, user-asserted permission, prohibition, and unknown. They are evidence labels, not automatic legal certification. Permission evidence may be sensitive; shareable manifests must exclude credentials, personal paths, private agreements, and source text unless sharing is permitted. A hash does not itself grant retention or redistribution rights. The acquisition stage should not produce an export-ready approval when the intended action is prohibited or unresolved; users may instead supply independently cleared local inputs. This is a future preparation policy, not a new restriction retroactively inserted into the renderer.

### Interaction and Failure Behavior

The proposed user sequence is: supply local audio and metadata; optionally request a named provider lookup; inspect candidate differences; select a record; record intended use and permission basis; review timing/format diagnostics; prepare local files; render offline using the existing invocation. Previewing provider text itself must comply with its display terms. Confirmation of identity and confirmation of permitted use are separate decisions.

For scripting, adopt predictable machine-readable results on stdout, diagnostics on stderr, refusal to overwrite by default, explicit input/output paths, and bounded noninteractive failure. Preserve current rendering exit statuses; define acquisition-specific result categories before adding codes. Distinguish no match, ambiguous match, restricted/missing lyrics, unsupported format, unauthorized credentials, rate limiting, outage, and cancellation. No hidden provider cascade or replacement of timed lyrics by plain text is allowed. FFmpeg, Git, ripgrep, and yt-dlp inform these interaction principles, not proposed stable command names.

Do not distribute provider secrets inside a desktop CLI. Where supported, use individually authorized credentials and an OS credential store or explicitly supplied secret source; redact headers, query parameters, URLs, and error payloads before logging. An API requiring a shared confidential client secret may need an approved backend and therefore does not qualify automatically for the portable offline-first design. No credentials belong in projects, public examples, or recorded terminal diagnostics.

Use timeouts, response-size/decompression limits, bounded retries, `Retry-After`, cancellation, and explicit refresh. Do not evade restrictions, rotate identities, or submit audio for identification without separate authorization. Metadata lookup itself discloses listening information; request only necessary fields. Treat returned markup, filenames, and links as untrusted data, never executable instructions or automatically fetched resources.

### Cache and Reproducibility

Cache only within established permissions. Separate query metadata, restricted raw payloads, and reviewed prepared inputs; assign source/scope/expiry and a deletion path to each. Do not invent a universal retention period. Keep caches private and out of Git, diagnostics, shared projects, and public fixtures. Cache refresh creates a new reviewed revision; it must not replace a pinned render input silently.

If a provider requires live reporting, immediate withdrawal, or online validation during use, reconcile that contract before promising offline export. A service incompatible with this boundary should remain unsupported. When retention is disallowed, do not promise archival reproducibility from retained lyrics; retain only permissible evidence and report that limitation. Deletion must cover authorized derived caches as well as raw responses. The renderer must never refresh a cache while evaluating frames.

## Strategy Decision Matrix

These are engineering assessments, not measured scores. Content availability and synchronization quality depend on the exact recording and permitted repertoire.

| Criterion | Direct Documented Provider | Supplied Files and Local Review | Hybrid, Explicit Provider Assistance |
| --- | --- | --- | --- |
| Implementation complexity | Medium to high: auth, restrictions, matching, conversion | Low incremental work over existing imports | Medium: local path plus optional adapter/review |
| Synchronization quality | Variable; line or fine data may mismatch a release | Supplied quality; manual correction possible | Candidate evidence plus local verification |
| Availability | Catalog, territory, entitlement, outage dependent | Requires user sourcing/authoring | Local fallback survives provider failure |
| Operational dependencies | Network, credentials, quotas, provider changes | No rendering network; optional external editor | Network only during requested preparation |
| Rights uncertainty | Significant unless intended video use is covered | User rights evidence still required | No automatic clearance; explicit separate decisions |
| Portability | Confidential credentials/reporting may require a service | Existing macOS rendering scope; portable data | Provider layer separable from platform backend |
| Maintainability | Adapter and contract changes | Smallest dependency surface | Bounded if only justified providers are added |
| Open-Source CLI suitability | Conditional; no shared secrets or lyric bundling | Strongest immediate foundation | Preferred longer-term architecture with local path primary |

**Primary:** provider-independent, offline-first preparation with supplied files as the supported baseline. **Fallback:** reviewed local correction or authoring, retaining line-level presentation when fine timing is unavailable. **First optional provider:** LRCLIB, restricted to documented reads and a permission-aware review workflow; begin with line LRC, not speculative universal Lyricsfile conversion. Commercial providers become justified only when a real use case and agreement cover the intended export, operational obligations, and distribution model. Apple retrieval remains a no-go absent a newly documented public capability.

## Verification, Risks, and Implementation Readiness

Publication is limited to this study, its README link, and a requirements clarification. All 43 relative links across those documents resolve. Heading review, whitespace checks, source attribution review, and private/generated-path checks passed. Four focused public policy tests passed, including missing-corpus and private-path refusal behavior. Historical reports, profiles, application code, tests, and project schemas are unchanged. Existing media results remain historical evidence; audiovisual, model, and provider integration tests were deliberately not repeated for a documentation-only gate. Source and model licenses were inspected, not selected for incorporation.

Unresolved dependencies are content-specific export permission, commercial agreements and entitlements, deployed Lyricsfile conformance, incomplete/overlapping timing, recording-version ambiguity, model/checkpoint rights, singing accuracy, and current importer resource ceilings. None demonstrates a rendering architectural obstacle. General native Music fidelity remains unvalidated.

## Implementation-Ready Phased Blueprint

| Phase | Bounded Deliverable | Prerequisites and Acceptance Criteria |
| --- | --- | --- |
| **1. Offline Intake and Review — Go** | Separate experimental preparation/validation operation using existing LRC/enhanced-LRC/TTML parsers and audio inspection; private provenance/permission report; exact offset proposal and reviewed local output | Original or independently cleared fixtures. Preserve source bytes and timings; test wrong editions, repeated phrases, duration/offset conflicts, parser limits, cluster refusals, and unknown/prohibited permission labels. No network, provider dependency, automatic alignment, or changes to existing project schemas. Reuse existing project versions and rendering. Network-denied preparation/render must pass |
| **2. Explicit LRCLIB Candidate Lookup — Conditional Go** | One read-only, user-requested adapter with metadata comparison, record selection, and pinned local result; initially ordinary LRC only | Recheck API terms/application identification; define item-level content-use evidence and retention policy before saving/export preparation. Test entirely synthetic responses for ambiguity, 429/non-JSON/503, cancellation, missing/restricted data, and changed revisions. No automatic first result, bulk harvesting, upload, or implied export license. Unknown rights yield review-required, not export-ready |
| **3. Reviewed Fine-Timing Conversion — Conditional Go** | One conservative Lyricsfile-to-supported-input conversion, only if actual authorized inputs justify it | Pin current draft; reject unresolved offsets, missing required ends, overlaps, text mismatch, and unrepresentable precision. Require lossless text/range tests and explicit review for every inferred change. Do not weaken whole-paragraph shaping or TTML validation |
| **4. Local Alignment Evaluation — Deferred, Conditional** | One aligner evaluated against manual correction on original Latin/Japanese singing | Verify every model/dictionary license and offline artifact dependency. Report boundary uncertainty, interpolation, failure cases, runtime/memory, and correction effort. Estimates remain distinct; no unattended timing acceptance or transcription substitution |
| **5. Licensed Provider Expansion — No-Go Pending Agreement** | Musixmatch or LyricFind adapter only for an identified permitted use | Written audiovisual/cache/conversion/distribution rights, applicable territories/reporting/deletion, actual schema examples, quotas, safe credential architecture, and synthetic contract tests. Musixmatch public terms are insufficient. No Apple private retrieval path |

The next coding agent should implement **Phase 1 only**, using the repository's current parsers, exact time model, preparation checks, and original fixtures. This is a bounded validation/provenance milestone, not a new lyric editor or acquisition framework. The current renderer already accepts supported local files; the new value is reproducible review and traceable preparation. Use the source register below to recheck only changed provider terms when a network gate is actually proposed, rather than repeating this entire study.

Lyrics Translation correspondence, automatic translation, SF Symbols-based control refinement, measured dynamic materials, broader full-screen fidelity, and edge-to-edge `adapt` remain separate future gates. No symbol-license investigation or material implementation was performed. Unresolved licensed acquisition must not block those independent milestones or rendering with appropriately cleared local inputs.

## Source Register and Access Record

All sources above and below were accessed **2026-10-08**. Human-readable links are authoritative entry points; pinned revisions identify inspected source snapshots. Documentation findings are not authenticated service observations.

| Source Group | Verification Basis and Limits |
| --- | --- |
| LRCLIB API, developers, terms | [API](https://lrclib.net/docs), [developer registration](https://lrclib.net/developers), [terms](https://lrclib.net/developers/terms). Public site text inspected through its served application assets where the page shell omitted content; terms version 2026-09-30. No record lookup or registration |
| Lyricsfile | [Format page](https://lrclib.net/lyricsfile), [draft](https://github.com/tranxuanthang/lyricsfile/blob/348cd04b9d002fac8f5f67694064605026f9d030/SPECIFICATION.md), [open questions](https://github.com/tranxuanthang/lyricsfile/blob/348cd04b9d002fac8f5f67694064605026f9d030/OPEN_QUESTIONS.md), [documentation license](https://github.com/tranxuanthang/lyricsfile/blob/348cd04b9d002fac8f5f67694064605026f9d030/LICENSE). Supersedes reliance on older LRCGET concept notes |
| Musixmatch | [Documentation index](https://docs.musixmatch.com/llms.txt), linked endpoint specifications, onboarding, restrictions, enterprise authentication/feed, and [terms](https://about.musixmatch.com/apiterms). Official Postman examples were cross-checked against current documentation; no key, negotiated agreement, or working pricing entitlement |
| Apple | Public MusicKit/Apple Music API references and provider-support pages linked above. Public DocC representations were inspected where web pages required JavaScript. No public lyric endpoint identified within this review |
| LyricFind | Official Lyric Display, Videos, and website terms linked above. Product capabilities verified as documented; API schemas and contractual permissions unverified |
| Recording Identity, Timed Text, and Rights | [IFPI handbook](https://isrc.ifpi.org/images/downloads/ISRC_Handbook.pdf), [FAQ](https://isrc.ifpi.org/faqs), [W3C TTML2](https://www.w3.org/TR/2018/REC-ttml2-20181108/), [U.S. Copyright Office](https://www.copyright.gov/register/pa-sr.html). Identity and interchange standards do not license lyric content; jurisdiction-specific explanations do not resolve other jurisdictions |
| Open-Source Projects | Pinned repositories in the reuse/alignment tables; public GitHub metadata, README, license files, and relevant adapter/alignment source. Recent pushes do not guarantee support, security, or deployed behavior |
| Alignment Models | [Japanese wav2vec2](https://huggingface.co/jonatasgrosman/wav2vec2-large-xlsr-53-japanese), [Japanese MFA](https://huggingface.co/MontrealCorpusTools/japanese_mfa), [WhisperX research](https://arxiv.org/abs/2303.00747), [SOFA phoneme mapping](https://github.com/qiuqiao/SOFA/blob/9549c6a86d16019c817eefe4bb8183405da524cc/modules/g2p/readme_g2p.md). No model downloaded or tested; model-card declarations are not independent rights or accuracy audits |
