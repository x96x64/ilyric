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
        c.saveGState();c.setAlpha(opacity);c.beginTransparencyLayer(in:r.insetBy(dx:0,dy:-2),auxiliaryInfo:nil);c.setBlendMode(.plusLighter)
        // Subpixel placement is the same complementary-weight interpolation in the vertical direction.
        let base=r.minY.rounded(.down),f=r.minY-base,lowRect=CGRect(x:r.minX,y:base,width:r.width,height:r.height)
        for (image,weight) in [(images[low],1-fraction),(images[high],fraction)] where weight>0 {
            c.setAlpha(weight*(1-f));c.draw(image,in:lowRect)
            if f>1e-6 { c.setAlpha(weight*f);c.draw(image,in:lowRect.offsetBy(dx:0,dy:1)) }
        }
        c.setBlendMode(.normal);c.endTransparencyLayer();c.restoreGState()
    }
}
