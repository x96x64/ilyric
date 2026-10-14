import Foundation
import ProgressDisplay

/// A usage error: reported with the command's usage and exit status 2.
struct UsageError: Error { let message: String }
/// A runtime failure: reported with its recovery step and exit status 1.
struct Failure: Error { let message: String }

/// Parsed command-line arguments of one subcommand: positional operands, flags, and option values.
struct Options {
    var operands = [String](), flags = Set<String>(), values = [String: String]()

    /// `valued` and `flags` list long names; `short` maps single letters to long names.
    init(_ arguments: ArraySlice<String>, valued: Set<String>, flags known: Set<String>, short: [Character: String])
        throws
    {
        var rest = arguments[...]
        while let argument = rest.popFirst() {
            if argument == "--" {
                operands += rest
                break
            }
            var name: String
            var inline: String? = nil
            if argument.hasPrefix("--") {
                let body = argument.dropFirst(2)
                if let eq = body.firstIndex(of: "=") {
                    name = String(body[..<eq])
                    inline = String(body[body.index(after: eq)...])
                } else {
                    name = String(body)
                }
            } else if argument.hasPrefix("-"), argument.count > 1, argument != "-" {
                let letter = argument[argument.index(after: argument.startIndex)]
                guard let long = short[letter] else { throw UsageError(message: "unknown option '\(argument)'") }
                name = long
                if argument.count > 2 { inline = String(argument.dropFirst(2)) }
            } else {
                operands.append(argument)
                continue
            }
            if valued.contains(name) {
                guard let value = inline ?? rest.popFirst() else {
                    throw UsageError(message: "option '--\(name)' requires a value")
                }
                values[name] = value
            } else if known.contains(name) {
                guard inline == nil else { throw UsageError(message: "option '--\(name)' takes no value") }
                flags.insert(name)
            } else {
                throw UsageError(message: "unknown option '\(argument)'")
            }
        }
    }
    func has(_ flag: String) -> Bool { flags.contains(flag) }
}

/// Messages and stage progress on standard error through one serialized reporter. `--quiet` keeps only
/// warnings and errors; details appear only with `--verbose`.
struct Console {
    let quiet, verbose: Bool
    let progress: StageReporter
    init(quiet: Bool, verbose: Bool, stages: [String] = []) {
        self.quiet = quiet
        self.verbose = verbose && !quiet
        progress = StageReporter(stages: stages, style: .detect(), quiet: quiet, verbose: verbose)
        if !stages.isEmpty { progress.startTicker() }
    }
    func say(_ s: String) { progress.info(s) }
    func detail(_ s: String) { progress.detail(s) }
    func warning(_ s: String) { progress.warning(s) }
}

/// Elapsed time as "1 min 05 s" or "8.2 s".
func elapsed(_ seconds: Double) -> String {
    seconds < 60
        ? String(format: "%.1f s", seconds) : String(format: "%d min %02d s", Int(seconds) / 60, Int(seconds) % 60)
}

/// Checks an output path before any work: it must not be a directory or one of the inputs, its folder must exist and
/// be writable, and an existing file is replaced only with `--force`.
func checkOutput(_ path: String, force: Bool, inputs: [String] = []) throws -> URL {
    let url = URL(fileURLWithPath: path)
    let files = FileManager.default
    var isDirectory: ObjCBool = false
    if files.fileExists(atPath: url.path, isDirectory: &isDirectory) {
        if isDirectory.boolValue { throw Failure(message: "\(path) is a folder; name an output file") }
        if !force { throw Failure(message: "\(path) already exists; pass --force to replace it") }
    }
    if let input = inputs.first(where: { sameFile(path, $0) }) {
        throw UsageError(message: "\(path) is also given as \(input); choose a different output file")
    }
    let folder = url.deletingLastPathComponent()
    guard files.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw Failure(message: "the folder for \(path) does not exist")
    }
    guard files.isWritableFile(atPath: folder.path) else {
        throw Failure(message: "the folder for \(path) is not writable")
    }
    return url
}

/// Whether two paths name the same file, through symbolic links, hard links, or a case-insensitive volume.
func sameFile(_ a: String, _ b: String) -> Bool {
    let x = URL(fileURLWithPath: a).standardizedFileURL.resolvingSymlinksInPath()
    let y = URL(fileURLWithPath: b).standardizedFileURL.resolvingSymlinksInPath()
    if x.path == y.path { return true }
    guard let i = try? x.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
        let j = try? y.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
    else { return false }
    return i.isEqual(j)
}
