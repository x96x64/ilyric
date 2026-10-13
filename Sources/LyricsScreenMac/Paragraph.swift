import Foundation
import CoreText
import CoreGraphics
import LyricsScreenCore
import TimelineCore

public struct ParagraphLine: Codable, Equatable {
    public let start, length: Int
    public let width, baseline: Double
    public let breakKind: String
}
private struct Layer {
    let image: CGImage
    let line: Int
    let event: Int?
    var left, right: Double
    var rasterX=0.0, precedingAdvance=0.0, totalAdvance=0.0
}
/// Shape once, cache source-range masks, and render immutable presentation state.
/// This scoped implementation rejects timing boundaries that split shaped clusters.
public final class ParagraphLayout {
    public let input: ParagraphInput
    public let lines: [ParagraphLine]
    public let fonts: [String]
    /// Validate source boundaries against complete-run clusters, without reshaping fragments.
    public static func validateShapedRange(_ start:Int,_ end:Int,boundaries:Set<Int>) throws {
        guard start<end,boundaries.contains(start),boundaries.contains(end) else { throw ScreenError.invalid("Event splits a shaped cluster") }
    }
    private let layers: [Layer]
    private let maskHeight: Int
    /// Fill-front knots along the paragraph's advance: each timed event fills its advance between its times.
    private var frontKnots: [(time: Double, position: Double)] = []
    private var eventStart: [Double] = [], eventAdvance: [Double] = []
    /// Average of the piecewise-linear front over [t - w/2, t + w/2], evaluated exactly from the knots.
    private func smoothedFront(_ t: Double, window w: Double) -> Double {
        let k=frontKnots
        func value(_ x: Double) -> Double {
            if x<=k[0].time { return k[0].position }
            if x>=k[k.count-1].time { return k[k.count-1].position }
            let i=k.lastIndex(where:{$0.time<=x})!,a=k[i],b=k[i+1]
            return b.time>a.time ? a.position+(b.position-a.position)*(x-a.time)/(b.time-a.time) : b.position
        }
        if w<=0 { return value(t) }
        let lo=t-w/2,hi=t+w/2
        var points=[lo]+k.map(\.time).filter { $0>lo && $0<hi }+[hi]
        points.sort()
        var area=0.0
        for (a,b) in zip(points,points.dropLast(0).dropFirst()) where b>a { area+=(value(a)+value(b))/2*(b-a) }
        return area/w
    }
    public init(_ input: ParagraphInput) throws {
        try input.validate(); self.input = input
        let p = input.parameters
        let regular = CTFontCreateUIFontForLanguage(.system,p.size,nil)!
        let font = CTFontCreateCopyWithSymbolicTraits(regular,p.size,nil,.traitBold,.traitBold)!
        let attributed = NSAttributedString(string:input.text,attributes:[
            NSAttributedString.Key(kCTFontAttributeName as String):font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:1,alpha:1)])
        let setter = CTTypesetterCreateWithAttributedString(attributed)
        let height = Int(ceil(p.size*2));maskHeight = height
        var details: [ParagraphLine] = [], storage: [Layer] = [], names = Set<String>(), start = 0
        while start < attributed.length {
            let length = CTTypesetterSuggestLineBreak(setter,start,p.width)
            guard length > 0 else { throw ScreenError.invalid("Unbreakable paragraph") }
            let line = CTTypesetterCreateLine(setter,CFRange(location:start,length:length))
            let width = CTLineGetTypographicBounds(line,nil,nil,nil)-CTLineGetTrailingWhitespaceWidth(line)
            let substring = (input.text as NSString).substring(with:NSRange(location:start,length:length))
            let explicit = substring.hasSuffix("\n")
            let lineIndex = details.count
            details.append(ParagraphLine(start:start,length:length,width:width,baseline:p.size+Double(lineIndex)*p.lineAdvance,
                breakKind:explicit ? (input.breakEvidence == "supplied-explicit-structure" ? "supplied-explicit" : "observed-explicit") : (start+length == attributed.length ? "end" : "automatic")))
            let runs = CTLineGetGlyphRuns(line) as! [CTRun]
            var boundaries = Set([start,start+length])
            for run in runs {
                if input.paragraphStyle?.timed == true && CTRunGetStatus(run).contains(.rightToLeft) {
                    throw ScreenError.invalid("Supplied progressive timing currently supports left-to-right shaped runs only")
                }
                let resolved = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
                if input.paragraphStyle?.timed == true && CTFontGetSymbolicTraits(resolved).contains(.traitColorGlyphs) {
                    throw ScreenError.invalid("Color-glyph progressive support is unqualified; use ordinary LRC or supply outline-font text")
                }
                names.insert(CTFontCopyPostScriptName(resolved) as String)
                var indices = [CFIndex](repeating:0,count:CTRunGetGlyphCount(run))
                CTRunGetStringIndices(run,CFRange(location:0,length:0),&indices)
                boundaries.formUnion(indices)
            }
            if input.paragraphStyle != nil && input.paragraphStyle?.timed != true {
                let context = Self.context(width:Int(ceil(p.width)),height:height)
                context.textPosition = CGPoint(x:0,y:Double(height)-p.size)
                // Draw the complete typeset line; no word-wise or timed-unit shaping.
                CTLineDraw(line,context)
                storage.append(Layer(image:context.makeImage()!,line:lineIndex,event:nil,left:0,right:width))
            }
            for (eventIndex,event) in input.events.enumerated() where event.start < start+length && event.start+event.length > start {
                let timed=input.paragraphStyle?.timed == true
                let a=max(event.start,start),b=min(event.start+event.length,start+length)
                guard (timed || (event.start>=start && event.start+event.length<=start+length)),
                      a<b else {
                    throw ScreenError.invalid("Event splits a shaped cluster or crosses an unsupported line")
                }
                try Self.validateShapedRange(a,b,boundaries:boundaries)
                let inkEnd=explicit ? start+length-1 : start+length
                let supportEnd=min(b,inkEnd)
                if a>=supportEnd { continue }
                let context = Self.context(width:Int(ceil(p.width)),height:height)
                context.textPosition = CGPoint(x:0,y:Double(height)-p.size)
                for run in runs {
                    var indices = [CFIndex](repeating:0,count:CTRunGetGlyphCount(run))
                    CTRunGetStringIndices(run,CFRange(location:0,length:0),&indices)
                    for (glyph,index) in indices.enumerated() where index >= a && index < supportEnd {
                        // Draw the existing shaped glyph, preserving its run position and font.
                        CTRunDraw(run,context,CFRange(location:glyph,length:1))
                    }
                }
                let left = CTLineGetOffsetForStringIndex(line,a,nil)
                let right = CTLineGetOffsetForStringIndex(line,supportEnd,nil)
                guard right > left else { throw ScreenError.invalid("Only inspected left-to-right support is implemented") }
                let image=context.makeImage()!
                if timed {
                    // Crop only cached raster storage; typographic advances remain explicit.
                    let bytes=image.dataProvider!.data! as Data
                    var lo=image.width,hi=0
                    for y in 0..<image.height { for x in 0..<image.width where bytes[y*image.bytesPerRow+x*4+3]>0 { lo=min(lo,x);hi=max(hi,x+1) } }
                    if lo>=hi { lo=max(0,Int(floor(left)));hi=min(image.width,max(lo+1,Int(ceil(right)))) }
                    let cropped=image.cropping(to:CGRect(x:lo,y:0,width:hi-lo,height:image.height))!
                    var layer=Layer(image:cropped,line:lineIndex,event:eventIndex,left:left,right:right)
                    layer.rasterX=Double(lo);storage.append(layer)
                } else { storage.append(Layer(image:image,line:lineIndex,event:eventIndex,left:left,right:right)) }
            }
            start += length
        }
        if input.paragraphStyle != nil {
            // At most four explicit lines are supplied; automatic wrapping of long lines may add more.
            guard (1...8).contains(details.count) else { throw ScreenError.invalid("Paragraph wraps to more than eight lines") }
        } else {
            guard details.count == 2, details[0].breakKind == "observed-explicit" else { throw ScreenError.invalid("Observed two-line structure did not fit") }
        }
        // Require complete source coverage except the explicit separator.
        for i in 0..<attributed.length where (input.paragraphStyle == nil || input.paragraphStyle?.timed == true) && (input.text as NSString).substring(with:NSRange(location:i,length:1)) != "\n" {
            guard input.events.contains(where: { $0.start <= i && i < $0.start+$0.length }) else { throw ScreenError.invalid("Uncovered source range") }
        }
        if input.paragraphStyle?.timed == true {
            for event in input.events.indices {
                let indices=storage.indices.filter { storage[$0].event==event }
                let total=indices.reduce(0.0) { $0+storage[$1].right-storage[$1].left }
                guard total>0 else { throw ScreenError.invalid("Timed segment has no supported visual advance") }
                var preceding=0.0
                for i in indices { storage[i].precedingAdvance=preceding;storage[i].totalAdvance=total;preceding+=storage[i].right-storage[i].left }
            }
        }
        if input.rightAligned == true {
            // Each line moves right by its unused width; fill positions are relative and remain unchanged.
            for k in storage.indices {
                let shift=p.width-details[storage[k].line].width
                storage[k].rasterX+=shift;storage[k].left+=shift;storage[k].right+=shift
            }
        }
        lines = details;fonts = names.sorted();layers = storage
        if input.paragraphStyle?.timed == true {
            var position=0.0
            for (e,event) in input.events.enumerated() {
                let advance=storage.filter { $0.event==e }.reduce(0.0) { $0+$1.right-$1.left }
                eventStart.append(position);eventAdvance.append(advance)
                if let b=event.begin,let f=event.end {
                    let begin=Time(b.numerator,b.denominator).seconds
                    var end=Time(f.numerator,f.denominator).seconds
                    // Bridging lets the fill run on to the next word's start instead of pausing in the gap.
                    if input.motion?.bridgesGaps == true,e+1<input.events.count,let nb=input.events[e+1].begin {
                        end=max(end,Time(nb.numerator,nb.denominator).seconds)
                    }
                    frontKnots.append((begin,position));frontKnots.append((end,position+advance))
                }
                position+=advance
            }
        }
    }
    private static func context(width:Int,height:Int) -> CGContext {
        CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
            space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    }
    public func render(_ state: ParagraphSnapshot, coverage: Bool = false) throws -> CGImage {
        guard state.spans.count == input.events.count,
              zip(state.spans,input.events).allSatisfy({ $0.start == $1.start && $0.length == $1.length }) else {
            throw ScreenError.invalid("Snapshot does not match paragraph")
        }
        let p = input.parameters;let context = Self.context(width:input.canvasWidth,height:input.canvas.height)
        context.interpolationQuality = .none
        for layer in layers {
            let span = layer.event.map { state.spans[$0] }
            // Integer mask translation follows the measured diagnostic raster convention.
            // Typography baselines remain explicit and are not altered by appearance.
            let top = (p.originY+Double(layer.line)*p.lineAdvance+(span?.displacement ?? 0)).rounded()
            let rect = CGRect(x:p.originX+layer.rasterX,y:Double(input.canvas.height)-top-Double(maskHeight),width:Double(layer.image.width),height:Double(maskHeight))
            if layer.event == nil {
                context.saveGState();context.setAlpha(coverage ? 1 : p.dimOpacity)
                context.draw(layer.image,in:rect);context.restoreGState();continue
            }
            guard let span else { throw ScreenError.invalid("Missing presentation range") }
            if !coverage, let appearance = input.appearance {
                // Multiply cached shaped support once; geometry and cluster mapping are unchanged.
                var bytes = [UInt8](layer.image.dataProvider!.data! as Data)
                for x in 0..<layer.image.width {
                    let timed=input.paragraphStyle?.timed == true
                    let position = timed ? (layer.precedingAdvance+layer.rasterX+Double(x)+0.5-layer.left)/layer.totalAdvance : (Double(x)+0.5-layer.left)/(layer.right-layer.left)
                    // Supplied intervals reach exact endpoints; private fitted crossing expansion is not imported.
                    let phase = timed ? span.progress*(1+appearance.softness)-0.5-appearance.softness/2 : span.phase
                    let fraction = timed && span.progress<=0 ? 0 : timed && span.progress>=1 ? 1 : appearance.fraction(position:position,phase:phase)
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
            if !coverage, let motion = input.motion {
                var moving=span
                if motion.smoothing>0 || motion.bridgesGaps,let e=layer.event,!frontKnots.isEmpty,eventAdvance[e]>0 {
                    // A smoothed paragraph front replaces abrupt per-word fills; endpoints remain exact.
                    let front=smoothedFront(state.time.seconds,window:motion.smoothing)
                    moving=SpanPresentation(start:span.start,length:span.length,progress:min(1,max(0,(front-eventStart[e])/eventAdvance[e])),
                        displacement:span.displacement,phase:span.phase,scale:span.scale,glow:span.glow)
                }
                drawMoving(layer,moving,motion,top:p.originY+Double(layer.line)*p.lineAdvance+span.displacement,into:context);continue
            }
            if coverage || span.progress >= 1 { context.draw(layer.image,in:rect);continue }
            if span.progress <= 0 {
                context.saveGState();context.setAlpha(p.dimOpacity);context.draw(layer.image,in:rect);context.restoreGState();continue
            }
            let unbounded = p.originX+layer.left+(input.paragraphStyle?.timed == true ? layer.totalAdvance*span.progress-layer.precedingAdvance : (layer.right-layer.left)*span.progress)
            let boundary=min(Double(input.canvasWidth),max(0,unbounded))
            // Disjoint clips avoid double-compositing antialiased glyph edges.
            context.saveGState();context.clip(to:CGRect(x:0,y:0,width:boundary,height:Double(input.canvas.height)))
            context.draw(layer.image,in:rect);context.restoreGState()
            context.saveGState();context.clip(to:CGRect(x:boundary,y:0,width:Double(input.canvasWidth)-boundary,height:Double(input.canvas.height)))
            context.setAlpha(p.dimOpacity);context.draw(layer.image,in:rect);context.restoreGState()
        }
        return context.makeImage()!
    }
    /// Soft-edged fill, continuous lift, emphasis scale about the ink center, and glow behind filled ink.
    private func drawMoving(_ layer:Layer,_ span:SpanPresentation,_ motion:WordMotion,top:Double,into context:CGContext) {
        let p=input.parameters,width=Double(layer.image.width),height=Double(maskHeight)
        // Nearest-neighbor sampling would snap a slowly scaling word to different pixels each frame.
        let previousQuality=context.interpolationQuality
        context.interpolationQuality = span.scale != 1 ? .high : previousQuality
        defer { context.interpolationQuality=previousQuality }
        let base=CGRect(x:p.originX+layer.rasterX,y:Double(input.canvas.height)-top-height,width:width,height:height)
        // Scale about the ink center so neighboring words keep their positions.
        let rect=CGRect(x:base.midX-width*span.scale/2,y:base.midY-height*span.scale/2,width:width*span.scale,height:height*span.scale)
        // The ramp starts fully before the word and ends fully after it, so endpoints are exact.
        let front=span.progress<=0 ? -Double.infinity : span.progress>=1 ? Double.infinity :
            -motion.edge/2+span.progress*(layer.totalAdvance+motion.edge)-layer.precedingAdvance
        let bytes=(0..<layer.image.width).map { x -> UInt8 in
            let position=layer.rasterX+Double(x)+0.5-layer.left
            let m=motion.edge>0 ? min(1,max(0,(front-position)/motion.edge+0.5)) : (position<front ? 1:0)
            return UInt8((m*255).rounded())
        }
        context.drawSubpixel(layer.image,in:rect,alpha:p.dimOpacity)
        guard bytes.contains(where:{$0>0}) else { return }
        let mask=CGImage(width:layer.image.width,height:1,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:layer.image.width,
            space:CGColorSpaceCreateDeviceGray(),bitmapInfo:[],provider:CGDataProvider(data:Data(bytes) as CFData)!,decode:nil,shouldInterpolate:true,intent:.defaultIntent)!
        if span.glow>0 && motion.glowRadius>0 {
            // Draw only the shadow: the glyphs land outside the canvas and the shadow is offset back.
            let away=Double(input.canvasWidth)*4
            context.saveGState();context.setShadow(offset:CGSize(width:-away,height:0),blur:motion.glowRadius,
                color:CGColor(gray:1,alpha:span.glow*span.progress))
            context.draw(layer.image,in:rect.offsetBy(dx:away,dy:0));context.restoreGState()
        }
        context.saveGState();context.clip(to:rect,mask:mask);context.drawSubpixel(layer.image,in:rect);context.restoreGState()
    }
    public func raw(_ time:Time, coverage:Bool = false) throws -> Data {
        let image = try render(input.evaluate(time),coverage:coverage)
        return image.dataProvider!.data! as Data
    }
}
