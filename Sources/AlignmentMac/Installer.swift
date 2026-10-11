import Foundation
import CoreML
import CryptoKit
import Compression
import AlignmentCore

/// Rebuilds the HTDemucs Core ML weights on the user's Mac from the official checkpoint and a weightless template,
/// so that iLyrics never redistributes the checkpoint's values (docs/reports/core-ml-port-feasibility.md).
public enum SeparationInstaller {
    struct Recipe: Decodable {
        struct Checkpoint: Decodable { let file, sha256, url: String }
        struct Weights: Decodable { let size: Int; let sha256, skeleton_sha256: String }
        struct Entry: Decodable {
            let offset, size: Int; let kind, key: String
            let start, end, bins, frames: Int?; let scale, outer_scale: Double?; let axes: [Int]?
        }
        /// Checkpoint-derived tensors stored inline in the program, replaced by sentinels in the template.
        struct Inline: Decodable { let name, sentinel, kind, key: String; let count: Int; let start, end: Int?; let axes: [Int]? }
        struct Program: Decodable { let sha256: String; let inline_entries: [Inline] }
        let format: String; let checkpoint: Checkpoint; let weights: Weights; let program: Program?; let entries: [Entry]
    }

    /// `template` holds htdemucs-template.mlpackage, weight-skeleton.bin.zlib, and weight-recipe.json.
    /// Returns the compiled model inside `destination`.
    public static func install(template: URL, checkpoint: URL, destination: URL) throws -> URL {
        let recipe=try JSONDecoder().decode(Recipe.self,from:Data(contentsOf:template.appendingPathComponent("weight-recipe.json")))
        guard recipe.format=="ilyric-weight-recipe-1" else { throw AlignmentError.invalid("Unsupported weight recipe") }
        let checkpointData=try Data(contentsOf:checkpoint)
        guard hex(SHA256.hash(data:checkpointData))==recipe.checkpoint.sha256 else { throw AlignmentError.invalid("Checkpoint SHA-256 differs from the pinned file") }
        var weights=try inflate(Data(contentsOf:template.appendingPathComponent("weight-skeleton.bin.zlib")),size:recipe.weights.size)
        guard hex(SHA256.hash(data:weights))==recipe.weights.skeleton_sha256 else { throw AlignmentError.invalid("Weight skeleton is corrupted") }
        let tensors=try TorchCheckpoint(checkpointData).tensors
        for entry in recipe.entries {
            guard let t=tensors[entry.key] else { throw AlignmentError.invalid("Checkpoint lacks \(entry.key)") }
            let values=try derive(entry,t)
            guard values.count*4==entry.size else { throw AlignmentError.invalid("Derived size differs for \(entry.key)") }
            values.withUnsafeBytes { weights.replaceSubrange(entry.offset..<entry.offset+entry.size,with:$0) }
        }
        guard hex(SHA256.hash(data:weights))==recipe.weights.sha256 else { throw AlignmentError.invalid("Rebuilt weights differ from the reference conversion") }
        let fm=FileManager.default
        try fm.createDirectory(at:destination,withIntermediateDirectories:true)
        let package=destination.appendingPathComponent("htdemucs.mlpackage"),compiled=destination.appendingPathComponent("htdemucs.mlmodelc")
        for url in [package,compiled] where fm.fileExists(atPath:url.path) { try fm.removeItem(at:url) }
        try fm.copyItem(at:template.appendingPathComponent("htdemucs-template.mlpackage"),to:package)
        if let program=recipe.program {
            let url=package.appendingPathComponent("Data/com.apple.CoreML/model.mlmodel")
            try restoreProgram(Data(contentsOf:url),program,tensors:tensors).write(to:url)
        }
        let weightsDirectory=package.appendingPathComponent("Data/com.apple.CoreML/weights")
        try fm.createDirectory(at:weightsDirectory,withIntermediateDirectories:true)
        try weights.write(to:weightsDirectory.appendingPathComponent("weight.bin"))
        try fm.moveItem(at:try MLModel.compileModel(at:package),to:compiled)
        try fm.removeItem(at:package)
        return compiled
    }

    /// Replaces each sentinel in the template program with its checkpoint values; the result must equal the
    /// reference conversion's program byte for byte.
    static func restoreProgram(_ data: Data,_ program: Recipe.Program,tensors: [String:TorchCheckpoint.Tensor]) throws -> Data {
        var bytes=data
        for e in program.inline_entries {
            guard let t=tensors[e.key] else { throw AlignmentError.invalid("Checkpoint lacks \(e.key)") }
            let entry=Recipe.Entry(offset:0,size:e.count*4,kind:e.kind,key:e.key,start:e.start,end:e.end,bins:nil,frames:nil,scale:nil,outer_scale:nil,axes:e.axes)
            let values=try derive(entry,t)
            guard values.count==e.count,let sentinel=Data(hex:e.sentinel),sentinel.count==e.count*4,
                  let range=bytes.range(of:sentinel) else { throw AlignmentError.invalid("Program template lacks the sentinel for \(e.name)") }
            values.withUnsafeBytes { bytes.replaceSubrange(range,with:$0) }
        }
        guard hex(SHA256.hash(data:bytes))==program.sha256 else { throw AlignmentError.invalid("Restored program differs from the reference conversion") }
        return bytes
    }

    static func derive(_ e: Recipe.Entry,_ t: TorchCheckpoint.Tensor) throws -> [Float] {
        switch e.kind {
        case "tensor": return t.values
        case "rows":
            guard let start=e.start,let end=e.end else { break }
            let row=t.shape.dropFirst().reduce(1,*);return Array(t.values[start*row..<end*row])
        case "permute":
            guard let axes=e.axes,axes.count==t.shape.count else { break }
            let shape=axes.map { t.shape[$0] },strides=t.shape.indices.map { d in t.shape[(d+1)...].reduce(1,*) }
            var out=[Float](repeating:0,count:t.values.count),index=[Int](repeating:0,count:shape.count)
            for n in 0..<out.count {
                out[n]=t.values[zip(index,axes).reduce(0) { $0+$1.0*strides[$1.1] }]
                var d=shape.count-1
                while d>=0 { index[d]+=1;if index[d]<shape[d] { break };index[d]=0;d-=1 }
            }
            return out
        case "frequency_embedding":
            // ScaledEmbedding: weight·scale, transposed to channels × bins, expanded over frames, times the outer scale,
            // in float32 as PyTorch computes it.
            guard let bins=e.bins,let frames=e.frames,let scale=e.scale,let outer=e.outer_scale,t.shape.count==2 else { break }
            let channels=t.shape[1],s=Float(scale),o=Float(outer)
            var out=[Float](repeating:0,count:channels*bins*frames)
            for c in 0..<channels { for b in 0..<bins {
                let v=(t.values[b*channels+c]*s)*o
                for f in 0..<frames { out[(c*bins+b)*frames+f]=v }
            }}
            return out
        default: break
        }
        throw AlignmentError.invalid("Unsupported weight recipe entry \(e.kind) for \(e.key)")
    }

    /// zlib (RFC 1950) data: the Compression framework expects raw DEFLATE, so the header and checksum are skipped.
    static func inflate(_ data: Data,size: Int) throws -> Data {
        guard data.count>6 else { throw AlignmentError.invalid("Weight skeleton is truncated") }
        let body=data.subdata(in:(data.startIndex+2)..<(data.endIndex-4))
        var out=Data(count:size)
        let written=out.withUnsafeMutableBytes { dst in body.withUnsafeBytes { src in
            compression_decode_buffer(dst.bindMemory(to:UInt8.self).baseAddress!,size,src.bindMemory(to:UInt8.self).baseAddress!,body.count,nil,COMPRESSION_ZLIB)
        }}
        guard written==size else { throw AlignmentError.invalid("Weight skeleton has an unexpected size") }
        return out
    }
    static func hex(_ digest: SHA256.Digest) -> String { digest.map { String(format:"%02x",$0) }.joined() }
}

/// Tensors of a safetensors file: an 8-byte little-endian header length, a JSON header, and raw data.
public struct SafeTensors {
    public let tensors: [String:TorchCheckpoint.Tensor]
    public init(_ data: Data) throws {
        guard data.count>=8 else { throw AlignmentError.invalid("Truncated safetensors file") }
        let headerLength=Int(data.prefix(8).enumerated().reduce(UInt64(0)) { $0|UInt64($1.element)<<(8*UInt64($1.offset)) })
        guard 8+headerLength<=data.count,let header=try JSONSerialization.jsonObject(with:data.subdata(in:(data.startIndex+8)..<(data.startIndex+8+headerLength))) as? [String:Any] else {
            throw AlignmentError.invalid("Malformed safetensors header")
        }
        let base=data.startIndex+8+headerLength
        var tensors=[String:TorchCheckpoint.Tensor]()
        for (name,value) in header where name != "__metadata__" {
            guard let info=value as? [String:Any],(info["dtype"] as? String)=="F32",let shape=info["shape"] as? [Int],
                  let offsets=info["data_offsets"] as? [Int],offsets.count==2,base+offsets[1]<=data.endIndex else {
                throw AlignmentError.invalid("Unsupported safetensors entry \(name)")
            }
            let raw=data.subdata(in:(base+offsets[0])..<(base+offsets[1]))
            tensors[name]=TorchCheckpoint.Tensor(shape:shape,values:raw.withUnsafeBytes { Array($0.bindMemory(to:Float.self)) })
        }
        self.tensors=tensors
    }
}

/// Rebuilds the wav2vec2 Core ML weights from the published safetensors file and verifies the model by self-test.
public enum RecognitionInstaller {
    struct Recipe: Decodable {
        struct Checkpoint: Decodable { let file, sha256, url, vocabulary_url: String }
        struct Weights: Decodable { let size: Int; let skeleton_sha256: String }
        struct SelfTest: Decodable { let samples, frames, labels: Int; let log_probs: [Double]; let tolerance: Double }
        struct Entry: Decodable { let offset, size: Int; let kind, key: String; let sha256, g: String?; let axes: [Int]?; let dim: Int? }
        let format: String; let checkpoint: Checkpoint; let weights: Weights; let self_test: SelfTest; let entries: [Entry]
    }

    /// `template` holds wav2vec2-template.mlpackage, wav2vec2-skeleton.bin.zlib, and wav2vec2-recipe.json.
    public static func install(template: URL, weights: URL, destination: URL) throws -> URL {
        let recipe=try JSONDecoder().decode(Recipe.self,from:Data(contentsOf:template.appendingPathComponent("wav2vec2-recipe.json")))
        guard recipe.format=="ilyric-weight-recipe-1" else { throw AlignmentError.invalid("Unsupported weight recipe") }
        let data=try Data(contentsOf:weights)
        guard SeparationInstaller.hex(SHA256.hash(data:data))==recipe.checkpoint.sha256 else { throw AlignmentError.invalid("Recognition weights SHA-256 differs from the pinned file") }
        var blob=try SeparationInstaller.inflate(Data(contentsOf:template.appendingPathComponent("wav2vec2-skeleton.bin.zlib")),size:recipe.weights.size)
        guard SeparationInstaller.hex(SHA256.hash(data:blob))==recipe.weights.skeleton_sha256 else { throw AlignmentError.invalid("Weight skeleton is corrupted") }
        let tensors=try SafeTensors(data).tensors
        for e in recipe.entries {
            guard let t=tensors[e.key] else { throw AlignmentError.invalid("Weights lack \(e.key)") }
            let values:[Float]
            switch e.kind {
            case "tensor": values=t.values
            case "permute":
                values=try SeparationInstaller.derive(try JSONDecoder().decode(SeparationInstaller.Recipe.Entry.self,from:JSONSerialization.data(withJSONObject:
                    ["offset":e.offset,"size":e.size,"kind":"permute","key":e.key,"axes":e.axes ?? []])),t)
            case "weight_norm":
                // w = v · g / ‖v‖ with the norm over every dimension except `dim`, accumulated in double precision.
                guard let gk=e.g,let g=tensors[gk],e.dim==2,t.shape.count==3 else { throw AlignmentError.invalid("Malformed weight-norm entry") }
                let (a,b,c)=(t.shape[0],t.shape[1],t.shape[2])
                var norms=[Double](repeating:0,count:c)
                for i in 0..<a { for j in 0..<b { for k in 0..<c { let v=Double(t.values[(i*b+j)*c+k]);norms[k]+=v*v } } }
                let factors=(0..<c).map { Float(Double(g.values[$0])/norms[$0].squareRoot()) }
                values=t.values.enumerated().map { $0.element*factors[$0.offset%c] }
            default: throw AlignmentError.invalid("Unsupported weight recipe entry \(e.kind)")
            }
            guard values.count*4==e.size else { throw AlignmentError.invalid("Derived size differs for \(e.key)") }
            let bytes=values.withUnsafeBytes { Data($0) }
            if let expected=e.sha256,SeparationInstaller.hex(SHA256.hash(data:bytes)) != expected { throw AlignmentError.invalid("Weights differ for \(e.key)") }
            blob.replaceSubrange(e.offset..<e.offset+e.size,with:bytes)
        }
        let fm=FileManager.default
        try fm.createDirectory(at:destination,withIntermediateDirectories:true)
        let package=destination.appendingPathComponent("wav2vec2.mlpackage"),compiled=destination.appendingPathComponent("wav2vec2.mlmodelc")
        for url in [package,compiled] where fm.fileExists(atPath:url.path) { try fm.removeItem(at:url) }
        try fm.copyItem(at:template.appendingPathComponent("wav2vec2-template.mlpackage"),to:package)
        let directory=package.appendingPathComponent("Data/com.apple.CoreML/weights")
        try fm.createDirectory(at:directory,withIntermediateDirectories:true)
        try blob.write(to:directory.appendingPathComponent("weight.bin"))
        try fm.moveItem(at:try MLModel.compileModel(at:package),to:compiled)
        try fm.removeItem(at:package)
        try selfTest(compiled,recipe.self_test)
        return compiled
    }

    /// The installed model must reproduce the reference conversion's log-probabilities and frame labels.
    static func selfTest(_ model: URL,_ test: Recipe.SelfTest) throws {
        let configuration=MLModelConfiguration();configuration.computeUnits = .cpuOnly
        let m=try MLModel(contentsOf:model,configuration:configuration)
        let t=(0..<test.samples).map { Double($0)/16000 }
        let raw=t.map { 0.3*sin(2*Double.pi*220*$0)*sin(2*Double.pi*3*$0)+0.1*sin(2*Double.pi*1330*$0) }
        let mean=raw.reduce(0,+)/Double(raw.count),variance=raw.reduce(0.0) { $0+($1-mean)*($1-mean) }/Double(raw.count)
        let x=raw.map { Float(($0-mean)/(variance+1e-7).squareRoot()) }
        let input=try MLMultiArray(shape:[1,NSNumber(value:x.count)],dataType:.float32)
        x.withUnsafeBufferPointer { s in input.withUnsafeMutableBytes { d,_ in d.copyMemory(from:UnsafeRawBufferPointer(s)) } }
        guard let out=try m.prediction(from:MLDictionaryFeatureProvider(dictionary:["input_values":input])).featureValue(for:"log_probs")?.multiArrayValue,
              out.shape[1].intValue==test.frames,out.shape[2].intValue==test.labels else { throw AlignmentError.invalid("Recognition self-test output shape differs") }
        let s1=out.strides[1].intValue,s2=out.strides[2].intValue
        for f in 0..<test.frames {
            var best=0,expectedBest=0
            for k in 0..<test.labels {
                let v=out[f*s1+k*s2].doubleValue,e=test.log_probs[f*test.labels+k]
                guard abs(v-e)<=test.tolerance else { throw AlignmentError.invalid("Recognition self-test differs at frame \(f)") }
                if v>out[f*s1+best*s2].doubleValue { best=k }
                if e>test.log_probs[f*test.labels+expectedBest] { expectedBest=k }
            }
            guard best==expectedBest else { throw AlignmentError.invalid("Recognition self-test labels differ at frame \(f)") }
        }
    }
}

extension Data {
    /// Bytes of an even-length hexadecimal string, or nil when it is malformed.
    init?(hex: String) {
        guard hex.count%2==0 else { return nil }
        var out=Data(capacity:hex.count/2),index=hex.startIndex
        while index<hex.endIndex {
            let next=hex.index(index,offsetBy:2)
            guard let byte=UInt8(hex[index..<next],radix:16) else { return nil }
            out.append(byte);index=next
        }
        self=out
    }
}
