import Foundation
import CoreGraphics
import CoreImage

/// Shared, serialized Core Image evaluation for inactive tiles and artwork backgrounds.
/// Prevent overlapping raster requests following hosted virtual-GPU crashes in MPS blur evaluation.
/// The image graph, working colour space, and requested software-renderer policy remain unchanged.
enum CoreImageRaster {
    private static let lock = NSLock()
    private static let space = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let context = CIContext(options: [
        .useSoftwareRenderer: true, .workingColorSpace: space, .outputColorSpace: space,
    ])
    static func image(_ image: CIImage, from extent: CGRect) -> CGImage {
        lock.lock()
        defer { lock.unlock() }
        // Complete evaluation before releasing the gate; a deferred image could render outside it.
        return context.createCGImage(image, from: extent, format: .RGBA8, colorSpace: space, deferred: false)!
    }
}
