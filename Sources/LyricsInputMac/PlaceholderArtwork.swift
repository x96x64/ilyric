import Foundation
import CoreGraphics

/// iLyric's original artwork for recordings without a cover: a neutral gray gradient with a beamed pair of
/// eighth notes, drawn from simple paths. It follows the common convention for missing artwork; no Apple asset is used.
public enum PlaceholderArtwork {
    public static func image(size: Int = 1024) -> CGImage {
        let s=Double(size)
        let c=CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size*4,
                        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        let colors=[CGColor(srgbRed:0.40,green:0.40,blue:0.42,alpha:1),CGColor(srgbRed:0.25,green:0.25,blue:0.27,alpha:1)]
        let gradient=CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB),colors:colors as CFArray,locations:[0,1])!
        // Core Graphics has a bottom-left origin: lighter at the top.
        c.drawLinearGradient(gradient,start:CGPoint(x:0,y:s),end:CGPoint(x:0,y:0),options:[])
        c.setFillColor(CGColor(srgbRed:0.62,green:0.62,blue:0.64,alpha:1))
        // Two tilted note heads, stems rising on their right, and a slanted beam joining the stems.
        let head=CGSize(width:0.165*s,height:0.12*s),stem=0.032*s
        let heads=[CGPoint(x:0.36*s,y:0.33*s),CGPoint(x:0.62*s,y:0.37*s)]
        let tops=[0.70*s,0.74*s]
        for (center,top) in zip(heads,tops) {
            c.saveGState();c.translateBy(x:center.x,y:center.y);c.rotate(by:0.42)
            c.fillEllipse(in:CGRect(x:-head.width/2,y:-head.height/2,width:head.width,height:head.height));c.restoreGState()
            let x=center.x+head.width*0.42-stem
            c.fill(CGRect(x:x,y:center.y,width:stem,height:top-center.y))
        }
        let left=heads[0].x+head.width*0.42-stem,right=heads[1].x+head.width*0.42,beam=0.085*s
        c.beginPath();c.move(to:CGPoint(x:left,y:tops[0]-beam));c.addLine(to:CGPoint(x:right,y:tops[1]-beam))
        c.addLine(to:CGPoint(x:right,y:tops[1]));c.addLine(to:CGPoint(x:left,y:tops[0]));c.closePath();c.fillPath()
        return c.makeImage()!
    }
}
