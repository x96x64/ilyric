import Foundation
import Testing

extension CommandSafetyTests {
    private var filenameWarning: String {
        "Warning: align writes TTML regardless of the output filename; use a .ttml extension so 'render' selects TTML.\n"
    }

    @Test func alignmentFilenameWarningIsNonfatalAndPrecedesWork() throws {
        let f = try CommandFixture()
        defer { f.remove() }
        _ = try f.wav()
        _ = try f.write("Paper boats\n", to: "words.txt")
        let environment = ["ILYRICS_MODELS": f.path("cache"), "ILYRICS_TEMPLATES": f.path("missing-templates")]
        let before = try FileManager.default.contentsOfDirectory(atPath: f.dir.path).sorted()
        for name in ["result.ttml", "result.TTML", "result.TtMl", "result.xml", "result.lrc", "result"] {
            for mode in [[], ["--quiet"], ["--force"], ["--quiet", "--force"], ["--verbose"]] {
                let result = try f.run(["align", "tone.wav", "words.txt", "-o", name] + mode, environment: environment)
                // The existing template failure proves that every filename passed preflight and audio decoding.
                // This is not a successful real-model alignment; no model is accessed or downloaded.
                #expect(result.status == 1 && result.stdout.isEmpty)
                #expect(result.stderr.contains("Error: ILYRICS_TEMPLATES") && result.stderr.contains("model templates"))
                let warns = !name.lowercased().hasSuffix(".ttml")
                #expect(result.stderr.components(separatedBy: filenameWarning).count - 1 == (warns ? 1 : 0))
                #expect(result.stderr.components(separatedBy: "Warning:").count - 1 == (warns ? 1 : 0))
                if warns { #expect(result.stderr.hasPrefix(filenameWarning)) }
                if mode.contains("--quiet") { #expect(!result.stderr.contains("==>")) }
                #expect(!FileManager.default.fileExists(atPath: f.path(name)))
                #expect(try FileManager.default.contentsOfDirectory(atPath: f.dir.path).sorted() == before)
            }
        }
        _ = try f.write("Existing output", to: "existing.xml")
        let forced = try f.run(
            ["align", "tone.wav", "words.txt", "-o", "existing.xml", "--quiet", "--force"],
            environment: environment)
        #expect(forced.status == 1 && forced.stdout.isEmpty && forced.stderr.hasPrefix(filenameWarning))
        #expect(forced.stderr.contains("Error: ILYRICS_TEMPLATES"))
        #expect(try String(contentsOfFile: f.path("existing.xml"), encoding: .utf8) == "Existing output")
        #expect(!FileManager.default.fileExists(atPath: f.path("cache")))
    }

    @Test func alignmentSafetyErrorsPrecedeFilenameWarningAndLeaveNoOutputs() throws {
        let f = try CommandFixture()
        defer { f.remove() }
        _ = try f.wav()
        _ = try f.lrc()
        _ = try f.write("Paper boats\n", to: "words.txt")
        _ = try f.write("Keep these bytes.", to: "kept.xml")
        try FileManager.default.createDirectory(atPath: f.path("folder.xml"), withIntermediateDirectories: false)
        let environment = ["ILYRICS_MODELS": f.path("cache"), "ILYRICS_TEMPLATES": f.path("missing-templates")]
        let cases: [([String], Int32, String)] = [
            (["align"], 2, "expected AUDIO and LYRICS"),
            (["align", "tone.wav", "words.txt"], 2, "missing -o, --output"),
            (["align", "tone.wav", "words.txt", "-o", "out.xml", "--language", "xx"], 2, "--language takes"),
            (["align", "missing.wav", "words.txt", "-o", "out.xml"], 1, "missing.wav does not exist"),
            (["align", "tone.wav", "missing.txt", "-o", "out.xml"], 1, "missing.txt does not exist"),
            (["align", "tone.wav", "words.lrc", "-o", "out.xml"], 1, "is already timed"),
            (["align", "tone.wav", "words.txt", "-o", "folder.xml", "--force"], 1, "is a folder"),
            (["align", "tone.wav", "words.txt", "-o", "words.txt", "--force"], 2, "is also given as"),
            (["align", "tone.wav", "words.txt", "-o", "missing/out.xml"], 1, "does not exist"),
            (["align", "tone.wav", "words.txt", "-o", "kept.xml"], 1, "already exists"),
            (
                ["align", "tone.wav", "words.txt", "-o", "out.xml", "--report", "words.txt", "--force"], 2,
                "is also given as"
            ),
            (["align", "tone.wav", "words.txt", "-o", "out.xml", "--report", "out.xml"], 2, "is also given as"),
            (["align", "tone.wav", "words.txt", "-o", "out.xml", "--report", "kept.xml"], 1, "already exists"),
            (["align", "tone.wav", "words.txt", "-o", "out.xml", "--report", "missing/r.json"], 1, "does not exist"),
        ]
        let before = try FileManager.default.contentsOfDirectory(atPath: f.dir.path).sorted()
        for (arguments, status, message) in cases {
            let result = try f.run(arguments, environment: environment)
            #expect(
                result.status == status && result.stdout.isEmpty && result.stderr.contains(message), "\(result.stderr)")
            #expect(!result.stderr.contains("Warning:") && !result.stderr.contains("==>"))
            #expect(try FileManager.default.contentsOfDirectory(atPath: f.dir.path).sorted() == before)
        }
        #expect(try String(contentsOfFile: f.path("kept.xml"), encoding: .utf8) == "Keep these bytes.")
        #expect(try String(contentsOfFile: f.path("words.txt"), encoding: .utf8) == "Paper boats\n")
    }
}
