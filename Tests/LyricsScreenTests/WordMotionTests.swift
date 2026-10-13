import Testing
import Foundation
import CoreGraphics
import TimelineCore
import LyricsScreenCore
import LyricsScreenMac

struct WordMotionTests {
    let m = WordMotion.measured
    static func input(_ motion: WordMotion?) -> ParagraphInput {
        // Original fixture: a short word followed by a sustained word.
        .suppliedTimed(
            text: "Bright skyline", japanese: false,
            events: [
                AppearanceEvent(
                    start: 0, length: 7, begin: ParagraphTime(1), end: ParagraphTime(13, 10), verticalEvent: nil),
                AppearanceEvent(
                    start: 7, length: 7, begin: ParagraphTime(14, 10), end: ParagraphTime(34, 10), verticalEvent: nil),
            ], motion: motion)
    }
    @Test func liftAndEmphasisAreContinuousAndBounded() {
        #expect(m.liftOffset(begin: 1, at: 1) == 0 && m.liftOffset(begin: 1, at: 0.5) == 0)
        #expect(
            abs(m.liftOffset(begin: 1, at: 1.27) - m.lift / 2) < 0.15
                && abs(m.liftOffset(begin: 1, at: 10) - m.lift) < 1e-9)
        #expect(m.emphasis(begin: 0, end: 0.5, at: 0.4) == 0 && m.emphasis(begin: 0, end: 2, at: 0) == 0)
        #expect(m.emphasis(begin: 0, end: 2, at: 2) == 1 && abs(m.emphasis(begin: 0, end: 2, at: 2.000001) - 1) < 1e-4)
        #expect(m.emphasis(begin: 0, end: 2, at: 3) < 0.05)
        #expect(throws: ScreenError.self) {
            try WordMotion(
                edge: -1, lift: 0, liftTime: 0.1, emphasisDuration: 1, emphasisScale: 1, emphasisLift: 0,
                emphasisGlow: 0, glowRadius: 0, release: 0.1)
        }
    }
    @Test func snapshotsCarryLiftScaleAndGlow() throws {
        let i = Self.input(m)
        try i.validate()
        let s = i.evaluate(Time(34, 10))
        #expect(s.spans[0].scale == 1 && s.spans[0].glow == 0 && abs(s.spans[0].displacement + m.lift) < 0.01)
        #expect(s.spans[1].scale == m.emphasisScale && s.spans[1].glow == m.emphasisGlow)
        #expect(abs(s.spans[1].displacement + m.liftOffset(begin: 1.4, at: 3.4) + m.emphasisLift) < 1e-9)
        #expect(Self.input(nil).evaluate(Time(34, 10)).spans[1].scale == 1)
        #expect(throws: ScreenError.self) {
            try ParagraphInput(text: "A\nB", events: [], paragraphStyle: .latinStatic, motion: m).validate()
        }
    }
    @Test func softFillIsExactAtEndpointsAndDeterministic() throws {
        let moving = try ParagraphLayout(Self.input(m))
        let hard = try ParagraphLayout(Self.input(nil))
        // Before any word begins, output equals the hard wipe; afterwards both words are filled.
        let before = try moving.raw(Time(1, 2))
        let hardBefore = try hard.raw(Time(1, 2))
        #expect(before == hardBefore)
        let mid = try moving.raw(Time(115, 100))
        let again = try moving.raw(Time(115, 100))
        let hardMid = try hard.raw(Time(115, 100))
        #expect(mid == again && mid != hardMid)
        // A partially filled word contains intermediate alpha from the soft edge.
        let alphas = Set(stride(from: 3, to: mid.count, by: 4).map { mid[$0] })
        #expect(alphas.count > 20)
    }
    @Test func shortWordsFillOverTheSmoothingWindow() throws {
        // A 20-ms word: without smoothing it is full 30 ms after it begins; with it, it is still filling.
        var instant = m
        instant.smoothing = 0
        func input(_ motion: WordMotion) -> ParagraphInput {
            .suppliedTimed(
                text: "Go on home", japanese: false,
                events: [
                    AppearanceEvent(
                        start: 0, length: 3, begin: ParagraphTime(1), end: ParagraphTime(12, 10), verticalEvent: nil),
                    AppearanceEvent(
                        start: 3, length: 3, begin: ParagraphTime(12, 10), end: ParagraphTime(122, 100),
                        verticalEvent: nil),
                    AppearanceEvent(
                        start: 6, length: 4, begin: ParagraphTime(13, 10), end: ParagraphTime(2), verticalEvent: nil),
                ], motion: motion)
        }
        let smooth = try ParagraphLayout(input(m))
        let hard = try ParagraphLayout(input(instant))
        let t = Time(123, 100)
        #expect(try smooth.raw(t) != hard.raw(t))
        // Long before and after every word, smoothing changes nothing.
        let early = try smooth.raw(Time(1, 2))
        let earlyHard = try hard.raw(Time(1, 2))
        let late = try smooth.raw(Time(3))
        let lateHard = try hard.raw(Time(3))
        #expect(early == earlyHard && late == lateHard)
        #expect(throws: ScreenError.self) {
            try WordMotion(
                edge: 30, lift: 0, liftTime: 0.1, emphasisDuration: 1, emphasisScale: 1, emphasisLift: 0,
                emphasisGlow: 0, glowRadius: 0, release: 0.1, smoothing: 2)
        }
    }
    @Test func onlyLineFinalSustainedWordsAreEmphasizedAndGapsAreBridged() throws {
        // Two 2-second words with a 1-second gap: only the final one is emphasized.
        let input = ParagraphInput.suppliedTimed(
            text: "Bright skyline", japanese: false,
            events: [
                AppearanceEvent(
                    start: 0, length: 7, begin: ParagraphTime(1), end: ParagraphTime(3), verticalEvent: nil),
                AppearanceEvent(
                    start: 7, length: 7, begin: ParagraphTime(4), end: ParagraphTime(6), verticalEvent: nil),
            ], motion: m)
        let s = input.evaluate(Time(3))
        #expect(s.spans[0].scale == 1 && s.spans[0].glow == 0)
        #expect(input.evaluate(Time(6)).spans[1].scale == m.emphasisScale)
        // During the gap the first word is still filling rather than pausing.
        var plain = m
        plain.bridgesGaps = false
        let bridged = try ParagraphLayout(input)
        let paused = try ParagraphLayout(
            ParagraphInput.suppliedTimed(text: "Bright skyline", japanese: false, events: input.events, motion: plain))
        let a = try bridged.raw(Time(7, 2))
        let b = try paused.raw(Time(7, 2))
        let c = try bridged.raw(Time(37, 10))
        #expect(a != b && a != c)
    }
    @Test func lineLevelSpansAreNeverEmphasized() {
        let line = ParagraphInput.suppliedTimed(
            text: "Bright skyline", japanese: false,
            events: [
                AppearanceEvent(
                    start: 0, length: 14, begin: ParagraphTime(1), end: ParagraphTime(4), verticalEvent: nil)
            ], motion: m)
        #expect(line.evaluate(Time(4)).spans[0].scale == 1 && line.evaluate(Time(4)).spans[0].glow == 0)
    }
}
