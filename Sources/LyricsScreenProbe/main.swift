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
            if args.count==2 && args[1]=="timeline" {
                let screen=try LyricsScreen.synthetic()
                let rows=(0..<360).map { i -> [String:Any] in
                    let state=screen.evaluate(Time(Int64(i),60))
                    return ["frame":i,"scroll":state.lyrics.scroll,"velocity":state.lyrics.velocity,
                        "focus":state.lyrics.focus,"media":state.lyrics.media.seconds,
                        "visible":state.components.filter(\.visible).map { $0.part.rawValue },
                        "opacity":state.lyrics.paragraphs.map(\.opacity),
                        "translation":state.lyrics.paragraphs.map(\.translationY)]
                }
                print(String(data:try JSONSerialization.data(withJSONObject:rows,options:[.sortedKeys]),encoding:.utf8)!)
                return
            }
            if args.count==5 && args[1]=="background-frames" {
                // Development parity check: background-only frames from a supplied artwork, 5 fps, raw RGB at 295×639.
                guard let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:args[2]) as CFURL,nil),
                      let art=CGImageSourceCreateImageAtIndex(source,0,nil),let seconds=Int(args[3]),(1...60).contains(seconds) else {
                    throw SliceError.invalid("background-frames ARTWORK.png SECONDS OUTPUT.raw") }
                let backdrop=ArtworkBackdrop(.fitted,artwork:art,canvasWidth:1180,canvasHeight:2556)
                var bytes=Data()
                for i in 0..<(seconds*5) {
                    let image=backdrop.image(at:Time(Int64(i),5))
                    let c=CGContext(data:nil,width:295,height:639,bitsPerComponent:8,bytesPerRow:295*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,
                                    bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
                    c.interpolationQuality = .high;c.draw(image,in:CGRect(x:0,y:0,width:295,height:639))
                    let rgba=[UInt8](Data(bytes:c.data!,count:295*639*4))
                    for p in 0..<(295*639) { bytes.append(contentsOf:rgba[(p*4)..<(p*4+3)]) }
                }
                try bytes.write(to:URL(fileURLWithPath:args[4]),options:.withoutOverwriting)
                return
            }
            guard args.count>=3 else { throw SliceError.invalid("Usage: LyricsScreenProbe timeline | native[-inactive][-background]|still[-inactive][-background] numerator denominator output.png | video[-inactive][-progression][-background] output.mp4") }
            let output=URL(fileURLWithPath:args.last!).standardizedFileURL
            let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("artifacts").resolvingSymlinksInPath()
            let parent=output.deletingLastPathComponent().resolvingSymlinksInPath()
            guard parent.path==root.path || parent.path.hasPrefix(root.path+"/"),
                  FileManager.default.fileExists(atPath:parent.path), !FileManager.default.fileExists(atPath:output.path) else { throw SliceError.invalid("Use a new output in an existing artifacts directory") }
            var commands:Set<String>=[]
            for base in ["native","still","video"] { for mode in ["","-inactive","-progression","-inactive-progression"] {
                for suffix in ["","-background","-symbols","-background-symbols"] { commands.insert(base+mode+suffix) }
            }}
            guard commands.contains(args[1]) else { throw SliceError.invalid("Invalid experimental command") }
            let calibrated=args[1].contains("-inactive")
            let progression=args[1].contains("-progression")
            let background=args[1].contains("-background") ? ArtworkBackground.fitted : nil
            let icons:ScreenIconSet=args[1].hasSuffix("-symbols") ? .systemSymbols : .original
            let command=args[1].replacingOccurrences(of:"-inactive",with:"").replacingOccurrences(of:"-progression",with:"").replacingOccurrences(of:"-background",with:"").replacingOccurrences(of:"-symbols",with:"")
            let scene=try progression ? LyricsScreen(composition:.progressionDemonstration(),title:"Paper Skies",artist:"Field Notes",duration:Time(8),volume:0.62,
                events:[.init(Time(0),order:0,controls:.init())],background:background) : .synthetic(background:background)
            let renderer=try ScreenRenderer(scene,calibratedInactive:calibrated,icons:icons)
            if icons == .systemSymbols { FileHandle.standardError.write(Data("LyricsScreenProbe: SF Symbols are resolved at runtime; Apple terms do not expressly license them in exported videos.\n".utf8)) }
            if ["still","native"].contains(command),args.count==5,let n=Int64(args[2]),let d=Int64(args[3]) {
                let time=try SliceTime(n,d).validated(),image=try (command=="native" ? renderer.native(renderer.screen.evaluate(time)):renderer.frame(time))
                guard let writer=CGImageDestinationCreateWithURL(output as CFURL,UTType.png.identifier as CFString,1,nil) else { throw SliceError.invalid("PNG output") }
                CGImageDestinationAddImage(writer,image,nil)
                guard CGImageDestinationFinalize(writer) else { throw SliceError.invalid("PNG write") }
                let state=renderer.screen.composition.evaluate(time)
                let record:[String:Any]=["status":"experimental","width":image.width,"height":image.height,
                    "numerator":time.numerator,"denominator":time.denominator,"focus":state.focus,
                    "scroll":state.scroll,"velocity":state.velocity,"media_seconds":state.media.seconds,
                    "components":try JSONSerialization.jsonObject(with:JSONEncoder().encode(renderer.screen.evaluate(time).components))]
                print(String(data:try JSONSerialization.data(withJSONObject:record,options:[.sortedKeys]),encoding:.utf8)!)
            } else if command=="video",args.count==3 {
                let result=try await Exporter.video(width:1080,height:1920,to:output,frames:progression ? 480 : 360,
                    draw:{ try renderer.draw($0,into:$1) },audioSample:{ renderer.screen.composition.audioSample($0) })
                let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
                print(String(data:try encoder.encode(result),encoding:.utf8)!)
            } else { throw SliceError.invalid("Invalid experimental invocation") }
        } catch { FileHandle.standardError.write(Data("LyricsScreenProbe: \(error)\n".utf8));exit(1) }
    }
}
