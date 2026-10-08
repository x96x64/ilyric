import Foundation
import CoreText
import CoreGraphics
import LyricsSliceCore
import SpikeCore

public struct SliceLine: Codable, Equatable {
    public let start, length: Int
    public let width, baseline: Double
    public let breakKind: String
}
private struct Layer {
    let image: CGImage
    let line, event: Int
    let left, right: Double
}
/// Shape once, cache source-range masks, and render immutable presentation state.
/// This scoped implementation rejects timing boundaries that split shaped clusters.
public final class SliceParagraph {
    public let input: SliceInput
    public let lines: [SliceLine]
    public let fonts: [String]
    private let layers: [Layer]
    private let maskHeight: Int
    public init(_ input: SliceInput) throws {
        try input.validate(); self.input = input
        let p = input.parameters
        let regular = CTFontCreateUIFontForLanguage(.system,p.size,nil)!
        let font = CTFontCreateCopyWithSymbolicTraits(regular,p.size,nil,.traitBold,.traitBold)!
        let attributed = NSAttributedString(string:input.text,attributes:[
            NSAttributedString.Key(kCTFontAttributeName as String):font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:1,alpha:1)])
        let setter = CTTypesetterCreateWithAttributedString(attributed)
        let height = Int(ceil(p.size*2));maskHeight = height
        var details: [SliceLine] = [], storage: [Layer] = [], names = Set<String>(), start = 0
        while start < attributed.length {
            let length = CTTypesetterSuggestLineBreak(setter,start,p.width)
            guard length > 0 else { throw SliceError.invalid("Unbreakable paragraph") }
            let line = CTTypesetterCreateLine(setter,CFRange(location:start,length:length))
            let width = CTLineGetTypographicBounds(line,nil,nil,nil)-CTLineGetTrailingWhitespaceWidth(line)
            let substring = (input.text as NSString).substring(with:NSRange(location:start,length:length))
            let explicit = substring.hasSuffix("\n")
            let lineIndex = details.count
            details.append(SliceLine(start:start,length:length,width:width,baseline:p.size+Double(lineIndex)*p.lineAdvance,
                breakKind:explicit ? "observed-explicit" : "end"))
            let runs = CTLineGetGlyphRuns(line) as! [CTRun]
            var boundaries = Set([start,start+length])
            for run in runs {
                let resolved = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
                names.insert(CTFontCopyPostScriptName(resolved) as String)
                var indices = [CFIndex](repeating:0,count:CTRunGetGlyphCount(run))
                CTRunGetStringIndices(run,CFRange(location:0,length:0),&indices)
                boundaries.formUnion(indices)
            }
            for (eventIndex,event) in input.events.enumerated() where event.start < start+length && event.start+event.length > start {
                guard event.start >= start, event.start+event.length <= start+length,
                      boundaries.contains(event.start), boundaries.contains(event.start+event.length) else {
                    throw SliceError.invalid("Event splits a shaped cluster or crosses a line")
                }
                let context = Self.context(width:Int(ceil(p.width)),height:height)
                context.textPosition = CGPoint(x:0,y:Double(height)-p.size)
                for run in runs {
                    var indices = [CFIndex](repeating:0,count:CTRunGetGlyphCount(run))
                    CTRunGetStringIndices(run,CFRange(location:0,length:0),&indices)
                    for (glyph,index) in indices.enumerated() where index >= event.start && index < event.start+event.length {
                        // Draw the existing shaped glyph, preserving its run position and font.
                        CTRunDraw(run,context,CFRange(location:glyph,length:1))
                    }
                }
                let left = CTLineGetOffsetForStringIndex(line,event.start,nil)
                let right = CTLineGetOffsetForStringIndex(line,event.start+event.length,nil)
                guard right > left else { throw SliceError.invalid("Only inspected left-to-right support is implemented") }
                storage.append(Layer(image:context.makeImage()!,line:lineIndex,event:eventIndex,left:left,right:right))
            }
            start += length
        }
        guard details.count == 2, details[0].breakKind == "observed-explicit" else { throw SliceError.invalid("Observed two-line structure did not fit") }
        // Require complete source coverage except the explicit separator.
        for i in 0..<attributed.length where (input.text as NSString).substring(with:NSRange(location:i,length:1)) != "\n" {
            guard input.events.contains(where: { $0.start <= i && i < $0.start+$0.length }) else { throw SliceError.invalid("Uncovered source range") }
        }
        lines = details;fonts = names.sorted();layers = storage
    }
    private static func context(width:Int,height:Int) -> CGContext {
        CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
            space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    }
    public func render(_ state: SliceSnapshot, coverage: Bool = false) throws -> CGImage {
        guard state.spans.count == input.events.count,
              zip(state.spans,input.events).allSatisfy({ $0.start == $1.start && $0.length == $1.length }) else {
            throw SliceError.invalid("Snapshot does not match paragraph")
        }
        let p = input.parameters;let context = Self.context(width:input.canvasWidth,height:2556)
        context.interpolationQuality = .none
        for layer in layers {
            let span = state.spans[layer.event]
            // Integer mask translation follows the measured diagnostic raster convention.
            // Typography baselines remain explicit and are not altered by appearance.
            let top = (p.originY+Double(layer.line)*p.lineAdvance+span.displacement).rounded()
            let rect = CGRect(x:p.originX,y:2556-top-Double(maskHeight),width:Double(layer.image.width),height:Double(maskHeight))
            if !coverage, let appearance = input.appearance {
                // Multiply cached shaped support once; geometry and cluster mapping are unchanged.
                var bytes = [UInt8](layer.image.dataProvider!.data! as Data)
                for x in 0..<layer.image.width {
                    let position = (Double(x)+0.5-layer.left)/(layer.right-layer.left)
                    let fraction = appearance.fraction(position:position,phase:span.phase)
                    let opacity = p.dimOpacity+(appearance.completedOpacity-p.dimOpacity)*fraction
                    for y in 0..<layer.image.height {
                        let offset = y*layer.image.bytesPerRow+x*4
                        for channel in 0..<4 { bytes[offset+channel] = UInt8((Double(bytes[offset+channel])*opacity).rounded()) }
                    }
                }
                let provider = CGDataProvider(data:Data(bytes) as CFData)!
                let image = CGImage(width:layer.image.width,height:layer.image.height,bitsPerComponent:8,bitsPerPixel:32,
                    bytesPerRow:layer.image.bytesPerRow,space:CGColorSpace(name:CGColorSpace.sRGB)!,
                    bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,
                    decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
                context.draw(image,in:rect);continue
            }
            if coverage || span.progress >= 1 { context.draw(layer.image,in:rect);continue }
            if span.progress <= 0 {
                context.saveGState();context.setAlpha(p.dimOpacity);context.draw(layer.image,in:rect);context.restoreGState();continue
            }
            let boundary = p.originX+layer.left+(layer.right-layer.left)*span.progress
            // Disjoint clips avoid double-compositing antialiased glyph edges.
            context.saveGState();context.clip(to:CGRect(x:0,y:0,width:boundary,height:2556))
            context.draw(layer.image,in:rect);context.restoreGState()
            context.saveGState();context.clip(to:CGRect(x:boundary,y:0,width:Double(input.canvasWidth)-boundary,height:2556))
            context.setAlpha(p.dimOpacity);context.draw(layer.image,in:rect);context.restoreGState()
        }
        return context.makeImage()!
    }
    public func raw(_ time:Time, coverage:Bool = false) throws -> Data {
        let image = try render(input.evaluate(time),coverage:coverage)
        return image.dataProvider!.data! as Data
    }
}
