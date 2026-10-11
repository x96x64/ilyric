import Foundation
import AVFoundation
import CoreGraphics
import SpikeCore

public struct ExportMetrics: Codable {
    public let width: Int
    public let height: Int
    public let frames: Int
    public let seconds: Double
    public let effectiveFPS: Double
    public let rasterSeconds: Double
    public let appendSeconds: Double
    public let backpressureSeconds: Double
    public let finishSeconds: Double
}

/// Pixel destinations and per-worker failure slots for one batch. Each worker writes only its own
/// slot and its own frames, so concurrent access never overlaps.
private final class BatchTargets: @unchecked Sendable {
    let targets: [(UnsafeMutableRawPointer?, Int)]
    let failures: UnsafeMutableBufferPointer<String?>
    private let lock = NSLock()
    private var next = 0
    init(_ targets: [(UnsafeMutableRawPointer?, Int)], workers: Int) {
        self.targets = targets
        failures = .allocate(capacity: workers); failures.initialize(repeating: nil)
    }
    /// The next unclaimed frame of the batch; workers on faster cores simply claim more frames.
    func claim() -> Int? {
        lock.lock(); defer { lock.unlock() }
        guard next < targets.count else { return nil }
        next += 1; return next - 1
    }
    deinit { failures.deallocate() }
}

/// SDK-specific writer compatibility path, isolated from timeline and raster code.
/// The adaptor supports macOS 14; migration to receiver APIs is a later backend decision.
public enum Exporter {
    @MainActor public static func video(renderer: Renderer, to url: URL, frames: Int = 240) async throws -> ExportMetrics {
        let timeline = Timeline()
        return try await video(width:renderer.width,height:renderer.height,to:url,frames:frames,
            draw:{ time, context in
                let wrapped=Time(time.numerator % (4*time.denominator),time.denominator)
                renderer.draw(timeline.evaluate(wrapped),into:context)
            },audioSample:{ timeline.audioSample($0 % 192_000) })
    }
    /// Shared writer only: callers supply deterministic frames and PCM samples.
    @MainActor public static func video(width: Int, height: Int, to url: URL, frames: Int,
        draw: @escaping (Time, CGContext) throws -> Void,
        audioSample: @escaping (Int) -> Int16) async throws -> ExportMetrics {
        try await video(width:width,height:height,to:url,frames:frames,workers:[draw],audioSample:audioSample)
    }
    /// Parallel rasterization: each worker closure owns its renderer and is never called concurrently with
    /// itself. Workers claim the batch's frames one at a time, so faster cores render more of them; frames
    /// are appended strictly in order, and every frame remains a pure function of its time.
    @MainActor public static func video(width: Int, height: Int, to url: URL, frames: Int,
        workers draws: [(Time, CGContext) throws -> Void],
        audioSample: @escaping (Int) -> Int16) async throws -> ExportMetrics {
        guard !draws.isEmpty else { throw SpikeError.failure("At least one frame worker is required") }
        guard frames > 0, !FileManager.default.fileExists(atPath: url.path) else { throw SpikeError.failure("Invalid frame count or existing output") }
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let start = Date()
        let writer = try AVAssetWriter(outputURL: temporary, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                       AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                       AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 12_000_000,
                                              AVVideoExpectedSourceFrameRateKey: 60,
                                              AVVideoMaxKeyFrameIntervalKey: 60]
        ]
        guard writer.canApply(outputSettings: settings, forMediaType: .video) else { throw SpikeError.failure("H.264 settings unsupported") }
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 128_000
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(video), writer.canAdd(audio) else { throw SpikeError.failure("Cannot add writer inputs") }
        writer.add(video); writer.add(audio)
        guard writer.startWriting() else { throw writer.error ?? SpikeError.failure("Writer start failed") }
        writer.startSession(atSourceTime: .zero)
        @MainActor @Sendable func ready(_ isVideo: Bool) async throws {
            let input = isVideo ? video : audio
            let began = Date()
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed { throw writer.error ?? SpikeError.failure("Writer failed") }
                if Date().timeIntervalSince(began) > 30 { throw SpikeError.failure("Writer backpressure timeout") }
                try await Task.sleep(nanoseconds: 1_000_000)
            }
        }
        @MainActor @Sendable func feedVideo() async throws -> (Double, Double, Double) {
            var raster = 0.0, append = 0.0, wait = 0.0
            let count = draws.count, batch = count * 4
            // Render into a separate pool: holding a whole batch of the encoder's own buffers can starve the
            // encoder, which then stops accepting frames while the batch waits to be appended.
            var created: CVPixelBufferPool?
            let attributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
            guard CVPixelBufferPoolCreate(nil, [kCVPixelBufferPoolMinimumBufferCountKey as String: batch] as CFDictionary,
                                          attributes as CFDictionary, &created) == kCVReturnSuccess, let pool = created else {
                throw SpikeError.failure("Pixel buffer pool creation failed")
            }
            var first = 0
            while first < frames {
                let n = min(batch, frames - first)
                var buffers: [CVPixelBuffer] = []
                for _ in 0..<n {
                    var value: CVPixelBuffer?
                    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &value) == kCVReturnSuccess, let buffer = value else {
                        throw SpikeError.failure("Pixel buffer allocation failed")
                    }
                    CVBufferSetAttachment(buffer, kCVImageBufferCGColorSpaceKey, colorSpace, .shouldPropagate)
                    CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
                    CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
                    CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
                    CVPixelBufferLockBaseAddress(buffer, [])
                    buffers.append(buffer)
                }
                let began = Date()
                let shared = BatchTargets(buffers.map { (CVPixelBufferGetBaseAddress($0), CVPixelBufferGetBytesPerRow($0)) }, workers: count)
                let base = first
                DispatchQueue.concurrentPerform(iterations: count) { w in
                    while let k = shared.claim() {
                        autoreleasepool {
                            do {
                                let ctx = try context(width: width, height: height, data: shared.targets[k].0, rowBytes: shared.targets[k].1)
                                try draws[w](.frame(Int64(base + k)), ctx)
                            } catch { shared.failures[w] = String(describing: error) }
                        }
                        if shared.failures[w] != nil { return }
                    }
                }
                for buffer in buffers { CVPixelBufferUnlockBaseAddress(buffer, []) }
                if let failure = shared.failures.compactMap({ $0 }).first { throw SpikeError.failure("Frame rendering failed: \(failure)") }
                raster += Date().timeIntervalSince(began)
                for (k, buffer) in buffers.enumerated() {
                    let waiting = Date()
                    try await ready(true)
                    wait += Date().timeIntervalSince(waiting)
                    let writing = Date()
                    guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(first + k), timescale: 60)) else {
                        throw writer.error ?? SpikeError.failure("Video append failed")
                    }
                    append += Date().timeIntervalSince(writing)
                }
                first += n
            }
            video.markAsFinished()
            return (raster, append, wait)
        }
        @MainActor @Sendable func feedAudio() async throws -> Double {
            var wait = 0.0
            for frame in 0..<frames {
                let began = Date()
                try await ready(false)
                wait += Date().timeIntervalSince(began)
                let sample = try pcm(sample: audioSample, start: frame * 800, count: 800)
                guard audio.append(sample) else { throw writer.error ?? SpikeError.failure("Audio append failed") }
            }
            audio.markAsFinished()
            return wait
        }
        // Independent producers prevent cross-track encoder backpressure deadlock.
        async let videoWork = feedVideo()
        async let audioWork = feedAudio()
        let timings: ((Double, Double, Double), Double)
        do { timings = try await (videoWork, audioWork) }
        catch { writer.cancelWriting(); throw error }
        let (raster, append, videoWait) = timings.0
        let wait = videoWait + timings.1
        writer.endSession(atSourceTime: CMTime(value: Int64(frames), timescale: 60))
        let finishing = Date()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? SpikeError.failure("Writer finish failed") }
        let finish = Date().timeIntervalSince(finishing)
        try FileManager.default.moveItem(at: temporary, to: url)
        let elapsed = Date().timeIntervalSince(start)
        return ExportMetrics(width: width, height: height, frames: frames, seconds: elapsed,
                             effectiveFPS: Double(frames) / elapsed, rasterSeconds: raster,
                             appendSeconds: append, backpressureSeconds: wait, finishSeconds: finish)
    }
    private static func pcm(sample: (Int) -> Int16, start: Int, count: Int) throws -> CMSampleBuffer {
        var description = AudioStreamBasicDescription(mSampleRate: 48_000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        var format: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: nil, asbd: &description, layoutSize: 0, layout: nil,
            magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format) == noErr else {
            throw SpikeError.failure("PCM format failed")
        }
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: count * 2,
            blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: count * 2,
            flags: 0, blockBufferOut: &block) == noErr else { throw SpikeError.failure("PCM allocation failed") }
        let samples = (start..<(start + count)).map { sample($0) }
        let status = samples.withUnsafeBytes { CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block!, offsetIntoDestination: 0, dataLength: count * 2) }
        guard status == noErr else { throw SpikeError.failure("PCM copy failed") }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48_000),
            presentationTimeStamp: CMTime(value: Int64(start), timescale: 48_000), decodeTimeStamp: .invalid)
        var sampleSize = 2
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReady(allocator: nil, dataBuffer: block, formatDescription: format,
            sampleCount: count, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize, sampleBufferOut: &sample) == noErr,
              let result = sample else { throw SpikeError.failure("PCM sample buffer failed") }
        return result
    }
}
