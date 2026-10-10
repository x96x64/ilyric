import Testing
import SpikeCore
import LyricsSliceCore

struct MotionTests {
    static func composition(_ stagger: FocusStagger) throws -> LyricsComposition {
        let base=try LyricsComposition.synthetic()
        return try LyricsComposition(paragraphs:base.paragraphs,events:base.events,stagger:stagger)
    }
    @Test func rigidStaggerReproducesExistingMotion() throws {
        let base=try LyricsComposition.synthetic(),rigid=try Self.composition(.rigid)
        for t in [Time(0),Time(21,20),Time(3),Time(31,10),Time(5)] { #expect(base.evaluate(t)==rigid.evaluate(t)) }
    }
    @Test func lowerParagraphsLagDeterministically() throws {
        let c=try Self.composition(.measured),rigid=try Self.composition(.rigid)
        let t=Time(31,10),s=c.evaluate(t),r=rigid.evaluate(t)
        // The focused paragraph moves without delay; paragraphs below it lag by a distance-dependent delay.
        #expect(s.paragraphs[2].translationY==r.paragraphs[2].translationY)
        #expect(FocusStagger.measured.delay(below:0)==0 && FocusStagger.measured.delay(below:650)>0.05)
        #expect(FocusStagger.measured.delay(below:100000)==0.3)
        #expect(c.evaluate(t)==s && c.evaluate(Time(6))==c.evaluate(Time(6)))
        // After motion settles, staggered and rigid layouts agree.
        #expect(abs(c.evaluate(Time(29,5)).paragraphs[0].translationY-rigid.evaluate(Time(29,5)).paragraphs[0].translationY)<1e-6)
    }
    @Test func invalidStaggerIsRejected() {
        #expect(throws:SliceError.self) { try FocusStagger(secondsPerPixel:-1,interceptSeconds:0,maximumSeconds:0.3) }
        #expect(throws:SliceError.self) { try FocusStagger(secondsPerPixel:0.001,interceptSeconds:0,maximumSeconds:2) }
    }
}
