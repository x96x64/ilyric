import Testing
import Foundation
import CoreImage
import CoreGraphics
@testable import LyricsScreenMac

struct CoreImageRasterTests {
    private func source() -> CIImage {
        let context = CGContext(
            data: nil, width: 128, height: 96, bitsPerComponent: 8, bytesPerRow: 512,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for i in 0..<8 {
            context.setFillColor(
                CGColor(
                    srgbRed: Double(i) / 7, green: Double(7 - i) / 7,
                    blue: 0.3, alpha: Double(i + 1) / 8))
            context.fill(CGRect(x: i * 16, y: 8 * i, width: 24, height: 40))
        }
        return CIImage(cgImage: context.makeImage()!)
    }
    private func pixels(_ image: CGImage) -> Data { image.dataProvider!.data! as Data }
    @Test func rasterMatchesIndependentContexts() {
        let source = source()
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        for outputSpace in [false, true] {
            var options: [CIContextOption: Any] = [.useSoftwareRenderer: true, .workingColorSpace: space]
            if outputSpace { options[.outputColorSpace] = space }
            let reference = CIContext(options: options)
            for sigma in [0.0, 1.0, 8.0, 20.0] {
                for clamped in [false, true] {
                    let input = clamped ? source.clampedToExtent() : source
                    let graph = input.applyingGaussianBlur(sigma: sigma).cropped(to: source.extent)
                    let expected = reference.createCGImage(
                        graph, from: source.extent, format: .RGBA8, colorSpace: space)!
                    #expect(pixels(CoreImageRaster.image(graph, from: source.extent)) == pixels(expected))
                }
            }
        }
    }
    @Test func concurrentBlurRastersAreDeterministic() async {
        let source = source()
        let graphs = [1.0, 4.0, 8.0, 20.0].map {
            source.clampedToExtent().applyingGaussianBlur(sigma: $0).cropped(to: source.extent)
        }
        let expected = graphs.map { pixels(CoreImageRaster.image($0, from: source.extent)) }
        await withTaskGroup(of: (Int, Data).self) { group in
            for i in 0..<32 {
                let index = i % graphs.count
                let graph = graphs[index]
                group.addTask {
                    let image = CoreImageRaster.image(graph, from: source.extent)
                    return (index, image.dataProvider!.data! as Data)
                }
            }
            for await (index, actual) in group { #expect(actual == expected[index]) }
        }
    }
}
