import Foundation
import Testing
import TimelineCore
import LyricsInputCore
import LyricsInputMac

extension InputTests {
    /// Lines 0.6 s apart: each line holds focus while it is sung, instead of focus running ahead by the full lead.
    @Test func closelySpacedLinesKeepFocusWhileSung() throws {
        let lrc = (0..<8).map { String(format: "[00:%05.2f]Line %d", 2.0 + 0.6 * Double($0), $0) }.joined(
            separator: "\n")
        let audio = LocalAudio(
            samples: Array(repeating: 0, count: 10 * 48_000), sourceRate: 48_000, sourceChannels: 1, sourceFormat: 0)
        let presentation = LocalPresentation(
            focusLead: LocalPresentation.measuredMotion.focusLead, stagger: LocalPresentation.measuredMotion.stagger)
        let scene = try LocalScene(
            lyrics: try LyricsParser.parse(Data(lrc.utf8), format: .lrc), audio: audio, presentation: presentation,
            title: "Synthetic", artist: "Synthetic")
        let composition = scene.renderer.screen.composition
        for k in 1..<7 {
            let sung = Time(Int64(200 + 60 * k + 10), 100)
            #expect(composition.evaluate(sung).focus == k, "line \(k)")
        }
        // A widely spaced line keeps the full measured lead.
        #expect(composition.evaluate(Time(2)).focus == 0)
    }
}

extension InputTests {
    /// A line with only line-level timing fills steadily from its onset to the next line.
    @Test func lineTimedLyricsFillSteadily() throws {
        let audio = LocalAudio(
            samples: Array(repeating: 0, count: 10 * 48_000), sourceRate: 48_000, sourceChannels: 1, sourceFormat: 0)
        let scene = try LocalScene(
            lyrics: try LyricsParser.parse(Data("[00:01.00]Paper boats drift\n[00:05.00]Away".utf8), format: .lrc),
            audio: audio, title: "Synthetic", artist: "Synthetic")
        let composition = scene.renderer.screen.composition
        let progress = { (t: Time) in composition.evaluate(t).paragraphs[0].appearance.spans.first?.progress ?? -1 }
        #expect(progress(Time(1)) == 0 && progress(Time(5)) == 1)
        #expect(progress(Time(3)) > 0.4 && progress(Time(3)) < 0.6)
    }
}
