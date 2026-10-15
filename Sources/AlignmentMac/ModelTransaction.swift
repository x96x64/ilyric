import Foundation
import Darwin
import AlignmentCore

/// Serializes cache mutations across processes. The lock file remains so waiters share one inode.
final class ModelCacheLock {
    private let descriptor: Int32
    init(_ directory: URL) throws {
        descriptor = open(
            directory.appendingPathComponent(".ilyrics-models.lock").path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC,
            0o600)
        guard descriptor >= 0 else { throw AlignmentError.invalid("Could not open the model cache lock") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw AlignmentError.invalid("The model cache is in use by another operation; try again after it finishes")
        }
    }
    deinit { close(descriptor) }
}

extension InstalledModels {
    struct Transaction: Codable {
        let names: [String]
        let marker: String
        let originals: [String]
        var complete: Bool
    }

    /// Restores interrupted publications under the cache lock; build-only staging folders are not touched.
    static func recoverTransactions(in directory: URL) throws {
        let fm = FileManager.default
        for stage in try fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        where stage.lastPathComponent.hasPrefix(".install-") {
            let properties = try stage.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            guard properties.isSymbolicLink != true, properties.isDirectory == true else { continue }
            let journal = stage.appendingPathComponent("transaction.json")
            guard fm.fileExists(atPath: journal.path) else { continue }
            let state = try JSONDecoder().decode(Transaction.self, from: Data(contentsOf: journal))
            let allowed: [String]
            switch state.marker {
            case "installed.json": allowed = ["htdemucs.mlmodelc", "wav2vec2.mlmodelc", "vocab.json"]
            case "installed-ja.json": allowed = ["ja-wav2vec2.mlmodelc", "ja-vocab.json"]
            default: throw AlignmentError.invalid("Unrecognized model transaction in \(stage.path)")
            }
            guard state.names == allowed, Set(state.originals).isSubset(of: Set(allowed + [state.marker])) else {
                throw AlignmentError.invalid("Invalid model transaction in \(stage.path)")
            }
            try restore(state, staging: stage, into: directory)
            try fm.removeItem(at: stage)
        }
    }

    /// A backup entry proves that the previous file was moved. Missing staged files identify published new files.
    static func restore(_ state: Transaction, staging: URL, into directory: URL) throws {
        guard !state.complete else { return }
        let fm = FileManager.default
        let backup = staging.appendingPathComponent("backup")
        let marker = directory.appendingPathComponent(state.marker)
        if fm.fileExists(atPath: backup.appendingPathComponent(state.marker).path)
            || !state.originals.contains(state.marker)
        {
            if fm.fileExists(atPath: marker.path) { try fm.removeItem(at: marker) }
        }
        // Restore the marker last so an incomplete restoration is never advertised as ready.
        for name in state.names + [state.marker] {
            let target = directory.appendingPathComponent(name)
            let saved = backup.appendingPathComponent(name)
            if fm.fileExists(atPath: saved.path) {
                if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
                try fm.moveItem(at: saved, to: target)
            } else if !state.originals.contains(name), !fm.fileExists(atPath: staging.appendingPathComponent(name).path)
            {
                if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            }
        }
    }

    /// Publishes a prepared generation. A persisted journal permits recovery after process termination.
    static func commit(_ staging: URL, into directory: URL, names: [String], marker: String) throws {
        let fm = FileManager.default
        let backup = staging.appendingPathComponent("backup")
        try fm.createDirectory(at: backup, withIntermediateDirectories: false)
        let journal = staging.appendingPathComponent("transaction.json")
        var state = Transaction(
            names: names, marker: marker,
            originals: ([marker] + names).filter {
                fm.fileExists(atPath: directory.appendingPathComponent($0).path)
            }, complete: false)
        try JSONEncoder().encode(state).write(to: journal, options: .atomic)
        do {
            for name in [marker] + names where state.originals.contains(name) {
                try fm.moveItem(at: directory.appendingPathComponent(name), to: backup.appendingPathComponent(name))
            }
            for name in names + [marker] {
                try fm.moveItem(at: staging.appendingPathComponent(name), to: directory.appendingPathComponent(name))
            }
            state.complete = true
            try JSONEncoder().encode(state).write(to: journal, options: .atomic)
        } catch {
            let original = error
            state.complete = false
            do {
                try restore(state, staging: staging, into: directory)
                try fm.removeItem(at: journal)
                try fm.removeItem(at: backup)
            } catch {
                throw AlignmentError.invalid(
                    "Model installation failed; recovery files remain in \(staging.path): \(error)")
            }
            throw original
        }
        try? fm.removeItem(at: backup)
    }
}
