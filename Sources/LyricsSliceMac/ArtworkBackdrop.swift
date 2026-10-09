import Foundation
import CoreGraphics
import CoreImage
import LyricsSliceCore
import SpikeCore

/// Renders `ArtworkBackground` at reduced resolution with software Core Image.
/// Each frame depends only on output time; no frame history or wall clock is used.
public final class ArtworkBackdrop {
    /// The model is low-frequency after blur, so evaluation at one-eighth scale loses no visible detail.
    static let reduction = 8
    let model: ArtworkBackground
    let artwork: CGImage
    let width, height: Int
    private let context = CIContext(options:[.useSoftwareRenderer:true,.workingColorSpace:CGColorSpace(name:CGColorSpace.sRGB)!,
                                             .outputColorSpace:CGColorSpace(name:CGColorSpace.sRGB)!])

    public init(_ model: ArtworkBackground, artwork: CGImage, canvasWidth: Int, canvasHeight: Int) {
        self.model=model;self.artwork=artwork
        width=max(1,canvasWidth/Self.reduction);height=max(1,canvasHeight/Self.reduction)
    }

    public func image(at time: Time) -> CGImage {
        let w=Double(width),h=Double(height)
        let c=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
                        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.interpolationQuality = .high
        c.setFillColor(CGColor(gray:0,alpha:1));c.fill(CGRect(x:0,y:0,width:w,height:h))
        // Equal-weight average of the layers: the first is opaque, later layers blend by 1/(index+1).
        for (index,layer) in model.layers(at:time,width:w,height:h).enumerated() {
            c.saveGState();c.setAlpha(1/Double(index+1))
            c.translateBy(x:layer.centerX,y:h-layer.centerY);c.rotate(by:layer.angle)
            c.draw(artwork,in:CGRect(x:-layer.side/2,y:-layer.side/2,width:layer.side,height:layer.side))
            c.restoreGState()
        }
        let base=CIImage(cgImage:c.makeImage()!),extent=base.extent
        let blurred=base.clampedToExtent().applyingGaussianBlur(sigma:model.blur/Double(Self.reduction)).cropped(to:extent)
        // Saturation about Rec. 709 luma: x' = s·x + (1−s)·luma(x), applied to encoded sRGB values.
        let s=model.saturation,l=(0.2126,0.7152,0.0722)
        func row(_ i:Int) -> CIVector {
            let own=[s,s,s][i]
            return CIVector(x:(i==0 ? own:0)+(1-s)*l.0,y:(i==1 ? own:0)+(1-s)*l.1,z:(i==2 ? own:0)+(1-s)*l.2,w:0)
        }
        let saturated=blurred.applyingFilter("CIColorMatrix",parameters:["inputRVector":row(0),"inputGVector":row(1),
            "inputBVector":row(2),"inputAVector":CIVector(x:0,y:0,z:0,w:1),"inputBiasVector":CIVector(x:0,y:0,z:0,w:0)])
        // Vertical gain: gain at the top edge, gain·(1−gradient) at the bottom edge.
        let top=model.gain,bottom=model.gain*(1-model.gradient)
        let ramp=CIFilter(name:"CILinearGradient",parameters:["inputPoint0":CIVector(x:0,y:h),"inputPoint1":CIVector(x:0,y:0),
            "inputColor0":CIColor(red:top,green:top,blue:top),"inputColor1":CIColor(red:bottom,green:bottom,blue:bottom)])!.outputImage!.cropped(to:extent)
        let shaded=saturated.applyingFilter("CIMultiplyCompositing",parameters:[kCIInputBackgroundImageKey:ramp])
            .applyingFilter("CIColorClamp").cropped(to:extent)
        return context.createCGImage(shaded,from:extent,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!)!
    }
}
