import Foundation
import CryptoKit
import SpikeCore
import RenderMac

@main struct Spike {
    static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            guard let command = args.first else { throw SpikeError.failure(usage) }
            switch command {
            case "frame":
                guard args.count == 4, let n = Int64(args[1]), let d = Int64(args[2]),
                      n >= 0, n <= 1_000_000_000, d > 0, d <= 1_000_000 else { throw SpikeError.failure(usage) }
                let renderer = try Renderer()
                try renderer.png(Timeline().evaluate(Time(n, d)), to: URL(fileURLWithPath: args[3]))
            case "video":
                guard (2...4).contains(args.count) else { throw SpikeError.failure(usage) }
                let scale = args.count >= 3 ? Int(args[2]) : 1
                let frames = args.count == 4 ? Int(args[3]) : 240
                guard let scale, [1, 2].contains(scale), let frames, (1...36000).contains(frames) else { throw SpikeError.failure(usage) }
                let began = Date()
                let renderer = try Renderer(width: 1080 * scale, height: 1920 * scale)
                let setup = Date().timeIntervalSince(began)
                let metrics = try await Exporter.video(renderer: renderer, to: URL(fileURLWithPath: args[1]), frames: frames)
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                print(String(decoding: try encoder.encode(metrics), as: UTF8.self))
                print("setupSeconds=\(setup) fonts=\(renderer.latin.fonts + renderer.japanese.fonts)")
            case "determinism":
                guard args.count == 1 else { throw SpikeError.failure(usage) }
                let renderer = try Renderer()
                let timeline = Timeline()
                let times = [Time(0), Time(59, 60), Time(1), Time(5, 4), Time(19, 12), Time(3), Time(239, 60)]
                var hashes: [Time: String] = [:]
                for time in times {
                    hashes[time] = SHA256.hash(data: try renderer.raw(timeline.evaluate(time))).description
                }
                // Fresh renderer exercises cache recreation as well as shuffled access.
                let fresh = try Renderer()
                for index in [6, 2, 4, 0, 5, 1, 3, 2, 0] {
                    let time = times[index]
                    guard SHA256.hash(data: try fresh.raw(timeline.evaluate(time))).description == hashes[time] else {
                        throw SpikeError.failure("Raw raster mismatch at \(time)")
                    }
                }
                for time in times { print("\(time.numerator)/\(time.denominator) \(hashes[time]!)") }
                print("Raw BGRA equality passed across sequential, shuffled, repeated, and fresh-renderer evaluation")
            default: throw SpikeError.failure(usage)
            }
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8)); exit(1)
        }
    }
    static let usage = "Spike only: ilyric frame NUMERATOR DENOMINATOR OUTPUT.png | video OUTPUT.mp4 [SCALE=1|2] [FRAMES=240] | determinism"
}
