import Foundation
import AlignmentCore
import VideoExport

/// The user-facing iLyrics command (docs/command-line-interface.md).
enum CLI {
    static let version = "1.3.1"
    static let usage = """
        Usage:
          ilyrics render AUDIO LYRICS -o VIDEO.mp4 [options]
          ilyrics align  AUDIO LYRICS -o LYRICS.ttml [options]
          ilyrics models install | status | remove
          ilyrics doctor
          ilyrics --help | --version

        Run 'ilyrics COMMAND --help' for the options of a command.
        """
}

let arguments = Array(CommandLine.arguments.dropFirst())
// Ctrl-C or termination removes partial outputs and ends the progress line before exiting with the usual status.
let interruptions = [SIGINT, SIGTERM, SIGHUP].map { number -> DispatchSourceSignal in
    signal(number, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: number, queue: .global())
    source.setEventHandler {
        TemporaryFiles.removeAll()
        if isatty(STDERR_FILENO) != 0 { FileHandle.standardError.write(Data("\u{1B}[?7h\n".utf8)) }
        exit(128 + number)
    }
    source.resume()
    return source
}
func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
    exit(status)
}
do {
    switch arguments.first {
    case nil, "-h", "--help", "help": print(CLI.usage)
    case "-V", "--version": print("ilyrics \(CLI.version)")
    case "render": try await Render.command(arguments.dropFirst())
    case "align": try await Align.command(arguments.dropFirst())
    case "models": try await Models.run(arguments.dropFirst())
    case "doctor": try Doctor.command(arguments.dropFirst())
    default: throw UsageError(message: "unknown command '\(arguments[0])'")
    }
} catch let error as UsageError {
    fail("\(error.message)\n\n\(CLI.usage)", status: 2)
} catch let error as Failure {
    fail(error.message, status: 1)
} catch AlignmentError.invalid(let reason) {
    fail(reason, status: 1)
} catch {
    // Foundation and system errors print their localized description rather than their full debug form.
    fail(type(of: error) is NSError.Type ? error.localizedDescription : "\(error)", status: 1)
}
