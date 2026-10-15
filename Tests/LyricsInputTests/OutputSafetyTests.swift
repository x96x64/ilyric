import Foundation
import Testing

extension CommandSafetyTests {
    /// Changes a destination only after preflight, while the render is writing its private temporary file.
    @Test func destinationsCreatedDuringRenderingArePreserved() throws {
        for kind in ["report", "video", "directory"] {
            let f = try CommandFixture()
            defer { f.remove() }
            let audio = try f.wav(seconds: 2)
            let lyrics = try f.lrc()
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
            let p = Process()
            let err = Pipe()
            p.executableURL = root.appendingPathComponent(".build/debug/ilyrics")
            p.arguments =
                [
                    "render", audio, lyrics, "-o", f.path("out.mp4"), "--report", f.path("report.json"),
                    "-j", "1", "--artist", "Synthetic",
                ] + (kind == "directory" ? ["--force"] : [])
            p.currentDirectoryURL = f.dir
            p.standardOutput = Pipe()
            p.standardError = err
            var suspended = false
            defer {
                if suspended { _ = p.resume() }
                if p.isRunning {
                    p.terminate()
                    p.waitUntilExit()
                }
            }
            try p.run()
            let deadline = Date().addingTimeInterval(60)
            func exporting() -> Bool {
                ((try? FileManager.default.contentsOfDirectory(atPath: f.dir.path)) ?? [])
                    .contains { $0.hasPrefix(".ilyrics-") }
            }
            while p.isRunning && !exporting() && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
            try #require(p.isRunning && exporting(), "The render must reach export before the destination changes")
            try #require(p.suspend())
            suspended = true
            let marker: String
            if kind == "directory" {
                try FileManager.default.createDirectory(atPath: f.path("out.mp4"), withIntermediateDirectories: false)
                marker = "out.mp4/keep.txt"
            } else {
                marker = kind == "report" ? "report.json" : "out.mp4"
            }
            _ = try f.write("Unrelated file; preserve these bytes.", to: marker)
            try #require(p.resume())
            suspended = false
            let stderr = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            p.waitUntilExit()
            #expect(p.terminationStatus == 1, "\(kind): \(stderr)")
            #expect(stderr.contains(kind == "directory" ? "is a folder" : "already exists"), "\(kind): \(stderr)")
            #expect(
                (try? String(contentsOfFile: f.path(marker), encoding: .utf8))
                    == "Unrelated file; preserve these bytes.",
                "\(kind) must not replace the new destination")
            #expect(
                try !FileManager.default.contentsOfDirectory(atPath: f.dir.path).contains { $0.hasPrefix(".ilyrics-") })
        }
    }

    @Test func forceReplacesVideoAndReportFiles() throws {
        let f = try CommandFixture()
        defer { f.remove() }
        let audio = try f.wav()
        let lyrics = try f.lrc()
        let video = try f.write("Old video", to: "out.mp4")
        let report = try f.write("Old report", to: "report.json")
        let result = try f.run([
            "render", audio, lyrics, "-o", video, "--report", report, "--force", "-j", "1", "--artist", "Synthetic",
        ])
        #expect(result.status == 0, "\(result.stderr)")
        let media = try Data(contentsOf: URL(fileURLWithPath: video))
        #expect(media.count > 8 && String(decoding: media[4..<8], as: UTF8.self) == "ftyp")
        let json =
            try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: report))) as? [String: Any]
        #expect(json?["format"] as? String == "ilyrics-render-report-1")
        #expect(try !FileManager.default.contentsOfDirectory(atPath: f.dir.path).contains { $0.hasPrefix(".ilyrics-") })
    }

    @Test func forceCannotReplaceInputsThroughLinks() throws {
        let f = try CommandFixture()
        defer { f.remove() }
        let audio = try f.wav()
        let lyrics = try f.lrc()
        let original = try Data(contentsOf: URL(fileURLWithPath: audio))
        for kind in ["hard", "symbolic"] {
            let output = f.path("\(kind).mp4")
            if kind == "hard" {
                try FileManager.default.linkItem(atPath: audio, toPath: output)
            } else {
                try FileManager.default.createSymbolicLink(atPath: output, withDestinationPath: audio)
            }
            let result = try f.run(["render", audio, lyrics, "-o", output, "--force"])
            #expect(result.status == 2 && result.stderr.contains("is also given as"), "\(result.stderr)")
            #expect(try Data(contentsOf: URL(fileURLWithPath: audio)) == original)
            #expect(try Data(contentsOf: URL(fileURLWithPath: output)) == original)
        }
    }
}
