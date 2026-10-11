import Foundation
import CoreText
import CoreGraphics

/// Artwork for recordings without a cover: a beamed pair of eighth notes in dark gray on a light gray tile, in the
/// colors and proportions of the Music app's missing-artwork tile. The notes are the character U+266B of the macOS
/// system font Hiragino Sans W6 (the system font's own fallback for it), resolved at runtime and never bundled; an
/// original drawing is used if the glyph is unavailable.
public enum PlaceholderArtwork {
    /// Tile and glyph colors, the glyph's ink height, and its ink center, measured on a Music library screenshot.
    public static let tile=(red:0.871,green:0.871,blue:0.878), glyph=(red:0.427,green:0.427,blue:0.447)
    public static let inkHeight=0.413, inkCenter=(x:0.472,y:0.502)
    /// Outline stroke, relative to the tile, that brings Hiragino Sans W6 to the reference stroke weight.
    public static let strokeWidth=0.024

    public static func image(size: Int = 1024) -> CGImage {
        let s=Double(size)
        let c=CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size*4,
                        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(CGColor(srgbRed:tile.red,green:tile.green,blue:tile.blue,alpha:1));c.fill(CGRect(x:0,y:0,width:s,height:s))
        let ink=CGColor(srgbRed:glyph.red,green:glyph.green,blue:glyph.blue,alpha:1)
        let font:CTFont?=CTFontCreateWithName("HiraginoSans-W6" as CFString,100,nil)
        var glyphs=[CGGlyph](repeating:0,count:1)
        if let font,CTFontGetGlyphsForCharacters(font,[0x266B],&glyphs,1),glyphs[0] != 0 {
            // Scale the glyph so that its ink has the measured height, then place its ink center.
            guard let path=CTFontCreatePathForGlyph(font,glyphs[0],nil) else { drawNotes(c,size:s,ink:ink);return c.makeImage()! }
            let bounds=path.boundingBoxOfPath
            // The outline is stroked as well as filled to match the reference stroke weight; the stroke adds half its
            // width on every side, which the scale accounts for.
            let stroke=strokeWidth*s,scale=(inkHeight*s-stroke)/bounds.height
            c.saveGState();c.setFillColor(ink);c.setStrokeColor(ink);c.setLineJoin(.round)
            c.translateBy(x:inkCenter.x*s-bounds.midX*scale,y:(1-inkCenter.y)*s-bounds.midY*scale);c.scaleBy(x:scale,y:scale)
            c.setLineWidth(stroke/scale);c.addPath(path);c.drawPath(using:.fillStroke);c.restoreGState()
        } else { drawNotes(c,size:s,ink:ink) }
        return c.makeImage()!
    }

    /// Original fallback: two tilted note heads with stems joined by a slanted beam.
    static func drawNotes(_ c: CGContext, size s: Double, ink: CGColor) {
        c.setFillColor(ink)
        let head=CGSize(width:0.165*s,height:0.12*s),stem=0.032*s
        let heads=[CGPoint(x:0.36*s,y:0.33*s),CGPoint(x:0.62*s,y:0.37*s)],tops=[0.70*s,0.74*s]
        for (center,top) in zip(heads,tops) {
            c.saveGState();c.translateBy(x:center.x,y:center.y);c.rotate(by:0.42)
            c.fillEllipse(in:CGRect(x:-head.width/2,y:-head.height/2,width:head.width,height:head.height));c.restoreGState()
            c.fill(CGRect(x:center.x+head.width*0.42-stem,y:center.y,width:stem,height:top-center.y))
        }
        let left=heads[0].x+head.width*0.42-stem,right=heads[1].x+head.width*0.42,beam=0.085*s
        c.beginPath();c.move(to:CGPoint(x:left,y:tops[0]-beam));c.addLine(to:CGPoint(x:right,y:tops[1]-beam))
        c.addLine(to:CGPoint(x:right,y:tops[1]));c.addLine(to:CGPoint(x:left,y:tops[0]));c.closePath();c.fillPath()
    }
}
