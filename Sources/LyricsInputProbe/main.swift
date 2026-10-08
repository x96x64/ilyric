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
            let help="Experimental: LyricsInputProbe render --lyrics FILE.lrc --audio FILE --output FILE.mp4"
            if args==["--help"] { print(help);return }
            guard args.first=="render",args.count==7 else { throw InputError.invalid(help) }
            var options:[String:String]=[:]
            for i in stride(from:1,to:args.count,by:2) {
                guard ["--lyrics","--audio","--output"].contains(args[i]),options[args[i]]==nil else { throw InputError.invalid("Unknown or repeated option. "+help) }
                options[args[i]]=args[i+1]
            }
            guard let lrc=options["--lyrics"],let audioPath=options["--audio"],let path=options["--output"] else { throw InputError.invalid(help) }
            let output=URL(fileURLWithPath:path).standardizedFileURL,parent=output.deletingLastPathComponent()
            var directory:ObjCBool=false
            guard output.pathExtension.lowercased()=="mp4",FileManager.default.fileExists(atPath:parent.path,isDirectory:&directory),directory.boolValue,
                  !FileManager.default.fileExists(atPath:output.path) else { throw InputError.invalid("Output must be a new .mp4 in an existing directory") }
            let lyricsURL=URL(fileURLWithPath:lrc)
            guard let size=try? lyricsURL.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey]),size.isRegularFile==true,
                  let count=size.fileSize,count<=LRCParser.byteLimit else { throw InputError.invalid("Lyrics file is missing, inaccessible, or exceeds 64 KiB") }
            let handle:FileHandle
            do { handle=try FileHandle(forReadingFrom:lyricsURL) }
            catch { throw InputError.invalid("Lyrics file is inaccessible") }
            let data:Data
            do { data=try handle.read(upToCount:LRCParser.byteLimit+1) ?? Data();try handle.close() }
            catch { try? handle.close();throw InputError.invalid("Lyrics file could not be read") }
            let lyrics=try LRCParser.parse(data)
            for diagnostic in lyrics.diagnostics { FileHandle.standardError.write(Data(("LyricsInputProbe: "+diagnostic+"\n").utf8)) }
            let audio=try await LocalAudio.decode(URL(fileURLWithPath:audioPath))
            let scene:LocalScene
            do { scene=try LocalScene(lyrics:lyrics,audio:audio) }
            catch let error as SliceError { throw InputError.invalid("Paragraph layout is outside the experimental four-line bounds: \(error)") }
            exporting=true
            let result=try await Exporter.video(width:1080,height:1920,to:output,frames:scene.schedule.frames,
                draw:{try scene.renderer.draw($0,into:$1)},audioSample:{audio.sample($0)})
            let record:[String:Any]=["status":"experimental","export":try JSONSerialization.jsonObject(with:JSONEncoder().encode(result)),
                "lyric_events":lyrics.entries.count,"paragraphs":scene.renderer.lyrics.paragraphs.count,"offset_milliseconds":lyrics.offsetMilliseconds,
                "audio_samples":audio.sampleCount,"source_sample_rate":audio.sourceRate,"source_channels":audio.sourceChannels,"source_format":audio.sourceFormat,
                "output_padding_samples":scene.schedule.frames*800-audio.sampleCount,"timing":"supplied-line-level","delivery":"contain",
                "focus_events":scene.renderer.screen.composition.events.map { ["numerator":$0.time.numerator,"denominator":$0.time.denominator,"paragraph":Int64($0.paragraph)] },
                "final_focus":scene.renderer.screen.evaluate(scene.schedule.outputEnd-Time(1,60)).lyrics.focus]
            print(String(data:try JSONSerialization.data(withJSONObject:record,options:[.sortedKeys]),encoding:.utf8)!)
        } catch {
            FileHandle.standardError.write(Data("LyricsInputProbe: \(error)\n".utf8));exit(exporting ? 1 : 2)
        }
    }
}
