import Foundation

/// The user-facing iLyrics command (docs/command-line-interface.md).
enum CLI {
    static let version="0.2.0-dev"
    static let usage="""
    Usage:
      ilyrics render AUDIO LYRICS -o VIDEO.mp4 [options]
      ilyrics align  AUDIO LYRICS -o LYRICS.ttml [options]
      ilyrics models install | status | remove
      ilyrics doctor
      ilyrics --help | --version

    Run 'ilyrics COMMAND --help' for the options of a command.
    """
}

let arguments=Array(CommandLine.arguments.dropFirst())
func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data("ilyrics: \(message)\n".utf8));exit(status)
}
do {
    switch arguments.first {
    case nil,"-h","--help","help": print(CLI.usage)
    case "-V","--version": print("ilyrics \(CLI.version)")
    case "render": try await Render.command(arguments.dropFirst())
    case "align": try await Align.command(arguments.dropFirst())
    case "models": try await Models.run(arguments.dropFirst())
    case "doctor": try Doctor.command(arguments.dropFirst())
    default: throw UsageError(message:"unknown command '\(arguments[0])'")
    }
} catch let error as UsageError {
    fail("\(error.message)\n\n\(CLI.usage)",status:2)
} catch let error as Failure {
    fail(error.message,status:1)
} catch {
    fail("\(error)",status:1)
}
