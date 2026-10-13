import Testing
import Foundation
import CoreGraphics
import TimelineCore
import LyricsInputCore
import LyricsInputMac
@testable import LyricsScreenCore
import LyricsScreenMac

/// Original timing fixture: a six-second introduction, then two supplied lyric paragraphs.
// The existing CI filter runs AudioSceneTests; keep this regression within that suite.
extension AudioSceneTests {
    static func scene(gaps: Bool = true) throws -> LocalScene {
        let lyrics = try LRCParser.parse(
            Data("[00:06.00]Morning carries quiet light\n[00:09.00]Paper rivers turn to gold\n".utf8))
        let audio = LocalAudio(
            samples: Array(repeating: 0, count: 12 * 48_000), sourceRate: 48_000, sourceChannels: 1, sourceFormat: 0)
        var presentation = LocalPresentation(
            icons: .original, minimumGap: gaps ? Time(4) : nil,
            focusLead: LocalPresentation.measuredMotion.focusLead, stagger: LocalPresentation.measuredMotion.stagger,
            marquee: .measured, wordMotion: .measured, fillLead: LocalPresentation.measuredFillLead,
            hideControls: LocalPresentation.measuredControlHide)
        presentation.holdsFinishedLine = true
        presentation.collapsesGaps = true
        return try LocalScene(
            lyrics: lyrics, audio: audio, presentation: presentation,
            title: "Original Introduction", artist: "Synthetic Fixture")
    }
    @Test func openingSlotIsEstablishedBeforeItsMarkerAppears() throws {
        let c = try Self.scene().renderer.screen.composition
        #expect(c.gaps.count == 1 && c.gaps[0].begin == Time(0) && c.gaps[0].end == Time(6))
        #expect(c.evaluate(Time(-1, 60)).gaps[0].state == nil)
        for time in [Time(0), Time(1, 60), Time(1, 10), Time(1, 5), Time(3), Time(5099, 1000)] {
            let s = c.evaluate(time)
            let p = c.paragraphs[0]
            let baseline = p.input.parameters.originY + p.input.parameters.size + s.paragraphs[0].translationY
            #expect(s.focus == -1 && s.gaps[0].state != nil)
            #expect(abs(s.gaps[0].translationY) < 1e-9)
            #expect(abs(baseline - (791.25 + GapIndicator.slotHeight)) < 1e-9)
        }
    }
    @Test func openingMarkerDoesNotCompositeOverTheFirstLyric() throws {
        let scene = try Self.scene()
        let r = scene.renderer
        let c = r.screen.composition
        let lead = Time(51, 10)
        #expect(c.evaluate(lead - Time(1, 1_000_000)).focus == -1)
        #expect(c.evaluate(lead - Time(1, 1_000_000)).gaps[0].state != nil)
        #expect(c.evaluate(lead - Time(1, 60)).gaps[0].state != nil)
        for time in [lead, lead + Time(1, 60), Time(28, 5), Time(5999, 1000), Time(6)] {
            let s = c.evaluate(time)
            #expect(s.focus == 0 && s.gaps[0].state == nil)
            let noMarker = CompositionSnapshot(
                output: s.output, media: s.media, focus: s.focus, scroll: s.scroll,
                velocity: s.velocity, paragraphs: s.paragraphs, gaps: [])
            #expect(
                try r.lyricLayer(s).dataProvider!.data! as Data == r.lyricLayer(noMarker).dataProvider!.data! as Data)
        }
        #expect(c.evaluate(Time(3)).gaps[0].state!.visibility == 1)
        #expect(c.evaluate(Time(3)).gaps[0].state == GapIndicator.fitted.evaluate(elapsed: 3, duration: 6))
        #expect(c.evaluate(Time(6)).paragraphs[0].active)
        #expect(!c.evaluate(Time(5999, 1000)).paragraphs[0].active)
    }
    @Test func rationalBoundariesAndControlsRemainRandomAccess() throws {
        let scene = try Self.scene()
        let plain = try Self.scene(gaps: false)
        let r = scene.renderer
        let fresh = try scene.makeRenderer()
        let times = [Time(0), Time(1, 10), Time(3), Time(51, 10) - Time(1, 60), Time(51, 10), Time(28, 5), Time(6)]
        let states = times.map(r.screen.evaluate)
        let images = try states.map { try r.native($0).dataProvider!.data! as Data }
        for i in [5, 1, 4, 0, 6, 3, 2, 5] {
            #expect(r.screen.evaluate(times[i]) == states[i])
            #expect(try r.native(states[i]).dataProvider!.data! as Data == images[i])
            #expect(try fresh.native(states[i]).dataProvider!.data! as Data == images[i])
            #expect(states[i].components == plain.renderer.screen.evaluate(times[i]).components)
        }
        let time = Time(28, 5)
        let a = try r.native(r.screen.evaluate(time))
        let b = try plain.renderer.native(plain.renderer.screen.evaluate(time))
        let x = a.dataProvider!.data! as Data
        let y = b.dataProvider!.data! as Data
        let row = a.bytesPerRow
        // Header, including More, and the fixed lower-control region have identical pixels.
        #expect(x[0..<550 * row] == y[0..<550 * row])
        // At this timestamp lower controls are hidden; use a visible timestamp for their raster check.
        let early = Time(3)
        let earlyA = try r.native(r.screen.evaluate(early)).dataProvider!.data! as Data
        let earlyB = try plain.renderer.native(plain.renderer.screen.evaluate(early)).dataProvider!.data! as Data
        #expect(earlyA[1600 * row..<2556 * row] == earlyB[1600 * row..<2556 * row])
    }
}
