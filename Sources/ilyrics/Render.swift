import Foundation
import AlignmentCore
import ProgressDisplay
import AVFoundation
import LyricsInputCore
import LyricsInputMac
import LyricsScreenCore
import VideoExport
import TimelineCore

/// The `render` subcommand: a Lyrics video from audio and untimed or timed lyrics.
enum Render {
    static let help = """
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
              --safe-area none|reels    Keep controls and lyrics clear of the sides that Instagram Reels crops
                                        (default: none)
              --no-marquee              Keep an overflowing title static
              --no-gaps                 Omit the instrumental-gap indicator
              --credits TEXT            Songwriters shown after the last line (default: a "Written by:" line in plain lyrics)
              --keep-ad-libs            Keep vocable-only lines that cannot be timed
              --language en|ja          Language of untimed lyrics; ja is experimental (default: en)
          -j, --jobs N                  Parallel rendering workers (default: processor count)
              --fast                    GPU and Neural Engine alignment; faster but not reproducible
              --report FILE             Write a JSON report of alignment and export
          -q, --quiet                   Print only warnings and errors
          -v, --verbose                 Also print step details, timings, and untimed lines
          -h, --help                    Show this help
        """

    /// Title, artist, and artwork from the audio file's common metadata.
    static func metadata(_ url: URL) async -> (title: String?, artist: String?, artwork: Data?) {
        guard let items = try? await AVURLAsset(url: url).load(.commonMetadata) else { return (nil, nil, nil) }
        func first(_ id: AVMetadataIdentifier) -> AVMetadataItem? {
            AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id).first
        }
        func text(_ id: AVMetadataIdentifier) async -> String? {
            let value = (try? await first(id)?.load(.stringValue)) ?? nil
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        let artwork = try? await first(.commonIdentifierArtwork)?.load(.dataValue)
        return (await text(.commonIdentifierTitle), await text(.commonIdentifierArtist), artwork ?? nil)
    }

    /// The header holds at most this many UTF-16 units per label.
    static let headerLimit = 80

    /// A header label from metadata or a file name, shortened with an ellipsis to the header limit.
    static func headerLabel(_ text: String) -> String {
        guard text.utf16.count > headerLimit else { return text }
        var result = ""
        for character in text {
            guard result.utf16.count + String(character).utf16.count < headerLimit else { break }
            result.append(character)
        }
        return result + "…"
    }

    @MainActor static func command(_ arguments: ArraySlice<String>) async throws {
        let options = try Options(
            arguments,
            valued: [
                "output", "title", "artist", "artwork", "background", "controls", "safe-area", "jobs", "report",
                "credits", "language",
            ],
            flags: ["help", "force", "no-marquee", "no-gaps", "keep-ad-libs", "fast", "quiet", "verbose"],
            short: ["o": "output", "j": "jobs", "h": "help", "q": "quiet", "v": "verbose"])
        if options.has("help") {
            print(help)
            return
        }
        guard options.operands.count == 2 else { throw UsageError(message: "expected AUDIO and LYRICS") }
        guard let output = options.values["output"] else { throw UsageError(message: "missing -o, --output") }
        guard URL(fileURLWithPath: output).pathExtension.lowercased() == "mp4" else {
            throw UsageError(message: "the output must be an .mp4 file")
        }
        let background = options.values["background"] ?? "artwork"
        let controls = options.values["controls"] ?? "auto-hide"
        guard ["artwork", "static"].contains(background) else {
            throw UsageError(message: "--background takes artwork or static")
        }
        guard ["auto-hide", "visible"].contains(controls) else {
            throw UsageError(message: "--controls takes auto-hide or visible")
        }
        let safeArea = options.values["safe-area"] ?? "none"
        guard ["none", "reels"].contains(safeArea) else {
            throw UsageError(message: "--safe-area takes none or reels")
        }
        let language = try Align.language(options)
        let jobs = options.values["jobs"].map { Int($0) ?? 0 } ?? max(1, ProcessInfo.processInfo.activeProcessorCount)
        guard (1...64).contains(jobs) else { throw UsageError(message: "--jobs takes a number from 1 to 64") }
        let console = Console(
            quiet: options.has("quiet"), verbose: options.has("verbose"), stages: Align.stages + ["Rendering video"])
        defer { console.progress.close() }
        let progress = console.progress
        let audioURL = URL(fileURLWithPath: options.operands[0])
        let lyricsURL = URL(fileURLWithPath: options.operands[1])
        for url in [audioURL, lyricsURL] + (options.values["artwork"].map { [URL(fileURLWithPath: $0)] } ?? [])
        where !FileManager.default.fileExists(atPath: url.path) {
            throw Failure(message: "\(url.relativePath) does not exist")
        }
        let inputs = options.operands + (options.values["artwork"].map { [$0] } ?? [])
        let target = try checkOutput(output, force: options.has("force"), inputs: inputs).standardizedFileURL
        if let path = options.values["report"] {
            _ = try checkOutput(path, force: options.has("force"), inputs: inputs + [output])
        }
        for name in ["title", "artist"] {
            if let value = options.values[name], value.isEmpty || value.utf16.count > headerLimit {
                throw UsageError(message: "--\(name) takes 1 to \(headerLimit) characters")
            }
        }
        let started = Date()
        // Header text: options first, then the audio file's metadata, checked before any lengthy work.
        let tags = await metadata(audioURL)
        let title = headerLabel(
            options.values["title"] ?? tags.title ?? audioURL.deletingPathExtension().lastPathComponent)
        let artist = headerLabel(options.values["artist"] ?? tags.artist ?? "Unknown Artist")

        let canvas: LyricsCanvas = safeArea == "reels" ? .reels : .video
        // Untimed paragraphs that cannot fit the screen are reported before minutes of alignment.
        if !["ttml", "lrc"].contains(lyricsURL.pathExtension.lowercased()),
            let raw = try? String(contentsOf: lyricsURL, encoding: .utf8)
        {
            let normalized = NormalizedLyrics(raw)
            var first = 0
            for paragraph in normalized.text.components(separatedBy: "\n\n") where !paragraph.isEmpty {
                let text = paragraph.trimmingCharacters(in: .newlines)
                let count = text.components(separatedBy: "\n").count
                if !LocalScene.fits(text, canvas: canvas), first + count <= normalized.sourceLines.count {
                    let a = normalized.sourceLines[first]
                    let b = normalized.sourceLines[first + count - 1]
                    throw Failure(
                        message: "\(a == b ? "line \(a)" : "lines \(a)–\(b)") of \(lyricsURL.relativePath) "
                            + "\(a == b ? "wraps" : "wrap") to more than eight rows on screen; split "
                            + "\(a == b ? "it into shorter lines" : "them into shorter lines or separate paragraphs")")
                }
                first += count
            }
        }

        // Lyrics: align untimed text, or parse supplied timing.
        var report: [String: Any] = ["format": "ilyrics-render-report-1"]
        let lyrics: LocalLyrics
        var credits = options.values["credits"]
        var timed = true
        do {
            switch lyricsURL.pathExtension.lowercased() {
            case "ttml":
                lyrics = try LyricsParser.parse(
                    LocalFile.boundedData(lyricsURL, limit: LRCParser.byteLimit, label: "Lyrics"), format: .ttml)
            case "lrc":
                let data = try LocalFile.boundedData(lyricsURL, limit: LRCParser.byteLimit, label: "Lyrics")
                let enhanced =
                    String(decoding: data, as: UTF8.self).range(
                        of: "<[0-9]+:[0-9]+(\\.[0-9]+)?>", options: .regularExpression) != nil
                lyrics = try LyricsParser.parse(data, format: enhanced ? .enhancedLRC : .lrc)
            default:
                timed = false
                let aligned = try await Align.run(
                    audio: audioURL, lyrics: lyricsURL, keepAdLibs: options.has("keep-ad-libs"),
                    fast: options.has("fast"), language: language, console: console)
                report["alignment"] = aligned.report
                credits = credits ?? aligned.credits
                lyrics = try LyricsParser.parse(Data(aligned.ttml.utf8), format: .ttml)
            }
        } catch let error as InputError { throw Failure(message: "\(lyricsURL.relativePath): \(error)") }
        for diagnostic in lyrics.diagnostics { console.detail("Lyrics: \(diagnostic)") }
        // Supplied timing skips separation and alignment; its audio is read here. Untimed lyrics read the audio
        // during alignment, and the export's own decoding belongs to the rendering stage.
        if timed { progress.begin(1) } else { progress.begin(4) }

        if options.values["artist"] == nil && tags.artist == nil {
            console.say("Note: the audio file names no artist; showing \"Unknown Artist\" (pass --artist TEXT)")
        }
        // Artwork: the option first, then the audio file's metadata.
        var artwork: LocalArtwork?
        if let path = options.values["artwork"] {
            do { artwork = try LocalArtwork.decode(URL(fileURLWithPath: path)) } catch {
                throw Failure(message: "\(path): \(error)")
            }
        } else if let data = tags.artwork {
            // Unusable embedded artwork is not worth failing a render for; the placeholder is drawn instead.
            do { artwork = try LocalArtwork.decode(data: data) } catch {
                console.warning("the artwork embedded in \(options.operands[0]) cannot be used (\(error))")
            }
        }
        if artwork == nil && tags.artwork == nil {
            console.say("Note: no artwork found; using the placeholder artwork (pass --artwork FILE to supply one)")
        }

        var presentation = LocalPresentation(
            background: background == "artwork" ? .fitted : nil, icons: .systemSymbols,
            minimumGap: options.has("no-gaps") ? nil : Time(4),
            focusLead: LocalPresentation.measuredMotion.focusLead, stagger: LocalPresentation.measuredMotion.stagger,
            marquee: options.has("no-marquee") ? nil : .measured, wordMotion: .measured,
            fillLead: LocalPresentation.measuredFillLead,
            hideControls: controls == "auto-hide" ? LocalPresentation.measuredControlHide : nil,
            canvas: canvas)
        presentation.holdsFinishedLine = true
        presentation.collapsesGaps = true

        let audio: LocalAudio
        let scene: LocalScene
        do {
            do { audio = try await LocalAudio.decode(audioURL) } catch let error as InputError {
                throw Failure(message: "\(audioURL.relativePath): \(error)")
            }
            if timed {
                progress.finish()
                progress.skip(2)
                progress.skip(3)
                progress.begin(4)
            }
            scene = try LocalScene(
                lyrics: lyrics, audio: audio, artwork: artwork?.image ?? PlaceholderArtwork.image(),
                highlighting: .enabled, presentation: presentation,
                title: title, artist: artist, credits: credits,
                placeholderArtwork: artwork == nil)
        } catch let error as InputError { throw Failure(message: "\(lyricsURL.relativePath): \(error)") }

        // Each worker owns one renderer; frames are pure functions of time, so output does not depend on the count.
        let renderers = try [scene.renderer] + (1..<jobs).map { _ in try scene.makeRenderer() }
        renderers.forEach { $0.enableGPUScaling() }
        let frames = scene.schedule.frames
        console.detail("Rendering \(frames) frames with \(jobs) workers")
        let temporary = target.deletingLastPathComponent().appendingPathComponent(".ilyrics-\(UUID().uuidString).mp4")
        TemporaryFiles.register(temporary)
        defer { TemporaryFiles.remove(temporary) }
        // After the last frame the writer still finishes the file, shown as a spinner.
        let submitted: (Int) -> Void = { count in
            if count < frames {
                progress.update(fraction: Double(count) / Double(frames))
            } else {
                progress.indeterminate()
            }
        }
        let metrics = try await Exporter.video(
            width: 1080, height: 1920, to: temporary, frames: frames,
            workers: renderers.map { r in { time, context in try r.draw(time, into: context) } },
            audioChannels: audio.channels, audioSample: { audio.interleavedSample($0) }, submitted: submitted)
        try finishOutput(temporary, to: output, force: options.has("force"), inputs: inputs)
        report["export"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(metrics))
        report["frames"] = frames
        report["jobs"] = jobs
        try Align.writeReport(
            report, to: options.values["report"], force: options.has("force"), inputs: inputs + [output])
        progress.finish()
        progress.summary(
            "Generated \(target.lastPathComponent) in \(durationInWords(Date().timeIntervalSince(started)))")
    }
}
