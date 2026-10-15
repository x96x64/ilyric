import Foundation
import Testing
@testable import AlignmentMac

struct ModelTransactionTests {
    @Test func interruptedPublicationsRestoreAtEveryMoveBoundary() throws {
        let fm = FileManager.default
        let names = ["ja-wav2vec2.mlmodelc", "ja-vocab.json"]
        let marker = "installed-ja.json"
        for installed in [false, true] {
            let moves = installed ? 6 : 3
            for cut in 0...moves {
                let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                defer { try? fm.removeItem(at: root) }
                let stage = root.appendingPathComponent(".install-test")
                let backup = stage.appendingPathComponent("backup")
                try fm.createDirectory(at: backup, withIntermediateDirectories: true)
                for name in names + [marker] {
                    try Data("new".utf8).write(to: stage.appendingPathComponent(name))
                    if installed { try Data("old".utf8).write(to: root.appendingPathComponent(name)) }
                }
                let state = InstalledModels.Transaction(
                    names: names, marker: marker, originals: installed ? names + [marker] : [], complete: false)
                try JSONEncoder().encode(state).write(to: stage.appendingPathComponent("transaction.json"))
                var actions: [(URL, URL)] = []
                if installed {
                    actions += ([marker] + names).map {
                        (root.appendingPathComponent($0), backup.appendingPathComponent($0))
                    }
                }
                actions += (names + [marker]).map {
                    (stage.appendingPathComponent($0), root.appendingPathComponent($0))
                }
                for (source, target) in actions.prefix(cut) { try fm.moveItem(at: source, to: target) }
                // Recovery is repeatable even if interrupted after all old files have been restored.
                try InstalledModels.restore(state, staging: stage, into: root)
                try InstalledModels.recoverTransactions(in: root)
                for name in names + [marker] {
                    if installed {
                        #expect(try Data(contentsOf: root.appendingPathComponent(name)) == Data("old".utf8))
                    } else {
                        #expect(!fm.fileExists(atPath: root.appendingPathComponent(name).path))
                    }
                }
                #expect(!fm.fileExists(atPath: stage.path))
            }
        }
    }

    @Test func completedPublicationKeepsNewFilesAndRejectsInvalidRecoveryPaths() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let stage = root.appendingPathComponent(".install-test")
        try fm.createDirectory(at: stage.appendingPathComponent("backup"), withIntermediateDirectories: true)
        let names = ["ja-wav2vec2.mlmodelc", "ja-vocab.json"]
        for name in names + ["installed-ja.json"] { try Data("new".utf8).write(to: root.appendingPathComponent(name)) }
        let state = InstalledModels.Transaction(
            names: names, marker: "installed-ja.json", originals: [], complete: true)
        try JSONEncoder().encode(state).write(to: stage.appendingPathComponent("transaction.json"))
        try InstalledModels.recoverTransactions(in: root)
        #expect(!fm.fileExists(atPath: stage.path))
        for name in names { #expect(try Data(contentsOf: root.appendingPathComponent(name)) == Data("new".utf8)) }
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        let invalid = InstalledModels.Transaction(
            names: ["../unrelated"], marker: "installed-ja.json", originals: [], complete: false)
        try JSONEncoder().encode(invalid).write(to: stage.appendingPathComponent("transaction.json"))
        #expect(throws: (any Error).self) { try InstalledModels.recoverTransactions(in: root) }
        #expect(fm.fileExists(atPath: stage.path))
    }

    @Test func cacheLockRejectsAnotherProcessAndReleasesAfterScope() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let executable = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/debug/ilyrics")
        func remove() throws -> (Int32, String) {
            let process = Process()
            let errors = Pipe()
            process.executableURL = executable
            process.arguments = ["models", "remove"]
            process.environment = ProcessInfo.processInfo.environment.merging(["ILYRICS_MODELS": root.path]) { _, new in
                new
            }
            process.standardError = errors
            process.standardOutput = FileHandle.nullDevice
            try process.run()
            let text = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            process.waitUntilExit()
            return (process.terminationStatus, text)
        }
        do {
            let lock = try ModelCacheLock(root)
            defer { withExtendedLifetime(lock) {} }
            let blocked = try remove()
            #expect(blocked.0 == 1 && blocked.1.contains("in use by another operation"))
        }
        #expect(try remove().0 == 0)
    }
    @Test func unrelatedDirectoryRemainsUntouched() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try Data("keep".utf8).write(to: root.appendingPathComponent("notes.txt"))
        try InstalledModels.remove(from: root)
        #expect(try fm.contentsOfDirectory(atPath: root.path) == ["notes.txt"])
    }

}
