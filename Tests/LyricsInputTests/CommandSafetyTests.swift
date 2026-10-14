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
