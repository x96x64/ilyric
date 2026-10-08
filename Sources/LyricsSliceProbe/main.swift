// Experimental developer invocation; deliberately separate from ilyric.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import LyricsSliceCore
import LyricsSliceMac
import SpikeCore

func canonical(_ url:URL) -> URL {
    if FileManager.default.fileExists(atPath:url.path) { return url.resolvingSymlinksInPath() }
    let parent=url.deletingLastPathComponent()
    return parent.path == url.path ? url.standardizedFileURL : canonical(parent).appendingPathComponent(url.lastPathComponent)
}
func save(_ image:CGImage,_ url:URL) throws {
    guard let writer=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil) else { throw SliceError.invalid("PNG destination") }
    CGImageDestinationAddImage(writer,image,nil)
    guard CGImageDestinationFinalize(writer) else { throw SliceError.invalid("PNG write") }
}
struct Output: Encodable {
    let status:String
    let width:Int
    let height=2556
    let timestamp:SliceTime
    let fonts:[String]
    let lines:[SliceLine]
    let spans:[SpanPresentation]
}
do {
    let args=CommandLine.arguments
    guard args.count==5, let n=Int64(args[2]),let d=Int64(args[3]) else { throw SliceError.invalid("Usage: LyricsSliceProbe synthetic|synthetic-soft|synthetic-latin|input.json numerator denominator output-directory") }
    let time=try SliceTime(n,d).validated(),root=canonical(URL(fileURLWithPath:FileManager.default.currentDirectoryPath))
    let output=canonical(URL(fileURLWithPath:args[4],isDirectory:true))
    let input:SliceInput
    if ["synthetic","synthetic-soft","synthetic-latin"].contains(args[1]) {
        guard output.path.hasPrefix(root.appendingPathComponent("artifacts").path+"/") else { throw SliceError.invalid("Synthetic outputs belong in artifacts") }
        input = args[1]=="synthetic-latin" ? .latin() : .synthetic(softened:args[1]=="synthetic-soft")
    } else {
        let source=canonical(URL(fileURLWithPath:args[1]))
        guard ["reference-private","artifacts"].contains(where:{ directory in
            let prefix=root.appendingPathComponent(directory).path+"/"
            return source.path.hasPrefix(prefix) && output.path.hasPrefix(prefix)
        }) else { throw SliceError.invalid("Keep experimental input and output together under reference-private or artifacts") }
        input=try JSONDecoder().decode(SliceInput.self,from:Data(contentsOf:source))
    }
    let paragraph=try SliceParagraph(input),state=input.evaluate(time)
    try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
    try save(paragraph.render(state),output.appendingPathComponent("appearance.png"))
    try save(paragraph.render(state,coverage:true),output.appendingPathComponent("coverage.png"))
    let result=Output(status:"experimental",width:input.canvasWidth,timestamp:SliceTime(time.numerator,time.denominator),fonts:paragraph.fonts,lines:paragraph.lines,spans:state.spans)
    let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
    try encoder.encode(result).write(to:output.appendingPathComponent("state.json"))
} catch {
    FileHandle.standardError.write(Data("LyricsSliceProbe: \(error)\n".utf8));exit(1)
}
