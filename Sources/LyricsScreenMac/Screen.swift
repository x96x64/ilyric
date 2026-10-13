import Foundation
import CoreGraphics
import CoreText
import CoreImage
import Metal
import LyricsScreenCore
import TimelineCore

/// Original assets and fixed component ordering. No system assets or native chrome.
public final class ScreenRenderer {
    public let screen: LyricsScreen
    private var canvasHeight: Double { Double(screen.canvas.height) }
    public let lyrics: CompositionRenderer
    private let backdrop, artwork, fadeMask, expandedFadeMask: CGImage
    private let tileCache: TileCache
    private let dynamicBackdrop: ArtworkBackdrop?
    public let icons: ScreenIconSet
    private let symbols = SystemSymbols()
    private let diagnosticMarkers, calibratedInactive, boundedCache: Bool
    private let title: CTLine
    private let artist: CTLine
    /// Optional measured header scrolling; nil keeps both labels static and clipped.
    public let marquee: TitleMarquee?
    private let marqueeMask: CGImage?
    private let scrollingParts: Set<ScreenPart>
    public init(
        _ screen: LyricsScreen, calibratedInactive: Bool = false, diagnosticMarkers: Bool = true,
        boundedCache: Bool = false, suppliedArtwork: CGImage? = nil, icons: ScreenIconSet = .original,
        marquee: TitleMarquee? = nil, sharing: ScreenRenderer? = nil, placeholderArtwork: Bool = false
    ) throws {
        let marquee = marquee?.adapted(to: screen.canvas)
        let canvasHeight = Double(screen.canvas.height)
        self.icons = icons
        self.marquee = marquee
        if let marquee {
            let width = Int((marquee.clipMaxX - marquee.clipMinX).rounded())
            let bytes = (0..<width).map {
                UInt8((marquee.opacity(at: marquee.clipMinX + Double($0) + 0.5) * 255).rounded())
            }
            marqueeMask = CGImage(
                width: width, height: 1, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [],
                provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)!
        } else {
            marqueeMask = nil
        }
        self.diagnosticMarkers = diagnosticMarkers
        self.calibratedInactive = calibratedInactive
        self.boundedCache = boundedCache
        // Renderers of the same scene share immutable layouts and inactive tiles; caches stay bounded.
        if let sharing, sharing.screen.composition.paragraphs.count == screen.composition.paragraphs.count,
            sharing.screen.composition.canvasWidth == screen.composition.canvasWidth
        {
            lyrics = sharing.lyrics
            tileCache = sharing.tileCache
        } else {
            lyrics = try CompositionRenderer(screen.composition)
            tileCache = TileCache(capacity: boundedCache ? 16 : Int.max)
        }
        self.screen = screen
        let titleLine = Self.line(screen.title, size: 51, bold: true)
        let artistLine = Self.line(screen.artist, size: 49, bold: false)
        title = titleLine
        artist = artistLine
        let probe = Self.context(1, 1)
        let header = screen.evaluate(Time(0)).components
        scrollingParts = Set(
            header.compactMap { part in
                guard let marquee, let line = part.part == .title ? titleLine : part.part == .artist ? artistLine : nil
                else { return nil }
                return marquee.overflows(origin: part.bounds.x, inkWidth: CTLineGetImageBounds(line, probe).width)
                    ? part.part : nil
            })
        // Palette shared by the original artwork and background; no source artwork.
        let colors = [
            CGColor(srgbRed: 0.12, green: 0.21, blue: 0.25, alpha: 1),
            CGColor(srgbRed: 0.29, green: 0.23, blue: 0.35, alpha: 1),
            CGColor(srgbRed: 0.16, green: 0.12, blue: 0.24, alpha: 1),
        ]
        let bg = Self.context(screen.composition.canvasWidth, screen.canvas.height)
        let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: [0, 0.45, 1])!
        bg.drawLinearGradient(
            gradient, start: CGPoint(x: 0, y: canvasHeight), end: CGPoint(x: screen.canvas.width, y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        backdrop = bg.makeImage()!
        let art = Self.context(216, 216)
        art.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 216, y: 216), options: [])
        art.setFillColor(CGColor(srgbRed: 0.94, green: 0.70, blue: 0.45, alpha: 1))
        art.fillEllipse(in: CGRect(x: 118, y: 111, width: 58, height: 58))
        art.setStrokeColor(CGColor(srgbRed: 0.54, green: 0.79, blue: 0.81, alpha: 0.9))
        art.setLineWidth(9)
        for y in [38.0, 62, 86] {
            art.move(to: CGPoint(x: -10, y: y))
            art.addCurve(
                to: CGPoint(x: 226, y: y + 12), control1: CGPoint(x: 62, y: y + 70),
                control2: CGPoint(x: 154, y: y - 55))
            art.strokePath()
        }
        if let image = suppliedArtwork {
            // Center-cover only the fixed artwork rectangle; scene geometry is unchanged.
            let target = Self.context(216, 216)
            let scale = max(216 / Double(image.width), 216 / Double(image.height))
            target.interpolationQuality = .high
            target.draw(
                image,
                in: CGRect(
                    x: (216 - Double(image.width) * scale) / 2, y: (216 - Double(image.height) * scale) / 2,
                    width: Double(image.width) * scale, height: Double(image.height) * scale))
            artwork = target.makeImage()!
        } else {
            artwork = art.makeImage()!
        }
        func mask(_ fade: (Double) -> Double) -> CGImage {
            let bytes = (0..<screen.canvas.height).map { UInt8((fade(Double($0) + 0.5) * 255).rounded()) }
            return CGImage(
                width: 1, height: screen.canvas.height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: 1,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [],
                provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)!
        }
        fadeMask = mask {
            LyricsScreen.fade(at: $0, viewport: screen.canvas.viewport, bottomFade: LyricsScreen.fadeLength)
        }
        expandedFadeMask = mask {
            LyricsScreen.fade(
                at: $0, viewport: screen.canvas.expandedViewport, bottomFade: LyricsScreen.expandedBottomFade)
        }
        if let model = screen.background {
            dynamicBackdrop = ArtworkBackdrop(
                model, artwork: artwork, canvasWidth: screen.composition.canvasWidth,
                canvasHeight: screen.canvas.height, abstract: placeholderArtwork)
        } else {
            dynamicBackdrop = nil
        }
        if calibratedInactive && !boundedCache {
            for (i, p) in screen.composition.paragraphs.enumerated()
            where (p.input.paragraphStyle == .latinStatic || p.input.paragraphStyle == .latinTimed) {
                _ = try tileCache.tiles(i) {
                    InactiveTiles(
                        try lyrics.paragraphs[i].render(
                            p.input.evaluate(Time(0)), coverage: p.input.paragraphStyle == .latinTimed))
                }
            }
        }
    }
    private static func context(_ w: Int, _ h: Int) -> CGContext {
        CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }
    private static func line(_ text: String, size: Double, bold: Bool) -> CTLine {
        let regular = CTFontCreateUIFontForLanguage(.system, size, nil)!
        let font = bold ? CTFontCreateCopyWithSymbolicTraits(regular, size, nil, .traitBold, .traitBold)! : regular
        return CTLineCreateWithAttributedString(
            NSAttributedString(
                string: text,
                attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
                ]))
    }
    /// Time labels use monospaced digits and a fixed reference position, so changing digits never
    /// move the label; the ink-based placement of other text would shift with each glyph's bounds.
    private func timeLabel(_ text: String, _ b: ScreenBounds, _ c: CGContext, right: Bool) {
        let regular = CTFontCreateUIFontForLanguage(.system, 35, nil)!
        let features = [
            [
                kCTFontFeatureTypeIdentifierKey: kNumberSpacingType,
                kCTFontFeatureSelectorIdentifierKey: kMonospacedNumbersSelector,
            ]
        ]
        let font = CTFontCreateCopyWithAttributes(
            regular, 35, nil,
            CTFontDescriptorCreateWithAttributes([kCTFontFeatureSettingsAttribute: features] as CFDictionary))
        func line(_ s: String) -> CTLine {
            CTLineCreateWithAttributedString(
                NSAttributedString(
                    string: s,
                    attributes: [
                        NSAttributedString.Key(kCTFontAttributeName as String): font,
                        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
                    ]))
        }
        c.saveGState()
        c.setAlpha(0.55)
        c.textMatrix = .identity
        c.textPosition = .zero
        let reference = CTLineGetImageBounds(line(right ? "−0:00" : "0:00"), c)
        let shown = line(text)
        let x = right ? b.x + b.width - CTLineGetTypographicBounds(shown, nil, nil, nil) : b.x - reference.minX
        c.textPosition = CGPoint(x: x, y: canvasHeight - b.y - reference.maxY)
        CTLineDraw(shown, c)
        c.restoreGState()
    }
    private func rect(_ b: ScreenBounds) -> CGRect {
        CGRect(x: b.x, y: canvasHeight - b.y - b.height, width: b.width, height: b.height)
    }
    private func ink(_ line: CTLine, _ b: ScreenBounds, _ c: CGContext, alpha: Double = 1, right: Bool = false) {
        c.saveGState()
        c.setAlpha(alpha)
        c.textMatrix = .identity
        c.textPosition = .zero
        let bounds = CTLineGetImageBounds(line, c)
        c.textPosition = CGPoint(
            x: (right ? b.x + b.width - bounds.width : b.x) - bounds.minX, y: canvasHeight - b.y - bounds.maxY)
        CTLineDraw(line, c)
        c.restoreGState()
    }
    /// Two copies separated by the measured gap, clipped to the measured header span with edge fades.
    private func scroll(_ line: CTLine, _ b: ScreenBounds, _ c: CGContext, seconds: Double, alpha: Double = 1) {
        guard let marquee, let marqueeMask else { return }
        c.saveGState()
        c.setAlpha(alpha)
        c.textMatrix = .identity
        c.textPosition = .zero
        let bounds = CTLineGetImageBounds(line, c)
        let offset = marquee.offset(at: seconds, origin: b.x, inkWidth: bounds.width)
        let r = rect(b)
        c.clip(
            to: CGRect(x: marquee.clipMinX, y: r.minY, width: marquee.clipMaxX - marquee.clipMinX, height: r.height),
            mask: marqueeMask)
        for copy in [0.0, bounds.width + marquee.gap] {
            c.textPosition = CGPoint(x: b.x - offset + copy - bounds.minX, y: canvasHeight - b.y - bounds.maxY)
            CTLineDraw(line, c)
        }
        c.restoreGState()
    }
    /// Optional backing text by paragraph index; inherited cues retain dim ink only during lead focus.
    public var secondary: [Int: SecondaryLine] = [:]
    /// Optional songwriter credits, such as "Written By: A, B", shown below the last paragraph.
    public var credits: String? { didSet { creditLines = nil } }
    private var creditLines: [CTLine]?
    private var secondaryLines: [Int: [CTLine]] = [:]
    /// Wrapped secondary lines at the measured size; cached per paragraph.
    func wrappedSecondary(_ i: Int) -> [CTLine] {
        if let cached = secondaryLines[i] { return cached }
        guard let s = secondary[i] else { return [] }
        let p = lyrics.paragraphs[i].input.parameters
        let size = p.size * SecondaryLine.sizeRatio
        let regular = CTFontCreateUIFontForLanguage(.system, size, nil)!
        let font = CTFontCreateCopyWithSymbolicTraits(regular, size, nil, .traitBold, .traitBold)!
        let attributed = NSAttributedString(
            string: s.text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
            ])
        let setter = CTTypesetterCreateWithAttributedString(attributed)
        var lines = [CTLine]()
        var start = 0
        while start < attributed.length {
            let n = max(1, CTTypesetterSuggestLineBreak(setter, start, p.width))
            lines.append(CTTypesetterCreateLine(setter, CFRange(location: start, length: n)))
            start += n
        }
        secondaryLines[i] = lines
        return lines
    }
    /// Songwriter credits measured on the reference capture: background-vocal size and weight, opacity 0.32, first
    /// baseline 163 px below the last background-vocal baseline, or at the background-vocal position without one.
    /// The credits fade with the last paragraph's inactive treatment rather than being blurred.
    static let creditsOpacity = 0.32, creditsGap = 163.0
    private func drawCredits(_ i: Int, translation: Double, weight: Double, into c: CGContext) {
        guard let text = credits, weight > 0, i == lyrics.paragraphs.count - 1 else { return }
        let p = lyrics.paragraphs[i].input.parameters
        let size = p.size * SecondaryLine.sizeRatio
        let advance = p.lineAdvance * SecondaryLine.sizeRatio
        if creditLines == nil {
            let regular = CTFontCreateUIFontForLanguage(.system, size, nil)!
            let font = CTFontCreateCopyWithSymbolicTraits(regular, size, nil, .traitBold, .traitBold)!
            let attributed = NSAttributedString(
                string: text,
                attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
                ])
            let setter = CTTypesetterCreateWithAttributedString(attributed)
            var lines = [CTLine]()
            var start = 0
            while start < attributed.length {
                let n = max(1, CTTypesetterSuggestLineBreak(setter, start, p.width))
                lines.append(CTTypesetterCreateLine(setter, CFRange(location: start, length: n)))
                start += n
            }
            creditLines = lines
        }
        let last =
            p.originY + Double(lyrics.paragraphs[i].lines.count - 1) * p.lineAdvance + p.size + translation
            + SecondaryLine.baselineOffset
        let secondaryCount = Double(wrappedSecondary(i).count)
        let first = secondaryCount > 0 ? last + (secondaryCount - 1) * advance + Self.creditsGap : last
        c.saveGState()
        c.textMatrix = .identity
        c.setAlpha(weight * Self.creditsOpacity)
        for (k, line) in (creditLines ?? []).enumerated() {
            c.textPosition = CGPoint(x: p.originX, y: canvasHeight - (first + Double(k) * advance))
            CTLineDraw(line, c)
        }
        c.restoreGState()
    }
    /// Inherited cues follow lead visibility without fill; explicit cues retain their existing soft fill ramp.
    private func drawSecondary(
        _ i: Int, translation: Double, weight: Double, focused: Bool, time: Time, into c: CGContext
    ) {
        guard let s = secondary[i], weight > 0, s.hasExplicitTiming || focused else { return }
        let inkWeight = weight
        let input = lyrics.paragraphs[i].input
        let p = input.parameters
        let lines = wrappedSecondary(i)
        let edge = 30.0
        let count = Double(lyrics.paragraphs[i].lines.count)
        let widths = lines.map { CTLineGetTypographicBounds($0, nil, nil, nil) }
        let total = widths.reduce(0, +)
        let front = s.progress(at: time) * (total + edge) - edge / 2
        var preceding = 0.0
        c.saveGState()
        c.textMatrix = .identity
        for (k, line) in lines.enumerated() {
            let baseline =
                p.originY + (count - 1) * p.lineAdvance + p.size + translation + SecondaryLine.baselineOffset + Double(
                    k) * p.lineAdvance * SecondaryLine.sizeRatio
            let y = canvasHeight - baseline
            let x = p.originX + (input.rightAligned == true ? p.width - widths[k] : 0)
            c.setAlpha(inkWeight * SecondaryLine.unfilledOpacity)
            c.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, c)
            let local = front - preceding
            if local > 0 {
                let w = Int(ceil(widths[k])) + 2
                let bytes = (0..<w).map {
                    UInt8((min(1, max(0, (local - Double($0) - 0.5) / edge + 0.5)) * 255).rounded())
                }
                let mask = CGImage(
                    width: w, height: 1, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w,
                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [],
                    provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil, shouldInterpolate: true,
                    intent: .defaultIntent)!
                c.saveGState()
                c.clip(to: CGRect(x: x, y: y - p.size, width: Double(w), height: p.size * 2), mask: mask)
                // Filled ink composites over the unfilled ink, so its own alpha completes the measured opacity.
                c.setAlpha(
                    inkWeight * (SecondaryLine.filledOpacity - SecondaryLine.unfilledOpacity)
                        / (1 - SecondaryLine.unfilledOpacity))
                c.textPosition = CGPoint(x: x, y: y)
                CTLineDraw(line, c)
                c.restoreGState()
            }
            preceding += widths[k]
        }
        c.restoreGState()
    }
    /// Full-canvas paragraph rasters are mostly transparent; draw only the paragraph's band.
    private func band(_ image: CGImage, paragraph i: Int, translation: Double) -> (CGImage, CGRect) {
        let input = lyrics.paragraphs[i].input
        let lines = lyrics.paragraphs[i].lines.count
        let w = Double(image.width)
        let top = max(0, (input.parameters.originY - 80).rounded(.down))
        let bottom = min(
            Double(image.height),
            (input.parameters.originY + Double(lines - 1) * input.parameters.lineAdvance + input.parameters.size * 2
                + 120).rounded(.up))
        guard bottom > top, let cropped = image.cropping(to: CGRect(x: 0, y: top, width: w, height: bottom - top))
        else {
            return (image, CGRect(x: 0, y: -translation, width: w, height: Double(image.height)))
        }
        return (cropped, CGRect(x: 0, y: Double(image.height) - bottom - translation, width: w, height: bottom - top))
    }
    public func lyricLayer(_ state: CompositionSnapshot, viewport v: ScreenBounds? = nil, reveal: Double = 1) throws
        -> CGImage
    {
        let c = Self.context(screen.composition.canvasWidth, screen.canvas.height)
        try drawLyrics(state, viewport: v ?? screen.canvas.viewport, reveal: reveal, into: c)
        return c.makeImage()!
    }
    /// Draws the lyric layer into any native-sized context, clipped and faded; used directly by the screen
    /// composite to avoid a full-canvas intermediate image per frame.
    func drawLyrics(_ state: CompositionSnapshot, viewport v: ScreenBounds, reveal: Double, into c: CGContext) throws {
        let w = screen.composition.canvasWidth
        c.saveGState()
        defer { c.restoreGState() }
        var mask = v == screen.canvas.expandedViewport ? expandedFadeMask : fadeMask
        if v == screen.canvas.expandedViewport && reveal < 1 {
            // During the hide transition the vacated area fades in: max(original fade, revealed expanded fade).
            let bytes = (0..<screen.canvas.height).map { y -> UInt8 in
                let yy = Double(y) + 0.5
                let e = LyricsScreen.fade(at: yy, viewport: v, bottomFade: LyricsScreen.expandedBottomFade)
                return UInt8(
                    (max(
                        LyricsScreen.fade(
                            at: yy, viewport: screen.canvas.viewport, bottomFade: LyricsScreen.fadeLength), e * reveal)
                        * 255).rounded())
            }
            mask = CGImage(
                width: 1, height: screen.canvas.height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: 1,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: [], provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil,
                shouldInterpolate: false, intent: .defaultIntent)!
        }
        c.clip(to: rect(v))
        c.clip(to: CGRect(x: 0, y: 0, width: Double(w), height: canvasHeight), mask: mask)
        for p in state.paragraphs {
            if boundedCache {
                let input = lyrics.paragraphs[p.index].input
                let lines = lyrics.paragraphs[p.index].lines
                let top = input.parameters.originY + p.translationY - 40
                let bottom =
                    top + Double(lines.count - 1) * input.parameters.lineAdvance + input.parameters.size * 2 + 80
                if bottom < v.y || top > v.y + v.height { continue }
            }
            let style = lyrics.paragraphs[p.index].input.paragraphStyle
            let tiles =
                calibratedInactive && (style == .latinStatic || style == .latinTimed)
                ? try tileCache.tiles(p.index) {
                    InactiveTiles(
                        try lyrics.paragraphs[p.index].render(
                            lyrics.paragraphs[p.index].input.evaluate(Time(0)), coverage: style == .latinTimed))
                } : nil
            if let tiles {
                let a = InactiveTreatment.evaluate(state.output, paragraph: p.index, events: screen.composition.events)
                if lyrics.paragraphs[p.index].input.paragraphStyle == .latinTimed {
                    // A bounded synthetic blend separates supplied highlighting from cached inactive support.
                    let weight = 1 - a.blur / 8
                    let image = weight > 0 ? try lyrics.paragraphs[p.index].render(p.appearance) : nil
                    let banded = image.map { band($0, paragraph: p.index, translation: p.translationY) }
                    // Bound the isolated layer to the paragraph's band and its blurred tile instead of the canvas.
                    let region = (banded?.1 ?? .null).union(tiles.bounds.offsetBy(dx: 0, dy: -p.translationY)).insetBy(
                        dx: 0, dy: -4)
                    c.saveGState()
                    c.beginTransparencyLayer(in: region, auxiliaryInfo: nil)
                    c.setBlendMode(.plusLighter)
                    tiles.draw(a.blur, opacity: a.opacity * (1 - weight), translation: p.translationY, into: c)
                    if let (part, frame) = banded { c.drawSubpixel(part, in: frame, alpha: a.opacity * weight) }
                    c.setBlendMode(.normal)
                    c.endTransparencyLayer()
                    c.restoreGState()
                } else {
                    tiles.draw(a.blur, opacity: a.opacity, translation: p.translationY, into: c)
                }
                drawSecondary(
                    p.index, translation: p.translationY, weight: a.opacity * max(0, 1 - a.blur / 8),
                    focused: state.focus == p.index, time: state.output, into: c)
                drawCredits(p.index, translation: p.translationY, weight: a.opacity * max(0, 1 - a.blur / 8), into: c)
                continue
            }
            let image = try lyrics.paragraphs[p.index].render(p.appearance)
            let (part, frame) = band(image, paragraph: p.index, translation: p.translationY)
            c.drawSubpixel(part, in: frame, alpha: p.opacity)
            drawSecondary(
                p.index, translation: p.translationY, weight: state.focus == p.index ? p.opacity : 0,
                focused: state.focus == p.index, time: state.output, into: c)
            drawCredits(p.index, translation: p.translationY, weight: p.opacity, into: c)
        }
        for g in state.gaps {
            if let s = g.state {
                Self.drawGap(
                    s, centerY: GapIndicator.focusedCenterY + g.translationY, canvasHeight: canvasHeight, into: c)
            }
        }
    }
    /// Three white dots scaled as a group about the middle dot; native coordinates, top-left origin.
    static func drawGap(_ s: GapIndicatorState, centerY: Double, canvasHeight: Double = 2556, into c: CGContext) {
        let middle = GapIndicator.firstCenterX + GapIndicator.spacing
        let d = GapIndicator.diameter * s.scale
        let y = canvasHeight - centerY
        for (k, opacity) in s.opacities.enumerated() {
            let x = middle + (Double(k) - 1) * GapIndicator.spacing * s.scale
            c.setFillColor(CGColor(gray: 1, alpha: opacity * s.visibility))
            c.fillEllipse(in: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d))
        }
    }
    public func native(_ state: ScreenSnapshot) throws -> CGImage {
        let c = Self.context(screen.composition.canvasWidth, screen.canvas.height)
        let lowerGroup: Set<ScreenPart> = [
            .progress, .elapsed, .remaining, .previous, .playback, .next, .volume, .volumeLow, .volumeHigh,
            .bottomLeft, .bottomCenter, .bottomRight, .translation, .singCompact, .singExpanded,
        ]
        for part in state.components.sorted(by: { $0.z < $1.z }) where part.visible {
            let moving = state.lowerOpacity < 1 && lowerGroup.contains(part.part)
            if moving {
                c.saveGState()
                c.translateBy(x: 0, y: -state.lowerOffset)
                c.setAlpha(state.lowerOpacity)
            }
            defer { if moving { c.restoreGState() } }
            // Measured symbol placement may exceed the provisional component rectangle, so it is not clipped.
            if icons == .systemSymbols,
                let symbol = ControlSymbols.symbol(for: part.part, playing: state.playing, canvas: screen.canvas)
            {
                try symbols.draw(symbol, canvasHeight: canvasHeight, into: c)
                continue
            }
            c.saveGState()
            let r = rect(part.bounds)
            let label = part.part == .title ? title : part.part == .artist ? artist : nil
            let scrolling = scrollingParts.contains(part.part)
            if part.clips && !scrolling { c.clip(to: r) }
            c.setFillColor(CGColor(gray: 1, alpha: 0.9))
            c.setStrokeColor(CGColor(gray: 1, alpha: 0.85))
            c.setLineWidth(5)
            switch part.part {
            case .background:
                // The backdrop is heavily blurred, so bilinear upscaling is indistinguishable from high quality.
                if let dynamicBackdrop {
                    c.interpolationQuality = .low
                    c.draw(dynamicBackdrop.image(at: state.lyrics.output), in: r)
                } else {
                    c.draw(backdrop, in: r)
                }
            case .lyrics: try drawLyrics(state.lyrics, viewport: part.bounds, reveal: state.lyricsReveal, into: c)
            case .artwork:
                // Corner radius fitted to the header artwork of the development screenshots (28.5–31.5 px).
                c.addPath(CGPath(roundedRect: r, cornerWidth: 30, cornerHeight: 30, transform: nil))
                c.clip()
                c.draw(artwork, in: r)
            case .title, .artist:
                let alpha = part.part == .title ? 1 : 0.6
                if scrolling {
                    scroll(label!, part.bounds, c, seconds: state.lyrics.output.seconds, alpha: alpha)
                } else {
                    ink(label!, part.bounds, c, alpha: alpha)
                }
            case .more:
                // Project-owned three-dot icon for public fixtures; no symbol asset is copied.
                c.setFillColor(CGColor(gray: 1, alpha: 1))
                for offset in [-22.0, 0, 22] {
                    c.fillEllipse(in: CGRect(x: r.midX + offset - 6, y: r.midY - 6, width: 12, height: 12))
                }
            case .handle: rounded(r, 6, c, alpha: 0.4)
            case .progress, .volume:
                rounded(r, r.height / 2, c, alpha: 0.22)
                c.saveGState()
                c.clip(
                    to: CGRect(
                        x: r.minX, y: r.minY, width: r.width * (part.part == .progress ? state.progress : state.volume),
                        height: r.height))
                rounded(r, r.height / 2, c, alpha: 0.75)
                c.restoreGState()
            case .elapsed, .remaining:
                let value = part.part == .elapsed ? state.elapsed : state.remaining
                let label = (part.part == .remaining ? "−" : "") + String(format: "%d:%02d", value / 60, value % 60)
                timeLabel(label, part.bounds, c, right: part.part == .remaining)
            case .playback:
                if state.playing {
                    rounded(CGRect(x: r.midX - 25, y: r.midY - 34, width: 17, height: 68), 3, c, alpha: 0.95)
                    rounded(CGRect(x: r.midX + 8, y: r.midY - 34, width: 17, height: 68), 3, c, alpha: 0.95)
                } else {
                    triangle(r.midX - 20, r.midY, 55, 70, c)
                }
            case .previous, .next:
                c.translateBy(x: r.midX, y: r.midY)
                if part.part == .previous { c.scaleBy(x: -1, y: 1) }
                triangle(-43, 0, 40, 48, c)
                triangle(-2, 0, 40, 48, c)
            case .translation, .singCompact, .singExpanded:
                rounded(r, part.part == .singExpanded ? 48 : 42, c, alpha: 0.14)
                if part.part == .translation {
                    ink(Self.line("Aa", size: 31, bold: true), .init(part.bounds.x + 17, part.bounds.y + 26, 60, 40), c)
                } else {
                    rounded(CGRect(x: r.midX - 9, y: r.midY - 18, width: 18, height: 40), 9, c, alpha: 0.85)
                    c.move(to: CGPoint(x: r.midX - 18, y: r.midY + 2))
                    c.addLine(to: CGPoint(x: r.midX - 18, y: r.midY - 25))
                    c.addLine(to: CGPoint(x: r.midX + 18, y: r.midY - 25))
                    c.addLine(to: CGPoint(x: r.midX + 18, y: r.midY + 2))
                    c.strokePath()
                }
            case .bottomLeft:
                c.stroke(r.insetBy(dx: 12, dy: 15))
                c.move(to: CGPoint(x: r.minX + 22, y: r.minY + 24))
                c.addLine(to: CGPoint(x: r.maxX - 22, y: r.minY + 24))
                c.strokePath()
            case .bottomCenter:
                c.strokeEllipse(in: r.insetBy(dx: 17, dy: 17))
                c.strokeEllipse(in: r.insetBy(dx: 5, dy: 5))
            case .bottomRight:
                for y in [-18.0, 0, 18] {
                    c.move(to: CGPoint(x: r.minX + 12, y: r.midY + y))
                    c.addLine(to: CGPoint(x: r.maxX - 12, y: r.midY + y))
                    c.strokePath()
                }
            case .volumeLow, .volumeHigh:
                triangle(r.minX + 7, r.midY, 22, 26, c)
                if part.part == .volumeHigh { c.strokeEllipse(in: r.insetBy(dx: 2, dy: 7)) }
            }
            c.restoreGState()
        }
        return c.makeImage()!
    }
    private func rounded(_ r: CGRect, _ radius: Double, _ c: CGContext, alpha: Double) {
        c.setFillColor(CGColor(gray: 1, alpha: alpha))
        c.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
        c.fillPath()
    }
    private func triangle(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: CGContext) {
        c.move(to: CGPoint(x: x, y: y - h / 2))
        c.addLine(to: CGPoint(x: x + w, y: y))
        c.addLine(to: CGPoint(x: x, y: y + h / 2))
        c.closePath()
        c.fillPath()
    }
    /// Optional GPU downscale of the native frame: Core Image Lanczos resampling on Metal, written directly into
    /// the destination bitmap. Resampling works on encoded sRGB values, as Core Graphics scaling does.
    private var gpu: CIContext?
    public var usesGPUScaling: Bool { gpu != nil }
    public func enableGPUScaling() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        gpu = CIContext(
            mtlDevice: device,
            options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, .cacheIntermediates: false])
    }
    public func draw(_ time: Time, into c: CGContext) throws {
        let w = Double(c.width)
        let h = Double(c.height)
        let fit = LyricsScreen.contain(
            width: w, height: h, canvasWidth: screen.composition.canvasWidth, canvasHeight: screen.canvas.height)
        let image = try native(screen.evaluate(time))
        if let gpu, let data = c.data, let space = c.colorSpace, c.bitsPerPixel == 32,
            c.bitmapInfo.contains(.byteOrder32Little)
        {
            let scaled = CIImage(cgImage: image).applyingFilter(
                "CILanczosScaleTransform",
                parameters: [kCIInputScaleKey: fit.width / Double(image.width), kCIInputAspectRatioKey: 1.0])
            let frame = CGRect(x: 0, y: 0, width: w, height: h)
            let placed = scaled.transformed(
                by: CGAffineTransform(translationX: fit.x - scaled.extent.minX, y: fit.y - scaled.extent.minY))
            let composed = placed.composited(
                over: CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: frame)
            ).cropped(to: frame)
            gpu.render(
                composed, toBitmap: data, rowBytes: c.bytesPerRow, bounds: frame, format: .BGRA8, colorSpace: space)
        } else {
            c.setFillColor(CGColor(gray: 0, alpha: 1))
            c.fill(CGRect(x: 0, y: 0, width: w, height: h))
            c.interpolationQuality = .high
            c.draw(image, in: CGRect(x: fit.x, y: fit.y, width: fit.width, height: fit.height))
        }
        // Existing audiovisual diagnostic marker, separate from native scene content.
        let t = Time(time.numerator % (4 * time.denominator), time.denominator)
        if diagnosticMarkers && Timeline.markerTimes.contains(where: { t >= $0 && t < $0 + Time(1, 20) }) {
            let marker = Fit(width: w, height: h)
            c.setFillColor(CGColor(gray: 1, alpha: 1))
            c.fill(
                CGRect(
                    x: marker.x + 35 * marker.scale, y: h - 843 * marker.scale, width: 20 * marker.scale,
                    height: 20 * marker.scale))
        }
    }
    public func frame(_ time: Time) throws -> CGImage {
        let c = Self.context(1080, 1920)
        try draw(time, into: c)
        return c.makeImage()!
    }
}
