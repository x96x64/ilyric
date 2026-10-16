import Foundation
import Testing

extension CommandSafetyTests {
    @Test func helpRoutesExactlyWithoutSideEffects() throws {
        let f = try CommandFixture()
        defer { f.remove() }
        let environment = ["ILYRICS_MODELS": f.path("cache"), "ILYRICS_TEMPLATES": f.path("missing-templates")]
        let before = try FileManager.default.contentsOfDirectory(atPath: f.dir.path)
        let overall = try f.run(["--help"], environment: environment)
        #expect(overall.status == 0 && overall.stderr.isEmpty)
        #expect(overall.stdout.hasPrefix("Usage:\n") && overall.stdout.contains("ilyrics help [COMMAND]"))
        for arguments in [[], ["help"], ["-h"]] {
            let result = try f.run(arguments, environment: environment)
            #expect(result.status == 0 && result.stderr.isEmpty && result.stdout == overall.stdout)
        }
        for command in ["render", "align", "models", "doctor"] {
            let direct = try f.run([command, "--help"], environment: environment)
            let routed = try f.run(["help", command], environment: environment)
            let short = try f.run([command, "-h"], environment: environment)
            #expect(direct.status == 0 && direct.stderr.isEmpty)
            #expect(direct.stdout.hasPrefix("Usage: ilyrics \(command)"))
            #expect(routed.status == 0 && routed.stderr.isEmpty && routed.stdout == direct.stdout)
            #expect(short.status == 0 && short.stderr.isEmpty && short.stdout == direct.stdout)
        }
        for flag in ["-V", "--version"] {
            let version = try f.run([flag], environment: environment)
            #expect(version.status == 0 && version.stderr.isEmpty && version.stdout == "ilyrics 1.3.1\n")
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.dir.path) == before)
    }

    @Test func helpRejectsUnknownTargetsAndAllExtraArguments() throws {
        let f = try CommandFixture()
        defer { f.remove() }
        let environment = ["ILYRICS_MODELS": f.path("cache"), "ILYRICS_TEMPLATES": f.path("missing-templates")]
        let overall = try f.run(["help"], environment: environment).stdout
        for target in ["unknown", "install", "--help", "-h", "--version", "", "Render"] {
            let result = try f.run(["help", target], environment: environment)
            #expect(result.status == 2 && result.stdout.isEmpty)
            #expect(
                result.stderr
                    == "Error: unknown help target '\(target)'; use render, align, models, or doctor\n\n" + overall)
        }
        for target in ["render", "align", "models", "doctor", "unknown"] {
            for extras in [["install"], ["--help"], ["-o", "out.ttml"], ["--", "install"]] {
                let result = try f.run(["help", target] + extras, environment: environment)
                #expect(result.status == 2 && result.stdout.isEmpty)
                #expect(
                    result.stderr == "Error: help takes one command; use 'ilyrics help COMMAND'\n\n" + overall)
            }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.dir.path).isEmpty)
    }

    @Test func bareCommandsAndExistingHelpParsingRemainUnchanged() throws {
        let f = try CommandFixture()
        defer { f.remove() }
        for (command, message) in [
            ("render", "expected AUDIO and LYRICS"), ("align", "expected AUDIO and LYRICS"),
            ("models", "expected one of install, status, remove"),
        ] {
            let bare = try f.run([command])
            #expect(bare.status == 2 && bare.stdout.isEmpty && bare.stderr.hasPrefix("Error: " + message + "\n"))
            let invalid = try f.run([command, "--unknown", "--help"])
            #expect(invalid.status == 2 && invalid.stdout.isEmpty && invalid.stderr.contains("unknown option"))
        }
        let help = try f.run(["align", "--help", "-o", "result.xml", "--quiet", "--force"])
        #expect(help.status == 0 && help.stderr.isEmpty)
        let models = try f.run(["models", "--help"])
        #expect(models.stdout.contains("-v, --verbose                 Enable verbose console mode"))
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.dir.path).isEmpty)
    }
}
