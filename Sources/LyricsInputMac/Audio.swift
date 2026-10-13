import Foundation
import AVFoundation
import AudioToolbox
import CoreMedia
import LyricsInputCore

/// Immutable, bounded PCM on the writer's existing 48-kHz mono sample lattice.
public struct LocalAudio: Sendable {
    public let samples: [Int16]
    /// Interleaved left and right samples on the same 48-kHz lattice for stereo sources; nil for mono sources.
    public let stereo: [Int16]?
    public let sourceRate: Double
    public let sourceChannels: Int
    public let sourceFormat: UInt32
    public var sampleCount: Int { samples.count }
    public func sample(_ index: Int) -> Int16 { samples.indices.contains(index) ? samples[index] : 0 }
    /// Output channels: two for stereo sources, otherwise one.
    public var channels: Int { stereo == nil ? 1 : 2 }
    /// Interleaved output sample `index` (frame × channels + channel), zero beyond the end.
    public func interleavedSample(_ index: Int) -> Int16 {
        guard let stereo else { return sample(index) }
        return stereo.indices.contains(index) ? stereo[index] : 0
    }
    public init(samples: [Int16], stereo: [Int16]? = nil, sourceRate: Double, sourceChannels: Int, sourceFormat: UInt32)
    {
        self.samples = samples
        self.stereo = stereo
        self.sourceRate = sourceRate
        self.sourceChannels = sourceChannels
        self.sourceFormat = sourceFormat
    }
    /// Largest accepted audio file; files are read incrementally, so this bounds work rather than memory.
    public static let maximumBytes = 2 * 1024 * 1024 * 1024
    /// The audio checks that need no decoding, for rejecting unsupported input before alignment starts.
    public struct Inspection: @unchecked Sendable {
        let asset: AVURLAsset, track: AVAssetTrack, format: AudioStreamBasicDescription, range: CMTimeRange
        public var sampleRate: Double { format.mSampleRate }
        public var channels: Int { Int(format.mChannelsPerFrame) }
    }

    public static func inspect(_ url: URL) async throws -> Inspection {
        let values: URLResourceValues
        do { values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isReadableKey]) } catch {
            throw InputError.invalid("Audio file is missing or inaccessible")
        }
        guard values.isRegularFile == true, values.isReadable == true, let bytes = values.fileSize, bytes > 0 else {
            throw InputError.invalid("Audio must be a readable, nonempty regular file")
        }
        guard bytes <= maximumBytes else {
            throw InputError.invalid(
                "Audio file is \(bytes/1_048_576) MiB; at most \(maximumBytes/1_073_741_824) GiB is supported")
        }
        let asset = AVURLAsset(url: url)
        do {
            guard try await !asset.load(.hasProtectedContent) else {
                throw InputError.invalid("Protected audio is unsupported")
            }
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard tracks.count == 1 else {
                throw InputError.invalid("Exactly one audio track is required; the file has \(tracks.count)")
            }
            let track = tracks[0]
            let descriptions = try await track.load(.formatDescriptions)
            let range = try await track.load(.timeRange)
            guard let description = descriptions.first,
                let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
                asbd.mSampleRate.isFinite, asbd.mSampleRate.rounded() == asbd.mSampleRate,
                range.start.isNumeric, range.duration.isNumeric, range.start >= .zero, range.duration > .zero
            else { throw InputError.invalid("Unsupported audio format or presentation range") }
            guard (8_000...384_000).contains(asbd.mSampleRate) else {
                throw InputError.invalid(
                    "Audio sample rate \(Int(asbd.mSampleRate)) Hz is unsupported; 8 kHz to 384 kHz is supported")
            }
            guard (1...2).contains(asbd.mChannelsPerFrame) else {
                throw InputError.invalid(
                    "Audio has \(asbd.mChannelsPerFrame) channels; only mono and stereo are supported, so mix it down to stereo first"
                )
            }
            guard CMTimeGetSeconds(CMTimeAdd(range.start, range.duration)) <= Double(InputLimits.maximumSeconds) else {
                throw InputError.invalid("Audio exceeds the twenty-minute bound")
            }
            return Inspection(asset: asset, track: track, format: asbd, range: range)
        } catch let error as InputError { throw error } catch {
            throw InputError.invalid("Audio inspection failed; use an unprotected local file supported by AVFoundation")
        }
    }

    public static func decode(_ url: URL) async throws -> LocalAudio {
        let inspection = try await inspect(url)
        let asset = inspection.asset
        let track = inspection.track
        let asbd = inspection.format
        let range = inspection.range
        do {
            let endpoint = CMTimeAdd(range.start, range.duration)
            // Every source is decoded at its own rate and converted by `resample`, which is deterministic; the
            // asset reader's own rate conversion was found to vary under concurrent load.
            let rate = Int32(asbd.mSampleRate)
            let channels = Int(asbd.mChannelsPerFrame)
            let declaredEnd = Int(CMTimeConvertScale(endpoint, timescale: rate, method: .roundHalfAwayFromZero).value)
            guard declaredEnd > 0 else {
                throw InputError.invalid("Audio presentation is shorter than one source sample")
            }
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(
                track: track,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: asbd.mSampleRate,
                    AVNumberOfChannelsKey: channels,
                    AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false,
                ])
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else {
                throw InputError.invalid("Audio decoder cannot produce source-rate PCM")
            }
            reader.add(output)
            guard reader.startReading() else { throw InputError.invalid("Audio decoding could not start") }
            var samples: [Int16] = []
            while let buffer = output.copyNextSampleBuffer() {
                let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                guard pts.isNumeric, pts >= .zero, let block = CMSampleBufferGetDataBuffer(buffer) else {
                    throw InputError.invalid("Invalid decoded audio timestamp or buffer")
                }
                let index = Int(CMTimeConvertScale(pts, timescale: rate, method: .roundHalfAwayFromZero).value)
                if samples.isEmpty, index > 0 {
                    guard index <= declaredEnd else {
                        throw InputError.invalid("Audio starts beyond its declared endpoint")
                    }
                    samples = Array(repeating: 0, count: index * channels)
                }
                guard abs(index - samples.count / channels) <= 1 else {
                    throw InputError.invalid("Decoded audio contains an unsupported gap or overlap")
                }
                let count = CMBlockBufferGetDataLength(block)
                guard count % (2 * channels) == 0, count / (2 * channels) == CMSampleBufferGetNumSamples(buffer),
                    samples.count + count / 2 <= Int(rate) * channels * InputLimits.maximumSeconds + 8192
                else { throw InputError.invalid("Decoded audio exceeds its resource or PCM-format bounds") }
                var chunk = [Int16](repeating: 0, count: count / 2)
                let status = chunk.withUnsafeMutableBytes {
                    CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count, destination: $0.baseAddress!)
                }
                guard status == kCMBlockBufferNoErr else { throw InputError.invalid("Decoded PCM could not be read") }
                samples.append(contentsOf: chunk)
            }
            guard reader.status == .completed, !samples.isEmpty else {
                throw InputError.invalid("Audio is corrupt or unsupported by the installed AVFoundation decoder")
            }
            // A codec may return a partial final decode block beyond its track edit endpoint.
            // Honor that explicit endpoint; do not shorten media by a lyric-derived rule.
            let frameCount = samples.count / channels
            // The endpoint is quantized to the track's time scale (for example 1/600 s), so decoding may end short
            // of it by up to one tick; that remainder is padded with silence.
            let tick = Int((Double(rate) / Double(endpoint.timescale)).rounded(.up)) + 1
            guard frameCount >= declaredEnd - tick, frameCount - declaredEnd <= 4096 else {
                throw InputError.invalid(
                    "Decoded audio duration disagrees with its track endpoint (decoded \(frameCount) frames, declared \(declaredEnd))"
                )
            }
            if frameCount > declaredEnd { samples.removeLast((frameCount - declaredEnd) * channels) }
            if frameCount < declaredEnd {
                samples.append(contentsOf: Array(repeating: 0, count: (declaredEnd - frameCount) * channels))
            }
            // Stereo sources keep both channels for export; the mono mix drives scheduling as before.
            var stereo: [Int16]? = channels == 2 ? samples : nil
            if channels == 2 {
                samples = stride(from: 0, to: samples.count, by: 2).map {
                    Int16((Int32(samples[$0]) + Int32(samples[$0 + 1])) / 2)
                }
            }
            if rate != 48_000 {
                let expected = Int(
                    CMTimeConvertScale(endpoint, timescale: 48_000, method: .roundHalfAwayFromZero).value)
                samples = try resample(samples, channels: 1, rate: rate, frames: declaredEnd, expected: expected)
                stereo = try stereo.map {
                    try resample($0, channels: 2, rate: rate, frames: declaredEnd, expected: expected)
                }
            }
            _ = try OutputSchedule(audioSamples: samples.count)
            return .init(
                samples: samples, stereo: stereo, sourceRate: asbd.mSampleRate,
                sourceChannels: Int(asbd.mChannelsPerFrame), sourceFormat: asbd.mFormatID)
        } catch let error as InputError { throw error } catch {
            throw InputError.invalid(
                "Audio inspection or decoding failed; use an unprotected local file supported by AVFoundation")
        }
    }
    /// Converts interleaved 16-bit PCM of `frames` source frames to 48 kHz, flushing the converter and matching the
    /// presentation endpoint within one sample.
    static func resample(_ input: [Int16], channels: Int, rate: Int32, frames: Int, expected: Int) throws -> [Int16] {
        let count = AVAudioChannelCount(channels)
        let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: Double(rate), channels: count, interleaved: true)!
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: 48_000, channels: count, interleaved: true)!
        guard let source = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(frames)),
            let converter = AVAudioConverter(from: sourceFormat, to: targetFormat),
            let target = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: 48_000)
        else { throw InputError.invalid("Audio conversion setup failed") }
        source.frameLength = AVAudioFrameCount(frames)
        input.withUnsafeBytes {
            source.mutableAudioBufferList.pointee.mBuffers.mData!.copyMemory(
                from: $0.baseAddress!, byteCount: min($0.count, frames * channels * 2))
        }
        converter.primeMethod = .normal
        converter.dither = false
        var supplied = false
        var converted: [Int16] = []
        while true {
            var conversionError: NSError?
            let status = converter.convert(to: target, error: &conversionError) { _, state in
                if supplied {
                    state.pointee = .endOfStream
                    return nil
                }
                supplied = true
                state.pointee = .haveData
                return source
            }
            guard status != .error, conversionError == nil else {
                throw InputError.invalid("Audio sample-rate or channel conversion failed")
            }
            if target.frameLength > 0 {
                converted.append(
                    contentsOf: UnsafeBufferPointer(
                        start: target.int16ChannelData![0], count: Int(target.frameLength) * channels))
            }
            guard converted.count <= (InputLimits.maximumSeconds * 48_000 + 800) * channels else {
                throw InputError.invalid("Converted audio exceeds the duration bound")
            }
            if status == .endOfStream { break }
            guard status == .haveData else {
                throw InputError.invalid("Audio conversion did not reach an explicit endpoint")
            }
        }
        let produced = converted.count / channels
        guard abs(produced - expected) <= 1 else {
            throw InputError.invalid(
                "Flushed audio conversion disagrees with the presentation endpoint (converted \(produced), expected \(expected))"
            )
        }
        if produced > expected { converted.removeLast(channels) }
        if produced < expected { converted.append(contentsOf: Array(repeating: 0, count: channels)) }
        return converted
    }
}
