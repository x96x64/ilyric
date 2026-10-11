import Foundation
import AlignmentCore
import AlignmentMac

/// Model cache and template locations, and the `models` subcommand.
enum Models {
    /// The cache directory: `ILYRIC_MODELS`, else Application Support/iLyric/Models.
    static var directory: URL {
        ProcessInfo.processInfo.environment["ILYRIC_MODELS"].map { URL(fileURLWithPath:$0,isDirectory:true) } ?? ModelStore.defaultDirectory
    }

    /// The weightless model templates: `ILYRIC_TEMPLATES`, else share/ilyric/templates beside the executable's prefix.
    static func templates() throws -> URL {
        if let path=ProcessInfo.processInfo.environment["ILYRIC_TEMPLATES"] { return URL(fileURLWithPath:path,isDirectory:true) }
        let executable=URL(fileURLWithPath:CommandLine.arguments[0]).resolvingSymlinksInPath()
        let shared=executable.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("share/ilyric/templates")
        guard FileManager.default.fileExists(atPath:shared.appendingPathComponent("weight-recipe.json").path) else {
            throw Failure(message:"model templates were not found; set ILYRIC_TEMPLATES to a directory built by scripts/build_separation_template.py and scripts/build_recognition_template.py")
        }
        return shared
    }

    /// Installed models, installing them first when missing or built from other templates.
    static func ready(_ console: Console) async throws -> InstalledModels {
        let templates=try templates()
        if let models=try InstalledModels.existing(in:directory,templates:templates) { return models }
        console.say("Installing alignment models into \(directory.path) (first use; about 460 MB is downloaded)")
        return try await install(templates,console)
    }

    static func install(_ templates: URL, _ console: Console) async throws -> InstalledModels {
        let started=Date()
        do {
            let models=try await InstalledModels.install(into:directory,templates:templates) { console.say("  \($0)") }
            console.say("Installed alignment models in \(elapsed(Date().timeIntervalSince(started)))")
            return models
        } catch let error as URLError {
            throw Failure(message:"model download failed (\(error.localizedDescription)); check the network connection and run 'ilyric models install' again")
        }
    }

    static let help="""
    Usage: ilyric models install | status | remove

    Installs, reports, or removes the alignment models. Installation downloads the pinned HTDemucs checkpoint from
    Meta and the wav2vec2 weights from Hugging Face, verifies their SHA-256, and rebuilds the Core ML models locally.

    Environment:
      ILYRIC_MODELS     Model cache directory (default: ~/Library/Application Support/iLyric/Models)
      ILYRIC_TEMPLATES  Directory of the weightless model templates
    """

    static func run(_ arguments: ArraySlice<String>) async throws {
        let options=try Options(arguments,valued:[],flags:["help","quiet","verbose","force"],short:["h":"help","q":"quiet","v":"verbose"])
        if options.has("help") { print(help);return }
        let console=Console(quiet:options.has("quiet"),verbose:options.has("verbose"))
        guard options.operands.count==1 else { throw UsageError(message:"expected one of install, status, remove") }
        switch options.operands[0] {
        case "install":
            let templates=try templates()
            if !options.has("force"),try InstalledModels.existing(in:directory,templates:templates) != nil { console.say("Alignment models are already installed in \(directory.path)");return }
            _=try await install(templates,console)
        case "status":
            let templates=try? templates()
            let installed=try templates.flatMap { try InstalledModels.existing(in:directory,templates:$0) } != nil
            print("Cache:     \(directory.path)")
            print("Templates: \(templates?.path ?? "not found (set ILYRIC_TEMPLATES)")")
            print("Models:    \(installed ? "installed (\(size(directory)))" : "not installed; run 'ilyric models install'")")
        case "remove":
            try InstalledModels.remove(from:directory)
            console.say("Removed alignment models from \(directory.path)")
        default: throw UsageError(message:"unknown models action '\(options.operands[0])'")
        }
    }

    static func size(_ directory: URL) -> String {
        var total=0
        if let items=FileManager.default.enumerator(at:directory,includingPropertiesForKeys:[.fileSizeKey]) {
            for case let url as URL in items { total+=(try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0) ?? 0 }
        }
        return ByteCountFormatter.string(fromByteCount:Int64(total),countStyle:.file)
    }
}
