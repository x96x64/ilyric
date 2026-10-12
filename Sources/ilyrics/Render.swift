import Foundation
import AVFoundation
import LyricsInputCore
import LyricsInputMac
import LyricsSliceCore
import RenderMac
import SpikeCore

/// The `render` subcommand: a Lyrics video from audio and untimed or timed lyrics.
enum Render {
    static let help="""
    Usage: ilyrics render AUDIO LYRICS -o VIDEO.mp4 [options]

    Renders a 1080×1920 Lyrics video. Untimed lyrics (.txt) are aligned automatically first; timed lyrics
    (.ttml, .lrc, Enhanced LRC) are used as supplied.

    Options:
      -o, --output FILE             Output video (.mp4, required)
          --force                   Replace an existing output
          --title TEXT              Header title (default: from the audio file)
          --artist TEXT             Header artist (default: from the audio file)
          --artwork FILE            Artwork image (default: embedded artwork, else a placeholder)
          --background artwork|static
                                    Background style (default: artwork)
          --controls auto-hide|visible
                                    Lower controls (default: auto-hide)
          --no-marquee              Keep an overflowing title static
          --no-gaps                 Omit the instrumental-gap indicator
          --credits TEXT            Songwriters shown after the last line (default: a "Written by:" line in plain lyrics)
          --keep-ad-libs            Keep vocable-only lines that cannot be timed
      -j, --jobs N                  Parallel rendering workers (default: processor count)
          --fast                    GPU and Neural Engine alignment; faster but not reproducible
          --report FILE             Write a JSON report of alignment and export
      -q, --quiet                   Print errors only
      -v, --verbose                 Print step timings and ignored lyrics lines
      -h, --help                    Show this help
    """

    /// Title, artist, and artwork from the audio file's common metadata.
    static func metadata(_ url: URL) async -> (title: String?, artist: String?, artwork: Data?) {
        guard let items=try? await AVURLAsset(url:url).load(.commonMetadata) else { return (nil,nil,nil) }
        func first(_ id: AVMetadataIdentifier) -> AVMetadataItem? { AVMetadataItem.metadataItems(from:items,filteredByIdentifier:id).first }
        let title=try? await first(.commonIdentifierTitle)?.load(.stringValue)
        let artist=try? await first(.commonIdentifierArtist)?.load(.stringValue)
        let artwork=try? await first(.commonIdentifierArtwork)?.load(.dataValue)
        return (title ?? nil,artist ?? nil,artwork ?? nil)
    }

    @MainActor static func command(_ arguments: ArraySlice<String>) async throws {
        let options=try Options(arguments,valued:["output","title","artist","artwork","background","controls","jobs","report","credits"],
                                flags:["help","force","no-marquee","no-gaps","keep-ad-libs","fast","quiet","verbose"],
                                short:["o":"output","j":"jobs","h":"help","q":"quiet","v":"verbose"])
        if options.has("help") { print(help);return }
        guard options.operands.count==2 else { throw UsageError(message:"expected AUDIO and LYRICS") }
        guard let output=options.values["output"] else { throw UsageError(message:"missing -o, --output") }
        guard URL(fileURLWithPath:output).pathExtension.lowercased()=="mp4" else { throw UsageError(message:"the output must be an .mp4 file") }
        let background=options.values["background"] ?? "artwork",controls=options.values["controls"] ?? "auto-hide"
        guard ["artwork","static"].contains(background) else { throw UsageError(message:"--background takes artwork or static") }
        guard ["auto-hide","visible"].contains(controls) else { throw UsageError(message:"--controls takes auto-hide or visible") }
        let jobs=options.values["jobs"].map { Int($0) ?? 0 } ?? max(1,ProcessInfo.processInfo.activeProcessorCount)
        guard (1...64).contains(jobs) else { throw UsageError(message:"--jobs takes a number from 1 to 64") }
        let console=Console(quiet:options.has("quiet"),verbose:options.has("verbose"))
        let audioURL=URL(fileURLWithPath:options.operands[0]),lyricsURL=URL(fileURLWithPath:options.operands[1])
        for url in [audioURL,lyricsURL]+(options.values["artwork"].map { [URL(fileURLWithPath:$0)] } ?? []) where !FileManager.default.fileExists(atPath:url.path) {
            throw Failure(message:"\(url.path) does not exist")
        }
        let target=try checkOutput(output,force:options.has("force")).standardizedFileURL
        let started=Date()

        // Lyrics: align untimed text, or parse supplied timing.
        var report:[String:Any]=["format":"ilyrics-render-report-1"]
        let lyrics:LocalLyrics
        var credits=options.values["credits"]
        do {
            switch lyricsURL.pathExtension.lowercased() {
            case "ttml": lyrics=try LyricsParser.parse(LocalFile.boundedData(lyricsURL,limit:LRCParser.byteLimit,label:"Lyrics"),format:.ttml)
            case "lrc":
                let data=try LocalFile.boundedData(lyricsURL,limit:LRCParser.byteLimit,label:"Lyrics")
                let enhanced=String(decoding:data,as:UTF8.self).range(of:"<[0-9]+:[0-9]+(\\.[0-9]+)?>",options:.regularExpression) != nil
                lyrics=try LyricsParser.parse(data,format:enhanced ? .enhancedLRC : .lrc)
            default:
                let aligned=try await Align.run(audio:audioURL,lyrics:lyricsURL,keepAdLibs:options.has("keep-ad-libs"),fast:options.has("fast"),console:console)
                console.say("Aligned \(aligned.resolved) lines, placed \(aligned.placed), omitted \(aligned.omitted)")
                report["alignment"]=aligned.report
                credits=credits ?? aligned.credits
                lyrics=try LyricsParser.parse(Data(aligned.ttml.utf8),format:.ttml)
            }
        } catch let error as InputError { throw Failure(message:"the lyrics could not be read: \(error)") }
        for diagnostic in lyrics.diagnostics { console.detail("Lyrics: \(diagnostic)") }

        // Header and artwork: options first, then the audio file's metadata.
        let tags=await metadata(audioURL)
        let artwork:LocalArtwork?
        do {
            if let path=options.values["artwork"] { artwork=try LocalArtwork.decode(URL(fileURLWithPath:path)) }
            else { artwork=try tags.artwork.map { try LocalArtwork.decode(data:$0) } }
        } catch { throw Failure(message:"the artwork could not be decoded: \(error)") }
        if artwork==nil { console.say("No artwork found; using the placeholder artwork (pass --artwork FILE to supply one)") }

        var presentation=LocalPresentation(background:background=="artwork" ? .fitted : nil,icons:.systemSymbols,
            minimumGap:options.has("no-gaps") ? nil : Time(4),
            focusLead:LocalPresentation.measuredMotion.focusLead,stagger:LocalPresentation.measuredMotion.stagger,
            marquee:options.has("no-marquee") ? nil : .measured,wordMotion:.measured,fillLead:LocalPresentation.measuredFillLead,
            hideControls:controls=="auto-hide" ? LocalPresentation.measuredControlHide : nil)
        presentation.holdsFinishedLine=true;presentation.collapsesGaps=true

        let audio:LocalAudio,scene:LocalScene
        do {
            audio=try await LocalAudio.decode(audioURL)
            scene=try LocalScene(lyrics:lyrics,audio:audio,artwork:artwork?.image ?? PlaceholderArtwork.image(),highlighting:.enabled,presentation:presentation,
                                 title:options.values["title"] ?? tags.title ?? audioURL.deletingPathExtension().lastPathComponent,
                                 artist:options.values["artist"] ?? tags.artist ?? "",credits:credits,placeholderArtwork:artwork==nil)
        } catch let error as InputError { throw Failure(message:"\(error)") }

        // Each worker owns one renderer; frames are pure functions of time, so output does not depend on the count.
        let renderers=try [scene.renderer]+(1..<jobs).map { _ in try scene.makeRenderer() }
        renderers.forEach { $0.enableGPUScaling() }
        let frames=scene.schedule.frames,progress=Progress(total:frames,console:console)
        console.say("Rendering \(frames) frames with \(jobs) workers")
        let temporary=target.deletingLastPathComponent().appendingPathComponent(".ilyrics-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at:temporary) }
        let metrics=try await Exporter.video(width:1080,height:1920,to:temporary,frames:frames,
            workers:renderers.map { r in { time,context in try r.draw(time,into:context);progress.advance() } },
            audioChannels:audio.channels,audioSample:{ audio.interleavedSample($0) })
        progress.finish()
        if FileManager.default.fileExists(atPath:target.path) { _=try FileManager.default.replaceItemAt(target,withItemAt:temporary) }
        else { try FileManager.default.moveItem(at:temporary,to:target) }
        report["export"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode(metrics))
        report["frames"]=frames;report["jobs"]=jobs
        try Align.writeReport(report,to:options.values["report"])
        console.say("Wrote \(output) in \(elapsed(Date().timeIntervalSince(started)))")
    }
}

/// Thread-safe frame progress on standard error, updated in whole percent.
final class Progress: @unchecked Sendable {
    let total: Int, console: Console, terminal=isatty(2) != 0
    private var done=0,shown = -1
    private let lock=NSLock()
    init(total: Int, console: Console) { self.total=total;self.console=console }
    func advance() {
        lock.lock();defer { lock.unlock() }
        done+=1
        let percent=done*100/total
        guard percent != shown,!console.quiet,terminal || percent%10==0 else { return }
        shown=percent
        FileHandle.standardError.write(Data((terminal ? "\r  \(percent)%" : "  \(percent)%\n").utf8))
    }
    func finish() { if terminal && !console.quiet { FileHandle.standardError.write(Data("\n".utf8)) } }
}
