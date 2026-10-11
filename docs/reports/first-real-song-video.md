# First Complete Real-Song Video

## Outcome and Scope

October 10, 2026. **iLyric produced its first complete Lyrics video of a commercially released song from supplied lyrics and audio with automatic synchronization.** The maintainer supplied lyric text for one recording from their local library. The separated-vocal CTC pipeline with version 2 rules timed 66 of 72 sung lines automatically. The renderer then exported a 318.7-second, 1080×1920, 60-fps video with the fitted artwork background, runtime control symbols, and instrumental-gap insertion. This milestone exercised existing components end to end; it is not a qualification and does not publish the recording, lyrics, or video.

## Procedure

The maintainer-supplied lyrics were normalized privately: section labels were removed, parenthesized backing-vocal phrases overlapping the lead were removed, lines without letters were dropped, and paragraphs were split to at most four lines. The result has 72 lines in 22 paragraphs. The original recording was read in place and its hash verified after processing. An external application modified every file in the album folder during the session; iLyric only read the recording, and the new hash was recorded with that provenance.

Alignment ran `align_full_song.py align --separator` on the original 96-kHz Apple Lossless file. For export, each line became its own TTML paragraph with its estimated interval. The six unresolved lines were filled evenly between neighboring estimates for this preview only; these fills are recorded as preview data, not estimates. Artwork was extracted from the recording. Because AVFoundation reported a duration mismatch for the Apple Lossless source, a 48-kHz PCM decode of the same source was used for export.

`LyricsInputProbe project` rendered the version 3 project with `--background fitted --icons system-symbols --gaps auto`. Rendering took 1,074 seconds for 19,122 frames, 17.8 rendered frames per second on Apple M4.

## Findings

Visual inspection of sampled frames confirmed line-by-line focus, inactive-line blur, the artwork-derived background, and runtime control symbols at their measured positions. The following defects and gaps were found:

1. **Paragraph limits.** A complete song with one paragraph per line exceeded the 64-paragraph bound; limits were raised to 256.
2. **Presentation integration.** The background, symbols, and gap indicator were available only in diagnostic scenes; `LocalPresentation` now exposes them for local projects, opt-in.
3. **Line-level export.** The preparation tool's TTML export groups each paragraph of up to four lines into one focus unit and refuses unresolved lines. Native presentation advances line by line, so export must emit one unit per line and handle unresolved lines explicitly.
4. **Apple Lossless decoding.** The local audio importer rejected the 96-kHz Apple Lossless original with a duration mismatch, although FFmpeg decoded it consistently.
5. **Mono audio.** The exporter writes mono AAC; stereo preservation is required for a product.
6. **Throughput.** 17.8 frames per second is below the proposed 20-fps target with all presentation features enabled.
7. **Viewport.** Lyrics are clipped above the visible controls throughout; native behavior when controls auto-hide during playback is not modeled.
8. **Workflow.** Five separate tools and manual JSON editing were required; a single command is needed.

## Consequences

These findings define the supported `ilyric` command: one invocation from audio and lyrics to video, line-level timing export, explicit handling of unresolved lines, robust lossless decoding, stereo output, and the presentation features enabled by default where rights permit. The native Core ML port of separation and alignment remains a separate feasibility gate.

Neither release readiness nor native iOS 27 Music fidelity is established.
