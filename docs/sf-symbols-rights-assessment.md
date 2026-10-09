# SF Symbols and System Font Rights Assessment

## Conclusion

October 9, 2026. **No published Apple term explicitly grants the use of SF Symbols in standalone exported videos, and none was found that addresses that use specifically.** The applicable developer agreement licenses system-provided symbols solely for developing Applications for Apple platforms and prohibits trademark use. iLyric can lawfully reference symbols through public APIs without redistributing them, but the rights status of symbols rasterized into user-generated videos remains **unresolved**. This assessment records engineering obligations and uncertainty; it is not legal advice.

The maintainer has decided to resolve SF Symbols at runtime and enable them by default, subject to the constraints in this document. That decision does not establish permission; it allocates the residual risk to the person rendering and publishing a video, who must be informed accordingly.

## Primary Sources

All sources were accessed on October 9, 2026.

| Source | Relevant Term | Consequence for iLyric |
| --- | --- | --- |
| [Xcode and Apple SDKs Agreement](https://www.apple.com/legal/sla/docs/xcode.pdf), EA2002, dated 06/08/2026, section 2.10 | System-provided assets, including symbols documented in the Human Interface Guidelines, “are licensed to You solely for the purpose of developing Applications for Apple-branded products that run on the system for which the image was provided.” They may not be used in app icons, logos, or other trademark use; Apple may require discontinuance. | An exported video is not an Application. Use within iLyric's own macOS interface is arguably covered; use in distributed video output is not expressly covered. |
| Same agreement, definition of “Application” | A software program developed by the licensee for use on Apple-branded products running Apple operating systems. | iLyric, as a macOS program built with the SDK, plausibly qualifies; its rendered media output is a separate work. |
| [Human Interface Guidelines: SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) | Symbols may not be used, nor confusingly similar images, in app icons, logos, or other trademark use. Symbols depicting Apple products and features are copyrighted, may be displayed in an app, and may not be customized. | Never use a symbol as an iLyric logo. Do not modify, recolor beyond supported rendering modes, or redraw restricted symbols. |
| [macOS Software License Agreement](https://www.apple.com/legal/sla/docs/macOS27.pdf), EA2005, section 2.E | Fonts included with macOS may be used “to display and print content while running the Apple Software”; embedding is limited by each font's embedding restrictions. | Rasterizing system-font text into video resembles displaying content and is not font-file embedding. The clause does not expressly address symbols or video distribution. |
| [Apple San Francisco Font License](https://developer.apple.com/fonts/), EA1370, dated 2/24/2016 | Downloadable San Francisco fonts may be used solely for mock-ups of user interfaces for software running on Apple operating systems, including depictions in screenshots and images, by registered Apple Developers; embedding in other products is prohibited. | Applies to the separately downloaded font files, which iLyric does not use or distribute. It indicates Apple's general restriction to interface mock-ups. |

## Assessment by Activity

| Activity | Status | Basis |
| --- | --- | --- |
| Publishing iLyric source that calls public symbol APIs | Permissible | No Apple asset is copied or redistributed. |
| Bundling, extracting, tracing, or vectorizing symbols or fonts | Prohibited | Redistribution of Apple-owned assets is not licensed. |
| Displaying symbols in iLyric's own macOS interface | Plausibly permitted | Development of an Application for an Apple platform. |
| Rasterizing symbols into a locally kept, personal video | Unresolved, lower risk | Not expressly covered; no distribution. |
| Publishing or redistributing videos containing symbols | Unresolved, higher risk | Not an Application; Apple-feature symbols carry additional copyright restrictions. |
| Using a symbol or similar image as an iLyric logo or trademark | Prohibited | Section 2.10 and the Human Interface Guidelines. |
| Rendering system-font text into video | Lower risk, not expressly confirmed | macOS section 2.E permits displaying content; no font file is embedded or distributed. |

## Engineering Policy

1. Resolve symbols only at runtime through public AppKit or Core Graphics APIs on the user's Mac. Never commit symbol rasters, vectors, glyph outlines, or font files.
2. Public fixtures, golden images, test outputs, documentation images, and demonstration videos must use the original icon set, never SF Symbols. Continuous integration must not compare against symbol-derived pixels.
3. Provide an explicit icon-set selection with SF Symbols as the maintainer-selected default and an original icon set of equal layout coverage. Record the selected set in output provenance.
4. State in user documentation and command help that Apple's terms do not expressly license SF Symbols in exported videos and that publication is the user's responsibility. Emit a concise diagnostic when SF Symbols are rendered into an output file.
5. Do not modify restricted Apple-feature symbols; use only supported weights, scales, and rendering modes.
6. Revisit this assessment when Apple publishes revised terms, or if the maintainer obtains written clarification. No inquiry has been sent.

The same runtime-only, no-redistribution policy applies to system fonts used for lyric and interface typography.
