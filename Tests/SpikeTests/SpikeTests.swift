import Testing
import Foundation
@testable import SpikeCore
@testable import RenderMac

struct SpikeTests {
    @Test func testRationalNormalizationAndScheduling() {
        #expect((Time(2, 4)) == (Time(1, 2)))
        #expect((Time(1, 3) + Time(1, 6)) == (Time(1, 2)))
        #expect((Time(5, 4) - Time(1)) == (Time(1, 4)))
        #expect(Time(1000000000, 999999) > Time(999999999, 1000000))
        #expect(Timeline().evaluate(Time(1000000000, 999983)).output == Time(1000000000, 999983))
        #expect(Time(Int64.max, 2) > Time(Int64.max - 1, 3))
        #expect((Time.frame(240)) == (Time(4)))
        #expect((Time.frame(30000, fpsNumerator: 30000, fpsDenominator: 1001)) == (Time(1001)))
        for frame in 0..<240 { #expect((Time.frame(Int64(frame + 1)) - .frame(Int64(frame))) == (Time(1, 60))) }
    }
    @Test func testHalfOpenMarkersAndSeek() {
        let t = Timeline()
        #expect(t.evaluate(Time(1)).marker)
        #expect(!(t.evaluate(Time(21, 20)).marker))
        #expect((t.evaluate(Time(74, 60)).media) == (Time(74, 60)))
        #expect((t.evaluate(Time(5, 4)).media) == (Time(1, 4)))
        #expect((t.evaluate(Time(2)).media) == (Time(1)))
        #expect(!(t.evaluate(Time(3599, 1000)).gap))
        #expect(t.evaluate(Time(18, 5)).gap)
    }
    @Test func testInterruptedMotionContinuity() {
        let before = Timeline(events: [Event(time: Time(1), order: 0, focus: 1)])
        let full = Timeline()
        let boundary = Time(5, 4)
        #expect(abs((before.evaluate(boundary).focus) - (full.evaluate(boundary).focus)) <= 1e-12)
        #expect(abs((before.evaluate(boundary).velocity) - (full.evaluate(boundary).velocity)) <= 1e-12)
        #expect(abs((full.evaluate(Time(21, 10)).focus) - (0)) <= 1e-12)
        #expect(abs((full.evaluate(Time(21, 10)).velocity) - (0)) <= 1e-12)
    }
    @Test func testSimultaneousEventsHaveExplicitOrder() {
        let events = [Event(time: Time(1), order: 9, focus: 2, seek: Time(3)),
                      Event(time: Time(1), order: 2, focus: 1, seek: Time(2))]
        let a = Timeline(events: events), b = Timeline(events: events.reversed())
        #expect((a.evaluate(Time(2))) == (b.evaluate(Time(2))))
        #expect((a.evaluate(Time(2)).focus) == (2))
        #expect((a.evaluate(Time(1)).media) == (Time(3)))
    }
    @Test func testRandomAccessStateAndHighlight() {
        let t = Timeline()
        let expected = (0..<240).map { t.evaluate(.frame(Int64($0))) }
        // Fixed coprime permutation covers every frame without a random seed.
        for n in 0..<240 { let i = (n * 137) % 240; #expect((t.evaluate(.frame(Int64(i)))) == (expected[i])) }
        #expect((t.evaluate(Time(1, 8)).highlights[0]) == (0.5))
        #expect((t.evaluate(Time(1, 4)).highlights[0]) == (1))
        #expect((t.evaluate(Time(1, 4)).highlights[1]) == (0))
    }
    @Test func testContainLayout() {
        let fit = Fit(width: 1080, height: 1920)
        #expect(abs((fit.scale) - (1920.0 / 874)) <= 1e-12)
        #expect((fit.y) == (0))
        #expect(abs((fit.x * 2 + fit.scale * 402) - (1080)) <= 1e-9)
    }
    @Test func testCoreTextLayoutAndSourceCoverage() throws {
        for text in [Timeline.text, Timeline.japanese, "A e\u{301} 日本語。\n次の行 123", "A deliberately longer paragraph wraps across the constrained width."] {
            let a = try TextLayout(text: text, scale: 2)
            let b = try TextLayout(text: text, scale: 2)
            #expect((a.metrics) == (b.metrics))
            #expect((a.metrics.map(\.length).reduce(0, +)) == ((text as NSString).length))
            #expect(a.metrics.allSatisfy { $0.width <= 342.01 && $0.width > 0 }, "Text: \(text), metrics: \(a.metrics)")
            #expect((a.metrics.count) >= (2))
        }
        let latin = try TextLayout(text: Timeline.text, scale: 2)
        #expect((latin.wordRects.count) == (8))
        #expect((latin.metrics.count) == (2))
    }
    @Test func testRawRasterOrderAndCacheRecreation() throws {
        let renderer = try Renderer(width: 270, height: 480)
        let fresh = try Renderer(width: 270, height: 480)
        let t = Timeline()
        let times = [Time(0), Time(9, 8), Time(5, 4), Time(3), Time(4)]
        let expected = try times.map { try renderer.raw(t.evaluate($0)) }
        for i in [4, 1, 3, 0, 2, 1] { #expect((try fresh.raw(t.evaluate(times[i]))) == (expected[i])) }
        #expect((expected[0]) != (expected[1]))
    }
    @Test func testSyntheticPCMIsDeterministicAndMarkersAreAudible() {
        let t = Timeline()
        let reference = (0..<960).map { t.audioSample($0) }
        #expect((reference) == ((0..<960).reversed().map { t.audioSample($0) }.reversed()))
        #expect((reference.map { abs(Int($0)) }.max()!) > (20000))
        #expect(((2000..<2960).map { abs(Int(t.audioSample($0))) }.max()!) < (1500))
        #expect((t.audioSample(60000 + 1200)) == (t.audioSample(12000 + 1200)))
    }
}
