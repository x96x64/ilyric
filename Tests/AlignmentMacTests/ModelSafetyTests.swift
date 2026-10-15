import Foundation
import Testing
@testable import AlignmentMac

struct ModelSafetyTests {
    func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ilyrics-audit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func failedFetchPreservesExistingBytes() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let cached = root.appendingPathComponent("weights.bin")
        let bytes = Data("previous cache".utf8)
        try bytes.write(to: cached)
        await #expect(throws: (any Error).self) {
            _ = try await ModelStore.fetch(
                root.appendingPathComponent("missing"), sha256: String(repeating: "0", count: 64), into: root,
                name: "weights.bin")
        }
        #expect((try? Data(contentsOf: cached)) == bytes)
    }

    @Test func removalPreservesUnrelatedDownloads() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let downloads = root.appendingPathComponent("downloads")
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: root.appendingPathComponent("installed.json"))
        let keep = downloads.appendingPathComponent("notes.txt")
        try Data("unrelated".utf8).write(to: keep)
        try InstalledModels.remove(from: root)
        #expect((try? Data(contentsOf: keep)) == Data("unrelated".utf8))
    }

    @Test func failedInstallationPreservesManifest() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let templates = root.appendingPathComponent("templates")
        let cache = root.appendingPathComponent("cache")
        for dir in [templates, cache] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let recipe: [String: Any] = [
            "checkpoint": [
                "file": "f", "sha256": String(repeating: "0", count: 64),
                "url": root.appendingPathComponent("missing").absoluteString,
            ], "weights": ["skeleton_sha256": "a"],
        ]
        let data = try JSONSerialization.data(withJSONObject: recipe)
        for name in ["weight-recipe.json", "wav2vec2-recipe.json"] {
            try data.write(to: templates.appendingPathComponent(name))
        }
        let manifest = cache.appendingPathComponent("installed.json")
        let bytes = try JSONEncoder().encode(InstalledModels.manifest(templates))
        try bytes.write(to: manifest)
        await #expect(throws: (any Error).self) {
            _ = try await InstalledModels.install(into: cache, templates: templates)
        }
        #expect((try? Data(contentsOf: manifest)) == bytes)
    }

    @Test func commitFailureRestoresPreviousGeneration() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let stage = root.appendingPathComponent("stage")
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        for name in ["model", "vocab", "marker"] { try Data("old".utf8).write(to: root.appendingPathComponent(name)) }
        try Data("new".utf8).write(to: stage.appendingPathComponent("model"))
        // Missing staged vocabulary forces failure after the first new file was published.
        #expect(throws: (any Error).self) {
            try InstalledModels.commit(stage, into: root, names: ["model", "vocab"], marker: "marker")
        }
        for name in ["model", "vocab", "marker"] {
            #expect(try Data(contentsOf: root.appendingPathComponent(name)) == Data("old".utf8))
        }
        for name in ["model", "vocab", "marker"] { try Data("new".utf8).write(to: stage.appendingPathComponent(name)) }
        try InstalledModels.commit(stage, into: root, names: ["model", "vocab"], marker: "marker")
        for name in ["model", "vocab", "marker"] {
            #expect(try Data(contentsOf: root.appendingPathComponent(name)) == Data("new".utf8))
        }
    }

    @Test func downloadNamesCannotEscapeTheCache() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        try Data("source".utf8).write(to: source)
        for name in ["../escape", "/absolute", "", ".", ".."] {
            await #expect(throws: (any Error).self) {
                _ = try await ModelStore.fetch(source, sha256: ModelStore.digest(source), into: root, name: name)
            }
        }
    }

}
