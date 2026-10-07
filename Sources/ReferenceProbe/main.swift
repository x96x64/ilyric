// Internal validation probe. Inputs may contain private reference text; outputs
// inherit that classification. No font identity on iPhone is asserted here.
import Foundation
import CoreText
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import RenderMac
import SpikeCore

struct Motion: Decodable {
    let model: String
    let onset, duration, offset, amplitude: Double
    func position(_ time: Time) throws -> Double {
        guard duration > 0 else { throw SpikeError.failure("Invalid fitted duration") }
        let u = max(0, (time.seconds - onset) / duration)
        let progress: Double
        switch model {
        case "hermite": let v = min(1, u); progress = v * v * (3 - 2 * v)
        case "critical": progress = 1 - (1 + u) * exp(-u)
        default: throw SpikeError.failure("Unknown fitted model")
        }
        return offset + amplitude * progress
    }
}
struct Input: Decodable {
    let text: String
    let width, size, lineAdvance: Double
    let font: String // "spike" exercises the unchanged renderer; "system-bold" is a candidate.
    let alignment: String?
    let numerator, denominator: Int64?
    let motion: Motion?
    let anchorOffset: Double?
    let fontSelection: String? // Public UI font API: symbolic-bold (default) or emphasized.
    let language: String?
    let opticalSize: String? // auto, none, or a positive numeric point size.
    let weight: Double? // Public normalized Core Text weight trait, -1 ... 1.
}
struct RunMetric: Encodable {
    let start, length, glyphCount: Int
    let font: String
    let size: Double
    let weight: Double?
    let matrix: [Double]
}
struct LineDetail: Encodable {
    let originX, ascent, descent, leading: Double
    let glyphPathBounds: [Double] // Baseline-relative, Core Text y-up coordinates.
    let breakKind: String // Observed input structure, not native source semantics.
    let runs: [RunMetric]
}
struct Metric: Encodable {
    let start, length: Int
    let width, baseline: Double
    var detail: LineDetail? = nil
}
struct Result: Encodable {
    let status: String
    let fonts: [String]
    let lines: [Metric]
    let timestampNumerator, timestampDenominator: Int64
    let fittedY: Double?
}
// Foundation may leave a nonexistent descendant under a different macOS path
// alias than its existing parent. Resolve the parent before appending new names.
func canonicalURL(_ url: URL) -> URL {
    if FileManager.default.fileExists(atPath: url.path) {
        return url.resolvingSymlinksInPath()
    }
    let parent = url.deletingLastPathComponent()
    guard parent.path != url.path else { return url.standardizedFileURL }
    return canonicalURL(parent).appendingPathComponent(url.lastPathComponent, isDirectory: url.hasDirectoryPath)
}

do {
    let args = CommandLine.arguments
    if args.count != 3 { throw SpikeError.failure("Usage: ReferenceProbe input.json output-directory") }
    let repository = canonicalURL(URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    let inputURL = canonicalURL(URL(fileURLWithPath: args[1]))
    let output = canonicalURL(URL(fileURLWithPath: args[2], isDirectory: true))
    let allowed = ["reference-private", "artifacts"].contains { directory in
        let prefix = repository.appendingPathComponent(directory).path + "/"
        return inputURL.path.hasPrefix(prefix) && output.path.hasPrefix(prefix)
    }
    guard allowed else {
        throw SpikeError.failure("Run from the repository root; keep inputs and outputs together under reference-private or artifacts")
    }
    let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf: inputURL))
    guard input.width > 0, input.width <= 4096, input.size > 0, input.size <= 512,
          input.lineAdvance > 0, input.text.utf16.count < 10000,
          (input.denominator ?? 1) > 0, (input.numerator ?? 0) != Int64.min else {
        throw SpikeError.failure("Invalid probe input")
    }
    let time = Time(input.numerator ?? 0, input.denominator ?? 1)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let image: CGImage
    let metrics: [Metric]
    let fonts: [String]
    if input.font == "spike" {
        // Reference coordinates are pixels. The scale factor of three is an explicit
        // experimental hypothesis, not measured UIKit point metadata.
        let layout = try TextLayout(text: input.text, width: input.width / 3, size: input.size / 3, scale: 3)
        image = layout.image; fonts = layout.fonts
        metrics = layout.metrics.map { Metric(start: $0.start, length: $0.length, width: $0.width * 3, baseline: $0.baseline * 3) }
    } else {
        guard input.font == "system-bold" else { throw SpikeError.failure("Unknown candidate font") }
        let selection = input.fontSelection ?? "symbolic-bold"
        guard ["symbolic-bold", "emphasized"].contains(selection),
              [nil, "left", "right"].contains(input.alignment),
              input.weight.map({ $0.isFinite && (-1...1).contains($0) }) ?? true else {
            throw SpikeError.failure("Invalid calibration configuration")
        }
        let regular = CTFontCreateUIFontForLanguage(selection == "emphasized" ? .emphasizedSystem : .system,
                                                    input.size, input.language as CFString?)!
        var font = selection == "emphasized" ? regular :
            CTFontCreateCopyWithSymbolicTraits(regular, input.size, nil, .traitBold, .traitBold)!
        var attributes: [CFString: Any] = [:]
        if let optical = input.opticalSize {
            if ["auto", "none"].contains(optical) { attributes[kCTFontOpticalSizeAttribute] = optical }
            else if let value = Double(optical), value.isFinite, value > 0 {
                attributes[kCTFontOpticalSizeAttribute] = value
            } else { throw SpikeError.failure("Invalid optical size") }
        }
        if let weight = input.weight { attributes[kCTFontTraitsAttribute] = [kCTFontWeightTrait: weight] }
        if !attributes.isEmpty {
            font = CTFontCreateCopyWithAttributes(font, input.size, nil,
                CTFontDescriptorCreateWithAttributes(attributes as CFDictionary))
        }
        let attributed = NSAttributedString(string: input.text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1)
        ])
        let setter = CTTypesetterCreateWithAttributedString(attributed)
        var lines: [(CTLine, Metric)] = []; var names = Set<String>(); var start = 0
        while start < attributed.length {
            let length = CTTypesetterSuggestLineBreak(setter, start, input.width)
            guard length > 0 else { throw SpikeError.failure("Unbreakable input") }
            let line = CTTypesetterCreateLine(setter, CFRange(location: start, length: length))
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading) - CTLineGetTrailingWhitespaceWidth(line)
            let x = input.alignment == "right" ? input.width - width : 0
            let pathBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            var runs: [RunMetric] = []
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                let attrs = CTRunGetAttributes(run) as NSDictionary
                let resolved = attrs[kCTFontAttributeName] as! CTFont
                let name = CTFontCopyPostScriptName(resolved) as String
                names.insert(name)
                let range = CTRunGetStringRange(run), matrix = CTFontGetMatrix(resolved)
                let traits = CTFontCopyTraits(resolved) as NSDictionary
                runs.append(RunMetric(start: range.location, length: range.length,
                    glyphCount: CTRunGetGlyphCount(run), font: name, size: CTFontGetSize(resolved),
                    weight: (traits[kCTFontWeightTrait] as? NSNumber)?.doubleValue,
                    matrix: [matrix.a, matrix.b, matrix.c, matrix.d, matrix.tx, matrix.ty]))
            }
            let substring = (input.text as NSString).substring(with: NSRange(location: start, length: length))
            let breakKind = substring.last.map({ "\n\r\u{2028}\u{2029}".contains($0) }) == true ? "explicit" :
                (start + length == attributed.length ? "end" : "automatic")
            lines.append((line, Metric(start: start, length: length, width: width,
                baseline: input.size + Double(lines.count) * input.lineAdvance,
                detail: LineDetail(originX: x, ascent: ascent, descent: descent, leading: leading,
                    glyphPathBounds: [pathBounds.minX, pathBounds.minY, pathBounds.maxX, pathBounds.maxY],
                    breakKind: breakKind, runs: runs))))
            start += length
        }
        fonts = names.sorted(); metrics = lines.map(\.1)
        let height = Int(ceil(input.size * 2 + Double(lines.count) * input.lineAdvance))
        guard height <= 16384 else { throw SpikeError.failure("Probe image too tall") }
        let ctx = CGContext(data: nil, width: Int(ceil(input.width)), height: height, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for (line, metric) in lines {
            let x = input.alignment == "right" ? input.width - metric.width : 0
            ctx.textPosition = CGPoint(x: x, y: Double(height) - metric.baseline)
            CTLineDraw(line, ctx)
        }
        image = ctx.makeImage()!
    }
    if let motion = input.motion {
        // Explicit native-space reconstruction. The supplied local anchor offset
        // registers the shaped text to the measured edge-centroid trajectory.
        let y = try motion.position(time) - (input.anchorOffset ?? 0)
        let canvas = CGContext(data: nil, width: 1179, height: 2556, bitsPerComponent: 8,
                               bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        canvas.draw(image, in: CGRect(x: 96, y: 2556 - y - Double(image.height),
                                     width: Double(image.width), height: Double(image.height)))
        let sceneDestination = CGImageDestinationCreateWithURL(output.appendingPathComponent("scene.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(sceneDestination, canvas.makeImage()!, nil)
        guard CGImageDestinationFinalize(sceneDestination) else { throw SpikeError.failure("Scene write failed") }
    }
    let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent("text.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw SpikeError.failure("PNG write failed") }
    let result = Result(status: "rendered", fonts: fonts, lines: metrics,
                        timestampNumerator: time.numerator, timestampDenominator: time.denominator,
                        fittedY: try input.motion?.position(time))
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(result).write(to: output.appendingPathComponent("metrics.json"))

} catch {
    FileHandle.standardError.write(Data("ReferenceProbe: \(error)\n".utf8))
    exit(1)
}
