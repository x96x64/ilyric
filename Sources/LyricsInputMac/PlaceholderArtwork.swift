import Foundation
import AppKit
import CoreGraphics

/// Artwork for recordings without a cover: the `music.note` SF Symbol in dark gray on a light gray tile, in the colors
/// of the Music app's missing-artwork tile. The symbol is resolved at runtime and never bundled; when it is
/// unavailable, an original beamed-note drawing is used instead.
public enum PlaceholderArtwork {
    /// Tile and glyph colors sampled from a Music library screenshot.
    public static let tile = (red: 0.871, green: 0.871, blue: 0.878), glyph = (red: 0.427, green: 0.427, blue: 0.447)
    /// Height of the symbol image relative to the tile; its ink is about 0.47 of the tile high.
    public static let symbolHeight = 0.56

    public static func image(size: Int = 1024) -> CGImage {
        let s = Double(size)
        let c = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(CGColor(srgbRed: tile.red, green: tile.green, blue: tile.blue, alpha: 1))
        c.fill(CGRect(x: 0, y: 0, width: s, height: s))
        let ink = NSColor(srgbRed: glyph.red, green: glyph.green, blue: glyph.blue, alpha: 1)
        if let symbol = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: symbolHeight * s, weight: .regular).applying(
                    .init(paletteColors: [ink])))
        {
            let scale = symbolHeight * s / symbol.size.height
            let w = symbol.size.width * scale
            let h = symbol.size.height * scale
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
            symbol.draw(in: NSRect(x: (s - w) / 2, y: (s - h) / 2, width: w, height: h))
            NSGraphicsContext.restoreGraphicsState()
        } else {
            drawNotes(c, size: s, ink: ink.cgColor)
        }
        return c.makeImage()!
    }

    /// Original fallback: two tilted note heads with stems joined by a slanted beam.
    static func drawNotes(_ c: CGContext, size s: Double, ink: CGColor) {
        c.setFillColor(ink)
        let head = CGSize(width: 0.165 * s, height: 0.12 * s)
        let stem = 0.032 * s
        let heads = [CGPoint(x: 0.36 * s, y: 0.33 * s), CGPoint(x: 0.62 * s, y: 0.37 * s)]
        let tops = [0.70 * s, 0.74 * s]
        for (center, top) in zip(heads, tops) {
            c.saveGState()
            c.translateBy(x: center.x, y: center.y)
            c.rotate(by: 0.42)
            c.fillEllipse(in: CGRect(x: -head.width / 2, y: -head.height / 2, width: head.width, height: head.height))
            c.restoreGState()
            c.fill(CGRect(x: center.x + head.width * 0.42 - stem, y: center.y, width: stem, height: top - center.y))
        }
        let left = heads[0].x + head.width * 0.42 - stem
        let right = heads[1].x + head.width * 0.42
        let beam = 0.085 * s
        c.beginPath()
        c.move(to: CGPoint(x: left, y: tops[0] - beam))
        c.addLine(to: CGPoint(x: right, y: tops[1] - beam))
        c.addLine(to: CGPoint(x: right, y: tops[1]))
        c.addLine(to: CGPoint(x: left, y: tops[0]))
        c.closePath()
        c.fillPath()
    }
}
