import Darwin
import Foundation
import CryptoKit
import AlignmentCore

/// Pinned downloads for first launch: a file is kept only when its SHA-256 matches, and a verified copy is reused.
public enum ModelStore {
    /// The user's cache directory for iLyrics models.
    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(
            "iLyrics/Models", isDirectory: true)
    }

    /// Returns the local file for `url`, downloading it when absent or corrupted.
    public static func fetch(_ url: URL, sha256: String, into directory: URL, name: String) async throws -> URL {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\"),
            !name.utf8.contains(0)
        else { throw AlignmentError.invalid("Model download name must be a filename") }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.appendingPathComponent(name)
        if fm.fileExists(atPath: target.path) {
            if try digest(target) == sha256 { return target }
        }
        let (temporary, response) = try await URLSession.shared.download(from: url)
        defer { try? fm.removeItem(at: temporary) }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AlignmentError.invalid("Download of \(name) failed with HTTP \(http.statusCode)")
        }
        guard try digest(temporary) == sha256 else {
            throw AlignmentError.invalid("Downloaded \(name) does not match its pinned SHA-256")
        }
        let staged = directory.appendingPathComponent(".download-\(UUID().uuidString)")
        try fm.copyItem(at: temporary, to: staged)
        defer { try? fm.removeItem(at: staged) }
        guard rename(staged.path, target.path) == 0 else {
            throw AlignmentError.invalid("Could not commit model download \(name): \(String(cString: strerror(errno)))")
        }
        return target
    }

    static func digest(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// The installed alignment models in a cache directory: compiled HTDemucs and wav2vec2 networks rebuilt from their
/// publishers' files, the recognition vocabulary, and a manifest naming the templates they were built from.
public struct InstalledModels: Equatable, Sendable {
    public let separator, recognizer, vocabulary: URL

    struct Manifest: Codable, Equatable {
        let format: String
        let separation, recognition: String
    }
    struct Pins: Decodable {
        struct Checkpoint: Decodable {
            let file, sha256, url: String
            let vocabulary_url, vocabulary_sha256: String?
        }
        struct Weights: Decodable { let skeleton_sha256: String }
        let checkpoint: Checkpoint
        let weights: Weights
    }

    init(_ directory: URL) {
        separator = directory.appendingPathComponent("htdemucs.mlmodelc", isDirectory: true)
        recognizer = directory.appendingPathComponent("wav2vec2.mlmodelc", isDirectory: true)
        vocabulary = directory.appendingPathComponent("vocab.json", isDirectory: false)
    }

    static func pins(_ templates: URL) throws -> (separation: Pins, recognition: Pins) {
        func read(_ name: String) throws -> Pins {
            let url = templates.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw AlignmentError.invalid("Model template file \(name) is missing from \(templates.path)")
            }
            return try JSONDecoder().decode(Pins.self, from: Data(contentsOf: url))
        }
        return (try read("weight-recipe.json"), try read("wav2vec2-recipe.json"))
    }
    static func manifest(_ templates: URL) throws -> Manifest {
        let p = try pins(templates)
        return Manifest(
            format: "ilyrics-installed-models-1", separation: p.separation.weights.skeleton_sha256,
            recognition: p.recognition.weights.skeleton_sha256)
    }

    /// The models in `directory` when they were completely installed from `templates`, otherwise nil.
    public static func existing(in directory: URL, templates: URL) throws -> InstalledModels? {
        let models = InstalledModels(directory)
        let fm = FileManager.default
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("installed.json")),
            let found = try? JSONDecoder().decode(Manifest.self, from: data), found == (try manifest(templates)),
            [models.separator, models.recognizer, models.vocabulary].allSatisfy({ fm.fileExists(atPath: $0.path) })
        else { return nil }
        return models
    }

    /// Downloads the pinned publisher files, rebuilds and self-tests both models, and removes the downloads.
    /// `progress` receives one line per step.
    public static func install(into directory: URL, templates: URL, progress: (String) -> Void = { _ in }) async throws
        -> InstalledModels
    {
        let p = try pins(templates)
        let fm = FileManager.default
        let downloads = directory.appendingPathComponent("downloads", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let lock = try ModelCacheLock(directory)
        defer { withExtendedLifetime(lock) {} }
        try recoverTransactions(in: directory)
        let staging = directory.appendingPathComponent(".install-\(UUID().uuidString)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        var preserveStaging = false
        defer { if !preserveStaging { try? fm.removeItem(at: staging) } }
        func fetch(_ url: String, _ sha: String, _ name: String) async throws -> URL {
            guard let remote = URL(string: url) else { throw AlignmentError.invalid("Malformed model URL \(url)") }
            progress("Fetching \(name) from \(remote.host ?? url)")
            return try await ModelStore.fetch(remote, sha256: sha, into: downloads, name: name)
        }
        let checkpoint = try await fetch(
            p.separation.checkpoint.url, p.separation.checkpoint.sha256, p.separation.checkpoint.file)
        progress("Rebuilding the vocal separation model")
        _ = try SeparationInstaller.install(template: templates, checkpoint: checkpoint, destination: staging)
        guard let vocabularyURL = p.recognition.checkpoint.vocabulary_url,
            let vocabularySHA = p.recognition.checkpoint.vocabulary_sha256
        else {
            throw AlignmentError.invalid("Recognition recipe lacks a pinned vocabulary")
        }
        let weights = try await fetch(
            p.recognition.checkpoint.url, p.recognition.checkpoint.sha256, p.recognition.checkpoint.file)
        let vocabulary = try await fetch(vocabularyURL, vocabularySHA, "vocab.json")
        progress("Rebuilding and testing the speech recognition model")
        _ = try RecognitionInstaller.install(template: templates, weights: weights, destination: staging)
        let stagedModels = InstalledModels(staging)
        try fm.copyItem(at: vocabulary, to: stagedModels.vocabulary)
        try JSONEncoder().encode(try manifest(templates)).write(
            to: staging.appendingPathComponent("installed.json"), options: .atomic)
        do {
            try commit(
                staging, into: directory, names: ["htdemucs.mlmodelc", "wav2vec2.mlmodelc", "vocab.json"],
                marker: "installed.json")
        } catch {
            preserveStaging = fm.fileExists(atPath: staging.appendingPathComponent("backup").path)
            throw error
        }
        for file in [checkpoint, weights, vocabulary] { try? fm.removeItem(at: file) }
        let models = InstalledModels(directory)
        return models
    }

    /// The Japanese recognition model and vocabulary in `directory` when installed from `templates`, otherwise nil.
    /// Japanese uses the shared separation model and is installed separately, only when Japanese is aligned.
    public static func existingJapanese(in directory: URL, templates: URL) throws -> (recognizer: URL, vocabulary: URL)?
    {
        let fm = FileManager.default
        let recognizer = directory.appendingPathComponent("ja-wav2vec2.mlmodelc", isDirectory: true)
        let vocabulary = directory.appendingPathComponent("ja-vocab.json")
        let pins = try japanesePins(templates)
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("installed-ja.json")),
            String(decoding: data, as: UTF8.self) == pins.weights.skeleton_sha256,
            fm.fileExists(atPath: recognizer.path), fm.fileExists(atPath: vocabulary.path)
        else { return nil }
        return (recognizer, vocabulary)
    }

    static func japanesePins(_ templates: URL) throws -> Pins {
        let url = templates.appendingPathComponent("ja-wav2vec2-recipe.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AlignmentError.invalid(
                "Model template file ja-wav2vec2-recipe.json is missing from \(templates.path)")
        }
        return try JSONDecoder().decode(Pins.self, from: Data(contentsOf: url))
    }

    /// Downloads the pinned Japanese checkpoint, rebuilds and self-tests the Japanese recognition model.
    public static func installJapanese(into directory: URL, templates: URL, progress: (String) -> Void = { _ in })
        async throws -> (recognizer: URL, vocabulary: URL)
    {
        let p = try japanesePins(templates)
        let fm = FileManager.default
        let downloads = directory.appendingPathComponent("downloads", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let lock = try ModelCacheLock(directory)
        defer { withExtendedLifetime(lock) {} }
        try recoverTransactions(in: directory)
        let staging = directory.appendingPathComponent(".install-\(UUID().uuidString)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        var preserveStaging = false
        defer { if !preserveStaging { try? fm.removeItem(at: staging) } }
        guard let remote = URL(string: p.checkpoint.url),
            let vocabularyURL = p.checkpoint.vocabulary_url.flatMap(URL.init),
            let vocabularySHA = p.checkpoint.vocabulary_sha256
        else { throw AlignmentError.invalid("Japanese recognition recipe lacks pinned URLs") }
        progress("Fetching \(p.checkpoint.file) from \(remote.host ?? p.checkpoint.url)")
        let weights = try await ModelStore.fetch(
            remote, sha256: p.checkpoint.sha256, into: downloads, name: "ja-" + p.checkpoint.file)
        let vocabulary = try await ModelStore.fetch(
            vocabularyURL, sha256: vocabularySHA, into: downloads, name: "ja-vocab.json")
        progress("Rebuilding and testing the Japanese speech recognition model")
        _ = try RecognitionInstaller.install(
            template: templates, weights: weights, destination: staging, name: "ja-wav2vec2")
        try fm.copyItem(at: vocabulary, to: staging.appendingPathComponent("ja-vocab.json"))
        try Data(p.weights.skeleton_sha256.utf8).write(
            to: staging.appendingPathComponent("installed-ja.json"), options: .atomic)
        do {
            try commit(
                staging, into: directory, names: ["ja-wav2vec2.mlmodelc", "ja-vocab.json"], marker: "installed-ja.json")
        } catch {
            preserveStaging = fm.fileExists(atPath: staging.appendingPathComponent("backup").path)
            throw error
        }
        try? fm.removeItem(at: weights)
        try? fm.removeItem(at: vocabulary)
        return (
            directory.appendingPathComponent("ja-wav2vec2.mlmodelc"), directory.appendingPathComponent("ja-vocab.json")
        )
    }

    /// Removes installed models and recognized download files from `directory`, preserving other downloads.
    /// A directory without an installed model or manifest is left untouched.
    public static func remove(from directory: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return }
        let markers = [
            "installed.json", "installed-ja.json", "htdemucs.mlmodelc", "wav2vec2.mlmodelc", "ja-wav2vec2.mlmodelc",
        ]
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let hasTransaction = contents.contains {
            $0.lastPathComponent.hasPrefix(".install-")
                && fm.fileExists(atPath: $0.appendingPathComponent("transaction.json").path)
        }
        guard
            hasTransaction || fm.fileExists(atPath: directory.appendingPathComponent(".ilyrics-models.lock").path)
                || markers.contains(where: { fm.fileExists(atPath: directory.appendingPathComponent($0).path) })
        else { return }
        let lock = try ModelCacheLock(directory)
        defer { withExtendedLifetime(lock) {} }
        try recoverTransactions(in: directory)
        guard markers.contains(where: { fm.fileExists(atPath: directory.appendingPathComponent($0).path) }) else {
            return
        }
        for name in [
            "installed.json", "installed-ja.json", "htdemucs.mlmodelc", "wav2vec2.mlmodelc", "ja-wav2vec2.mlmodelc",
            "vocab.json", "ja-vocab.json",
        ] {
            let url = directory.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
        }
        let downloads = directory.appendingPathComponent("downloads")
        if (try? downloads.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == false {
            for name in [
                "955717e8-8726e21a.th", "model.safetensors", "ja-model.safetensors", "vocab.json", "ja-vocab.json",
            ] {
                let file = downloads.appendingPathComponent(name)
                if (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                    try fm.removeItem(at: file)
                }
            }
            if (try? fm.contentsOfDirectory(atPath: downloads.path).isEmpty) == true {
                try fm.removeItem(at: downloads)
            }
        }
    }
}
