# Runtime Control Symbols

## Outcome and Scope

October 9, 2026. **Retain an opt-in runtime SF Symbols icon set whose measured geometry matches the reference controls within two native pixels.** Ten control symbols on the reference iPhone 16, reported iOS 27.0.1, exact build Unknown, were measured from eight private screenshots and reproduced by resolving public SF Symbols at runtime with fitted point sizes, weights, opacities, and ink centers. Every rendered ink bound lies within ±2 native pixels of the median reference bound, inside the release plan's proposed p95 static-geometry target of five pixels.

This is gate B2 of the [release and fidelity decisions](release-and-fidelity-decisions.md). It follows the policy in the [SF Symbols rights assessment](sf-symbols-rights-assessment.md): symbols are resolved only on the rendering Mac, never stored in the repository, and never used in public fixtures, golden images, or documentation media. The original icon set remains the renderer default; the maintainer-selected product default will be applied by the future supported command-line interface.

## Measurement

For each control, a fixed search window around the previously measured component center was thresholded 70 code values above its 20th-percentile luminance. Ink bounds repeated within ±1 pixel across all eight screenshots that showed the control. Opacity was estimated as `(ink − background) / (255 − background)` at the 90th ink percentile. Disc backgrounds were measured as the brightness difference between the disc interior and adjacent background. Crops and per-screenshot measurements remain under ignored `reference-private/`.

Candidate symbols were identified by visual comparison. For each, every public weight and point sizes from 6 to 110 points were rasterized, and the configuration minimizing bound and area differences, in points at the display's 3× scale, was selected.

| Control | Symbol | Point Size | Weight | Opacity | Ink Center (px) | Notes |
| --- | --- | ---: | --- | ---: | --- | --- |
| Previous | `backward.fill` | 29 | Semibold | 1.00 | 269.5, 1948 | |
| Pause | `pause.fill` | 47 | Semibold | 1.00 | 590, 1948.5 | |
| Play | `play.fill` | 40 | Semibold | 1.00 | 595.5, 1949.5 | One observation |
| Next | `forward.fill` | 29 | Semibold | 1.00 | 910, 1948 | |
| Volume low | `speaker.fill` | 13.5 | Medium | 0.56 | 114, 2203.5 | |
| Volume high | `speaker.wave.3.fill` | 13.5 | Medium | 0.58 | 1048.5, 2203.5 | |
| Lyrics (active) | `quote.bubble.fill` | 21 | Regular | Knockout | 248, 2361 | 114-px disc, opacity 0.57 |
| AirPlay | `airplay.audio` | 21 | Medium | 0.69 | 590.5, 2358 | |
| Queue | `list.bullet` | 21 | Medium | 0.57 | 931.5, 2358.5 | |
| Translation | `translate` | 17 | Medium | 1.00 | 153, 1531 | 84-px disc, opacity 0.30 |
| Sing | `music.mic` | 20 | Semibold | 1.00 | 1026, 1532.5 | Approximation; 84-px disc |

The native Sing glyph combines a microphone with sparkles. No public symbol with that design was found on the development Mac, and Music application assets must not be extracted, so `music.mic` is a disclosed approximation. The expanded Sing control, time labels, sliders, and the Dolby Atmos badge are outside this gate; the badge is a third-party trademark and is not reproduced.

## Implementation

`ControlSymbols` in `LyricsSliceCore` holds the measured table as plain data. `SystemSymbols` in `LyricsSliceMac` resolves each symbol through `NSImage(systemSymbolName:)` at three times its point size, tints it white, caches the mask, and aligns its ink-bounds center to the measured center. Disc backgrounds are drawn beneath the symbol; the active lyrics control cuts the symbol out of its disc. `ScreenRenderer` accepts `icons: .systemSymbols`; symbol drawing is not clipped to the provisional component rectangles, because the measured lyrics disc is larger than its rectangle. An unavailable symbol fails with an explicit error rather than a substitute. `LyricsScreenProbe` accepts a `-symbols` suffix and prints the rights notice to standard error.

## Verification

A render of the synthetic screen with runtime symbols reproduced every reference ink bound within ±2 pixels; five of ten were within ±1 pixel on every edge. Three new Swift tests check the symbol table, the original default, within-run determinism, and that icon selection leaves the lyric viewport unchanged. They compare symbol pixels only within one process and store none. All related Swift suites passed.

## Limitations

- Symbol rendering depends on the SF Symbols version installed on the rendering Mac; outputs on other macOS releases may differ.
- Opacity is estimated from encoded values over varied backgrounds and does not identify native material blending.
- Controls are static: pressed states, transitions between play and pause, and auto-hiding are not modeled.
- Native control materials (gate B3), sliders, and time-label typography remain provisional.
- The rights status of symbols in published videos remains unresolved.

Native iOS 27 Music control fidelity is not established beyond the measured static geometry.
