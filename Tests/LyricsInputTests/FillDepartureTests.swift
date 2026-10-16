import Foundation
import Testing
import TimelineCore
import LyricsInputCore
import LyricsInputMac
import LyricsScreenCore
import LyricsScreenMac

/// Original synthetic inputs distinguish actual focus departure from source onset and raster completion.
struct FillDepartureTests {
    private func scene(_ lyrics: LocalLyrics, seconds: Int, presentation: LocalPresentation) throws -> LocalScene {
        try LocalScene(
            lyrics: lyrics,
            audio: LocalAudio(
                samples: Array(repeating: 0, count: seconds * 48_000), sourceRate: 48_000,
                sourceChannels: 1, sourceFormat: 0),
            presentation: presentation, title: "Synthetic", artist: "Synthetic")
    }
    private func ttml(_ body: String) throws -> LocalLyrics {
        try TTMLParser.parse(
            Data(
                ("<tt xmlns=\"http://www.w3.org/ns/ttml\" xml:space=\"preserve\"><body><div>"
                    + body + "</div></body></tt>").utf8))
    }
    private func interval(_ event: AppearanceEvent) throws -> (Time, Time) {
        (try #require(event.begin).validated(), try #require(event.end).validated())
    }
    @Test func emptyEntriesUseActualReleaseInsteadOfAnInventedLead() throws {
        let lyrics = try LRCParser.parse(Data("[00:00.000]A\n[00:00.001]".utf8))
        let c = try scene(lyrics, seconds: 1, presentation: .init(focusLead: Time(9, 10)))
            .renderer.screen.composition
        let (a, b) = try interval(c.paragraphs[0].input.events[0])
        #expect(a == Time(0) && b == Time(1, 1000))
        #expect(c.events.map(\.time) == [Time(0), Time(0), Time(1, 1000)])
        #expect(c.events.map(\.paragraph) == [-1, 0, -1])
        #expect(c.evaluate(Time(999, 1_000_000)).focus == 0)
        #expect(c.evaluate(Time(1, 1000)).focus == -1)

        let enhanced = try EnhancedLRCParser.parse(Data("[00:00.000]<00:04.500>A<00:05.000>\n[00:05.000]".utf8))
        let d = try scene(enhanced, seconds: 6, presentation: .init(focusLead: Time(9, 10)))
            .renderer.screen.composition
        let (x, y) = try interval(d.paragraphs[0].input.events[0])
        #expect(x == Time(9, 2) && y == Time(5))
        #expect(d.evaluate(Time(4999, 1000)).focus == 0)
        #expect(d.evaluate(Time(5)).focus == -1)
    }
    @Test func laterNonemptyFocusCanPrecedeAnEmptyEntry() throws {
        let lyrics = try EnhancedLRCParser.parse(
            Data("[00:00.000]<00:04.500>A<00:05.000>\n[00:05.000]\n[00:05.100]B".utf8))
        let c = try scene(lyrics, seconds: 6, presentation: .init(focusLead: Time(9, 10)))
            .renderer.screen.composition
        let (_, end) = try interval(c.paragraphs[0].input.events[0])
        #expect(end == Time(21, 5))
        #expect(c.events.map(\.time) == [Time(0), Time(0), Time(21, 5), Time(5)])
        #expect(c.events.map(\.paragraph) == [-1, 0, 1, -1])
    }
    @Test(arguments: [true, false]) func gapsAndExplicitReleaseBoundSubmillisecondFill(gap: Bool) throws {
        let lyrics = try ttml("<p begin=\"0s\" end=\"0.0005s\">A</p><p begin=\"3s\" end=\"4s\">B</p>")
        var p = LocalPresentation(minimumGap: gap ? Time(1) : nil, focusLead: Time(9, 10))
        p.holdsFinishedLine = gap
        let c = try scene(lyrics, seconds: 4, presentation: p).renderer.screen.composition
        let (a, b) = try interval(c.paragraphs[0].input.events[0])
        #expect(a >= Time(0) && a < b && b == Time(1, 2000))
        #expect(c.evaluate(Time(499, 1_000_000)).focus == 0)
        #expect(c.evaluate(Time(1, 2000)).focus == -1)
        if gap { #expect(c.evaluate(Time(1, 2000)).gaps[0].state != nil) }
    }
    @Test(arguments: [true, false]) func finalFillDoesNotExtendPastTheAudio(held: Bool) throws {
        let lyrics = try ttml("<p begin=\"0.9995s\" end=\"1s\">A</p>")
        var p = LocalPresentation()
        p.holdsFinishedLine = held
        let c = try scene(lyrics, seconds: 1, presentation: p).renderer.screen.composition
        let (a, b) = try interval(c.paragraphs[0].input.events[0])
        #expect(a == Time(1999, 2000) && b == Time(1))
    }
    @Test(arguments: ["5.1s", "0.000002s"]) func lateSegmentsKeepSourceOrderAndNormalPrefix(next: String) throws {
        let small = next == "0.000002s"
        let body =
            small
            ? "<span begin=\"0s\" end=\"0.000001s\">A</span><span begin=\"0.000001s\" end=\"0.000002s\">B</span>"
            : "<span begin=\"1s\" end=\"2s\">X</span><span begin=\"4.1995s\" end=\"4.2002s\">A</span><span begin=\"4.2002s\" end=\"4.3s\">B</span>"
        let lyrics = try ttml("<p begin=\"0s\" end=\"\(next)\">\(body)</p><p begin=\"\(next)\" end=\"6s\">C</p>")
        let c = try scene(lyrics, seconds: 6, presentation: .init(focusLead: Time(9, 10)))
            .renderer.screen.composition
        let events = c.paragraphs[0].input.events
        let deadline = small ? Time(1, 1_000_000) : Time(21, 5)
        let times = try events.map(interval)
        #expect(times.allSatisfy { Time(0) <= $0.0 && $0.0 < $0.1 && $0.1 <= deadline })
        #expect(zip(times, times.dropFirst()).allSatisfy { $0.1 <= $1.0 })
        if !small { #expect(times[0].0 == Time(1) && times[0].1 == Time(2)) }
        #expect(events.map(\.start) == lyrics.entries[0].segments.map(\.start))
    }
    @Test(arguments: [true, false]) func smoothingReachesCompleteInkAtActualDeparture(clamped: Bool) throws {
        let begin = clamped ? "4.42" : "4.40"
        let end = clamped ? "4.52" : "4.41"
        let lyrics = try ttml(
            "<p begin=\"0s\" end=\"5.1s\"><span begin=\"\(begin)s\" end=\"\(end)s\">A</span></p>"
                + "<p begin=\"5.1s\" end=\"6s\">B</p>")
        // Preserve measured smoothing/edge; disable geometry and glow only in this synthetic isolation fixture.
        var motion = WordMotion.measured
        motion.lift = 0
        motion.emphasisScale = 1
        motion.emphasisLift = 0
        motion.emphasisGlow = 0
        let c = try scene(
            lyrics, seconds: 6,
            presentation: .init(
                focusLead: Time(9, 10), wordMotion: motion, fillLead: LocalPresentation.measuredFillLead)
        )
        .renderer.screen.composition
        let input = c.paragraphs[0].input
        let layout = try ParagraphLayout(input)
        let deadline = Time(21, 5)
        #expect(input.evaluate(deadline).spans[0].progress == 1)
        #expect(try layout.raw(deadline) == layout.raw(deadline + Time(61, 1000)))
        #expect(try layout.raw(deadline - Time(1, 25)) != layout.raw(deadline))
        if !clamped {
            let (a, b) = try interval(input.events[0])
            #expect(a == Time(209, 50) && b == Time(419, 100))
        }
    }
    @Test func zeroTimeOpeningGapPreservesUnfocusedMotion() throws {
        let lyrics = try ttml("<p begin=\"0.1s\" end=\"0.5s\">A</p><p begin=\"3s\" end=\"4s\">B</p>")
        let c = try scene(
            lyrics, seconds: 4,
            presentation: .init(
                minimumGap: Time(1, 20), focusLead: Time(9, 10), wordMotion: .measured)
        )
        .renderer.screen.composition
        #expect(c.evaluate(Time(0)).focus == -1)
        let input = c.paragraphs[0].input
        #expect(input.fillDeadline == nil)
        let reference = ParagraphInput.suppliedTimed(
            text: "A", japanese: false, events: input.events, motion: .measured)
        #expect(try ParagraphLayout(input).raw(Time(11, 100)) == ParagraphLayout(reference).raw(Time(11, 100)))
    }
    @Test(arguments: [false, true]) func sourceBeginsRetainExternalBoundsWhenMoved(moved: Bool) throws {
        let spans =
            moved
            ? "<span begin=\"0s\" end=\"0.000001ms\">A</span><span begin=\"0.000001ms\" end=\"0.000001s\">B</span>"
            : "<span begin=\"0.000001ms\" end=\"0.000001s\">A</span>"
        let lyrics = try ttml(
            "<p begin=\"0s\" end=\"0.000001s\">\(spans)</p><p begin=\"0.000001s\" end=\"1s\">C</p>")
        #expect(throws: ScreenError.self) {
            try scene(lyrics, seconds: 1, presentation: .init(focusLead: Time(9, 10)))
        }
    }
    @Test(arguments: [Int64(72_057_594_037_927_936), 144_115_188_075_855_872])
    func extremeLeadDoesNotOverflowBoundaryAllocation(denominator: Int64) throws {
        let lyrics = try ttml(
            "<p begin=\"0s\" end=\"1s\"><span begin=\"0.999s\" end=\"0.9995s\">A</span>"
                + "<span begin=\"0.9995s\" end=\"1s\">B</span></p><p begin=\"1s\" end=\"2s\">C</p>")
        let deadline = Time(denominator - 1, denominator)
        let events = try LocalScene.fillEvents(lyrics.entries[0].segments, lead: Time(0), deadline: deadline)
        let times = try events.map(interval)
        #expect(times.allSatisfy { Time(0) <= $0.0 && $0.0 < $0.1 && $0.1 <= deadline })
        #expect(times[0].1 == times[1].0)
        // The larger denominator exceeds pre-existing Time subtraction in renderer initialization.
        // Allocation is verified independently; that separate native reproducer remains recorded.
        if denominator == 72_057_594_037_927_936 {
            let c = try scene(lyrics, seconds: 2, presentation: .init(focusLead: Time(1, denominator)))
                .renderer.screen.composition
            #expect(c.evaluate(deadline).focus == 1)
        }
    }
    @Test func exactDeadlineCompletesInkWhenDoubleKnotsCoincide() throws {
        let lyrics = try ttml(
            "<p begin=\"0s\" end=\"1s\"><span begin=\"0.5s\" end=\"0.5005s\">A</span>"
                + "<span begin=\"0.5005s\" end=\"1s\">B</span></p><p begin=\"1s\" end=\"2s\">C</p>")
        var motion = WordMotion.measured
        motion.lift = 0
        let denominator: Int64 = 72_057_594_037_927_936
        let lead = Time(1, 2) - Time(1, denominator)
        let c = try scene(lyrics, seconds: 2, presentation: .init(focusLead: lead, wordMotion: motion))
            .renderer.screen.composition
        let deadline = Time(1, 2) + Time(1, denominator)
        let input = c.paragraphs[0].input
        #expect(input.evaluate(deadline).spans.allSatisfy { $0.progress == 1 })
        let layout = try ParagraphLayout(input)
        #expect(try layout.raw(deadline) == layout.raw(deadline + Time(1, 8)))
    }
    @Test func ordinaryMotionPixelsRemainUnchanged() throws {
        let lyrics = try ttml(
            "<p begin=\"0s\" end=\"5.1s\"><span begin=\"1s\" end=\"2s\">A</span></p><p begin=\"5.1s\" end=\"6s\">B</p>")
        let c = try scene(lyrics, seconds: 6, presentation: .init(focusLead: Time(9, 10), wordMotion: .measured))
            .renderer.screen.composition
        let input = c.paragraphs[0].input
        let reference = ParagraphInput.suppliedTimed(
            text: "A", japanese: false, events: input.events, motion: .measured)
        let actual = try ParagraphLayout(input)
        let prior = try ParagraphLayout(reference)
        for time in [Time(1, 2), Time(1), Time(3, 2), Time(2), Time(21, 10), Time(21, 5)] {
            #expect(try actual.raw(time) == prior.raw(time))
        }
    }
}
