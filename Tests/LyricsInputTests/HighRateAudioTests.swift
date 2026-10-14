import Testing
import Foundation
import LyricsInputCore
import LyricsInputMac

extension AudioSceneTests {
    /// High-resolution sources decode directly at 48 kHz with the same duration; stereo is kept. Synthetic tones.
    @Test func highSampleRatesDecodeAtFortyEightKilohertz() async throws {
        for rate in [176_400, 192_000, 352_800, 384_000] {
            let url = try wav(rate: rate)
            defer { try? FileManager.default.removeItem(at: url) }
            let inspection = try await LocalAudio.inspect(url)
            #expect(inspection.sampleRate == Double(rate) && inspection.channels == 2)
            let audio = try await LocalAudio.decode(url)
            #expect(audio.sourceRate == Double(rate) && audio.sampleCount == 144_000 && audio.channels == 2)
            #expect(audio.samples.contains { $0 > 5000 })
            #expect(try await LocalAudio.decode(url).samples == audio.samples)
        }
    }

    @Test func unsupportedAudioIsDescribedBeforeDecoding() async throws {
        let six = try wav(rate: 48_000, channels: 6)
        defer { try? FileManager.default.removeItem(at: six) }
        await #expect { _ = try await LocalAudio.inspect(six) } throws: { "\($0)".contains("6 channels") }
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try Data().write(to: empty)
        defer { try? FileManager.default.removeItem(at: empty) }
        await #expect { _ = try await LocalAudio.inspect(empty) } throws: { "\($0)".contains("nonempty") }
    }
}
