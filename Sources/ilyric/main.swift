import Foundation

/// The user-facing iLyric command (docs/command-line-interface.md).
enum CLI {
    static let version="0.1.0-dev"
    static let usage="""
    Usage:
      ilyric render AUDIO LYRICS -o VIDEO.mp4 [options]
      ilyric align  AUDIO LYRICS -o LYRICS.ttml [options]
      ilyric models install | status | remove
      ilyric doctor
      ilyric --help | --version

    Run 'ilyric COMMAND --help' for the options of a command.
    """
}

let arguments=Array(CommandLine.arguments.dropFirst())
func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data("ilyric: \(message)\n".utf8));exit(status)
}
do {
    switch arguments.first {
    case nil,"-h","--help","help": print(CLI.usage)
    case "-V","--version": print("ilyric \(CLI.version)")
    case "align": try await Align.command(arguments.dropFirst())
    case "models": try await Models.run(arguments.dropFirst())
    default: throw UsageError(message:"unknown command '\(arguments[0])'")
    }
} catch let error as UsageError {
    fail("\(error.message)\n\n\(CLI.usage)",status:2)
} catch let error as Failure {
    fail(error.message,status:1)
} catch {
    fail("\(error)",status:1)
}
