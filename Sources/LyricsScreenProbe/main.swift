import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import LyricsSliceCore
import LyricsSliceMac
import SpikeCore
import RenderMac

@main struct Probe {
    @MainActor static func main() async {
        do {
            let args=CommandLine.arguments
            guard args.count>=3 else { throw SliceError.invalid("Usage: LyricsScreenProbe native|still numerator denominator output.png | video output.mp4") }
            let output=URL(fileURLWithPath:args.last!).standardizedFileURL
            let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("artifacts").resolvingSymlinksInPath()
            let parent=output.deletingLastPathComponent().resolvingSymlinksInPath()
            guard parent.path==root.path || parent.path.hasPrefix(root.path+"/"),
                  FileManager.default.fileExists(atPath:parent.path), !FileManager.default.fileExists(atPath:output.path) else { throw SliceError.invalid("Use a new output in an existing artifacts directory") }
            let renderer=try ScreenRenderer(.synthetic())
            if ["still","native"].contains(args[1]),args.count==5,let n=Int64(args[2]),let d=Int64(args[3]) {
                let time=try SliceTime(n,d).validated(),image=try (args[1]=="native" ? renderer.native(renderer.screen.evaluate(time)):renderer.frame(time))
                guard let writer=CGImageDestinationCreateWithURL(output as CFURL,UTType.png.identifier as CFString,1,nil) else { throw SliceError.invalid("PNG output") }
                CGImageDestinationAddImage(writer,image,nil)
                guard CGImageDestinationFinalize(writer) else { throw SliceError.invalid("PNG write") }
                let state=renderer.screen.composition.evaluate(time)
                let record:[String:Any]=["status":"experimental","width":image.width,"height":image.height,
                    "numerator":time.numerator,"denominator":time.denominator,"focus":state.focus,
                    "scroll":state.scroll,"velocity":state.velocity,"media_seconds":state.media.seconds,
                    "components":try JSONSerialization.jsonObject(with:JSONEncoder().encode(renderer.screen.evaluate(time).components))]
                print(String(data:try JSONSerialization.data(withJSONObject:record,options:[.sortedKeys]),encoding:.utf8)!)
            } else if args[1]=="video",args.count==3 {
                let result=try await Exporter.video(width:1080,height:1920,to:output,frames:360,
                    draw:{ try renderer.draw($0,into:$1) },audioSample:{ renderer.screen.composition.audioSample($0) })
                let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
                print(String(data:try encoder.encode(result),encoding:.utf8)!)
            } else { throw SliceError.invalid("Invalid experimental invocation") }
        } catch { FileHandle.standardError.write(Data("LyricsScreenProbe: \(error)\n".utf8));exit(1) }
    }
}
