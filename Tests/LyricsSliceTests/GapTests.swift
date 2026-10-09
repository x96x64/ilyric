import Testing
import Foundation
import CoreGraphics
import SpikeCore
import LyricsSliceCore
import LyricsSliceMac

struct GapTests {
    @Test func indicatorIsHalfOpenAndOrdered() throws {
        let g=GapIndicator.fitted
        #expect(g.evaluate(elapsed:-0.01,duration:8)==nil && g.evaluate(elapsed:8,duration:8)==nil)
        let start=g.evaluate(elapsed:0,duration:8)!
        #expect(start.fills==[0,0,0] && start.visibility==0)
        #expect(start.opacities.allSatisfy { abs($0-g.unlit)<1e-12 })
        // Fill completes in order and the third dot is full by the fixed lead before the end.
        var previous=[0.0,0.0,0.0]
        for i in 1..<80 {
            let s=g.evaluate(elapsed:Double(i)*0.1,duration:8)!
            #expect(zip(s.fills,previous).allSatisfy { $0>=$1 } && s.fills[0]>=s.fills[1] && s.fills[1]>=s.fills[2])
            #expect(abs(s.scale-1)<=g.amplitude+1e-12)
            previous=s.fills
        }
        #expect(g.evaluate(elapsed:8-g.lead,duration:8)!.fills==[1,1,1])
        #expect(g.evaluate(elapsed:7.999,duration:8)!.visibility<0.01)
    }
    @Test func shortGapsKeepHalfTheirDurationForFilling() throws {
        let s=GapIndicator.fitted.evaluate(elapsed:0.5,duration:2)!
        #expect(s.fills[0]>0 && s.fills[2]==0)
        #expect(GapIndicator.fitted.evaluate(elapsed:1.0,duration:2)!.fills==[1,1,1])
    }
    @Test func invalidParametersAreRejected() {
        #expect(throws:SliceError.self) { try GapIndicator(lead:2,ramp:0,unlit:0.1,amplitude:0.1,period:5,phase:0,fadeIn:0.4,fadeOut:0.15) }
        #expect(throws:SliceError.self) { try GapIndicator(lead:2,ramp:0.7,unlit:0.1,amplitude:0.1,period:0,phase:0,fadeIn:0.4,fadeOut:0.15) }
    }
    @Test func gapFocusScrollsAndDimsParagraphs() throws {
        let c=try LyricsComposition.gapDemonstration()
        let during=c.evaluate(Time(9)),before=c.evaluate(Time(1)),after=c.evaluate(Time(13))
        #expect(during.focus == -1 && during.paragraphs.allSatisfy { $0.opacity<1 })
        #expect(abs(during.scroll-c.gaps[0].position)<1e-6 && abs(during.gaps[0].translationY)<1e-6)
        #expect(before.gaps[0].state==nil && after.gaps[0].state==nil && during.gaps[0].state != nil)
        #expect(throws:SliceError.self) { try LyricsComposition(paragraphs:c.paragraphs,events:[.init(Time(0),order:0,gap:3)],gaps:c.gaps) }
        #expect(throws:SliceError.self) { try LyricsComposition(paragraphs:c.paragraphs,events:c.events,gaps:[.init(position:0,begin:Time(3),end:Time(11))]) }
    }
    @Test func indicatorRendersDeterministicallyAtTheFocusedSlot() throws {
        let c=try LyricsComposition.gapDemonstration(),r=try CompositionRenderer(c)
        let screen=try LyricsScreen(composition:c,title:"A",artist:"B",duration:Time(14),volume:0.5,events:[.init(Time(0),order:0,controls:.init())])
        let renderer=try ScreenRenderer(screen),fresh=try ScreenRenderer(screen)
        _ = r
        let times=[Time(9),Time(5),Time(10,1)]
        let first=try times.map { [UInt8](try renderer.lyricLayer(c.evaluate($0)).dataProvider!.data! as Data) }
        for i in [2,0,1] { #expect([UInt8](try fresh.lyricLayer(c.evaluate(times[i])).dataProvider!.data! as Data)==first[i]) }
        // During the gap the first dot is lit; its center pixel at the focused row is bright.
        let row=Int(GapIndicator.focusedCenterY),x=Int(GapIndicator.firstCenterX),w=c.canvasWidth
        #expect(first[0][(row*w+x)*4+3]>200)
        #expect([UInt8](try renderer.lyricLayer(c.evaluate(Time(1))).dataProvider!.data! as Data)[(row*w+x)*4+3] != first[0][(row*w+x)*4+3])
    }
}
