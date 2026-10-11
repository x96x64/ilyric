# iLyric Product Requirements

## Status and Product Objective

This document records confirmed long-term goals and deferred decisions. It is not a feature declaration, implementation plan for any single engineering gate, or stabilized schema. Historical experiment reports remain authoritative for measured capabilities and limitations.

iLyric is developed independently by one human maintainer and is intended for public open-source distribution. Personal, noncommercial development remains the immediate working context; lawful public installation, redistribution, reproducibility, and reliable operation are explicit release requirements. The public source repository, private research assets, and separately licensed model dependencies must remain distinct. Commercial deployment and third-party services are unnecessary, but a personal-use restriction must not silently become a mandatory dependency of an unrestricted open-source product. No software license has been selected; a license decision requires explicit maintainer approval.

The intended product is a scriptable command-line tool that creates animated Lyrics videos from user-supplied recordings, corresponding lyric text or synchronized lyric data, artwork, and configuration. Rendering existing songs must eventually be possible; synthetic fixtures are engineering tests, not the final input workflow.

| Area | Current Status | Required Future Outcome |
| --- | --- | --- |
| Rendering | Deterministic experimental typography, appearance, composition, and audiovisual export | Supported user inputs and documented compatibility guarantees |
| Fidelity | Qualified physical-reference reconstruction candidates | Stable canonical native-layout preset with explicit uncertainty |
| Input and synchronization | Bounded ordinary/enhanced LRC and TTML/audio imports; experimental reviewed alignment preparation | Mandatory automatic singing-audio alignment, measured accuracy, correction, and broader timing compatibility |
| Configuration and CLI | Experimental developer invocations | Versioned project configuration and conventional scripting interface |
| Materials, controls, and animation | Provisional backgrounds, original placeholders, bounded test events | Separately measured and tested presentation options |

## Mandatory Automatic Synchronization

Automatic alignment of user-supplied complete lyric text with the corresponding singing recording is the highest-priority prerequisite for a usable iLyric product. Legitimately available synchronized timing may satisfy the timing requirement for a verified matching recording without acoustic inference. Automatic alignment remains mandatory as the fallback when usable timing is unavailable; service-cache accessibility alone does not establish permission or recording correspondence. Users must not be required to timestamp every line, word, or character manually. Automatic transcription, online retrieval, and provider matching are not prerequisites when the user supplies the complete text. Optional acquisition remains deferred.

The [automatic-alignment experiment](automatic-alignment.md) establishes an offline preparation prototype, not completion of this requirement. Product acceptance requires practical automatic timing on complete supplied recordings, explicit unmatched or ambiguous occurrences, manageable single-user correction, practical runtime/memory, and an auditable correction path. Review cannot substitute for a functional automatic synchronization system. Formal multi-annotator studies and publication-grade certification remain optional; a single maintainer can perform documented engineering evaluation. Public support claims nevertheless require a locked evaluation set representative of the declared recording subset, with failures, correction effort, and uncertainty reported. Preserve historical research criteria and distinguish single-user listening review from independent acoustic ground truth. Automatic acceptance remains disabled; a complete forced path or a vocal-activity flag cannot establish lyric correspondence. A technically valid video or a successful speech-model invocation does not establish synchronization accuracy. Separate original text, pronunciation/model units, estimated boundaries, reviewed corrections, and deterministic rendering; preserve whole-paragraph shaping.

Broad visual expansion, SF Symbols, edge-to-edge 9:16 adaptation, Lyrics Translation, and generalized customization remain deferred until automatic synchronization has a demonstrated practical path. Licensing decisions, model-free CI, and installation planning may proceed independently. Canonical visual refinement may resume after complete-song correspondence qualification and a working correction-to-export path; it need not await every research uncertainty or Japanese automatic-alignment qualification. This sequencing preserves separate evidence and rights gates and does not declare deferred features implemented.

## Recordings, Lyrics, and Timing

Investigate TTML, ordinary LRC, enhanced LRC, and a versioned native project format through bounded import milestones. Preserve supplied line structure separately from inferred authored semantics. Do not stabilize field names or commands before format and compatibility studies.

Potential workflows include user-authored or user-supplied timed lyrics, metadata-based matching, appropriately licensed synchronization providers, and automatic alignment of supplied lyric text to supplied singing audio. Provider integration requires verification of actual accessible data, terms, permissions, attribution, caching, and redistribution constraints. Matching metadata does not establish lyric rights or timing accuracy.

Apple documents MusicKit `Song.hasLyrics` as an availability Boolean. It does not supply text or timestamps through that property. No complete synchronized-lyric retrieval capability is established by this review; an automated integration must independently verify its supported API and permissions. [Apple documentation](https://developer.apple.com/documentation/musickit/song/haslyrics).

Distinguish supplied timestamps from estimated alignment. Record source, granularity, and uncertainty, and provide review and correction of uncertain alignment. Line, word, syllable, and character timing are separate capabilities. Fine-grained highlighting must be independently switchable from line focus. When timing precision is insufficient, require an explicit fallback or diagnostic; never manufacture exact character or word timestamps from line-only data.

Do not extract protected Apple Music data, bypass DRM, scrape restricted services, redistribute copyrighted lyrics, or include commercial recordings in public fixtures. Users must supply media they are entitled to process; provider access does not itself establish export rights.

### Acquisition and Preparation Boundary

The [Lyrics acquisition feasibility study](lyrics-acquisition-feasibility.md) establishes an offline-first direction: local intake, provenance, compatibility validation, and reviewed timing correction precede optional provider integration. Network access must be explicitly requested during preparation and must never enter deterministic frame evaluation. Rendering prepared local inputs must remain possible without network access.

Record source identity, exact recording correspondence, retrieval or intake provenance, timing granularity, supplied versus estimated boundaries, conversion losses, and review decisions. Preserve permission evidence separately for retrieval, retention/cache, transformation, alignment, video embedding, publication, commercial use, and redistribution. Unknown permission is not authorization; user confirmation is an assertion, not verification, and cannot override an explicit provider prohibition. Source and model software licenses do not license lyric content.

Matching a lyric record and aligning it to the supplied recording are separate validation steps. Ambiguous editions, unexplained duration differences, missing ends, overlapping vocals, unsupported Unicode/shaped support, and resource-limit violations require explicit diagnostics or review rather than silent repair. Preserve original files and correction history where retention is permitted. Provider credentials and restricted caches must remain outside shared projects and diagnostics. These requirements do not stabilize a provider interface or public preparation schema. Experimental alignment capabilities and unresolved accuracy are recorded separately.

## Presentation and Delivery

Plan configurable visibility for artwork, metadata, progress information, transport, volume, lower controls, optional lyric controls, and explicitly qualified system-chrome approximations. Preserve application content and system-owned chrome as distinct concepts.

Future appearance controls include typography, alignment, opacity, blur, highlighting, gradients, and backgrounds. Motion controls may configure the independently justified lyric-focus and appearance animations, including duration, easing, and bounded intensity. A generalized screen, artwork, or scene-transition library is not an established product requirement. Lyrics Translation denotes translated lyric display, not screen-transition animation. A documented canonical reference preset must remain available alongside customization.

Whole-paragraph shaping and deterministic arbitrary-time evaluation remain invariants. Customization must not silently change text shaping at timing boundaries or introduce frame-history dependence.

Native-layout presentation and edge-to-edge 9:16 adaptation are distinct outputs. Preserve uniform `contain`; develop `adapt` through explicit layout rules. Do not stretch the native reference or describe reflowed adaptation as screenshot reproduction.

## Lyrics Translation

Lyrics Translation is a deferred product capability: display user-supplied translated text alongside or in association with original synchronized lyrics. Define explicit original-to-translation line correspondence, language identification, configurable visibility, and synchronized focus presentation. Typography, wrapping, vertical spacing, active/inactive appearance, and full-screen composition must be validated together before integration.

Translated-text display, automatic translation generation, and external translation retrieval are separate capabilities. Only supplied translated-text display is established as a product goal here; generation and retrieval require independent requirements, provider permissions, and rights review. Translations do not inherit original word or character timestamps. Correspondence and timing semantics must be specified explicitly in a later gate; no translation fields are reserved in the current experimental configuration.

## Configuration and Command-Line Behavior

Prefer a documented, versioned project/configuration format for detailed customization. Common command options should remain concise, conventional, and suitable for automation. Use FFmpeg, Git, ripgrep, and yt-dlp as design references for predictable option behavior, exit status, diagnostics, configuration precedence, and scripting. This records design criteria, not a commitment to copy their syntax.

Define compatibility, validation errors, output-overwrite behavior, diagnostic streams, and reproducibility before stabilizing the public CLI. No final command names or schema fields are established here.

## Iconography and Licensing Gate

Prefer system-resolved SF Symbols through supported Apple-platform APIs only where applicable licensing permits the intended use, including generated video export. Select appropriate weight, scale, configuration, and rendering mode rather than bundling extracted assets. Apple describes these symbol capabilities on its [SF Symbols page](https://developer.apple.com/sf-symbols/).

The current published Xcode and Apple SDKs Agreement, section 2.10, limits system-provided images to specified Apple-platform application development and prohibits trademark uses. This review does not establish permission for standalone rendered-video distribution. Before implementation, verify the applicable SF Symbols and SDK terms, symbol-specific restrictions, and export rights; obtain clarification where necessary. Application-display permission must not be assumed to authorize every output use. [Apple agreement](https://www.apple.com/legal/sla/docs/xcode.pdf), [agreement guidance](https://developer.apple.com/support/terms/).

Do not extract Music application icons or use SF Symbols as the iLyric logo or trademark. Retain original or appropriately licensed alternatives when system symbols are unavailable or unsuitable. Symbol rendering and visual calibration belong to a separate control-refinement gate. No project software license has been selected.

## Deferred Milestones

The bounded [ordinary LRC/audio experiment](local-input-integration.md) supplies line-level timing only. The separate [enhanced-LRC experiment](enhanced-lrc-integration.md) accepts explicit segment boundaries; source granularity and renderable glyph support remain distinct. The [bounded TTML importer](ttml-integration.md) preserves explicit paragraph ends; future importers must not replace supplied ends with next-event holds or silently approximate unsupported overlap. Future timing importers must preserve complete text, validate grapheme and shaped-cluster boundaries, and reject unsupported visual support explicitly rather than reshaping timed fragments. External acquisition, broader synchronization, configuration stabilization, translated-text display, symbol rendering, and generalized customization remain deferred. Focus-motion and appearance animation remain independently justified capabilities; generalized screen-transition libraries are not required by the Lyrics Translation goal. Introduce each through explicit requirements, a bounded experiment, public synthetic regression tests, rights review where applicable, and compatibility decisions. Dynamic materials and cross-script inactive appearance remain separate measurement questions. None of these goals is implemented by documenting it.

## Public Release Requirements

The [implementation-readiness and release plan](implementation-release-readiness.md) defines a proposed bounded architecture, measurable acceptance criteria, and staged implementation gates. English automatic line timing may be the first qualified subset; Japanese automatic timing requires separate evidence. Supplied Japanese timing remains distinct from automatic Japanese alignment. Unsupported input must fail explicitly, and uncertain correspondence must remain visible rather than receive fabricated timestamps.

A usable preview must include reliable automatic timing within its declared subset, efficient correction, complete audiovisual output, clean installation, documented limits, and lawful default dependencies. Restricted or uncertain research checkpoints may remain optional and separately provisioned, but cannot be the only functioning automatic path. Software/model permissions do not license user recordings, lyrics, artwork, or published videos. Public fixtures and tests must operate without private media, subscriptions, or model downloads.

Develop correspondence reliability, efficient single-user correction, and end-to-end validation before broad native Music visual work. The [review-first full-song prototype](review-first-full-song.md) and [TIFA search](tifa-passage-search.md) record measured failures, not completed synchronization. Preserve exact timing, original text shaping, correction provenance, and offline export. No inference or network access may enter deterministic frame evaluation. Stabilize the public CLI and configuration only around a qualified preparation path, retain explicit compatibility behavior, and keep initial platform support limited to tested macOS/Apple Silicon configurations.

Distinguish licensed experimental source availability, a functional public preview with declared limitations, and a qualified stable release. A repository of experiments is not production-ready. Stable native-layout fidelity requires bounded physical-reference validation; edge-to-edge adaptation and every customization option need not precede the initial supported release. The measured reference remains iPhone 16, reported iOS 27.0.1, exact build Unknown.
