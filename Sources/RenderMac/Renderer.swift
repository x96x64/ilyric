import Foundation
import CoreGraphics
import CoreText
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import SpikeCore

public enum SpikeError: Error { case failure(String) }
let colorSpace = CGColorSpace(name: CGColorSpace.itur_709)!
let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

func context(width: Int, height: Int, data: UnsafeMutableRawPointer? = nil, rowBytes: Int? = nil) throws -> CGContext {
    guard let ctx = CGContext(data: data, width: width, height: height, bitsPerComponent: 8,
                              bytesPerRow: rowBytes ?? width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else {
        throw SpikeError.failure("Cannot allocate bitmap context")
    }
    return ctx
}

public struct LineMetrics: Equatable {
    public let start: Int
    public let length: Int
    public let width: Double
    public let baseline: Double
}

/// Whole paragraphs are shaped once. Timed ranges only clip an existing raster.
public final class TextLayout {
    public let metrics: [LineMetrics]
    public let fonts: [String]
    public let image: CGImage
    public let wordRects: [CGRect]
    public init(text: String, width: Double = 342, size: Double = 27, scale: Double) throws {
        let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1)
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let setter = CTTypesetterCreateWithAttributedString(attributed)
        let ns = text as NSString
        var start = 0
        var lines: [(CTLine, LineMetrics)] = []
        var names = Set<String>()
        while start < ns.length {
            let length = CTTypesetterSuggestLineBreak(setter, start, width)
            guard length > 0 else { throw SpikeError.failure("Text layout made no progress") }
            let line = CTTypesetterCreateLine(setter, CFRange(location: start, length: length))
            // Trailing whitespace advances may exceed the wrap width; measure visible content.
            let measured = CTLineGetTypographicBounds(line, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(line)
            let metric = LineMetrics(start: start, length: length, width: measured, baseline: 32 + Double(lines.count) * 37)
            lines.append((line, metric))
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                let attrs = CTRunGetAttributes(run) as NSDictionary
                if let resolved = attrs[kCTFontAttributeName] {
                    names.insert(CTFontCopyPostScriptName(resolved as! CTFont) as String)
                }
            }
            start += length
        }
        metrics = lines.map(\.1)
        fonts = names.sorted()
        let height = max(1, Int(ceil((Double(lines.count) * 37 + 10) * scale)))
        let ctx = try context(width: Int(ceil(width * scale)), height: height)
        ctx.scaleBy(x: scale, y: scale)
        for (line, metric) in lines {
            ctx.textPosition = CGPoint(x: 0, y: Double(height) / scale - metric.baseline)
            CTLineDraw(line, ctx)
        }
        image = ctx.makeImage()!
        // Fixture-only Latin word timing. No production grapheme/cluster schema is implied.
        let regex = try NSRegularExpression(pattern: "[A-Za-z]+[.]?")
        var rectangles: [CGRect] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            for (line, metric) in lines {
                let intersection = NSIntersectionRange(match.range, NSRange(location: metric.start, length: metric.length))
                if intersection.length == 0 { continue }
                let left = CTLineGetOffsetForStringIndex(line, intersection.location, nil)
                let right = CTLineGetOffsetForStringIndex(line, intersection.location + intersection.length, nil)
                rectangles.append(CGRect(x: left, y: metric.baseline - 30, width: right - left, height: 38))
            }
        }
        wordRects = rectangles
    }
}

public final class Renderer {
    public let width: Int
    public let height: Int
    public let latin: TextLayout
    public let japanese: TextLayout
    private let label: TextLayout
    private let background: CGImage
    private let fit: Fit
    public init(width: Int = 1080, height: Int = 1920) throws {
        self.width = width; self.height = height
        fit = Fit(width: Double(width), height: Double(height))
        latin = try TextLayout(text: Timeline.text, scale: fit.scale)
        japanese = try TextLayout(text: Timeline.japanese, scale: fit.scale)
        label = try TextLayout(text: "iLyric / SYNTHETIC STUDY", size: 13, scale: fit.scale)
        // One static backdrop, blurred before foreground composition. No per-frame GPU readback.
        let ctx = try context(width: 402, height: 874)
        ctx.setFillColor(CGColor(srgbRed: 0.07, green: 0.12, blue: 0.20, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 402, height: 874))
        ctx.setFillColor(CGColor(srgbRed: 0.12, green: 0.50, blue: 0.56, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: -100, y: 180, width: 430, height: 550))
        ctx.setFillColor(CGColor(srgbRed: 0.42, green: 0.20, blue: 0.36, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 150, y: 550, width: 350, height: 320))
        let source = CIImage(cgImage: ctx.makeImage()!)
        let ci = CIContext(options: [.useSoftwareRenderer: true,
                                     .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
                                     .outputColorSpace: colorSpace])
        let blurred = source.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 35]).cropped(to: source.extent)
        guard let result = ci.createCGImage(blurred, from: source.extent, format: .RGBA8, colorSpace: colorSpace) else {
            throw SpikeError.failure("Core Image blur failed")
        }
        background = result
    }
    private func drawImage(_ image: CGImage, in rect: CGRect, context ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        ctx.restoreGState()
    }
    public func draw(_ snapshot: Snapshot, into ctx: CGContext) {
        ctx.saveGState()
        ctx.setFillColor(CGColor(gray: 0.025, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // All layout uses top-left-origin synthetic 402 × 874 logical points.
        ctx.translateBy(x: fit.x, y: Double(height) - fit.y)
        ctx.scaleBy(x: fit.scale, y: -fit.scale)
        drawImage(background, in: CGRect(x: 0, y: 0, width: 402, height: 874), context: ctx)
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.20))
        ctx.fill(CGRect(x: 18, y: 310, width: 366, height: 355))
        // Original artwork: an orbit and a disk, unrelated to any commercial release.
        ctx.setFillColor(CGColor(srgbRed: 0.08, green: 0.18, blue: 0.25, alpha: 1))
        ctx.fill(CGRect(x: 111, y: 100, width: 180, height: 180))
        ctx.setStrokeColor(CGColor(srgbRed: 0.6, green: 0.9, blue: 0.83, alpha: 1))
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: CGRect(x: 125, y: 133, width: 150, height: 95))
        ctx.setFillColor(CGColor(srgbRed: 0.95, green: 0.64, blue: 0.37, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 171, y: 152, width: 61, height: 61))
        drawImage(label.image, in: CGRect(x: 30, y: 36, width: Double(label.image.width) / fit.scale, height: Double(label.image.height) / fit.scale), context: ctx)
        func text(_ layout: TextLayout, y: Double, alpha: Double) {
            ctx.saveGState(); ctx.setAlpha(alpha)
            drawImage(layout.image, in: CGRect(x: 30, y: y, width: Double(layout.image.width) / fit.scale, height: Double(layout.image.height) / fit.scale), context: ctx)
            ctx.restoreGState()
        }
        let latinY = 350 - snapshot.focus * 45
        text(latin, y: latinY, alpha: snapshot.gap ? 0.25 : 0.5 - snapshot.focus * 0.15)
        if !snapshot.gap {
            for (index, rect) in latin.wordRects.enumerated() where index < snapshot.highlights.count {
                ctx.saveGState()
                ctx.clip(to: CGRect(x: 30 + rect.minX, y: latinY + rect.minY,
                                    width: rect.width * snapshot.highlights[index], height: rect.height))
                text(latin, y: latinY, alpha: 1)
                ctx.restoreGState()
            }
        }
        text(japanese, y: 510 - snapshot.focus * 45, alpha: snapshot.gap ? 0.25 : 0.4 + snapshot.focus * 0.6)
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.25))
        ctx.fill(CGRect(x: 40, y: 707, width: 322, height: 3))
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.9))
        ctx.fill(CGRect(x: 40, y: 707, width: 322 * snapshot.media.seconds / 4, height: 3))
        // Independent original placeholder controls, not extracted icons.
        ctx.fill(CGRect(x: 187, y: 755, width: 8, height: 32))
        ctx.fill(CGRect(x: 207, y: 755, width: 8, height: 32))
        for (x, sign) in [(112.0, -1.0), (290.0, 1.0)] {
            ctx.beginPath(); ctx.move(to: CGPoint(x: x + sign * 13, y: 771))
            ctx.addLine(to: CGPoint(x: x - sign * 10, y: 756))
            ctx.addLine(to: CGPoint(x: x - sign * 10, y: 786)); ctx.closePath(); ctx.fillPath()
        }
        ctx.fillEllipse(in: CGRect(x: 341, y: 765, width: 8, height: 8))
        ctx.setFillColor(CGColor(gray: snapshot.marker ? 1 : 0.1, alpha: 1))
        ctx.fill(CGRect(x: 30, y: 823, width: 30, height: 20))
        ctx.restoreGState()
    }
    public func raw(_ snapshot: Snapshot) throws -> Data {
        let ctx = try context(width: width, height: height)
        draw(snapshot, into: ctx)
        return Data(bytes: ctx.data!, count: ctx.bytesPerRow * height)
    }
    public func png(_ snapshot: Snapshot, to url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { throw SpikeError.failure("Output exists") }
        let ctx = try context(width: width, height: height)
        draw(snapshot, into: ctx)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw SpikeError.failure("Cannot open PNG destination")
        }
        CGImageDestinationAddImage(destination, ctx.makeImage()!, nil)
        guard CGImageDestinationFinalize(destination) else { throw SpikeError.failure("PNG write failed") }
    }
}
