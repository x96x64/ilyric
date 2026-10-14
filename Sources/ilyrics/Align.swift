import Foundation
import CoreML
import AlignmentCore
import AlignmentMac
import ProgressDisplay
import LyricsInputCore
import LyricsInputMac

/// Automatic alignment of untimed lyrics, shared by `align` and `render`.
enum Align {
    /// Stages shared by `align` and the alignment part of `render`, whose fourth stage renders the video.
    static let stages = ["Reading audio", "Separating vocals", "Aligning lyrics"]

    struct Result {
        let ttml: String
        let report: [String: Any]
        let resolved, placed, omitted: Int
        let credits: String?
    }

    static func run(audio: URL, lyrics: URL, keepAdLibs: Bool, fast: Bool, console: Console) async throws -> Result {
        guard let raw = try? String(contentsOf: lyrics, encoding: .utf8) else {
            throw Failure(message: "\(lyrics.relativePath) is not readable UTF-8 text")
        }
        let normalized = NormalizedLyrics(raw)
        try checkLyrics(raw, normalized, name: lyrics.relativePath)
        if !normalized.background.isEmpty
            || normalized.dropped.contains(where: { $0.hasSuffix(" (background vocals without a preceding line)") })
        {
            console.warning(
                "Parenthesized backing choruses are experimental, unverified, and unsupported; omit such chorus text from plain lyrics input."
            )
        }
        for line in normalized.dropped { console.detail("Ignored lyrics line: \(line)") }
        let source: LyricSource
        do { source = try LyricSource(Data(normalized.text.utf8)) } catch AlignmentError.invalid(let reason) {
            throw Failure(message: "the lyrics cannot be aligned: \(reason)")
        }
        // Unsupported audio fails here, after the lyrics checks and before model installation or alignment.
        do { _ = try await LocalAudio.inspect(audio) } catch let error as InputError {
            throw Failure(message: "\(audio.relativePath): \(error)")
        }
        let models = try await Models.ready(console)
        let units: MLComputeUnits = fast ? .all : .cpuOnly
        console.detail(
            "Aligning \(source.lines.count) lines to \(audio.lastPathComponent)\(fast ? " (fast, not reproducible)" : "")"
        )
        let progress = console.progress
        let started = Date()
        progress.begin(1)
        let decoded: (left: [Float], right: [Float], durationMicroseconds: Int)
        do { decoded = try readStereo44k(audio) } catch {
            throw Failure(message: "\(audio.relativePath) could not be decoded (\(error.localizedDescription))")
        }
        let duration = decoded.durationMicroseconds
        let decodedAt = Date()
        progress.finish()
        console.detail("  Decoded in \(elapsed(decodedAt.timeIntervalSince(started)))")
        progress.begin(2)
        // Analysis samples follow the reference pipeline: 48-kHz frames of the source, one third at 16 kHz.
        let expected = (Int((Double(duration) * 48000 / 1_000_000).rounded()) + 2) / 3
        let vocals = try VocalSeparator(modelURL: models.separator, computeUnits: units).vocals16k(
            left: decoded.left, right: decoded.right, expectedSamples: expected
        ) { done, total in
            // Normalization and resampling follow the last segment, so the line returns to a spinner.
            if done < total {
                progress.update(fraction: Double(done) / Double(total))
            } else {
                progress.indeterminate()
            }
        }
        let separatedAt = Date()
        progress.finish()
        console.detail("  Separated vocals in \(elapsed(separatedAt.timeIntervalSince(decodedAt)))")
        progress.begin(3)
        let model = try RecognitionModel(
            modelURL: models.recognizer, vocabularyURL: models.vocabulary, computeUnits: units)
        let rows: [LineAlignment]
        do {
            rows = try alignLyrics(
                Data(normalized.text.utf8), vocals: vocals, durationMicroseconds: duration, model: model,
                neighbourAcceptance: true)
        } catch AlignmentError.invalid(let reason) { throw Failure(message: "alignment failed: \(reason)") }
        let alignedAt = Date()
        console.detail("  Aligned in \(elapsed(alignedAt.timeIntervalSince(separatedAt)))")
        let omitted = keepAdLibs ? [] : rows.filter { $0.estimate == nil && TTMLExport.nonlexical($0.text) }.map(\.id)
        let activity = try VocalRules.activity(vocals)
        let fills = TTMLExport.relocateBoundaryFallbacks(
            rows, fills: TTMLExport.fillUnresolved(rows, duration: duration),
            duration: duration, level: activity.level, reference: activity.reference,
            protectedLines: Set(omitted).union(normalized.background.keys))
        let ttml = try TTMLExport.ttml(
            rows, fills: fills, background: normalized.background, dropNonlexical: !keepAdLibs,
            secondVoice: normalized.secondVoice)
        let resolved = rows.filter { $0.estimate != nil }.count
        progress.finish()
        console.detail(
            "Aligned \(resolved) lines, placed \(rows.count-resolved-omitted.count), omitted \(omitted.count)")
        for row in rows where row.estimate == nil {
            console.detail(
                omitted.contains(row.id)
                    ? "  Omitted untimed ad-lib line \(row.id+1)"
                    : "  Placed line \(row.id+1) (no reliable timing: \(row.flags.joined(separator:", ")))")
        }
        let placed = rows.count - resolved - omitted.count
        if placed > 0 || !omitted.isEmpty {
            let parts = [
                placed > 0 ? "\(placed) \(placed==1 ? "line has" : "lines have") no word timing" : nil,
                omitted.isEmpty
                    ? nil : "\(omitted.count) untimed ad-lib \(omitted.count==1 ? "line was" : "lines were") omitted",
            ].compactMap { $0 }
            console.say("Note: \(parts.joined(separator:"; ")) (run with --verbose to list them)")
        }
        let lines: [[String: Any]] = rows.map { r in
            [
                "line": r.id + 1, "text": r.text,
                "status": r.estimate != nil ? "aligned" : omitted.contains(r.id) ? "omitted" : "placed",
                "interval_us": (r.estimate ?? fills[r.id]).map { $0 as Any } ?? NSNull(), "flags": r.flags,
                "background": normalized.background[r.id] ?? NSNull(),
                "words": r.wordEstimates.map {
                    $0.map {
                        ["start_utf16": $0.startUTF16, "length_utf16": $0.lengthUTF16, "interval_us": $0.interval]
                    }
                } ?? NSNull(),
                // Evidence behind the decision: the forced proposal before acceptance, its mean log-probability, and the
                // greedy transcription's similarity to the line.
                "proposal_us": r.proposal.map { $0 as Any } ?? NSNull(), "support": r.support ?? NSNull(),
                "similarity": r.similarity ?? NSNull(),
                "proposal_words": r.words.map {
                    $0.map {
                        ["start_utf16": $0.startUTF16, "length_utf16": $0.lengthUTF16, "interval_us": $0.interval]
                    }
                } ?? NSNull(),
            ]
        }
        let report: [String: Any] = [
            "format": "ilyrics-alignment-report-1", "audio": audio.lastPathComponent, "duration_us": duration,
            "compute_units": fast ? "all" : "cpu", "ignored_input_lines": normalized.dropped, "lines": lines,
            "seconds": [
                "decode": decodedAt.timeIntervalSince(started), "separation": separatedAt.timeIntervalSince(decodedAt),
                "alignment": alignedAt.timeIntervalSince(separatedAt),
            ],
        ]
        return Result(
            ttml: ttml, report: report, resolved: resolved, placed: rows.count - resolved - omitted.count,
            omitted: omitted.count, credits: normalized.credits)
    }

    /// Rejects lyrics that cannot be aligned before any model work, naming the file, the line, and the character.
    static func checkLyrics(_ raw: String, _ normalized: NormalizedLyrics, name: String) throws {
        guard !normalized.sourceLines.isEmpty else {
            if raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}"))).isEmpty
            {
                throw Failure(message: "\(name) is empty; write the lyrics with one sung line per line")
            }
            throw Failure(
                message:
                    "\(name) contains no lines to sing; section labels such as [Chorus], \"Written by:\" lines, and lines without letters are not lyrics"
            )
        }
        let lines = normalized.text.components(separatedBy: "\n").filter { !$0.isEmpty }
        for (k, line) in lines.enumerated() {
            guard let c = unsupportedCharacter(in: line) else { continue }
            let number = k < normalized.sourceLines.count ? normalized.sourceLines[k] : k + 1
            let code = c.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " ")
            let advice: String
            if c.isNumber && c.isASCII {
                advice =
                    "this way of writing a number is not supported; write it as it is sung, for example 3.5 as three point five"
            } else if c.isLetter || c.isNumber {
                advice = "only English lyrics can be aligned; other languages are planned for a later release"
            } else {
                advice = "remove it or write it as it is sung"
            }
            throw Failure(
                message: "line \(number) of \(name) contains \"\(c)\" (\(code)), which cannot be aligned; \(advice)")
        }
    }

    static func writeReport(_ report: [String: Any], to path: String?) throws {
        guard let path else { return }
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(
            to: URL(fileURLWithPath: path), options: .atomic)
    }

    static let help = """
        Usage: ilyrics align AUDIO LYRICS -o LYRICS.ttml [options]

        Aligns untimed lyrics (UTF-8 text) to a recording and writes word-timed TTML.

        Options:
          -o, --output FILE   Output TTML file (required)
              --force         Replace an existing output
              --keep-ad-libs  Keep vocable-only lines that cannot be timed
              --fast          GPU and Neural Engine inference; faster but not reproducible
              --report FILE   Write a JSON report of estimates, placements, and timings
          -q, --quiet         Print only warnings and errors
          -v, --verbose       Also print step details, timings, and untimed lines
          -h, --help          Show this help
        """

    static func command(_ arguments: ArraySlice<String>) async throws {
        let options = try Options(
            arguments, valued: ["output", "report"],
            flags: ["help", "force", "keep-ad-libs", "fast", "quiet", "verbose"],
            short: ["o": "output", "h": "help", "q": "quiet", "v": "verbose"])
        if options.has("help") {
            print(help)
            return
        }
        guard options.operands.count == 2 else { throw UsageError(message: "expected AUDIO and LYRICS") }
        guard let output = options.values["output"] else { throw UsageError(message: "missing -o, --output") }
        let console = Console(quiet: options.has("quiet"), verbose: options.has("verbose"), stages: stages)
        defer { console.progress.close() }
        let audio = URL(fileURLWithPath: options.operands[0])
        let lyrics = URL(fileURLWithPath: options.operands[1])
        for url in [audio, lyrics] where !FileManager.default.fileExists(atPath: url.path) {
            throw Failure(message: "\(url.relativePath) does not exist")
        }
        guard !["ttml", "lrc"].contains(lyrics.pathExtension.lowercased()) else {
            throw Failure(message: "\(lyrics.relativePath) is already timed; 'align' takes untimed text")
        }
        let target = try checkOutput(output, force: options.has("force"), inputs: options.operands)
        if let path = options.values["report"] {
            _ = try checkOutput(path, force: options.has("force"), inputs: options.operands + [output])
        }
        let started = Date()
        let result = try await run(
            audio: audio, lyrics: lyrics, keepAdLibs: options.has("keep-ad-libs"), fast: options.has("fast"),
            console: console)
        try result.ttml.write(to: target, atomically: true, encoding: .utf8)
        try writeReport(result.report, to: options.values["report"])
        console.progress.summary(
            "Generated \(target.lastPathComponent) in \(durationInWords(Date().timeIntervalSince(started)))")
    }
}
