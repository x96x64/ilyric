import Foundation
import AppKit
import CoreGraphics
import LyricsSliceCore

/// Resolves SF Symbols through public AppKit APIs at runtime and caches alpha masks.
/// No symbol data is stored in the repository or written except as pixels of the requested output.
final class SystemSymbols {
    private struct Mask { let image: CGImage; let inkCenter: CGPoint }
    private var cache: [String:Mask] = [:]

    private func mask(_ s: ControlSymbol) throws -> Mask {
        let key="\(s.name)|\(s.pointSize)|\(s.weight.rawValue)"
        if let m=cache[key] { return m }
        let weight: NSFont.Weight = switch s.weight { case .regular: .regular; case .medium: .medium; case .semibold: .semibold }
        // Render at native pixels: point size × 3, matching the reference display scale.
        guard let symbol=NSImage(systemSymbolName:s.name,accessibilityDescription:nil)?
                .withSymbolConfiguration(.init(pointSize:s.pointSize*ControlSymbols.nativeScale,weight:weight)) else {
            throw SliceError.invalid("System symbol \(s.name) is unavailable on this Mac")
        }
        var rect=NSRect(origin:.zero,size:symbol.size)
        guard let source=symbol.cgImage(forProposedRect:&rect,context:nil,hints:[.ctm:AffineTransform.identity]) else {
            throw SliceError.invalid("System symbol \(s.name) could not be rasterized")
        }
        let w=source.width,h=source.height
        let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,
                        bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(source,in:CGRect(x:0,y:0,width:w,height:h))
        // Tint to opaque white and locate ink bounds (alpha > 50%) for measured-center placement.
        c.setBlendMode(.sourceIn);c.setFillColor(CGColor(gray:1,alpha:1));c.fill(CGRect(x:0,y:0,width:w,height:h))
        let d=c.data!.assumingMemoryBound(to:UInt8.self);var x0=w,y0=h,x1=0,y1=0
        for y in 0..<h { for x in 0..<w where d[(y*w+x)*4+3]>127 { x0=min(x0,x);y0=min(y0,y);x1=max(x1,x+1);y1=max(y1,y+1) } }
        guard x1>x0,y1>y0 else { throw SliceError.invalid("System symbol \(s.name) has no ink") }
        // Bitmap rows run top to bottom in memory; convert to a bottom-left-origin center.
        let m=Mask(image:c.makeImage()!,inkCenter:CGPoint(x:Double(x0+x1)/2,y:Double(h)-Double(y0+y1)/2))
        cache[key]=m
        return m
    }

    /// Draws into a native canvas whose CoreGraphics origin is bottom-left with height `canvasHeight`.
    func draw(_ s: ControlSymbol, canvasHeight: Double, into c: CGContext) throws {
        let m=try mask(s),center=CGPoint(x:s.centerX,y:canvasHeight-s.centerY)
        let origin=CGPoint(x:center.x-m.inkCenter.x,y:center.y-m.inkCenter.y)
        let glyph=CGRect(origin:origin,size:CGSize(width:m.image.width,height:m.image.height))
        c.saveGState();c.beginTransparencyLayer(auxiliaryInfo:nil)
        if let d=s.disc {
            c.setFillColor(CGColor(gray:1,alpha:s.discOpacity))
            c.fillEllipse(in:CGRect(x:center.x-d/2,y:center.y-d/2,width:d,height:d))
        }
        if s.knockout { c.setBlendMode(.destinationOut) } else { c.setAlpha(s.opacity) }
        c.draw(m.image,in:glyph)
        c.endTransparencyLayer();c.restoreGState()
    }
}
