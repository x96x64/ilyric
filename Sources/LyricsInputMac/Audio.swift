import Foundation
import AVFoundation
import AudioToolbox
import CoreMedia
import LyricsInputCore

/// Immutable, bounded PCM on the writer's existing 48-kHz mono sample lattice.
public struct LocalAudio: Sendable {
    public let samples: [Int16]
    public let sourceRate: Double
    public let sourceChannels: Int
    public let sourceFormat: UInt32
    public var sampleCount: Int { samples.count }
    public func sample(_ index: Int) -> Int16 { samples.indices.contains(index) ? samples[index] : 0 }
    public static func decode(_ url: URL) async throws -> LocalAudio {
        let values: URLResourceValues
        do { values=try url.resourceValues(forKeys:[.isRegularFileKey,.fileSizeKey,.isReadableKey]) }
        catch { throw InputError.invalid("Audio file is missing or inaccessible") }
        guard values.isRegularFile==true,values.isReadable==true,let bytes=values.fileSize,bytes>0,bytes<=256*1024*1024 else { throw InputError.invalid("Audio must be a readable regular file no larger than 256 MiB") }
        let asset=AVURLAsset(url:url)
        do {
            guard try await !asset.load(.hasProtectedContent) else { throw InputError.invalid("Protected audio is unsupported") }
            let tracks=try await asset.loadTracks(withMediaType:.audio)
            guard tracks.count==1 else { throw InputError.invalid("Exactly one audio track is required") }
            let track=tracks[0],descriptions=try await track.load(.formatDescriptions),range=try await track.load(.timeRange)
            guard let description=descriptions.first,let asbd=CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
                  asbd.mSampleRate.isFinite,(8_000...96_000).contains(asbd.mSampleRate),asbd.mSampleRate.rounded()==asbd.mSampleRate,(1...2).contains(asbd.mChannelsPerFrame),
                  range.start.isNumeric,range.duration.isNumeric,range.start >= .zero,range.duration > .zero else { throw InputError.invalid("Unsupported audio format, channels, or presentation range") }
            let endpoint=CMTimeAdd(range.start,range.duration)
            guard CMTimeGetSeconds(endpoint)<=600 else { throw InputError.invalid("Audio exceeds the ten-minute bound") }
            let rate=Int32(asbd.mSampleRate),channels=Int(asbd.mChannelsPerFrame)
            let declaredEnd=Int(CMTimeConvertScale(endpoint,timescale:rate,method:.roundHalfAwayFromZero).value)
            guard declaredEnd>0 else { throw InputError.invalid("Audio presentation is shorter than one source sample") }
            let reader=try AVAssetReader(asset:asset)
            let output=AVAssetReaderTrackOutput(track:track,outputSettings:[
                AVFormatIDKey:kAudioFormatLinearPCM,AVSampleRateKey:asbd.mSampleRate,AVNumberOfChannelsKey:channels,
                AVLinearPCMBitDepthKey:16,AVLinearPCMIsFloatKey:false,
                AVLinearPCMIsBigEndianKey:false,AVLinearPCMIsNonInterleaved:false])
            output.alwaysCopiesSampleData=false
            guard reader.canAdd(output) else { throw InputError.invalid("Audio decoder cannot produce source-rate PCM") }
            reader.add(output)
            guard reader.startReading() else { throw InputError.invalid("Audio decoding could not start") }
            var samples:[Int16]=[]
            while let buffer=output.copyNextSampleBuffer() {
                let pts=CMSampleBufferGetPresentationTimeStamp(buffer)
                guard pts.isNumeric,pts >= .zero,let block=CMSampleBufferGetDataBuffer(buffer) else { throw InputError.invalid("Invalid decoded audio timestamp or buffer") }
                let index=Int(CMTimeConvertScale(pts,timescale:rate,method:.roundHalfAwayFromZero).value)
                if samples.isEmpty,index>0 {
                    guard index<=declaredEnd else { throw InputError.invalid("Audio starts beyond its declared endpoint") }
                    samples=Array(repeating:0,count:index*channels)
                }
                guard abs(index-samples.count/channels)<=1 else { throw InputError.invalid("Decoded audio contains an unsupported gap or overlap") }
                let count=CMBlockBufferGetDataLength(block)
                guard count%(2*channels)==0,count/(2*channels)==CMSampleBufferGetNumSamples(buffer),samples.count+count/2<=Int(rate)*channels*600+8192 else { throw InputError.invalid("Decoded audio exceeds its resource or PCM-format bounds") }
                var chunk=[Int16](repeating:0,count:count/2)
                let status=chunk.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block,atOffset:0,dataLength:count,destination:$0.baseAddress!) }
                guard status==kCMBlockBufferNoErr else { throw InputError.invalid("Decoded PCM could not be read") }
                samples.append(contentsOf:chunk)
            }
            guard reader.status == .completed,!samples.isEmpty else { throw InputError.invalid("Audio is corrupt or unsupported by the installed AVFoundation decoder") }
            // A codec may return a partial final decode block beyond its track edit endpoint.
            // Honor that explicit endpoint; do not shorten media by a lyric-derived rule.
            let frameCount=samples.count/channels
            guard frameCount>=declaredEnd-1,frameCount-declaredEnd<=4096 else { throw InputError.invalid("Decoded audio duration disagrees with its track endpoint") }
            if frameCount>declaredEnd { samples.removeLast((frameCount-declaredEnd)*channels) }
            if frameCount<declaredEnd { samples.append(contentsOf:Array(repeating:0,count:channels)) }
            if channels == 2 {
                samples=stride(from:0,to:samples.count,by:2).map { Int16((Int32(samples[$0])+Int32(samples[$0+1]))/2) }
            }
            if rate != 48_000 {
                let sourceFormat=AVAudioFormat(commonFormat:.pcmFormatInt16,sampleRate:Double(rate),channels:1,interleaved:false)!
                let targetFormat=AVAudioFormat(commonFormat:.pcmFormatInt16,sampleRate:48_000,channels:1,interleaved:false)!
                guard let source=AVAudioPCMBuffer(pcmFormat:sourceFormat,frameCapacity:AVAudioFrameCount(declaredEnd)),
                      let converter=AVAudioConverter(from:sourceFormat,to:targetFormat),
                      let target=AVAudioPCMBuffer(pcmFormat:targetFormat,frameCapacity:48_000) else { throw InputError.invalid("Audio conversion setup failed") }
                source.frameLength=AVAudioFrameCount(declaredEnd)
                samples.withUnsafeBytes { source.mutableAudioBufferList.pointee.mBuffers.mData!.copyMemory(from:$0.baseAddress!,byteCount:$0.count) }
                converter.primeMethod = .normal
                converter.dither = false
                var supplied=false,converted:[Int16]=[]
                while true {
                    var conversionError:NSError?
                    let status=converter.convert(to:target,error:&conversionError) { _,state in
                        if supplied { state.pointee = .endOfStream;return nil }
                        supplied=true;state.pointee = .haveData;return source
                    }
                    guard status != .error,conversionError==nil else { throw InputError.invalid("Audio sample-rate or channel conversion failed") }
                    if target.frameLength>0 { converted.append(contentsOf:UnsafeBufferPointer(start:target.int16ChannelData![0],count:Int(target.frameLength))) }
                    guard converted.count<=28_800_800 else { throw InputError.invalid("Converted audio exceeds the duration bound") }
                    if status == .endOfStream { break }
                    guard status == .haveData else { throw InputError.invalid("Audio conversion did not reach an explicit endpoint") }
                }
                let expected=Int(CMTimeConvertScale(endpoint,timescale:48_000,method:.roundHalfAwayFromZero).value)
                guard abs(converted.count-expected)<=1 else { throw InputError.invalid("Flushed audio conversion disagrees with the presentation endpoint (converted \(converted.count), expected \(expected))") }
                if converted.count>expected { converted.removeLast() }
                if converted.count<expected { converted.append(0) }
                samples=converted
            }
            _=try OutputSchedule(audioSamples:samples.count)
            return .init(samples:samples,sourceRate:asbd.mSampleRate,sourceChannels:Int(asbd.mChannelsPerFrame),sourceFormat:asbd.mFormatID)
        } catch let error as InputError { throw error }
        catch { throw InputError.invalid("Audio inspection or decoding failed; use an unprotected local file supported by AVFoundation") }
    }
}
