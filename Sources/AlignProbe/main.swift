import Foundation
import AlignmentCore
import AlignmentMac
import CoreML

// Development probe: align untimed lyrics to a 16-kHz vocal stem with the Core ML recognition model and print JSON.
// Usage: AlignProbe MODEL.mlpackage VOCAB.json LYRICS.txt VOCALS.wav DURATION_US
let args=CommandLine.arguments
// ILYRIC_COMPUTE_UNITS=cpu|gpu|all selects Core ML compute units for development comparisons; cpu is the default.
let units:MLComputeUnits={ switch ProcessInfo.processInfo.environment["ILYRIC_COMPUTE_UNITS"] { case "gpu": return .cpuAndGPU; case "all": return .all; default: return .cpuOnly } }()
// Installation mode: AlignProbe install TEMPLATE_DIR CHECKPOINT.th DESTINATION_DIR
if args.count==5,args[1]=="install" {
    do {
        let started=Date()
        let url=try SeparationInstaller.install(template:URL(fileURLWithPath:args[2]),checkpoint:URL(fileURLWithPath:args[3]),destination:URL(fileURLWithPath:args[4]))
        print("{\"model\":\"\(url.path)\",\"seconds\":\(Date().timeIntervalSince(started))}")
    } catch { FileHandle.standardError.write(Data("AlignProbe: \(error)\n".utf8));exit(1) }
    exit(0)
}
// Separation mode: AlignProbe separate NETWORK.mlpackage MIX.f32 EXPECTED_SAMPLES OUT.f32
// MIX.f32 is interleaved stereo 44.1-kHz float32 PCM; OUT.f32 receives mono 16-kHz float32 vocals.
if args.count==6,args[1]=="separate",let expected=Int(args[4]) {
    do {
        let started=Date()
        let separator=try VocalSeparator(modelURL:URL(fileURLWithPath:args[2]),computeUnits:units)
        let raw=try Data(contentsOf:URL(fileURLWithPath:args[3]))
        let interleaved=raw.withUnsafeBytes { Array($0.bindMemory(to:Float.self)) }
        let left=stride(from:0,to:interleaved.count,by:2).map { interleaved[$0] },right=stride(from:1,to:interleaved.count,by:2).map { interleaved[$0] }
        let vocals=try separator.vocals16k(left:left,right:right,expectedSamples:expected)
        try vocals.withUnsafeBufferPointer { Data(buffer:$0) }.write(to:URL(fileURLWithPath:args[5]))
        print("{\"samples\":\(vocals.count),\"seconds\":\(Date().timeIntervalSince(started))}")
    } catch { FileHandle.standardError.write(Data("AlignProbe: \(error)\n".utf8));exit(1) }
    exit(0)
}
guard args.count==6,let duration=Int(args[5]) else {
    FileHandle.standardError.write(Data("Usage: AlignProbe MODEL VOCAB LYRICS VOCALS DURATION_US\n".utf8));exit(2)
}
do {
    let started=Date()
    let model=try RecognitionModel(modelURL:URL(fileURLWithPath:args[1]),vocabularyURL:URL(fileURLWithPath:args[2]),computeUnits:units)
    let loaded=Date()
    let vocals=try readMono16k(URL(fileURLWithPath:args[4]))
    let rows=try alignLyrics(Data(contentsOf:URL(fileURLWithPath:args[3])),vocals:vocals,durationMicroseconds:duration,model:model)
    let lines:[[String:Any]]=rows.map { r in
        var d:[String:Any]=["id":r.id,"flags":r.flags]
        d["proposal"]=r.proposal ?? NSNull();d["estimate"]=r.estimate ?? NSNull()
        d["support"]=r.support ?? NSNull();d["similarity"]=r.similarity ?? NSNull()
        d["word_estimates"]=r.wordEstimates.map { $0.map { ["start_utf16":$0.startUTF16,"length_utf16":$0.lengthUTF16,"interval_us":$0.interval] } } ?? NSNull()
        return d
    }
    let out:[String:Any]=["samples":vocals.count,"load_seconds":loaded.timeIntervalSince(started),"align_seconds":Date().timeIntervalSince(loaded),"lines":lines]
    print(String(data:try JSONSerialization.data(withJSONObject:out,options:[.sortedKeys]),encoding:.utf8)!)
} catch { FileHandle.standardError.write(Data("AlignProbe: \(error)\n".utf8));exit(1) }
