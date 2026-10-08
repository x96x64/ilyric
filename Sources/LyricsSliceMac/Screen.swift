import Foundation
import CoreGraphics
import CoreText
import LyricsSliceCore
import SpikeCore

/// Original assets and fixed component ordering. No system assets or native chrome.
public final class ScreenRenderer {
    public let screen: LyricsScreen
    public let lyrics: CompositionRenderer
    private let backdrop, artwork, fadeMask: CGImage
    private let title: CTLine
    private let artist: CTLine
    public init(_ screen: LyricsScreen) throws {
        self.screen=screen; lyrics=try CompositionRenderer(screen.composition)
        title=Self.line(screen.title,size:51,bold:true); artist=Self.line(screen.artist,size:49,bold:false)
        // Palette shared by the original artwork and background; no source artwork.
        let colors=[CGColor(srgbRed:0.12,green:0.21,blue:0.25,alpha:1),CGColor(srgbRed:0.29,green:0.23,blue:0.35,alpha:1),CGColor(srgbRed:0.16,green:0.12,blue:0.24,alpha:1)]
        let bg=Self.context(screen.composition.canvasWidth,2556)
        let gradient=CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB),colors:colors as CFArray,locations:[0,0.45,1])!
        bg.drawLinearGradient(gradient,start:CGPoint(x:0,y:2556),end:CGPoint(x:1179,y:0),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
        backdrop=bg.makeImage()!
        let art=Self.context(216,216)
        art.drawLinearGradient(gradient,start:.zero,end:CGPoint(x:216,y:216),options:[])
        art.setFillColor(CGColor(srgbRed:0.94,green:0.70,blue:0.45,alpha:1)); art.fillEllipse(in:CGRect(x:118,y:111,width:58,height:58))
        art.setStrokeColor(CGColor(srgbRed:0.54,green:0.79,blue:0.81,alpha:0.9));art.setLineWidth(9)
        for y in [38.0,62,86] { art.move(to:CGPoint(x:-10,y:y));art.addCurve(to:CGPoint(x:226,y:y+12),control1:CGPoint(x:62,y:y+70),control2:CGPoint(x:154,y:y-55));art.strokePath() }
        artwork=art.makeImage()!
        let bytes=(0..<2556).map { UInt8((LyricsScreen.fade(at:Double($0)+0.5)*255).rounded()) }
        fadeMask=CGImage(width:1,height:2556,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:1,
            space:CGColorSpaceCreateDeviceGray(),bitmapInfo:[],provider:CGDataProvider(data:Data(bytes) as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
    }
    private static func context(_ w:Int,_ h:Int) -> CGContext {
        CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    }
    private static func line(_ text:String,size:Double,bold:Bool) -> CTLine {
        let regular=CTFontCreateUIFontForLanguage(.system,size,nil)!
        let font=bold ? CTFontCreateCopyWithSymbolicTraits(regular,size,nil,.traitBold,.traitBold)! : regular
        return CTLineCreateWithAttributedString(NSAttributedString(string:text,attributes:[
            NSAttributedString.Key(kCTFontAttributeName as String):font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:1,alpha:1)]))
    }
    private func rect(_ b:ScreenBounds) -> CGRect { CGRect(x:b.x,y:2556-b.y-b.height,width:b.width,height:b.height) }
    private func ink(_ line:CTLine,_ b:ScreenBounds,_ c:CGContext,alpha:Double=1,right:Bool=false) {
        c.saveGState();c.setAlpha(alpha);c.textMatrix = .identity;c.textPosition = .zero
        let bounds=CTLineGetImageBounds(line,c)
        c.textPosition=CGPoint(x:(right ? b.x+b.width-bounds.width : b.x)-bounds.minX,y:2556-b.y-bounds.maxY)
        CTLineDraw(line,c);c.restoreGState()
    }
    public func lyricLayer(_ state:CompositionSnapshot) throws -> CGImage {
        let w=screen.composition.canvasWidth,c=Self.context(w,2556),v=LyricsScreen.viewport
        c.clip(to:rect(v));c.clip(to:CGRect(x:0,y:0,width:w,height:2556),mask:fadeMask)
        for p in state.paragraphs {
            let image=try lyrics.paragraphs[p.index].render(p.appearance)
            c.saveGState();c.setAlpha(p.opacity);c.draw(image,in:CGRect(x:0,y:-p.translationY,width:Double(w),height:2556));c.restoreGState()
        }
        return c.makeImage()!
    }
    public func native(_ state:ScreenSnapshot) throws -> CGImage {
        let c=Self.context(screen.composition.canvasWidth,2556)
        for part in state.components.sorted(by:{$0.z<$1.z}) where part.visible {
            c.saveGState();let r=rect(part.bounds)
            if part.clips { c.clip(to:r) }
            c.setFillColor(CGColor(gray:1,alpha:0.9));c.setStrokeColor(CGColor(gray:1,alpha:0.85));c.setLineWidth(5)
            switch part.part {
            case .background: c.draw(backdrop,in:r)
            case .lyrics: c.draw(try lyricLayer(state.lyrics),in:CGRect(x:0,y:0,width:screen.composition.canvasWidth,height:2556))
            case .artwork:
                c.addPath(CGPath(roundedRect:r,cornerWidth:14,cornerHeight:14,transform:nil));c.clip();c.draw(artwork,in:r)
            case .title: ink(title,part.bounds,c)
            case .artist: ink(artist,part.bounds,c,alpha:0.6)
            case .handle: rounded(r,6,c,alpha:0.4)
            case .progress,.volume:
                rounded(r,r.height/2,c,alpha:0.22)
                c.saveGState();c.clip(to:CGRect(x:r.minX,y:r.minY,width:r.width*(part.part == .progress ? state.progress:state.volume),height:r.height))
                rounded(r,r.height/2,c,alpha:0.75);c.restoreGState()
            case .elapsed,.remaining:
                let value=part.part == .elapsed ? state.elapsed:state.remaining
                let label=(part.part == .remaining ? "−":"")+String(format:"%d:%02d",value/60,value%60)
                ink(Self.line(label,size:35,bold:false),part.bounds,c,alpha:0.55,right:part.part == .remaining)
            case .playback:
                if state.playing {
                    rounded(CGRect(x:r.midX-25,y:r.midY-34,width:17,height:68),3,c,alpha:0.95)
                    rounded(CGRect(x:r.midX+8,y:r.midY-34,width:17,height:68),3,c,alpha:0.95)
                } else { triangle(r.midX-20,r.midY,55,70,c) }
            case .previous,.next:
                c.translateBy(x:r.midX,y:r.midY); if part.part == .previous { c.scaleBy(x:-1,y:1) }
                triangle(-43,0,40,48,c);triangle(-2,0,40,48,c)
            case .translation,.singCompact,.singExpanded:
                rounded(r,part.part == .singExpanded ? 48:42,c,alpha:0.14)
                if part.part == .translation { ink(Self.line("Aa",size:31,bold:true),.init(part.bounds.x+17,part.bounds.y+26,60,40),c) }
                else {
                    rounded(CGRect(x:r.midX-9,y:r.midY-18,width:18,height:40),9,c,alpha:0.85)
                    c.move(to:CGPoint(x:r.midX-18,y:r.midY+2));c.addLine(to:CGPoint(x:r.midX-18,y:r.midY-25));c.addLine(to:CGPoint(x:r.midX+18,y:r.midY-25));c.addLine(to:CGPoint(x:r.midX+18,y:r.midY+2));c.strokePath()
                }
            case .bottomLeft:
                c.stroke(r.insetBy(dx:12,dy:15));c.move(to:CGPoint(x:r.minX+22,y:r.minY+24));c.addLine(to:CGPoint(x:r.maxX-22,y:r.minY+24));c.strokePath()
            case .bottomCenter:
                c.strokeEllipse(in:r.insetBy(dx:17,dy:17));c.strokeEllipse(in:r.insetBy(dx:5,dy:5))
            case .bottomRight:
                for y in [-18.0,0,18] { c.move(to:CGPoint(x:r.minX+12,y:r.midY+y));c.addLine(to:CGPoint(x:r.maxX-12,y:r.midY+y));c.strokePath() }
            case .volumeLow,.volumeHigh:
                triangle(r.minX+7,r.midY,22,26,c)
                if part.part == .volumeHigh { c.strokeEllipse(in:r.insetBy(dx:2,dy:7)) }
            }
            c.restoreGState()
        }
        return c.makeImage()!
    }
    private func rounded(_ r:CGRect,_ radius:Double,_ c:CGContext,alpha:Double) {
        c.setFillColor(CGColor(gray:1,alpha:alpha));c.addPath(CGPath(roundedRect:r,cornerWidth:radius,cornerHeight:radius,transform:nil));c.fillPath()
    }
    private func triangle(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ c:CGContext) {
        c.move(to:CGPoint(x:x,y:y-h/2));c.addLine(to:CGPoint(x:x+w,y:y));c.addLine(to:CGPoint(x:x,y:y+h/2));c.closePath();c.fillPath()
    }
    public func draw(_ time:Time,into c:CGContext) throws {
        let w=Double(c.width),h=Double(c.height),fit=LyricsScreen.contain(width:w,height:h,canvasWidth:screen.composition.canvasWidth)
        c.setFillColor(CGColor(gray:0,alpha:1));c.fill(CGRect(x:0,y:0,width:w,height:h));c.interpolationQuality = .high
        c.draw(try native(screen.evaluate(time)),in:CGRect(x:fit.x,y:fit.y,width:fit.width,height:fit.height))
        // Existing audiovisual diagnostic marker, separate from native scene content.
        let t=Time(time.numerator % (4*time.denominator),time.denominator)
        if Timeline.markerTimes.contains(where:{t >= $0 && t < $0+Time(1,20)}) {
            let marker=Fit(width:w,height:h);c.setFillColor(CGColor(gray:1,alpha:1))
            c.fill(CGRect(x:marker.x+35*marker.scale,y:h-843*marker.scale,width:20*marker.scale,height:20*marker.scale))
        }
    }
    public func frame(_ time:Time) throws -> CGImage {
        let c=Self.context(1080,1920);try draw(time,into:c);return c.makeImage()!
    }
}
