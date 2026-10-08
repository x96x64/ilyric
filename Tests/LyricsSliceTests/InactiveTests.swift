import Testing
import Foundation
import SpikeCore
import LyricsSliceCore
import LyricsSliceMac

struct InactiveTests {
    @Test func boundariesAndInterruptedEvaluation() throws {
        let events=[FocusEvent(Time(0),order:0,paragraph:0),.init(Time(1),order:1,paragraph:1),.init(Time(21,20),order:2,paragraph:0)]
        let times=[Time(0),Time(1),Time(21,20),Time(23,20),Time(2)]
        let expected=times.map { InactiveTreatment.evaluate($0,paragraph:0,events:events) }
        #expect(expected[0].opacity==1 && expected[1].blur==0)
        #expect(expected.last!.opacity==1 && expected.last!.blur==0)
        for i in [4,1,3,0,2,1] { #expect(InactiveTreatment.evaluate(times[i],paragraph:0,events:events)==expected[i]) }
        let left=InactiveTreatment.evaluate(Time(1049999,1000000),paragraph:0,events:events)
        #expect(abs(left.opacity-expected[2].opacity)<0.0001)
        for i in 0..<360 {
            let value=InactiveTreatment.evaluate(Time(Int64(i),60),paragraph:1,events:events)
            #expect((0...8).contains(value.blur) && (0.42...1).contains(value.opacity))
        }
    }
    @Test func completeFixtureSchedule() throws {
        let screen=try LyricsScreen.synthetic(),states=(0..<360).map{screen.evaluate(Time(Int64($0),60))}
        let changes=(1..<360).filter { i in states[i].components.map(\.visible) != states[i-1].components.map(\.visible) }
        #expect(changes==[120,240,300])
        #expect(abs(states[240].lyrics.scroll-650)<0.02)
        #expect(abs(states[359].lyrics.scroll-650)<1e-9)
        #expect(states[359].lyrics.focus==2)
        #expect(states[180].lyrics.scroll<326)
        for i in 1..<360 { #expect(states[i].lyrics.scroll>=states[i-1].lyrics.scroll) }
    }
    @Test func cachedAppearanceRasterAndIsolation() throws {
        let screen=try LyricsScreen.synthetic(),old=try ScreenRenderer(screen)
        let r=try ScreenRenderer(screen,calibratedInactive:true),fresh=try ScreenRenderer(screen,calibratedInactive:true)
        let times=[Time(0),Time(1),Time(21,20),Time(3),Time(61,20),Time(4)]
        let states=times.map(screen.evaluate)
        let pixels=try states.map{try r.native($0).dataProvider!.data! as Data}
        for i in [4,0,3,1,5,2,4] { #expect(try fresh.native(states[i]).dataProvider!.data! as Data == pixels[i]) }
        for i in times.indices {
            let before=try old.native(states[i]).dataProvider!.data! as Data,after=pixels[i],row=1179*4
            #expect(before[..<(550*row)]==after[..<(550*row)])
            #expect(before[(1500*row)...]==after[(1500*row)...])
            #expect(r.lyrics.paragraphs.map(\.lines)==old.lyrics.paragraphs.map(\.lines))
        }
        // The active Latin paragraph is unchanged before any outgoing event.
        let before=try old.native(states[0]).dataProvider!.data! as Data,row=1179*4
        #expect(before[(680*row)..<(970*row)]==pixels[0][(680*row)..<(970*row)])
        // Japanese still uses its original appearance path and source shaping.
        #expect(try r.lyrics.paragraphs[1].raw(Time(3,2))==old.lyrics.paragraphs[1].raw(Time(3,2)))
    }
}
