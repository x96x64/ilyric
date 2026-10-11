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
switch arguments.first {
case nil,"-h","--help","help":
    print(CLI.usage)
case "-V","--version":
    print("ilyric \(CLI.version)")
default:
    FileHandle.standardError.write(Data("ilyric: unknown command '\(arguments[0])'\n\n\(CLI.usage)\n".utf8));exit(2)
}
