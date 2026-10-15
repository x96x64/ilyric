import Foundation
import Testing
@testable import AlignmentMac

/// Maintainer check: rebuilds the Japanese recognition model from the pinned checkpoint and runs its self-test.
/// Runs only when ILYRICS_JA_TEMPLATE and ILYRICS_JA_CHECKPOINT name the template folder and pytorch_model.bin;
/// the public suite needs neither the private checkpoint nor network access.
struct JapaneseInstallTests {
    @Test func japaneseModelRebuildsFromThePyTorchArchive() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let template = environment["ILYRICS_JA_TEMPLATE"], let checkpoint = environment["ILYRICS_JA_CHECKPOINT"]
        else { return }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: destination) }
        let compiled = try RecognitionInstaller.install(
            template: URL(fileURLWithPath: template), weights: URL(fileURLWithPath: checkpoint),
            destination: destination, name: "ja-wav2vec2")
        #expect(compiled.lastPathComponent == "ja-wav2vec2.mlmodelc")
    }
}
