import Foundation
import CoreGraphics
import LyricsSliceCore
import SpikeCore

/// Minimal ordered paragraph compositor, not a generalized scene graph.
public final class CompositionRenderer {
    public let composition: LyricsComposition
    public let paragraphs: [SliceParagraph]
    public let viewport = CGRect(x:72,y:550,width:1040,height:1000) // Synthetic clip, not measured safe area.
    public init(_ composition: LyricsComposition) throws {
        self.composition=composition;paragraphs=try composition.paragraphs.map { try SliceParagraph($0.input) }
    }
    /// Native top-left paragraph transforms, in fixed source order.
    public func native(_ state: CompositionSnapshot, transparent: Bool = false) throws -> CGImage {
        let width=composition.canvasWidth,height=2556
        let c=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
            space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        if !transparent { c.setFillColor(CGColor(srgbRed:0.08,green:0.10,blue:0.14,alpha:1));c.fill(CGRect(x:0,y:0,width:width,height:height)) }
        c.saveGState();c.clip(to:CGRect(x:viewport.minX,y:2556-viewport.maxY,width:viewport.width,height:viewport.height))
        for p in state.paragraphs {
            let image=try paragraphs[p.index].render(p.appearance)
            c.saveGState();c.setAlpha(p.opacity)
            c.draw(image,in:CGRect(x:0,y:-p.translationY,width:Double(width),height:2556));c.restoreGState()
        }
        c.restoreGState();return c.makeImage()!
    }
    public func draw(_ time: Time, into context: CGContext) throws {
        let width=Double(context.width),height=Double(context.height)
        context.setFillColor(CGColor(gray:0,alpha:1));context.fill(CGRect(x:0,y:0,width:width,height:height))
        let scale=min(width/Double(composition.canvasWidth),height/2556)
        let image=try native(composition.evaluate(time))
        context.interpolationQuality = .high
        context.draw(image,in:CGRect(x:(width-Double(image.width)*scale)/2,y:(height-2556*scale)/2,width:Double(image.width)*scale,height:2556*scale))
        // Reuse the existing output-space audiovisual test marker. It is not native UI.
        let t=Time(time.numerator % (4*time.denominator),time.denominator)
        if Timeline.markerTimes.contains(where:{t >= $0 && t < $0+Time(1,20)}) {
            let fit=Fit(width:width,height:height)
            context.setFillColor(CGColor(gray:1,alpha:1))
            context.fill(CGRect(x:fit.x+35*fit.scale,y:height-843*fit.scale,width:20*fit.scale,height:20*fit.scale))
        }
    }
    public func frame(_ time: Time) throws -> CGImage {
        let c=CGContext(data:nil,width:1080,height:1920,bitsPerComponent:8,bytesPerRow:4320,
            space:CGColorSpace(name:CGColorSpace.itur_709)!,bitmapInfo:CGBitmapInfo.byteOrder32Little.rawValue|CGImageAlphaInfo.premultipliedFirst.rawValue)!
        try draw(time,into:c);return c.makeImage()!
    }
}
