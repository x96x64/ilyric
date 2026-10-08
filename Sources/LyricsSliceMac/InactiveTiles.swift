import Foundation
import CoreGraphics
import CoreImage

/// Finite isolated paragraph tiles. No control or background pixels enter blur.
/// All integer-radius kernels are evaluated once, outside frame evaluation.
final class InactiveTiles {
    let images: [CGImage]
    let bounds: CGRect
    init(_ source: CGImage) {
        let bytes=[UInt8](source.dataProvider!.data! as Data),w=source.width,h=source.height
        var x0=w,y0=h,x1=0,y1=0
        for y in 0..<h { for x in 0..<w where bytes[y*source.bytesPerRow+x*4+3]>0 {
            x0=min(x0,x);y0=min(y0,y);x1=max(x1,x+1);y1=max(y1,y+1)
        }}
        x0=max(0,x0-40);y0=max(0,y0-40);x1=min(w,max(x0+1,x1+40));y1=min(h,max(y0+1,y1+40))
        let cropped=source.cropping(to:CGRect(x:x0,y:y0,width:x1-x0,height:y1-y0))!
        bounds=CGRect(x:x0,y:h-y1,width:x1-x0,height:y1-y0)
        let context=CIContext(options:[.useSoftwareRenderer:true,.workingColorSpace:CGColorSpace(name:CGColorSpace.sRGB)!])
        let image=CIImage(cgImage:cropped)
        images=(0...8).map { radius in
            if radius==0 { return cropped }
            return context.createCGImage(image.applyingGaussianBlur(sigma:Double(radius)),from:image.extent,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!)!
        }
    }
    func draw(_ blur: Double, opacity: Double, translation: Double, into c: CGContext) {
        let low=Int(floor(blur)),high=min(8,low+1),fraction=blur-Double(low)
        let r=bounds.offsetBy(dx:0,dy:-translation)
        // Additive accumulation preserves a convex interpolation of premultiplied
        // masks; ordinary source-over would darken overlapping intermediate tiles.
        c.saveGState();c.setAlpha(opacity);c.beginTransparencyLayer(auxiliaryInfo:nil);c.setBlendMode(.plusLighter)
        c.setAlpha(1-fraction);c.draw(images[low],in:r)
        if fraction>0 { c.setAlpha(fraction);c.draw(images[high],in:r) }
        c.setBlendMode(.normal);c.endTransparencyLayer();c.restoreGState()
    }
}
