import Foundation
import AVFoundation
import CoreVideo

/// Independently decodes the synthetic two-second installation fixture on the target operating system.
@main
struct VerifyVideo {
    static func main() async {
        do { try await verify() } catch {
            FileHandle.standardError.write(Data("Video verification failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    static func verify() async throws {
        let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoVerification", code: 1)
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? NSError(domain: "VideoVerification", code: 2) }
        var frames = 0
        var cadenceError = 0.0
        while let sample = autoreleasepool(invoking: { output.copyNextSampleBuffer() }) {
            guard let image = CMSampleBufferGetImageBuffer(sample),
                CVPixelBufferGetWidth(image) == 1080, CVPixelBufferGetHeight(image) == 1920
            else { throw NSError(domain: "VideoVerification", code: 3) }
            cadenceError = max(
                cadenceError, abs(CMSampleBufferGetPresentationTimeStamp(sample).seconds - Double(frames) / 60))
            frames += 1
        }
        let duration = try await asset.load(.duration).seconds
        guard reader.status == .completed, frames == 120, cadenceError < 0.000001,
            abs(duration - 2) < 0.05,
            !(try await asset.loadTracks(withMediaType: .audio)).isEmpty
        else {
            throw reader.error
                ?? NSError(
                    domain: "VideoVerification", code: 4,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Expected 120 frames at 60 fps in a two-second audiovisual file; decoded \(frames) frames, duration \(duration), cadence error \(cadenceError)"
                    ])
        }
        let data = try JSONSerialization.data(
            withJSONObject: ["decodedFrames": frames, "maxCadenceErrorSeconds": cadenceError, "seconds": duration])
        print(String(decoding: data, as: UTF8.self))
    }
}
