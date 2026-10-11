import Foundation
import CoreML
import CryptoKit
import Compression
import AlignmentCore

/// Rebuilds the HTDemucs Core ML weights on the user's Mac from the official checkpoint and a weightless template,
/// so that iLyric never redistributes the checkpoint's values (docs/core-ml-port-feasibility.md).
public enum SeparationInstaller {
    struct Recipe: Decodable {
        struct Checkpoint: Decodable { let file, sha256, url: String }
        struct Weights: Decodable { let size: Int; let sha256, skeleton_sha256: String }
        struct Entry: Decodable {
            let offset, size: Int; let kind, key: String
            let start, end, bins, frames: Int?; let scale, outer_scale: Double?; let axes: [Int]?
        }
        let format: String; let checkpoint: Checkpoint; let weights: Weights; let entries: [Entry]
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
        let weightsDirectory=package.appendingPathComponent("Data/com.apple.CoreML/weights")
        try fm.createDirectory(at:weightsDirectory,withIntermediateDirectories:true)
        try weights.write(to:weightsDirectory.appendingPathComponent("weight.bin"))
        try fm.moveItem(at:try MLModel.compileModel(at:package),to:compiled)
        try fm.removeItem(at:package)
        return compiled
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
