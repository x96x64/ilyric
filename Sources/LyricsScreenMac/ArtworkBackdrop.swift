import Foundation
import CoreGraphics
import CoreImage
import LyricsScreenCore
import TimelineCore

/// Renders `ArtworkBackground` at reduced resolution with software Core Image.
/// Each frame depends only on output time; no frame history or wall clock is used.
public final class ArtworkBackdrop {
    /// The model is low-frequency after blur, so evaluation at one-eighth scale loses no visible detail.
    static let reduction = 8
    let model: ArtworkBackground
    let artwork: CGImage
    /// The image the layers draw: the artwork, or for placeholder artwork a field of soft colour blobs sampled from it,
    /// which carries its colours but none of its shapes.
    let field: CGImage
    let width, height: Int
    /// Saturation after adaptation to the artwork's mean chroma, sampled at 192×192 as in the fitting model.
    let saturation: Double
    /// Spread adaptation factor and the artwork's mean colour it scales about, in encoded sRGB units.
    let spread: Double, meanColour: [Double]
    private let context = CIContext(options: [
        .useSoftwareRenderer: true, .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    ])

    /// With `abstract`, the layers draw a colour field derived from the artwork instead of the artwork itself. The
    /// calibration against the reference captures preferred the artwork itself (docs/reports/background-colour-field.md),
    /// so the field is used only for iLyrics's own placeholder artwork, whose symbol would otherwise show through.
    public init(
        _ model: ArtworkBackground, artwork: CGImage, canvasWidth: Int, canvasHeight: Int, abstract: Bool = false
    ) {
        self.model = model
        self.artwork = artwork
        width = max(1, canvasWidth / Self.reduction)
        height = max(1, canvasHeight / Self.reduction)
        let side = 192
        let c = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        c.interpolationQuality = .high
        c.draw(artwork, in: CGRect(x: 0, y: 0, width: side, height: side))
        let rgba = [UInt8](Data(bytes: c.data!, count: side * side * 4))
        var rgb = [UInt8]()
        rgb.reserveCapacity(side * side * 3)
        for p in 0..<(side * side) { rgb.append(contentsOf: rgba[(p * 4)..<(p * 4 + 3)]) }
        saturation = model.saturation(artworkChroma: ArtworkBackground.meanChroma(rgb: rgb))
        // Coarse structure: 12×12-pixel block means of the 192-pixel sample give the 16×16 artwork of the fitting model.
        var coarse = [Double]()
        for by in 0..<16 {
            for bx in 0..<16 {
                var sum = 0.0
                for y in by * 12..<(by + 1) * 12 {
                    for x in bx * 12..<(bx + 1) * 12 {
                        let i = (y * side + x) * 3
                        sum += 0.2126 * Double(rgb[i]) + 0.7152 * Double(rgb[i + 1]) + 0.0722 * Double(rgb[i + 2])
                    }
                }
                coarse.append(sum / 144 / 255)
            }
        }
        let m = coarse.reduce(0, +) / Double(coarse.count)
        spread = model.spreadFactor(
            coarseLightnessDeviation: (coarse.reduce(0.0) { $0 + ($1 - m) * ($1 - m) } / Double(coarse.count))
                .squareRoot())
        meanColour = (0..<3).map { ch in
            stride(from: ch, to: rgb.count, by: 3).reduce(0.0) { $0 + Double(rgb[$1]) } / Double(side * side) / 255
        }
        field = abstract ? Self.colorField(artwork) : artwork
    }

    /// Colour clusters of the artwork (k-means at 32×32, deterministic), drawn as radial blobs on a field filled with
    /// the mean colour. Each cluster contributes blobs in proportion to its share, at positions from a generator
    /// seeded by the artwork's pixels, so the field is a pure function of the artwork.
    public static func colorField(_ artwork: CGImage, side: Int = 128) -> CGImage {
        let n = 32
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let small = CGContext(
            data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        small.interpolationQuality = .high
        small.draw(artwork, in: CGRect(x: 0, y: 0, width: n, height: n))
        let bytes = [UInt8](Data(bytes: small.data!, count: n * n * 4))
        let pixels = (0..<(n * n)).map { p in
            [Double(bytes[p * 4]), Double(bytes[p * 4 + 1]), Double(bytes[p * 4 + 2])]
        }
        // Deterministic k-means: centres start at luminance quantiles.
        let k = 6
        let order = pixels.indices.sorted {
            (pixels[$0][0] * 0.2126 + pixels[$0][1] * 0.7152 + pixels[$0][2] * 0.0722, $0) < (
                pixels[$1][0] * 0.2126 + pixels[$1][1] * 0.7152 + pixels[$1][2] * 0.0722, $1
            )
        }
        var centres = (0..<k).map { pixels[order[($0 * 2 + 1) * pixels.count / (2 * k)]] }
        var assignment = [Int](repeating: 0, count: pixels.count)
        for _ in 0..<12 {
            for (i, p) in pixels.enumerated() {
                var best = 0
                var distance = Double.infinity
                for (j, c) in centres.enumerated() {
                    let d =
                        (p[0] - c[0]) * (p[0] - c[0]) + (p[1] - c[1]) * (p[1] - c[1]) + (p[2] - c[2]) * (p[2] - c[2])
                    if d < distance {
                        distance = d
                        best = j
                    }
                }
                assignment[i] = best
            }
            for j in 0..<k {
                let members = pixels.indices.filter { assignment[$0] == j }
                guard !members.isEmpty else { continue }
                centres[j] = (0..<3).map { ch in members.reduce(0.0) { $0 + pixels[$1][ch] } / Double(members.count) }
            }
        }
        let shares = (0..<k).map { j in Double(assignment.filter { $0 == j }.count) / Double(pixels.count) }
        // SplitMix64 seeded by an FNV-1a hash of the sampled pixels.
        var state = bytes.reduce(UInt64(0xcbf2_9ce4_8422_2325)) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
        func random() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return Double(z >> 11) / Double(UInt64(1) << 53)
        }
        let c = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let mean = (0..<3).map { ch in pixels.reduce(0.0) { $0 + $1[ch] } / Double(pixels.count) / 255 }
        c.setFillColor(CGColor(srgbRed: mean[0], green: mean[1], blue: mean[2], alpha: 1))
        c.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let s = Double(side)
        for j in (0..<k).sorted(by: { (shares[$0], $0) > (shares[$1], $1) }) where shares[j] > 0 {
            let colour = CGColor(
                srgbRed: centres[j][0] / 255, green: centres[j][1] / 255, blue: centres[j][2] / 255, alpha: 1)
            let clear = CGColor(
                srgbRed: centres[j][0] / 255, green: centres[j][1] / 255, blue: centres[j][2] / 255, alpha: 0)
            let gradient = CGGradient(colorsSpace: space, colors: [colour, clear] as CFArray, locations: [0, 1])!
            for _ in 0..<max(1, Int((shares[j] * 14).rounded())) {
                let x = random() * s
                let y = random() * s
                let r = s * (0.18 + 0.16 * random())
                c.drawRadialGradient(
                    gradient, startCenter: CGPoint(x: x, y: y), startRadius: 0, endCenter: CGPoint(x: x, y: y),
                    endRadius: r, options: [])
            }
        }
        return c.makeImage()!
    }

    public func image(at time: Time) -> CGImage {
        let w = Double(width)
        let h = Double(height)
        let c = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.interpolationQuality = .high
        c.setFillColor(CGColor(gray: 0, alpha: 1))
        c.fill(CGRect(x: 0, y: 0, width: w, height: h))
        // Equal-weight average of the layers: the first is opaque, later layers blend by 1/(index+1).
        for (index, layer) in model.layers(at: time, width: w, height: h).enumerated() {
            c.saveGState()
            c.setAlpha(1 / Double(index + 1))
            c.translateBy(x: layer.centerX, y: h - layer.centerY)
            c.rotate(by: layer.angle)
            c.draw(field, in: CGRect(x: -layer.side / 2, y: -layer.side / 2, width: layer.side, height: layer.side))
            c.restoreGState()
        }
        let base = CIImage(cgImage: c.makeImage()!)
        let extent = base.extent
        let blurred = base.clampedToExtent().applyingGaussianBlur(sigma: model.blur / Double(Self.reduction)).cropped(
            to: extent)
        // Spread adaptation about the artwork's mean colour: x' = f·x + (1−f)·mean.
        let f = spread
        let adapted =
            f == 1
            ? blurred
            : blurred.applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: f, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: f, z: 0, w: 0), "inputBVector": CIVector(x: 0, y: 0, z: f, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(
                        x: (1 - f) * meanColour[0], y: (1 - f) * meanColour[1], z: (1 - f) * meanColour[2], w: 0),
                ])
        // Saturation about Rec. 709 luma: x' = s·x + (1−s)·luma(x), applied to encoded sRGB values.
        let s = saturation
        let l = (0.2126, 0.7152, 0.0722)
        let bias = model.gain > 0 ? model.lift / model.gain : 0
        func row(_ i: Int) -> CIVector {
            let own = [s, s, s][i]
            return CIVector(
                x: (i == 0 ? own : 0) + (1 - s) * l.0, y: (i == 1 ? own : 0) + (1 - s) * l.1,
                z: (i == 2 ? own : 0) + (1 - s) * l.2, w: 0)
        }
        let saturated = adapted.applyingFilter(
            "CIColorMatrix",
            parameters: [
                "inputRVector": row(0), "inputGVector": row(1),
                "inputBVector": row(2), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: 0),
            ])
        // Vertical gain: gain at the top edge, gain·(1−gradient) at the bottom edge; with the bias above,
        // the result is (x·gain + lift)·(1 − gradient·y).
        let top = model.gain
        let bottom = model.gain * (1 - model.gradient)
        let ramp = CIFilter(
            name: "CILinearGradient",
            parameters: [
                "inputPoint0": CIVector(x: 0, y: h), "inputPoint1": CIVector(x: 0, y: 0),
                "inputColor0": CIColor(red: top, green: top, blue: top),
                "inputColor1": CIColor(red: bottom, green: bottom, blue: bottom),
            ])!.outputImage!.cropped(to: extent)
        let shaded = saturated.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: ramp])
            .applyingFilter("CIColorClamp").cropped(to: extent)
        return context.createCGImage(
            shaded, from: extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)!
    }
}
