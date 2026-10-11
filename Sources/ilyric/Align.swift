import Foundation
import CoreML
import AlignmentCore
import AlignmentMac

/// Automatic alignment of untimed lyrics, shared by `align` and `render`.
enum Align {
    struct Result { let ttml: String; let report: [String:Any]; let resolved, placed, omitted: Int }

    static func run(audio: URL, lyrics: URL, keepAdLibs: Bool, fast: Bool, console: Console) async throws -> Result {
        guard let raw=try? String(contentsOf:lyrics,encoding:.utf8) else { throw Failure(message:"\(lyrics.path) is not readable UTF-8 text") }
        let normalized=NormalizedLyrics(raw)
        for line in normalized.dropped { console.detail("Ignored lyrics line: \(line)") }
        let source:LyricSource
        do { source=try LyricSource(Data(normalized.text.utf8)) }
        catch AlignmentError.invalid(let reason) { throw Failure(message:"the lyrics cannot be aligned: \(reason)") }
        let models=try await Models.ready(console)
        let units:MLComputeUnits=fast ? .all : .cpuOnly
        console.say("Aligning \(source.lines.count) lines to \(audio.lastPathComponent)\(fast ? " (fast, not reproducible)" : "")")
        let started=Date()
        let decoded:(left:[Float],right:[Float],durationMicroseconds:Int)
        do { decoded=try readStereo44k(audio) } catch { throw Failure(message:"\(audio.path) could not be decoded (\(error.localizedDescription))") }
        let duration=decoded.durationMicroseconds
        let decodedAt=Date()
        console.detail("  Decoded in \(elapsed(decodedAt.timeIntervalSince(started)))")
        // Analysis samples follow the reference pipeline: 48-kHz frames of the source, one third at 16 kHz.
        let expected=(Int((Double(duration)*48000/1_000_000).rounded())+2)/3
        let vocals=try VocalSeparator(modelURL:models.separator,computeUnits:units).vocals16k(left:decoded.left,right:decoded.right,expectedSamples:expected)
        let separatedAt=Date()
        console.detail("  Separated vocals in \(elapsed(separatedAt.timeIntervalSince(decodedAt)))")
        let model=try RecognitionModel(modelURL:models.recognizer,vocabularyURL:models.vocabulary,computeUnits:units)
        let rows:[LineAlignment]
        do { rows=try alignLyrics(Data(normalized.text.utf8),vocals:vocals,durationMicroseconds:duration,model:model) }
        catch AlignmentError.invalid(let reason) { throw Failure(message:"alignment failed: \(reason)") }
        let alignedAt=Date()
        console.detail("  Aligned in \(elapsed(alignedAt.timeIntervalSince(separatedAt)))")
        let fills=TTMLExport.fillUnresolved(rows,duration:duration)
        let ttml=try TTMLExport.ttml(rows,fills:fills,background:normalized.background,dropNonlexical:!keepAdLibs)
        let omitted=keepAdLibs ? [] : rows.filter { $0.estimate==nil && TTMLExport.nonlexical($0.text) }.map(\.id)
        let resolved=rows.filter { $0.estimate != nil }.count
        for row in rows where row.estimate==nil {
            console.say(omitted.contains(row.id) ? "  Omitted untimed ad-lib line \(row.id+1)" : "  Placed line \(row.id+1) between its neighbours (no reliable timing: \(row.flags.joined(separator:", ")))")
        }
        let lines:[[String:Any]]=rows.map { r in
            ["line":r.id+1,"text":r.text,"status":r.estimate != nil ? "aligned" : omitted.contains(r.id) ? "omitted" : "placed",
             "interval_us":(r.estimate ?? fills[r.id]).map { $0 as Any } ?? NSNull(),"flags":r.flags,"background":normalized.background[r.id] ?? NSNull(),
             "words":r.wordEstimates.map { $0.map { ["start_utf16":$0.startUTF16,"length_utf16":$0.lengthUTF16,"interval_us":$0.interval] } } ?? NSNull(),
             // Evidence behind the decision: the forced proposal before acceptance, its mean log-probability, and the
             // greedy transcription's similarity to the line.
             "proposal_us":r.proposal.map { $0 as Any } ?? NSNull(),"support":r.support ?? NSNull(),"similarity":r.similarity ?? NSNull(),
             "proposal_words":r.words.map { $0.map { ["start_utf16":$0.startUTF16,"length_utf16":$0.lengthUTF16,"interval_us":$0.interval] } } ?? NSNull()]
        }
        let report:[String:Any]=["format":"ilyric-alignment-report-1","audio":audio.lastPathComponent,"duration_us":duration,
            "compute_units":fast ? "all" : "cpu","ignored_input_lines":normalized.dropped,"lines":lines,
            "seconds":["decode":decodedAt.timeIntervalSince(started),"separation":separatedAt.timeIntervalSince(decodedAt),"alignment":alignedAt.timeIntervalSince(separatedAt)]]
        return Result(ttml:ttml,report:report,resolved:resolved,placed:rows.count-resolved-omitted.count,omitted:omitted.count)
    }

    static func writeReport(_ report: [String:Any], to path: String?) throws {
        guard let path else { return }
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:path),options:.atomic)
    }

    static let help="""
    Usage: ilyric align AUDIO LYRICS -o LYRICS.ttml [options]

    Aligns untimed lyrics (UTF-8 text) to a recording and writes word-timed TTML.

    Options:
      -o, --output FILE   Output TTML file (required)
          --force         Replace an existing output
          --keep-ad-libs  Keep vocable-only lines that cannot be timed
          --fast          GPU and Neural Engine inference; faster but not reproducible
          --report FILE   Write a JSON report of estimates, placements, and timings
      -q, --quiet         Print errors only
      -v, --verbose       Print step timings and ignored lyrics lines
      -h, --help          Show this help
    """

    static func command(_ arguments: ArraySlice<String>) async throws {
        let options=try Options(arguments,valued:["output","report"],flags:["help","force","keep-ad-libs","fast","quiet","verbose"],
                                short:["o":"output","h":"help","q":"quiet","v":"verbose"])
        if options.has("help") { print(help);return }
        guard options.operands.count==2 else { throw UsageError(message:"expected AUDIO and LYRICS") }
        guard let output=options.values["output"] else { throw UsageError(message:"missing -o, --output") }
        let console=Console(quiet:options.has("quiet"),verbose:options.has("verbose"))
        let audio=URL(fileURLWithPath:options.operands[0]),lyrics=URL(fileURLWithPath:options.operands[1])
        for url in [audio,lyrics] where !FileManager.default.fileExists(atPath:url.path) { throw Failure(message:"\(url.path) does not exist") }
        guard !["ttml","lrc"].contains(lyrics.pathExtension.lowercased()) else { throw Failure(message:"\(lyrics.lastPathComponent) is already timed; 'align' takes untimed text") }
        let target=try checkOutput(output,force:options.has("force"))
        let started=Date()
        let result=try await run(audio:audio,lyrics:lyrics,keepAdLibs:options.has("keep-ad-libs"),fast:options.has("fast"),console:console)
        try result.ttml.write(to:target,atomically:true,encoding:.utf8)
        try writeReport(result.report,to:options.values["report"])
        console.say("Wrote \(output): \(result.resolved) lines aligned, \(result.placed) placed, \(result.omitted) omitted, in \(elapsed(Date().timeIntervalSince(started)))")
    }
}
