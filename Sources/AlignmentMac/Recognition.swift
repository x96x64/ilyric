import Foundation
import CoreML
import AVFoundation
import AlignmentCore

/// wav2vec2 CTC recognition through Core ML: log-probabilities per 20-ms frame over the analysis windows.
public final class RecognitionModel {
    let model: MLModel
    public let vocabulary: [String:Int]
    public let blank: Int

    /// `modelURL` is a converted `.mlpackage` (compiled on load) or a compiled `.mlmodelc`;
    /// `vocabularyURL` is the model's `vocab.json`.
    public init(modelURL: URL, vocabularyURL: URL, computeUnits: MLComputeUnits = .all) throws {
        let compiled=modelURL.pathExtension=="mlmodelc" ? modelURL : try MLModel.compileModel(at:modelURL)
        let configuration=MLModelConfiguration();configuration.computeUnits=computeUnits
        model=try MLModel(contentsOf:compiled,configuration:configuration)
        vocabulary=try JSONDecoder().decode([String:Int].self,from:Data(contentsOf:vocabularyURL))
        guard let pad=vocabulary["<pad>"] else { throw AlignmentError.invalid("Vocabulary lacks the blank label") }
        blank=pad
    }

    /// Emissions for a complete 16-kHz signal, window by window with central frame ownership.
    public func emissions(_ samples: [Float]) throws -> [[Double]] {
        var result=[[Double]]()
        for window in try analysisWindows(samples:samples.count) {
            let segment=Array(samples[window.startSample..<window.endSample])
            let scores=try logProbabilities(normalized(segment))
            for local in try ownedFrames(window,frameCount:scores.count,expected:result.count) { result.append(scores[local]) }
        }
        return result
    }

    /// Zero mean and unit variance per window, as the wav2vec2 feature extractor normalizes.
    func normalized(_ x: [Float]) -> [Float] {
        let n=Double(x.count),mean=x.reduce(0.0) { $0+Double($1) }/n
        let variance=x.reduce(0.0) { let d=Double($1)-mean;return $0+d*d }/n
        let scale=1/(variance+1e-7).squareRoot()
        return x.map { Float((Double($0)-mean)*scale) }
    }

    func logProbabilities(_ x: [Float]) throws -> [[Double]] {
        let input=try MLMultiArray(shape:[1,NSNumber(value:x.count)],dataType:.float32)
        x.withUnsafeBufferPointer { source in
            input.withUnsafeMutableBytes { raw,_ in raw.copyMemory(from:UnsafeRawBufferPointer(source)) }
        }
        let output=try model.prediction(from:MLDictionaryFeatureProvider(dictionary:["input_values":input]))
        guard let scores=output.featureValue(for:"log_probs")?.multiArrayValue,scores.shape.count==3 else {
            throw AlignmentError.invalid("Recognition model output is missing")
        }
        let frames=scores.shape[1].intValue,labels=scores.shape[2].intValue
        let s1=scores.strides[1].intValue,s2=scores.strides[2].intValue
        var rows=[[Double]](repeating:[Double](repeating:0,count:labels),count:frames)
        if scores.dataType == .float32 {
            let p=scores.dataPointer.assumingMemoryBound(to:Float.self)
            for f in 0..<frames { for k in 0..<labels { rows[f][k]=Double(p[f*s1+k*s2]) } }
        } else {
            for f in 0..<frames { for k in 0..<labels { rows[f][k]=scores[[0,NSNumber(value:f),NSNumber(value:k)]].doubleValue } }
        }
        return rows
    }
}

/// Mono 16-kHz Float samples from an audio file; multichannel input is averaged.
public func readMono16k(_ url: URL) throws -> [Float] {
    let file=try AVAudioFile(forReading:url)
    let target=AVAudioFormat(commonFormat:.pcmFormatFloat32,sampleRate:16000,channels:1,interleaved:false)!
    let source=file.processingFormat
    guard let input=AVAudioPCMBuffer(pcmFormat:source,frameCapacity:AVAudioFrameCount(file.length)) else { throw AlignmentError.invalid("Audio buffer allocation failed") }
    try file.read(into:input)
    if source.sampleRate==16000 && source.channelCount==1 {
        return Array(UnsafeBufferPointer(start:input.floatChannelData![0],count:Int(input.frameLength)))
    }
    guard let converter=AVAudioConverter(from:source,to:target) else { throw AlignmentError.invalid("Unsupported audio format") }
    let capacity=AVAudioFrameCount(Double(input.frameLength)*16000/source.sampleRate)+1024
    guard let output=AVAudioPCMBuffer(pcmFormat:target,frameCapacity:capacity) else { throw AlignmentError.invalid("Audio buffer allocation failed") }
    var consumed=false,error:NSError?
    converter.convert(to:output,error:&error) { _,status in
        if consumed { status.pointee = .endOfStream;return nil }
        consumed=true;status.pointee = .haveData;return input
    }
    if let error { throw error }
    return Array(UnsafeBufferPointer(start:output.floatChannelData![0],count:Int(output.frameLength)))
}

/// Complete native line and word alignment of separated vocals against untimed lyrics.
public func alignLyrics(_ lyrics: Data, vocals: [Float], durationMicroseconds: Int, model: RecognitionModel) throws -> [LineAlignment] {
    let source=try LyricSource(lyrics),targets=try textTargets(source)
    guard targets.tokens.allSatisfy({ model.vocabulary[$0] != nil }) else { throw AlignmentError.invalid("Text cannot be represented by the recognition model") }
    let emissions=try model.emissions(vocals)
    let spans=try ctcPath(emissions,targets:targets.tokens.map { model.vocabulary[$0]! },blank:model.blank)
    var rows=try proposals(source,duration:durationMicroseconds,emissions:emissions,targets:targets,spans:spans,vocabulary:model.vocabulary,blank:model.blank)
    let activity=try VocalRules.activity(vocals)
    VocalRules.apply(&rows,level:activity.level,reference:activity.reference)
    return rows
}
