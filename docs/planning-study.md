**Recommendation: proceed with a measurement-led proof of concept, using Swift on macOS, Core Text, Metal/Core Image, and AVFoundation.** Build a deterministic composition engine that models the complete screen, but make Lyrics-focused rendering the initial public release.

High-fidelity Lyrics reproduction is technically plausible. It is **not yet demonstrated for iOS 27**, and pixel-identical reproduction across devices, operating-system versions, and fonts should not be promised. Complete-screen reproduction is also plausible within a defined set of states, but requires substantially more measurement and introduces an unavoidable aspect-ratio decision.

This study uses public sources checked on October 7, 2026. No production code was written, no renderer was benchmarked, and no physical iPhone measurements were performed. All numerical acceptance thresholds below are proposed engineering requirements, not measurements of Apple Music.

**1. Evidence and Its Limits.** Apple’s current public site identifies iOS 27, and its current iPhone User Guide includes iOS 27. This establishes the reference generation, but not the exact Music build, layout, or animation parameters to reproduce. Freeze those against a physical device before claiming fidelity. [Apple](https://www.apple.com/os/ios/?utm_source=chatgpt.com)

| Evidence Class | Established Finding | Consequence |
|---|---|---|
| Documented fact | Apple documents synchronized lyrics, entering and leaving Lyrics, and jumping to a verse by tapping a lyric. | These interactions belong in the reference state model. |
| Documented fact | Apple documents Sing’s highlighted, beat-by-beat lyrics and adjustable vocal volume for supported songs. | Sing needs a separate capability and behavior profile. |
| Documented fact | Translation, pronunciation, and larger-text settings can affect the Lyrics presentation. | Capture settings must be recorded; translated layouts cannot be assumed equivalent. |
| Direct observation | None of native iOS 27 Music was performed in this study. | No font sizes, blur radii, spring constants, or transition durations are asserted. |
| Engineering inference | A finite collection of visible states can be reconstructed using shaped text, timed transforms, masks, and image effects. | A deterministic offline renderer is a credible approach. |
| Hypothesis | Some lyric movements can be approximated by damped springs or fitted curves. | Compare candidate curves against captures rather than assuming Apple uses springs. |
| Unknown | Exact typography, material construction, event timing, background phase, and behavior under interrupted transitions. | These are measurement gates. |

The documented behavior above comes from Apple’s current Lyrics and Sing guides. Those guides do not establish exact visual or temporal specifications. [Apple Support](https://support.apple.com/guide/iphone/show-song-credits-and-lyrics-iphb9bf483aa/ios?utm_source=chatgpt.com)

Public evidence retrieved here is **insufficient for an implementation-ready numerical iOS 27 appearance specification**. The architecture and work sequence can be settled now; the numerical profile must follow empirical capture. Earlier iOS versions, macOS Music, web players, and replicas are comparison material only.

**2. Scope and Fidelity Contract.** Define the target as a named profile tied to an observed OS build, device, and settings—for example, an internal `ios27-reference-v1` profile whose manifest records the actual build number.

The first release should support:

- Ordinary synchronized lyrics, including multiline and mixed-script text.
- Explicitly timed word or syllable highlighting through a separate Sing-style mode.
- Artwork-derived background treatment.
- Deterministic still frames and 30/60 fps video with synchronized audio.
- One validated iPhone layout and documented 9:16 presentation policies.
- Playback, pause, gaps, and explicitly scripted seek events.

Full Music-screen output should follow in a later phase. The proof of concept must nevertheless include artwork and representative controls to test the architecture’s suitability for that phase.

“Complete screen” should mean the visible Now Playing/Lyrics composition and specified transitions. It should not imply reproduction of the entire Music application, library browsing, account interfaces, notifications, every system overlay, or every accessibility configuration.

Sing-style rendering must not imply vocal separation. Initially it should consume supplied timings and audio. A vocal-volume control may reflect supplied state; changing the actual vocal mix requires separately supplied stems and belongs outside the initial renderer.

**3. Ground-Truth Capture Procedure.** Use **iPhone 16 Pro running the selected iOS 27 build** as the canonical reference. Apple lists this device as compatible with iOS 27 and specifies a 1206×2622 display. It is a useful established reference with Dynamic Island geometry and a high-refresh display. [Apple](https://www.apple.com/os/ios/?utm_source=chatgpt.com)

Record a capture manifest containing the hardware model, exact OS build, available Music version information, locale, preferred languages, display zoom, text size, Bold Text, Reduce Motion, Reduce Transparency, contrast settings, material appearance settings, and playback configuration. Record artwork variant, track edition, translation/pronunciation state, Sing state, and whether animated artwork is enabled.

Use this procedure:

1. **Establish static geometry.** Capture original-resolution screenshots of settled states. Preserve original files and color metadata. Measure screen bounds, content margins, baselines, artwork bounds, control centers, clipping edges, and visible chrome.
2. **Capture continuous behavior.** Record 20–40-second passages spanning several transitions. Repeat each passage at least three times to expose phase variation, timing variation, and content-dependent behavior.
3. **Inspect recording timestamps.** Determine actual frame cadence, duplicate frames, dropped frames, and variable-frame-rate behavior. A display capable of high refresh does not establish the recording’s sampling rate.
4. **Capture interactions manually.** Include pause/resume, forward and backward lyric taps, seeking during scrolling, entering/leaving Lyrics, and toggling Sing. Record enough lead-in to recover the preceding state.
5. **Obtain audio alignment when permitted.** Check whether the recording actually contains usable audio. If absent, use a lawful external synchronized recording or visible playback references, and document the resulting timing uncertainty.
6. **Supplement when necessary.** External high-speed video can reveal motion missed by screen capture, but requires correction for perspective, rolling shutter, display refresh, and camera exposure. Use screenshots for pixel geometry.
7. **Extract frames using their presentation timestamps.** Do not treat frame number divided by a nominal rate as ground truth for variable-rate captures.
8. **Fit and cross-validate.** Fit motion and appearance parameters on one subset; validate on different passages, line lengths, and scripts.

Required fixtures should include:

| Fixture | Measurements |
|---|---|
| Short Latin lines | Active anchor, line spacing, opacity, focus transition |
| Two- and three-line lyrics | Wrapping, baseline spacing, scroll distance, clipping |
| Japanese and mixed Latin/Japanese | Font fallback, punctuation behavior, run metrics |
| Chinese and Korean | Wrapping and fallback differences |
| Rapid consecutive lines | Interrupted motion, velocity continuity, overlapping focus |
| Long instrumental gap | Retained focus, indicators, background continuation |
| Timed words/syllables | Highlight boundaries, progression, glow, held syllables |
| Simultaneous singers | Overlapping intervals, alignment, background-vocal treatment |
| Pause and seek | Which clocks stop, jump behavior, transition reset rules |
| Enter/leave Lyrics | Artwork, controls, text, and material choreography |

Measure position, scale, opacity, and blur separately. A brightening glyph can appear larger without geometric scaling; a blurred inactive line can appear dimmer without an opacity change.

For background motion, determine whether repeated playback produces the same trajectory and phase. If it does not, validate its spatial and temporal characteristics rather than promising a pixelwise match to an unknowable random sequence.

**4. Technology Comparison.** The following judgments are architectural assessments, not benchmark results.

| Candidate | Arbitrary-Time Rendering | Typography and Materials | Export and Performance | Portability and Maintenance | Decision |
|---|---|---|---|---|---|
| Swift + Core Text + Metal/Core Image | Strong with explicit state evaluation | Best access to Apple text APIs; fully controllable effects; iPhone parity unproven | Direct GPU-to-video path; promising at 1080p60 and higher | macOS-specific renderer; coherent native toolchain | **Choose** |
| TypeScript/JavaScript + browser | Strong if every effect derives from supplied time | Good typography; browser/platform differences; custom materials possible | Credible frame capture and encoding; browser and GPU overhead need testing | Broad portability; browser pinning and asset loading add complexity | Strong fallback |
| Remotion-based implementation | Established frame-driven model | Same browser limitations | Mature programmatic-video workflow | Useful ecosystem; license requires separate consideration | Study, not default dependency |
| Python + Pillow/Cairo/Skia/MoviePy | Strong at orchestration level | Requires careful shaping backend; no automatic Apple typography advantage | Straightforward export, but CPU image processing and copies can dominate | Portable; native dependencies complicate packaging | Use for measurement and QA |
| FFmpeg + libass/filter graphs | Strong for supported timestamp expressions | Excellent subtitle tooling; awkward fit for rich UI and per-glyph effects | Mature encoding and muxing | Portable and established | Export/verification component |
| SwiftUI-driven offline capture | Insufficiently explicit by default | Convenient UI authoring; framework-driven layout and animation | Snapshot fidelity and headless behavior require proof | Easy preview development, weaker export contract | Preview only |
| Python/JS orchestrating a Swift renderer | Strong | Same native strengths | Additional process boundaries | Useful only if integrations justify complexity | Defer |

Core Text exposes font cascading, metrics, lines, and glyph runs, making it suitable for explicit shaping and measurement. This supports the Swift choice, but does not prove identical iPhone and macOS output. [Apple Developer Documentation](https://developer.apple.com/documentation/CoreText?utm_source=chatgpt.com)

Remotion explicitly recommends rendering as a function of frame number, independent of render order, and waiting for assets and fonts. Adopt that architectural principle regardless of language. Its current license includes eligibility and derivative-use restrictions, so it should not be treated as an unrestricted permissive dependency. [Make videos programmatically](https://www.remotion.dev/docs/flickering?utm_source=chatgpt.com)

Reject Python as the production rendering core because it adds no clear advantage for this specific typography target. Reject FFmpeg/libass as the scene engine because screen composition, material sampling, and glyph-level choreography would become difficult to maintain. Reject a browser-first default because native typography and controlled Apple-platform export matter more here than portability.

These are target-specific choices. If Linux rendering becomes mandatory, reconsider the browser or Skia/HarfBuzz route rather than obscuring a macOS dependency behind wrappers.

**5. Recommended Architecture.** Use a Swift package with a platform-independent domain/timeline core and a macOS rendering backend.

The rendering contract should be:

\[
\mathrm{Frame}(t)=R\bigl(E(\mathrm{CompiledProject},t),\mathrm{RenderProfile}\bigr)
\]

`CompiledProject` contains normalized timing, resolved assets, text layout, and precomputed transition segments. `E` evaluates an immutable presentation snapshot. `R` renders that snapshot without consulting a wall clock or a previously rendered frame.

Model the full screen from the beginning:

| Model | Required Contents |
|---|---|
| Project | Schema version, assets, track metadata, duration, scene selection |
| Lyrics | Stable line IDs, text, language, spans, timing granularity, singer/role |
| Playback | Initial media position, pause/play/seek events, rate, audio mapping |
| Interface | Lyrics visibility, Sing state, control visibility, translation/pronunciation state |
| Device | Logical bounds, scale, safe areas, status region, occlusion geometry |
| Layout | Shaped runs, wrapped lines, baselines, anchors, clipping regions |
| Appearance profile | Measured typography, motion, material and control parameters |
| Render settings | Output size, rational fps, color policy, codec, quality, seed |
| Provenance | Input hashes, resolved fonts, software versions, profile revision |

Use both a **scene hierarchy** and an **effect dependency graph**. Parent-child relationships express transforms, clipping, and opacity. Effect dependencies express operations such as sampling the background behind a material panel. A material must not accidentally blur itself or content composited above it.

Each node needs stable identity, bounds, local transform, anchor, z-order, clip, opacity, blend mode, and effect parameters. Useful node types are text group, artwork, path/icon, material region, background, mask, and system chrome.

Core Animation should not own the canonical timeline. Apple documents that `CALayer.render(in:)` renders the layer tree while ignoring animations added to the render tree. It is therefore not a general “freeze Music-like animation at time t” solution. [Apple Developer Documentation](https://developer.apple.com/documentation/quartzcore/calayer/render%28in%3A%29?utm_source=chatgpt.com)

Core Animation can support preview presentation. If used offline at all, set evaluated properties explicitly with implicit animation disabled and test supported effects. Do not make correctness depend on a live presentation layer.

SwiftUI can provide a timeline scrubber, fixture browser, parameter inspector, and preview window around the same renderer. It must not independently determine export layout.

**6. Time, Playback, and Reproducible Motion.** Separate three clocks:

- **Output time:** position in the produced video.
- **Media time:** position in the supplied audio/lyric timeline.
- **Interface time:** elapsed time driving UI transitions and any background motion.

A pause freezes media time. Whether it freezes a background animation is a measured behavior. A seek changes media time while potentially starting a new interface transition.

Use rational timestamps throughout parsing, event ordering, frame scheduling, and muxing. Convert to floating-point seconds only for numerical animation evaluation. At frame rate \(p/q\), frame \(n\) is evaluated at \(nq/p\). Define intervals as half-open and specify deterministic ordering for simultaneous events.

For spring-like motion, fit an analytic damped oscillator or a bounded spline to observations. A candidate oscillator is:

\[
x(t)=x_\mathrm{target}
+e^{-\zeta\omega_n\tau}
\left(A\cos(\omega_d\tau)+B\sin(\omega_d\tau)\right)
\]

Here \(\tau\) is time since the transition began. Include critically damped and overdamped alternatives; do not force oscillation where captures show none.

When motion is interrupted, evaluate position and velocity at the interruption and use them as the next segment’s initial conditions. Compile these segments once. Random-access evaluation then looks up a segment and evaluates it directly.

Do not advance a mutable spring by “one frame” on every render call. That makes results depend on frame rate and render order. If procedural effects require simulation, precompute a deterministic trajectory or use reproducible checkpoints; analytic time functions are preferable.

Define determinism at three levels:

| Level | Contract |
|---|---|
| Timeline | Identical normalized inputs produce identical evaluated state. |
| Raster | Identical pinned environment produces identical raw frames; other environments meet stated tolerances. |
| Encoded output | Correct decoded frames, timestamps, and audio; byte-identical hardware-encoded files are not promised. |

Record OS, GPU, renderer version, shader version, font fingerprints, color settings, seed, and encoder configuration. Pinning Swift dependencies alone does not pin system fonts or GPU behavior.

**7. Typography and Lyric Behavior.** Shape complete text runs before applying timed highlighting. Preserve shaping across timing boundaries; splitting every word into separately laid-out views can change kerning, ligatures, and wrapping.

Maintain a mapping from source text ranges to shaped glyph clusters and visual fragments. Timed units may cross line boundaries, and glyph clusters may not map one-to-one to Unicode characters.

The typography specification must include font resolution, size, weight, width/optical axes where applicable, tracking, leading, paragraph spacing, alignment, baseline offsets, maximum text width, and line-breaking rules.

For Japanese and other CJK text:

- Test prohibited line-start and line-end punctuation.
- Preserve explicit breaks independently of automatic wrapping.
- Do not infer syllable timing from character count.
- Treat pronunciation and translation as separate text tracks.
- Test combining marks, emoji, Latin digits, and punctuation fallback.
- Preserve source indexing; normalization must not silently invalidate timed ranges.
- Compare macOS and iPhone advances, baselines, line breaks, and raster edges separately.

Render text masks at the required output scale, with sufficient resolution for the maximum supported animated scale. Cache shaped layouts and masks, not final screen frames. Avoid signed-distance-field text as the initial fidelity path; its edge appearance needs its own validation.

Ordinary synchronization and Sing should share the layout engine but have separate behavior profiles. Timing granularity is also separate from mode: do not assume ordinary Lyrics is always line-only or that every Sing span is a linguistic syllable.

Use explicit line ends and gap intervals where available. Do not automatically hold the previous line active until the next begins. Overlapping singers require overlapping intervals and stable ordering.

A timed highlight should operate on shaped glyph masks. Whether progression is a wipe, a discrete change, a softened edge, a glow, or a combination remains an empirical question.

**8. Device Geometry and 9:16 Output.** Use top-left-origin logical device points internally, with floating-point geometry and one explicit output transform. Keep device layout separate from video dimensions.

Use 402×874 points as the provisional iPhone 16 Pro working canvas corresponding to 1206×2622 at 3×; verify logical bounds, display zoom, safe areas, and capture dimensions on the actual device before freezing the preset. Do not infer safe-area insets from the display resolution.

There are three distinct output policies:

| Policy | Effect | Fidelity Status |
|---|---|---|
| `contain` | Uniformly fits the entire native composition inside 9:16, with padding | Preserves native layout |
| `cover` | Uniformly fills 9:16 and crops the taller composition | Omits some native content |
| `adapt` | Reflows layout into a 9:16 viewport | Deliberate layout adaptation |

For the specified physical display dimensions, fitting height into 1080×1920 produces an approximately 883-pixel-wide image, leaving approximately 98 pixels on each side. Filling the width instead produces approximately 2348 pixels of height, requiring roughly 428 pixels of vertical cropping. These are geometric calculations, not UI measurements.

**Default full-screen fidelity output should use `contain`.** A borderless 9:16 composition can be offered as `adapt`, clearly identified as adapted. Nonuniform stretching should not be supported.

Represent safe areas, status content, home indicator, rounded display mask, and Dynamic Island occlusion separately. Determine which elements are actually present in screenshots and recordings; physical display occlusion is not automatically application content.

Other portrait presets can share constraints, but should remain unvalidated until tested. Do not label interpolated geometry as a measured device profile.

**9. Materials and Video Export.** Choose a native pipeline:

1. Resolve and decode assets.
2. Shape text and compile layout.
3. Evaluate the presentation snapshot.
4. Rasterize/cache text and paths.
5. Composite background, artwork, text, controls, and materials using Metal/Core Image.
6. Render into a managed pool of pixel buffers.
7. Append frames with explicit presentation timestamps.
8. Produce and mux the corresponding audio timeline.
9. Validate the encoded output.

Core Image can render into Metal textures with an explicit command buffer and color space. AVFoundation provides timestamped pixel-buffer writing; current documentation points new work toward pixel-buffer receiver APIs rather than assuming the older adaptor is the preferred interface. Isolate SDK-specific writing behind an export abstraction. [Apple Developer Documentation](https://developer.apple.com/documentation/coreimage/cicontext/render%28_%3Ato%3Acommandbuffer%3Abounds%3Acolorspace%3A%29?changes=l_3\&utm_source=chatgpt.com)

Use Core Image for established image operations and initial blur experiments. Add custom Metal kernels when measured material behavior or profiling requires them. Native macOS materials do not establish equivalence with iPhone Music materials.

Specify blur edge extension, kernel units, sampling scale, saturation/tint order, premultiplied alpha, and backdrop sampling order. Compare linear-light and display-referred blur against captures rather than selecting whichever looks more attractive.

For color:

- Preserve and interpret input ICC profiles.
- Use an explicitly selected floating-point working space.
- Default delivery to SDR Rec.709 with explicit conversion and metadata.
- Convert screenshot references into the same comparison space.
- Keep wide-gamut/HDR export out of the initial release.
- Maintain a lossless image-sequence path to separate rendering errors from compression errors.

For export:

- Support 1080×1920 at exact 30 and 60 fps initially.
- Treat 2160×3840 as a required scalability experiment, not an unmeasured performance promise.
- Default to H.264/AAC MP4; offer HEVC where supported.
- Check encoder capabilities before rendering.
- Apply backpressure and bounded buffering.
- Inspect decoded presentation timestamps, frame count, duration, and color.
- Verify audio encoder priming and final-sample trimming.
- Never use elapsed processing time to schedule frames.

A 1080×1920 RGBA8 frame contains approximately 8.29 MB; at 60 fps that is approximately 498 MB/s before additional passes. At 2160×3840, the corresponding raw traffic is approximately 1.99 GB/s. These calculations favor GPU-resident compositing and avoiding repeated CPU readbacks.

FFmpeg is valuable as an optional encoder/muxer, media probe, and validation tool. Its filter system can also supply reference blur and compositing experiments. Keep it outside the canonical layout engine. [ffmpeg.org](https://ffmpeg.org/ffmpeg.html?utm_source=chatgpt.com)

`AVVideoCompositionCoreAnimationTool` is a credible alternative for layered video composition, but adds another animation evaluation path. Use direct frame rendering and writing for the primary architecture; evaluate that tool only if a concrete export requirement justifies it. [Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avvideocompositioncoreanimationtool?utm_source=chatgpt.com)

**10. Prior Work and Reuse.**

| Project | What to Study or Reuse | Boundary |
|---|---|---|
| [AMLL](https://github.com/amll-dev/applemusic-like-lyrics) | Lyric data models, timing formats, word highlighting, scrolling, fluid backgrounds | Explicitly iPad-like; not a verified iOS 27 iPhone renderer |
| [AMLL TTML Tool](https://github.com/amll-dev/amll-ttml-tool) | Timing authoring and interchange workflow | Editor, not final renderer |
| [Remotion](https://www.remotion.dev/docs/flickering) | Frame-driven evaluation, asset readiness, parallel rendering | Browser fidelity and license need consideration |
| [libass](https://github.com/libass/libass) | Subtitle shaping, karaoke behavior, compatibility fixtures | ASS/SSA renderer, not Music screen composition |
| [Aegisub](https://github.com/Aegisub/Aegisub) | Manual karaoke timing and subtitle QA | Authoring reference, not an iPhone visual target |
| [MoviePy](https://github.com/Zulko/moviepy) | Measurement utilities and short comparison-video workflows | No inherent Apple typography advantage |
| [MetalPetal](https://github.com/MetalPetal/MetalPetal) | GPU effect graphs, texture reuse, compositing architecture | No Apple Music material equivalence |
| [Swift Argument Parser](https://github.com/apple/swift-argument-parser) | CLI parsing and generated help | Appropriate direct dependency |

AMLL is the most relevant visual prior art found. Its README explicitly describes similarity to the iPad version and says complete imitation is not its goal. Its documented components include lyric rendering and dynamic backgrounds; its AGPL-3.0-only licensing must be considered before copying or porting code. Study concepts first; do not silently incorporate implementation into a permissively licensed project. [GitHub](https://github.com/amll-dev/applemusic-like-lyrics?utm_source=chatgpt.com)

libass is an ISC-licensed ASS/SSA renderer. MoviePy supplies general cross-platform video editing. MetalPetal demonstrates image-graph optimizations, but its own documentation notes that stronger comparative performance claims need benchmark data. [GitHub](https://github.com/libass/libass?utm_source=chatgpt.com)

**No mature project found in this review establishes the complete requested combination:** native iOS 27 iPhone fidelity, independently evaluated arbitrary timestamps, full composition, documented device geometry, and deterministic offline video export. This is a bounded research finding, not proof that no unpublished or unindexed implementation exists.

**11. Inputs and Normalization.** Accept local, user-supplied assets. Rendering should require no service connection.

| Input | Contract |
|---|---|
| TTML | Preferred rich interchange; explicitly supported profile |
| LRC | Line timing; documented enhanced dialect support where applicable |
| Native JSON | Canonical project, timeline, state events, device and export settings |
| Audio | Local decodable audio; explicit duration and timeline mapping |
| Artwork | Local image; animated artwork later |
| Font | System-resolved or appropriately licensed supplied font |
| UI metadata | Title, artist, duration, progress, control state, optional chrome |
| Output | Size, rational fps, codec, color policy, range, destination |

TTML includes nested timing and container semantics; it is not sufficient to parse only paragraph timestamps. Normalize supported timing into absolute rational intervals. Document support for `begin`, `end`, `dur`, spans, whitespace, explicit breaks, and timing containers; reject unsupported timing modes rather than silently misinterpreting them. Disable external XML entity resolution. [w3.org](https://www.w3.org/TR/2018/REC-ttml2-20181108/?utm_source=chatgpt.com)

For LRC, document repeated timestamps, offsets, absent end times, and the exact enhanced syntax accepted. Inferred line ends must be marked as inferred. Reject Sing-style rendering when the input lacks required fine timing unless the user explicitly chooses a visibly labeled approximation.

The native JSON schema should use versioned records and rational time objects with integer numerator/denominator values. Text spans should refer to defined Unicode scalar ranges, validated against grapheme and shaping boundaries. Include source provenance and timing confidence.

Define offsets unambiguously:

- Positive lyric offset delays lyrics relative to source media.
- Positive audio offset delays audio relative to the output timeline.
- `--start` selects an output-timeline range without discarding earlier event history.
- Seek/pause events affect both rendered playback information and the audio edit timeline.

Initial playback rates should be limited to 0 and 1. Variable-rate audio with pitch handling is a separate feature.

**12. Proposed CLI.** Use `lyricrender` as a placeholder pending name clearance.

Adopt Git-style subcommands; readable long options and explicit diagnostics informed by ripgrep; output/configuration conventions informed by yt-dlp; explicit media parameters informed by FFmpeg; and straightforward still-image output informed by ImageMagick. These are design influences, not a claim that their option grammars are identical. [git Documentation](https://git-scm.com/docs/git?utm_source=chatgpt.com)

Representative invocations:

```sh
lyricrender render \
  --lyrics song.ttml --audio song.wav --artwork cover.png \
  --scene lyrics --size 1080x1920 --fps 60 \
  --output lyrics.mp4
```

```sh
lyricrender render \
  --project song.json --scene music \
  --device iphone-16-pro --fit contain \
  --size 1080x1920 --fps 30 --codec h264 \
  --output music-screen.mp4
```

```sh
lyricrender render \
  --lyrics syllables.ttml --audio instrumental.wav \
  --artwork cover.png --behavior sing \
  --fps 60 --codec hevc --output sing.mp4
```

```sh
lyricrender frame \
  --project song.json --time 12.350 \
  --size 1080x1920 --output frame.png
```

```sh
lyricrender render \
  --project regression.json --start 8 --duration 4 \
  --fps 60 --output regression.mp4 \
  --manifest regression.render.json
```

```sh
lyricrender validate --project song.json
lyricrender inspect --project song.json --json
lyricrender presets list
lyricrender doctor
```

The full-screen invocation is the planned later-phase interface, not an initial-release promise.

Specify configuration precedence as explicit CLI flags, project file, then defaults. Avoid ambient configuration that changes reproducibility. Send diagnostics/progress to stderr; reserve stdout for requested machine-readable output. Provide `--help`, `--version`, `--quiet`, `--verbose`, `--`, and shell completions.

Refuse overwrite unless explicitly authorized by `--overwrite`. Define stable exit statuses for invalid inputs, missing capabilities, rendering/export failure, and cancellation. Write outputs atomically.

Keep appearance constants inside the versioned reference profile. Public options should express user intent—scene, device, timing, output—not expose dozens of spring and blur parameters.

**13. Validation and Acceptance.** Maintain two distinct suites:

- **Public offline regression suite:** original or redistributable lyrics, audio, artwork, and fonts; no Apple Music, subscription, or network.
- **Reference fidelity suite:** controlled native captures and matching metadata, retained or distributed only as permitted.

Synthetic fixtures test the implementation, but cannot alone prove resemblance to native Music. Native captures establish fidelity. When lawful matching media cannot be distributed, publish measurement summaries and sanitized geometry/motion fixtures rather than commercial media.

Measure:

- Line breaks and glyph-cluster mapping.
- Baseline and control geometry.
- Active-line trajectory, velocity, overshoot, and settling.
- Highlight onset and completion.
- Text-region image differences and edge alignment.
- Material luminance, hue, blur, and temporal behavior.
- Audio/visual synchronization and long-run drift.
- Random-order versus sequential raw-frame equality.
- Decoded output timestamps and compression artifacts.

Use region-specific comparisons. Whole-screen SSIM can hide severe lyric errors behind a large blurred background. Do not use dynamic time warping for acceptance; it could conceal incorrect timing.

Proposed levels:

| Level | Proposed Requirement |
|---|---|
| Apple Music-inspired | Coherent aesthetic; no measured native-fidelity claim |
| Convincing approximation | Exact fixture wrapping; primary geometry within 2 reference points; motion trajectory RMSE ≤2 points; key events within 2 frames at 60 fps |
| Production-quality recreation | Declared device/build/state coverage; exact fixture wrapping; primary geometry within 1 point; trajectory RMSE ≤1 point; key events within 1 frame at 60 fps; no visible clipping/fallback failures; human review passed |

For normalized, registered text/control regions, use provisional SSIM targets of 0.97 and 0.99 for the latter two levels. Calibrate these against repeat-capture variability before freezing the suite; compression and subpixel sampling can make a nominal threshold inappropriate.

Require decoded audio-marker alignment within one output frame and no accumulated drift beyond that bound over a ten-minute synthetic fixture. Validate the PCM edit timeline separately from codec delay.

Have at least three reviewers inspect randomized A/B clips at normal speed and frame-by-frame. All should report no obvious systematic typography, scrolling, or synchronization defect for production acceptance. This review supplements numerical gates.

If capture uncertainty exceeds the claimed tolerance, the fidelity claim is a no-go until measurement improves.

**14. Repository, Releases, and Rights.** Use clear package boundaries:

| Module | Responsibility |
|---|---|
| `Domain` | Project schema, rational time, validation |
| `Import` | TTML/LRC normalization |
| `Timeline` | Playback mapping and compiled animation segments |
| `Layout` | Shaping, wrapping, baselines, constraints |
| `Scene` | Nodes, composition, effect dependencies |
| `RenderMac` | Core Text rasterization, Metal/Core Image |
| `ExportMac` | Video writing, audio timeline, muxing |
| `CLI` | Commands and diagnostics |
| `Preview` | Optional SwiftUI authoring interface |
| `Fixtures` / `Tests` | Licensed assets, timing, raster and encoded-output checks |

Use Swift Package Manager and pinned dependencies. Start with Apple silicon macOS binaries; add Intel support only after demand and validation. Provide signed/notarized releases where feasible, checksums, build provenance, a Homebrew formula, and documented source builds.

Run domain/import tests independently of GPU tests. Use a pinned macOS/GPU runner for golden renders and a separate compatibility matrix with tolerance-based comparisons. An OS upgrade must trigger deliberate golden review, not automatic replacement.

Version the project schema, appearance profile, and renderer separately. Record profile revisions in output manifests. A patch must not silently change the appearance of previously reproducible projects.

Use MLA headline-style title case throughout English documentation—for example, “Rendering a Video,” “Timing and Playback State,” and “Working with CJK Text”—while preserving literals such as `README.md`, `AVAssetWriter`, and `--fps`. Keep documentation concise and generate command reference material from CLI definitions where possible.

Rights considerations are release requirements, not legal advice:

- Use an independent name and clear non-affiliation statement.
- Do not extract Music icons, application assets, private frameworks, or fonts.
- Draw original control geometry or use appropriately licensed assets.
- Do not assume that avoiding redistribution settles all font-use permissions. Apple’s downloadable fonts have specific usage terms; review the applicable font source and license for video-generation use. [Apple Developer](https://developer.apple.com/fonts/?utm_source=chatgpt.com)
- Require users to supply media they may use; do not include scraping or DRM circumvention.
- Track rights for lyrics, audio, artwork, reference captures, and fonts independently.
- Audit dependency licenses before reuse, especially AMLL and Remotion.
- Keep a licensed fallback-font mode, clearly indicating that it cannot satisfy the canonical typography claim.

**15. Decisive Recommendation and Implementation Blueprint.** **High-fidelity iOS 27 Lyrics reproduction is a conditional go.** A convincing, measured recreation of a defined device/build and fixture set is a realistic objective. Universal pixel identity is not.

**Complete visible Music-screen reproduction is also a conditional go, but belongs after the Lyrics release.** Preserving the entire native composition in a 9:16 video requires `contain`; edge-to-edge 9:16 output is an adaptation or crop.

Choose **Swift + Core Text + Metal/Core Image + AVFoundation**, with a full-screen scene model, compiled event timeline, and immutable arbitrary-time presentation snapshots. Study AMLL, Remotion, MetalPetal, libass/Aegisub, and Apple’s rendering/export examples. Reuse permissively licensed infrastructure where appropriate; independently implement the canonical appearance from measurements.

The smallest useful proof of concept is one **12–15-second authored scene** containing Latin/Japanese multiline lyrics, one measured focus transition, an interrupted transition or seek, timed highlighting, a short gap, artwork, a representative material, and several original controls. Produce native-reference geometry and 1080×1920 `contain` output, random-access stills, and an encoded 60 fps video with synthetic audio markers.

| Phase | Deliverable | Go Criteria | No-Go or Required Response |
|---|---|---|---|
| 0. Capture the Reference | Exact device/build manifest, repeated captures, measurement uncertainty, initial appearance specification | Usable geometry and motion evidence for ordinary Lyrics and Sing | Without evidence, proceed only under “inspired” status |
| 1. Challenge Typography | Core Text layout study using Latin, Japanese, CJK and mixed-script fixtures | Correct wrapping and baseline/advance errors within approximation targets using permitted fonts | Investigate explicit shaping/layout corrections; reject high-fidelity claim if inaccessible font behavior is essential |
| 2. Prove the Vertical Slice | The 12–15-second scene, arbitrary-time frames, background/material, controls, audio and encoded output | Random-order frames match sequential frames in pinned environment; valid 60 fps output; synchronization within one frame | Reject history-dependent rendering; repair color/export path before expanding scope |
| 3. Test Performance | 1080p60 and 2160p60 workload reports on a named Mac | Proposed minimum: ≥15 encoded fps at 1080p60 output, bounded memory ≤4 GiB, no growth with duration; higher-resolution short render completes correctly | Profile text rerasterization, readbacks and blur passes; revise backend if basic design remains impractical |
| 4. Ship Lyrics | TTML/LRC/JSON, ordinary and separately validated Sing-style modes, stills, audio, CLI and offline tests | Approximation gates pass across held-out fixtures; documented limitations; clean install succeeds | Do not release with silent timing inference, unexplained fallback fonts, or known drift |
| 5. Add the Full Screen | Artwork/control choreography, chrome, entry/exit transitions, additional playback states | Full-screen geometry and transition gates pass; `contain` and `adapt` clearly distinguished | Keep unsupported states unavailable rather than fabricating native behavior |
| 6. Qualify Production Fidelity | Expanded reference corpus, reviewed profiles, release/compatibility process | Production thresholds pass for explicitly listed configurations, including human review and rights audit | Retain “convincing approximation” designation; do not broaden the claim beyond evidence |

Proceed through these gates in order. The coding agent should preserve the selected architecture unless typography, arbitrary-time rendering, materials, or export fails a concrete proof-of-concept gate.