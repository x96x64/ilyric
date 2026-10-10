import CoreGraphics

public extension CGContext {
    /// Core Graphics places an unscaled image on whole pixels, so slow motion would step in
    /// one-pixel increments. Drawing at the two neighboring rows with complementary weights,
    /// summed additively in an isolated layer, is exact vertical linear interpolation.
    func drawSubpixel(_ image: CGImage, in rect: CGRect, alpha: Double = 1) {
        let base=rect.minY.rounded(.down),f=rect.minY-base
        guard f>1e-6 else { saveGState();setAlpha(alpha);draw(image,in:rect);restoreGState();return }
        let low=CGRect(x:rect.minX,y:base,width:rect.width,height:rect.height)
        saveGState();setAlpha(alpha);beginTransparencyLayer(in:low.insetBy(dx:0,dy:-1),auxiliaryInfo:nil);setBlendMode(.plusLighter)
        setAlpha(1-f);draw(image,in:low)
        setAlpha(f);draw(image,in:low.offsetBy(dx:0,dy:1))
        endTransparencyLayer();restoreGState()
    }
}
