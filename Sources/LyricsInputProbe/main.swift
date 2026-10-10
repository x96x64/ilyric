import Foundation
import LyricsInputCore
import LyricsInputMac
import LyricsSliceCore
import RenderMac
import SpikeCore

@main struct Probe {
    @MainActor static func main() async {
        var exporting=false
        do {
            let args=Array(CommandLine.arguments.dropFirst())
            let help="Experimental: LyricsInputProbe render --lyrics FILE.lrc --audio FILE --output FILE.mp4 [--format enhanced-lrc|ttml --highlighting enabled|disabled] | project --project FILE.json --output FILE.mp4; either mode accepts [--background fitted|static] [--icons original|system-symbols] [--gaps auto|none]"
            if args==["--help"] { print(help);return }
            let projectMode=args.first=="project"
            guard args.first=="render" || projectMode,args.count%2==1 else { throw InputError.invalid(help) }
            let presentationOptions=["--background","--icons","--gaps"]
            let allowed=(projectMode ? ["--project","--output"] : ["--lyrics","--audio","--output","--format","--highlighting"])+presentationOptions
            var options:[String:String]=[:]
            for i in stride(from:1,to:args.count,by:2) {
                guard allowed.contains(args[i]),options[args[i]]==nil else { throw InputError.invalid("Unknown or repeated option. "+help) }
                options[args[i]]=args[i+1]
            }
            guard let path=options["--output"] else { throw InputError.invalid(help) }
            guard ["fitted","static",nil].contains(options["--background"]),["original","system-symbols",nil].contains(options["--icons"]),
                  ["auto","none",nil].contains(options["--gaps"]) else { throw InputError.invalid(help) }
            let presentation=LocalPresentation(background:options["--background"]=="fitted" ? .fitted : nil,
                icons:options["--icons"]=="system-symbols" ? .systemSymbols : .original,
                minimumGap:options["--gaps"]=="auto" ? Time(4) : nil)
            if presentation.icons == .systemSymbols { FileHandle.standardError.write(Data("LyricsInputProbe: SF Symbols are resolved at runtime; Apple terms do not expressly license them in exported videos.\n".utf8)) }
            let output=URL(fileURLWithPath:path).standardizedFileURL,parent=output.deletingLastPathComponent()
            var directory:ObjCBool=false
            guard output.pathExtension.lowercased()=="mp4",FileManager.default.fileExists(atPath:parent.path,isDirectory:&directory),directory.boolValue,FileManager.default.isWritableFile(atPath:parent.path),
                  !FileManager.default.fileExists(atPath:output.path) else { throw InputError.invalid("Output must be a new .mp4 in an existing directory") }
            let scene:LocalScene,artworkInfo:ArtworkInfo?
            var version=0,highlighting=Highlighting.enabled
            do {
                if projectMode {
                    guard let file=options["--project"] else { throw InputError.invalid(help) }
                    let prepared=try await PreparedProject.load(URL(fileURLWithPath:file),presentation:presentation)
                    scene=prepared.scene;artworkInfo=prepared.artworkInfo;version=prepared.project.version;highlighting=prepared.project.highlighting
                } else {
                    guard let lrc=options["--lyrics"],let audioPath=options["--audio"] else { throw InputError.invalid(help) }
                    guard let format=LyricsFormat(rawValue:options["--format"] ?? "lrc"),
                          let mode=Highlighting(rawValue:options["--highlighting"] ?? "enabled") else { throw InputError.invalid("Use --format lrc|enhanced-lrc|ttml and --highlighting enabled|disabled") }
                    guard options["--highlighting"]==nil || format != .lrc else { throw InputError.invalid("--highlighting requires --format enhanced-lrc or ttml") }
                    highlighting=mode
                    let lyrics=try LyricsParser.parse(LocalFile.boundedData(URL(fileURLWithPath:lrc),limit:LRCParser.byteLimit,label:"Lyrics"),format:format)
                    let audio=try await LocalAudio.decode(URL(fileURLWithPath:audioPath))
                    scene=try LocalScene(lyrics:lyrics,audio:audio,highlighting:highlighting,presentation:presentation);artworkInfo=nil
                }
            } catch let error as SliceError { throw InputError.invalid("Paragraph layout or timed source range is unsupported: \(error)") }
            let lyrics=scene.lyrics,audio=scene.audio
            for diagnostic in lyrics.diagnostics { FileHandle.standardError.write(Data(("LyricsInputProbe: "+diagnostic+"\n").utf8)) }
            exporting=true
            let result=try await Exporter.video(width:1080,height:1920,to:output,frames:scene.schedule.frames,
                draw:{try scene.renderer.draw($0,into:$1)},audioSample:{audio.sample($0)})
            let record:[String:Any]=["status":"experimental","project_version":version,"artwork":artworkInfo.map { ["width":$0.width,"height":$0.height,"reported_color_profile":$0.reportedColorProfile] as [String:Any] } ?? [:],"export":try JSONSerialization.jsonObject(with:JSONEncoder().encode(result)),
                "lyric_events":lyrics.entries.count,"paragraphs":scene.renderer.lyrics.paragraphs.count,"offset_milliseconds":lyrics.offsetMilliseconds,
                "audio_samples":audio.sampleCount,"source_sample_rate":audio.sourceRate,"source_channels":audio.sourceChannels,"source_format":audio.sourceFormat,
                "output_padding_samples":scene.schedule.frames*800-audio.sampleCount,"timing":lyrics.entries.contains(where:{!$0.segments.isEmpty}) ? "supplied-segment-boundaries" : "supplied-line-level","highlighting":highlighting.rawValue,"timed_segments":lyrics.entries.reduce(0) { $0+$1.segments.count },"delivery":"contain",
                "focus_events":scene.renderer.screen.composition.events.map { ["numerator":$0.time.numerator,"denominator":$0.time.denominator,"paragraph":Int64($0.paragraph)] },
                "final_focus":scene.renderer.screen.evaluate(scene.schedule.outputEnd-Time(1,60)).lyrics.focus]
            print(String(data:try JSONSerialization.data(withJSONObject:record,options:[.sortedKeys]),encoding:.utf8)!)
        } catch {
            FileHandle.standardError.write(Data("LyricsInputProbe: \(error)\n".utf8));exit(exporting ? 1 : 2)
        }
    }
}
