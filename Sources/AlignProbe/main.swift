import Foundation
import AlignmentCore
import AlignmentMac

// Development probe: align untimed lyrics to a 16-kHz vocal stem with the Core ML recognition model and print JSON.
// Usage: AlignProbe MODEL.mlpackage VOCAB.json LYRICS.txt VOCALS.wav DURATION_US
let args=CommandLine.arguments
guard args.count==6,let duration=Int(args[5]) else {
    FileHandle.standardError.write(Data("Usage: AlignProbe MODEL VOCAB LYRICS VOCALS DURATION_US\n".utf8));exit(2)
}
do {
    let started=Date()
    let model=try RecognitionModel(modelURL:URL(fileURLWithPath:args[1]),vocabularyURL:URL(fileURLWithPath:args[2]))
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
