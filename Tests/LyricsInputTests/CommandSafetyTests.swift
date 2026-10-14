import Foundation
import Testing

/// Runs the debug `ilyrics` command in a scratch directory with original synthetic inputs.
struct CommandFixture {
    let dir: URL
    init() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    func remove() { try? FileManager.default.removeItem(at: dir) }
    func path(_ name: String) -> String { dir.appendingPathComponent(name).path }

    /// One second of an untagged 48 kHz mono tone.
    func wav(_ name: String = "tone.wav", seconds: Double = 1) throws -> String {
        let frames = Int(48_000 * seconds)
        var data = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ n: T) {
            withUnsafeBytes(of: n.littleEndian) { data.append(contentsOf: $0) }
        }
        append(UInt32(36 + frames * 2))
        data.append(Data("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(48_000))
        append(UInt32(96_000))
        append(UInt16(2))
        append(UInt16(16))
        data.append(Data("data".utf8))
        append(UInt32(frames * 2))
        for i in 0..<frames { append(Int16(sin(2 * Double.pi * 440 * Double(i) / 48_000) * 6000)) }
        try data.write(to: dir.appendingPathComponent(name))
        return path(name)
    }
    func write(_ text: String, to name: String) throws -> String {
        try text.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        return path(name)
    }
    /// Timed lyrics within one second, so that `render` skips alignment.
    func lrc(_ name: String = "words.lrc") throws -> String {
        try write("[00:00.10]Paper boats\n[00:00.60]Drift away\n", to: name)
    }

    @discardableResult
    func run(_ arguments: [String], environment: [String: String] = [:]) throws -> (status: Int32, stderr: String) {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let p = Process()
        let err = Pipe()
        p.executableURL = root.appendingPathComponent(".build/debug/ilyrics")
        p.arguments = arguments
        p.currentDirectoryURL = dir
        var env = ProcessInfo.processInfo.environment
        env.merge(environment) { $1 }
        p.environment = env
        p.standardError = err
        p.standardOutput = Pipe()
        try p.run()
        let stderr = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        return (p.terminationStatus, stderr)
    }
}

@Suite(.serialized) struct CommandSafetyTests {
    @Test func untaggedAudioRendersAndHeaderOptionsAreCheckedFirst() throws {
        let f = try CommandFixture()
        defer { f.remove() }
        let audio = try f.wav()
        let lyrics = try f.lrc()
        let rendered = try f.run(["render", audio, lyrics, "-o", f.path("a.mp4")])
        #expect(rendered.status == 0, "\(rendered.stderr)")
        #expect(rendered.stderr.contains("Note: the audio file names no artist"))
        for option in ["--title", "--artist"] {
            for value in ["", String(repeating: "x", count: 81)] {
                let result = try f.run(["render", audio, lyrics, "-o", f.path("b.mp4"), option, value])
                #expect(result.status == 2 && result.stderr.contains("takes 1 to 80 characters"))
            }
        }
        #expect(!FileManager.default.fileExists(atPath: f.path("b.mp4")))
    }
}

extension CommandSafetyTests {
    @Test func outputsNeverReplaceFoldersInputsOrUnrelatedFiles() throws {
        let f = try CommandFixture()
        defer { f.remove() }
        let audio = try f.wav()
        let lyrics = try f.lrc()
        let plain = try f.write("Paper boats\n", to: "plain.txt")
        let folder = f.path("folder.mp4")
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: false)
        try Data("keep".utf8).write(to: URL(fileURLWithPath: folder + "/inside.txt"))
        let kept = try f.write("keep", to: "kept.json")
        let cases: [([String], Int32, String)] = [
            (["render", audio, lyrics, "-o", folder, "--force"], 1, "is a folder"),
            (["render", audio, lyrics, "-o", audio + ".mp4", "--force", "--report", lyrics], 2, "is also given as"),
            (["render", audio, lyrics, "-o", f.path("v.mp4"), "--report", f.path("v.mp4")], 2, "is also given as"),
            (["render", audio, lyrics, "-o", f.path("w.mp4"), "--report", kept], 1, "already exists"),
            (["render", audio, lyrics, "-o", f.path("missing/x.mp4")], 1, "does not exist"),
            (
                ["render", audio, lyrics, "-o", f.path("y.mp4"), "--report", f.path("missing/r.json")], 1,
                "does not exist"
            ),
            (["align", audio, plain, "-o", plain, "--force"], 2, "is also given as"),
            (["align", audio, plain, "-o", f.path("missing/x.ttml")], 1, "does not exist"),
        ]
        for (arguments, status, message) in cases {
            let result = try f.run(arguments)
            #expect(result.status == status && result.stderr.contains(message), "\(arguments): \(result.stderr)")
        }
        #expect(try String(contentsOfFile: folder + "/inside.txt", encoding: .utf8) == "keep")
        #expect(try String(contentsOfFile: kept, encoding: .utf8) == "keep")
        #expect(try String(contentsOfFile: plain, encoding: .utf8) == "Paper boats\n")
        for name in ["v.mp4", "w.mp4", "y.mp4"] { #expect(!FileManager.default.fileExists(atPath: f.path(name))) }
    }
}

extension CommandSafetyTests {
    @Test func modelRemovalNeverTouchesFoldersWithoutInstalledModels() throws {
        let f = try CommandFixture()
        defer { f.remove() }
        try FileManager.default.createDirectory(atPath: f.path("downloads"), withIntermediateDirectories: false)
        let kept = try f.write("keep", to: "downloads/photo.txt")
        let vocabulary = try f.write("{}", to: "vocab.json")
        // Only this scratch folder is ever passed to `remove`; an empty value would select the real cache.
        let result = try f.run(["models", "remove"], environment: ["ILYRICS_MODELS": f.dir.path])
        #expect(result.status == 0, "\(result.stderr)")
        #expect(FileManager.default.fileExists(atPath: kept) && FileManager.default.fileExists(atPath: vocabulary))
        // An empty value counts as unset: the cache is the default, not the current folder.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let p = Process()
        let out = Pipe()
        p.executableURL = root.appendingPathComponent(".build/debug/ilyrics")
        p.arguments = ["models", "status"]
        p.currentDirectoryURL = f.dir
        var env = ProcessInfo.processInfo.environment
        env["ILYRICS_MODELS"] = ""
        p.environment = env
        p.standardOutput = out
        p.standardError = Pipe()
        try p.run()
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        #expect(text.contains("Cache:") && !text.contains("Cache:     " + f.dir.path + "\n"))
    }
}

extension CommandSafetyTests {
    @Test func interruptedRenderLeavesNoPartialFiles() throws {
        let f = try CommandFixture()
        defer { f.remove() }
        let audio = try f.wav(seconds: 20)
        let lyrics = try f.lrc()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let p = Process()
        p.executableURL = root.appendingPathComponent(".build/debug/ilyrics")
        p.arguments = ["render", audio, lyrics, "-o", f.path("out.mp4"), "--artist", "Synthetic"]
        p.standardError = Pipe()
        p.standardOutput = Pipe()
        try p.run()
        // Wait until rendering has written its temporary output, then interrupt.
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline, p.isRunning,
            !((try? FileManager.default.contentsOfDirectory(atPath: f.dir.path)) ?? []).contains(where: {
                $0.hasPrefix(".ilyrics-")
            })
        {
            Thread.sleep(forTimeInterval: 0.05)
        }
        p.interrupt()
        p.waitUntilExit()
        #expect(p.terminationStatus == 130)
        let left = try FileManager.default.contentsOfDirectory(atPath: f.dir.path)
        #expect(!left.contains { $0.hasPrefix(".") || $0 == "out.mp4" }, "\(left)")
    }
}

extension CommandSafetyTests {
    @Test func errorsNameFilesAsTypedInPlainLanguage() throws {
        let f = try CommandFixture()
        defer { f.remove() }
        _ = try f.wav()
        _ = try f.lrc()
        let long = Array(repeating: "window", count: 60).joined(separator: " ")
        _ = try f.write("Paper boats\n\n" + long + "\n", to: "long.txt")
        _ = try f.write("[00:00.10]" + long + "\n", to: "long.lrc")
        let cases: [([String], String)] = [
            (["render", "nope.wav", "words.lrc", "-o", "a.mp4"], "Error: nope.wav does not exist"),
            (
                ["render", "tone.wav", "long.txt", "-o", "b.mp4"],
                "Error: line 3 of long.txt wraps to more than eight rows"
            ),
            (
                ["render", "tone.wav", "long.lrc", "-o", "c.mp4"],
                "Error: long.lrc: the lyric line at 0:00.10 wraps to more than eight rows"
            ),
        ]
        for (arguments, message) in cases {
            let result = try f.run(arguments)
            #expect(result.status == 1 && result.stderr.contains(message), "\(arguments): \(result.stderr)")
            #expect(!result.stderr.contains("invalid(") && !result.stderr.contains("Error Domain="))
        }
    }
}
