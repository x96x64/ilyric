# iLyric Product Requirements

## Status and Product Objective

This document records confirmed long-term goals and deferred decisions. It is not a feature declaration, implementation plan for the current appearance gate, or stabilized schema. Historical experiment reports remain authoritative for measured capabilities and limitations.

The intended product is a scriptable command-line tool that creates animated Lyrics videos from user-supplied recordings, synchronized lyric data, artwork, and configuration. Rendering existing songs must eventually be possible; synthetic fixtures are engineering tests, not the final input workflow.

| Area | Current Status | Required Future Outcome |
| --- | --- | --- |
| Rendering | Deterministic experimental typography, appearance, composition, and audiovisual export | Supported user inputs and documented compatibility guarantees |
| Fidelity | Qualified physical-reference reconstruction candidates | Stable canonical native-layout preset with explicit uncertainty |
| Input and synchronization | Synthetic fixtures and private diagnostic inputs | Rights-respecting local input, timing provenance, and correction workflow |
| Configuration and CLI | Experimental developer invocations | Versioned project configuration and conventional scripting interface |
| Materials, controls, transitions | Provisional backgrounds, original placeholders, bounded test events | Separately measured and tested presentation options |

## Recordings, Lyrics, and Timing

Investigate TTML, ordinary LRC, enhanced LRC, and a versioned native project format through bounded import milestones. Preserve supplied line structure separately from inferred authored semantics. Do not stabilize field names or commands before format and compatibility studies.

Potential workflows include user-authored or user-supplied timed lyrics, metadata-based matching, appropriately licensed synchronization providers, and optional audio-assisted alignment. Provider integration requires verification of actual accessible data, terms, permissions, attribution, caching, and redistribution constraints. Matching metadata does not establish lyric rights or timing accuracy.

Apple documents MusicKit `Song.hasLyrics` as an availability Boolean. It does not supply text or timestamps through that property. No complete synchronized-lyric retrieval capability is established by this review; an automated integration must independently verify its supported API and permissions. [Apple documentation](https://developer.apple.com/documentation/musickit/song/haslyrics).

Distinguish supplied timestamps from estimated alignment. Record source, granularity, and uncertainty, and provide review and correction of uncertain alignment. Line, word, syllable, and character timing are separate capabilities. Fine-grained highlighting must be independently switchable from line focus. When timing precision is insufficient, require an explicit fallback or diagnostic; never manufacture exact character or word timestamps from line-only data.

Do not extract protected Apple Music data, bypass DRM, scrape restricted services, redistribute copyrighted lyrics, or include commercial recordings in public fixtures. Users must supply media they are entitled to process; provider access does not itself establish export rights.

## Presentation and Delivery

Plan configurable visibility for artwork, metadata, progress information, transport, volume, lower controls, optional lyric controls, and explicitly qualified system-chrome approximations. Preserve application content and system-owned chrome as distinct concepts.

Future appearance controls include typography, alignment, opacity, blur, highlighting, gradients, and backgrounds. Motion controls include transition selection, duration, easing, and bounded animation intensity. Optional transitions may connect interface, lyric, artwork, and composition states where technically justified. A documented canonical reference preset must remain available alongside customization.

Whole-paragraph shaping and deterministic arbitrary-time evaluation remain invariants. Customization must not silently change text shaping at timing boundaries or introduce frame-history dependence.

Native-layout presentation and edge-to-edge 9:16 adaptation are distinct outputs. Preserve uniform `contain`; develop `adapt` through explicit layout rules. Do not stretch the native reference or describe reflowed adaptation as screenshot reproduction.

## Configuration and Command-Line Behavior

Prefer a documented, versioned project/configuration format for detailed customization. Common command options should remain concise, conventional, and suitable for automation. Use FFmpeg, Git, ripgrep, and yt-dlp as design references for predictable option behavior, exit status, diagnostics, configuration precedence, and scripting. This records design criteria, not a commitment to copy their syntax.

Define compatibility, validation errors, output-overwrite behavior, diagnostic streams, and reproducibility before stabilizing the public CLI. No final command names or schema fields are established here.

## Iconography and Licensing Gate

Prefer system-resolved SF Symbols through supported Apple-platform APIs only where applicable licensing permits the intended use, including generated video export. Select appropriate weight, scale, configuration, and rendering mode rather than bundling extracted assets. Apple describes these symbol capabilities on its [SF Symbols page](https://developer.apple.com/sf-symbols/).

The current published Xcode and Apple SDKs Agreement, section 2.10, limits system-provided images to specified Apple-platform application development and prohibits trademark uses. This review does not establish permission for standalone rendered-video distribution. Before implementation, verify the applicable SF Symbols and SDK terms, symbol-specific restrictions, and export rights; obtain clarification where necessary. Application-display permission must not be assumed to authorize every output use. [Apple agreement](https://www.apple.com/legal/sla/docs/xcode.pdf), [agreement guidance](https://developer.apple.com/support/terms/).

Do not extract Music application icons or use SF Symbols as the iLyric logo or trademark. Retain original or appropriately licensed alternatives when system symbols are unavailable or unsuitable. Symbol rendering and visual calibration belong to a separate control-refinement gate. No project software license has been selected.

## Deferred Milestones

Input acquisition, synchronization, configuration, symbol rendering, generalized customization, and transition libraries remain deferred. Introduce each through explicit requirements, a bounded experiment, public synthetic regression tests, rights review where applicable, and compatibility decisions. Dynamic materials and cross-script inactive appearance remain separate measurement questions. None of these goals is implemented by documenting it.
