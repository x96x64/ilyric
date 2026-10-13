import Foundation
import Testing

extension InputTests {
    @Test func plainBackingWarningUsesExistingRecognitionAndConsoleModes() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let executable = root.appendingPathComponent(".build/debug/ilyrics")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let main = String((0..<8).map { Character(UnicodeScalar(65 + $0)!) })
        let bg = String((0..<6).map { Character(UnicodeScalar(97 + $0)!) })
        let cases = [
            (main + " (" + bg + ")\n(" + bg + ")", true), (main + "\n(" + bg + ")", true),
            ("(" + bg + ")\n" + main, true), ("[Chorus]\n" + main, false), (main + "\n" + main, false),
            ("ooh\nna-na\n" + main, false), ("[Chorus (" + bg + ")]\n" + main, false), (main + " ()", false),
        ]
        let audio = dir.appendingPathComponent("fixture.wav")
        try Data().write(to: audio)
        for (i, fixture) in cases.enumerated() {
            let input = dir.appendingPathComponent("input-\(i).txt")
            try fixture.0.write(to: input, atomically: true, encoding: .utf8)
            for mode in [[], ["--quiet"], ["--verbose"]] {
                let p = Process()
                let out = Pipe()
                let err = Pipe()
                p.executableURL = executable
                p.arguments =
                    ["align", audio.path, input.path, "-o", dir.appendingPathComponent("result.ttml").path] + mode
                var env = ProcessInfo.processInfo.environment
                // Stop before model access; the warning must neither reject input nor change this existing failure.
                env["ILYRICS_TEMPLATES"] = dir.appendingPathComponent("missing-templates").path
                p.environment = env
                p.standardOutput = out
                p.standardError = err
                try p.run()
                p.waitUntilExit()
                let stderr = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                let warnings = stderr.components(separatedBy: "\n").filter { $0.hasPrefix("Warning:") }
                #expect(p.terminationStatus == 1 && out.fileHandleForReading.readDataToEndOfFile().isEmpty)
                // Warnings remain visible with --quiet, which hides only progress and informational output.
                #expect(warnings.count == (fixture.1 ? 1 : 0))
                for warning in warnings {
                    #expect(warning.contains("experimental, unverified, and unsupported"))
                    #expect(!warning.contains(main) && !warning.contains(bg) && !warning.contains(dir.path))
                }
            }
        }
    }
}
