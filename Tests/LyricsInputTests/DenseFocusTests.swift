import Foundation
import CoreGraphics
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
    /// Synthetic TTML isolates presentation timing from acoustic alignment, for Latin and Japanese text.
    @Test(arguments: ["A", "あ"]) func fillIntervalsStayBeforeNextFocus(text: String) throws {
        let audio = LocalAudio(
            samples: Array(repeating: 0, count: 6 * 48_000), sourceRate: 48_000, sourceChannels: 1, sourceFormat: 0)
        let deadline = Time(21, 5)
        let cases: [(String, String, Time, Time)] = [
            ("1", "2", Time(1), Time(2)),
            ("4.198", "4.3", Time(2099, 500), deadline),
            ("4.1995", "4.3", Time(8399, 2000), deadline),
            ("4.1995", "4.19975", Time(8399, 2000), deadline),
            ("4.2", "4.3", Time(4199, 1000), deadline),
            ("4.202", "4.3", Time(4199, 1000), deadline),
        ]
        for (begin, end, expectedBegin, expectedEnd) in cases {
            let bytes = Data(
                ("<tt xmlns=\"http://www.w3.org/ns/ttml\" xml:space=\"preserve\"><body><div>"
                    + "<p begin=\"0s\" end=\"5.1s\"><span begin=\"\(begin)s\" end=\"\(end)s\">\(text)</span></p>"
                    + "<p begin=\"5.1s\" end=\"6s\">B</p></div></body></tt>").utf8)
            let lyrics = try TTMLParser.parse(bytes)
            let original = lyrics.entries
            let scene = try LocalScene(
                lyrics: lyrics, audio: audio, presentation: LocalPresentation(focusLead: Time(9, 10)),
                title: "Synthetic", artist: "Synthetic")
            let composition = scene.renderer.screen.composition
            let event = try #require(composition.paragraphs[0].input.events.first)
            let a = try #require(event.begin).validated()
            let b = try #require(event.end).validated()
            #expect(a == expectedBegin && b == expectedEnd && a >= Time(0) && a < b && b <= deadline)
            #expect(event.start == 0 && event.length == text.utf16.count)
            #expect(scene.lyrics.entries == original && lyrics.entries == original)
            #expect(try TTMLParser.parse(bytes).entries == original)
            #expect(composition.paragraphs[0].begin == original[0].time)
            #expect(composition.paragraphs[0].end == original[0].intervalEnd)
            #expect(composition.evaluate(deadline - Time(1, 1_000_000)).focus == 0)
            #expect(composition.evaluate(deadline).focus == 1)
            let times = [deadline, a, b, Time(0), deadline - Time(1, 1_000_000)]
            let snapshots = times.map { composition.evaluate($0).paragraphs[0].appearance }
            for i in times.indices.reversed() {
                #expect(composition.evaluate(times[i]).paragraphs[0].appearance == snapshots[i])
            }
            #expect(composition.evaluate(b).paragraphs[0].appearance.spans[0].progress == 1)
        }
    }

    /// Synthetic dense LRC onsets leave only half a millisecond before the next focus; fill lead clamps to zero.
    @Test(arguments: [Time(0), LocalPresentation.measuredFillLead])
    func denseFillIntervalsRemainPositiveNearZero(fillLead: Time) throws {
        let bytes = Data("[00:00.000]A\n[00:00.001]B\n[00:00.002]C".utf8)
        let lyrics = try LRCParser.parse(bytes)
        let original = lyrics.entries
        let audio = LocalAudio(
            samples: Array(repeating: 0, count: 48_000), sourceRate: 48_000, sourceChannels: 1, sourceFormat: 0)
        let scene = try LocalScene(
            lyrics: lyrics, audio: audio,
            presentation: LocalPresentation(focusLead: Time(9, 10), fillLead: fillLead),
            title: "Synthetic", artist: "Synthetic")
        let composition = scene.renderer.screen.composition
        for i in 0..<2 {
            let event = try #require(composition.paragraphs[i].input.events.first)
            let a = try #require(event.begin).validated()
            let b = try #require(event.end).validated()
            let deadline = Time(Int64(2 * i + 1), 2000)
            #expect(Time(0) <= a && a < b && b <= deadline)
            #expect(composition.evaluate(deadline).focus == i + 1)
        }
        #expect(scene.lyrics.entries == original)
        // Simultaneous distinct LRC onsets and overlapping TTML paragraphs retain their existing rejection.
        #expect(throws: InputError.self) {
            _ = try LRCParser.parse(Data("[00:00.000]A\n[00:00.000]B".utf8))
        }
        #expect(throws: InputError.self) {
            _ = try TTMLParser.parse(
                Data(
                    ("<tt xmlns=\"http://www.w3.org/ns/ttml\" xml:space=\"preserve\"><body><div>"
                        + "<p begin=\"0s\" end=\"1s\">A</p><p begin=\"0s\" end=\"1s\">B</p>"
                        + "</div></body></tt>").utf8))
        }
    }

    @Test func lateFillNearZeroUsesTheAvailableInterval() throws {
        let bytes = Data(
            ("<tt xmlns=\"http://www.w3.org/ns/ttml\" xml:space=\"preserve\"><body><div>"
                + "<p begin=\"0s\" end=\"0.0002s\"><span begin=\"0.00015s\" end=\"0.0002s\">あ</span></p>"
                + "<p begin=\"0.0002s\" end=\"1s\">B</p></div></body></tt>").utf8)
        let lyrics = try TTMLParser.parse(bytes)
        let audio = LocalAudio(
            samples: Array(repeating: 0, count: 48_000), sourceRate: 48_000, sourceChannels: 1, sourceFormat: 0)
        let scene = try LocalScene(
            lyrics: lyrics, audio: audio, presentation: LocalPresentation(focusLead: Time(9, 10)),
            title: "Synthetic", artist: "Synthetic")
        let composition = scene.renderer.screen.composition
        let event = try #require(composition.paragraphs[0].input.events.first)
        #expect(try #require(event.begin).validated() == Time(0))
        #expect(try #require(event.end).validated() == Time(1, 10_000))
        #expect(composition.evaluate(Time(1, 10_000)).focus == 1)
        #expect(scene.lyrics.entries == lyrics.entries)
    }

    /// Synthetic odd microseconds, and existing millisecond-unit precision, require exact derived boundaries.
    @Test(arguments: ["0.000001s", "0.000003s", "0.000999s", "0.000001ms"])
    func generatedFocusBoundariesKeepExactPrecision(next: String) throws {
        let bytes = Data(
            ("<tt xmlns=\"http://www.w3.org/ns/ttml\" xml:space=\"preserve\"><body><div>"
                + "<p begin=\"0s\" end=\"\(next)\">A</p><p begin=\"\(next)\" end=\"1s\">B</p>"
                + "</div></body></tt>").utf8)
        let lyrics = try TTMLParser.parse(bytes)
        let audio = LocalAudio(
            samples: Array(repeating: 0, count: 48_000), sourceRate: 48_000, sourceChannels: 1, sourceFormat: 0)
        let scene = try LocalScene(
            lyrics: lyrics, audio: audio,
            presentation: LocalPresentation(focusLead: Time(9, 10), fillLead: LocalPresentation.measuredFillLead),
            title: "Synthetic", artist: "Synthetic")
        let composition = scene.renderer.screen.composition
        let event = try #require(composition.paragraphs[0].input.events.first)
        let begin = try #require(event.begin).validated()
        let end = try #require(event.end).validated()
        let suppliedNext = try TTMLParser.time(next)
        let deadline = Time(suppliedNext.numerator, suppliedNext.denominator * 2)
        #expect(begin == Time(0) && begin < end && end == deadline)
        #expect(composition.evaluate(deadline).focus == 1)
        #expect(composition.evaluate(deadline).paragraphs[0].appearance.spans[0].progress == 1)
        #expect(scene.lyrics.entries == lyrics.entries)
        #expect(try TTMLParser.parse(bytes).entries == lyrics.entries)
        #expect(throws: InputError.self) { try TTMLParser.time("0.0000001s") }
    }

    @Test func boundedFillAndGapFocusKeepTheirSuppliedTiming() throws {
        let bytes = Data(
            ("<tt xmlns=\"http://www.w3.org/ns/ttml\" xml:space=\"preserve\"><body><div>"
                + "<p begin=\"0s\" end=\"1s\"><span begin=\"0.9s\" end=\"1s\">A</span></p>"
                + "<p begin=\"3s\" end=\"4s\">B</p></div></body></tt>").utf8)
        let lyrics = try TTMLParser.parse(bytes)
        let audio = LocalAudio(
            samples: Array(repeating: 0, count: 4 * 48_000), sourceRate: 48_000, sourceChannels: 1, sourceFormat: 0)
        let scene = try LocalScene(
            lyrics: lyrics, audio: audio,
            presentation: LocalPresentation(minimumGap: Time(1), focusLead: Time(9, 10)),
            title: "Synthetic", artist: "Synthetic")
        let composition = scene.renderer.screen.composition
        let event = try #require(composition.paragraphs[0].input.events.first)
        #expect(try #require(event.begin).validated() == Time(9, 10))
        #expect(try #require(event.end).validated() == Time(1))
        #expect(composition.gaps.count == 1)
        #expect(composition.evaluate(Time(1)).focus == -1)
        #expect(composition.evaluate(Time(1)).gaps[0].state != nil)
        #expect(composition.evaluate(Time(21, 10)).focus == 1)
        #expect(scene.lyrics.entries == lyrics.entries)
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

extension InputTests {
    /// A paragraph of many rows under visible controls moves up as its fill reaches the lower rows, smoothly, and
    /// a short paragraph never moves.
    @Test func tallParagraphsKeepTheFillingRowVisible() throws {
        let long = Array(repeating: "window", count: 22).joined(separator: " ")
        let audio = LocalAudio(
            samples: Array(repeating: 0, count: 20 * 48_000), sourceRate: 48_000, sourceChannels: 1, sourceFormat: 0)
        let scene = try LocalScene(
            lyrics: try LyricsParser.parse(Data("[00:01.00]\(long)\n[00:15.00]Short".utf8), format: .lrc),
            audio: audio,
            presentation: LocalPresentation(
                focusLead: LocalPresentation.measuredMotion.focusLead,
                stagger: LocalPresentation.measuredMotion.stagger,
                canvas: .video),
            title: "Synthetic", artist: "Synthetic")
        let r = scene.renderer
        #expect(r.lyrics.paragraphs[0].lines.count >= 6)
        let viewport = r.screen.canvas.viewport
        let states = stride(from: 1.0, through: 18.0, by: 0.05).map {
            r.screen.composition.evaluate(Time(Int64(($0 * 100).rounded()), 100))
        }
        let lifts = states.map { r.overflow($0, viewport: viewport) }
        #expect(lifts.first == 0 && lifts.max()! > 200 && lifts.last! == 0)
        // The lift never makes the drawn paragraph move faster than the composition's own scrolling, and it never
        // jumps when focus moves on.
        let drawn = zip(states, lifts).map { $0.paragraphs[0].translationY - $1 }
        let scrolled = states.map { $0.paragraphs[0].translationY }
        for k in 0..<states.count - 1 {
            #expect(abs(drawn[k + 1] - drawn[k]) <= abs(scrolled[k + 1] - scrolled[k]) + 40)
        }
    }
}

extension InputTests {
    /// Original synthetic text exercises the native renderer at a corrected sub-millisecond boundary.
    @Test(arguments: ["A", "あ"]) func boundedFillFramesAreRandomAccessDeterministic(text: String) throws {
        let bytes = Data(
            ("<tt xmlns=\"http://www.w3.org/ns/ttml\" xml:space=\"preserve\"><body><div>"
                + "<p begin=\"0s\" end=\"5.1s\"><span begin=\"4.202s\" end=\"4.3s\">\(text)</span></p>"
                + "<p begin=\"5.1s\" end=\"6s\">B</p></div></body></tt>").utf8)
        let scene = try LocalScene(
            lyrics: TTMLParser.parse(bytes),
            audio: LocalAudio(
                samples: Array(repeating: 0, count: 6 * 48_000), sourceRate: 48_000,
                sourceChannels: 1, sourceFormat: 0),
            presentation: LocalPresentation(icons: .original, focusLead: Time(9, 10)),
            title: "Synthetic", artist: "Synthetic")
        func frame(_ time: Time, fresh: Bool = false) throws -> Data {
            let renderer = try fresh ? scene.makeRenderer() : scene.renderer
            let context = try #require(
                CGContext(
                    data: nil, width: 1080, height: 1920, bitsPerComponent: 8, bytesPerRow: 4320,
                    space: CGColorSpace(name: CGColorSpace.itur_709)!,
                    bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue))
            try renderer.draw(time, into: context)
            return Data(bytes: try #require(context.data), count: 4320 * 1920)
        }
        let times = [Time(4199, 1000), Time(8399, 2000), Time(21, 5), Time(4201, 1000)]
        let frames = try times.map { try frame($0) }
        #expect(frames[0] != frames[2])
        for i in times.indices.reversed() {
            #expect(try frame(times[i]) == frames[i])
            #expect(try frame(times[i], fresh: true) == frames[i])
        }
    }
}
