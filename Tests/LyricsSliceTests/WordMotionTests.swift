import Testing
import Foundation
import CoreGraphics
import SpikeCore
import LyricsSliceCore
import LyricsSliceMac

struct WordMotionTests {
    let m=WordMotion.measured
    static func input(_ motion: WordMotion?) -> SliceInput {
        // Original fixture: a short word followed by a sustained word.
        .suppliedTimed(text:"Bright skyline",japanese:false,events:[
            AppearanceEvent(start:0,length:7,begin:SliceTime(1),end:SliceTime(13,10),verticalEvent:nil),
            AppearanceEvent(start:7,length:7,begin:SliceTime(14,10),end:SliceTime(34,10),verticalEvent:nil)],motion:motion)
    }
    @Test func liftAndEmphasisAreContinuousAndBounded() {
        #expect(m.liftOffset(begin:1,at:1)==0 && m.liftOffset(begin:1,at:0.5)==0)
        #expect(abs(m.liftOffset(begin:1,at:1.27)-m.lift/2)<0.15 && abs(m.liftOffset(begin:1,at:10)-m.lift)<1e-9)
        #expect(m.emphasis(begin:0,end:0.5,at:0.4)==0 && m.emphasis(begin:0,end:2,at:0)==0)
        #expect(m.emphasis(begin:0,end:2,at:2)==1 && abs(m.emphasis(begin:0,end:2,at:2.000001)-1)<1e-4)
        #expect(m.emphasis(begin:0,end:2,at:3)<0.05)
        #expect(throws:SliceError.self) { try WordMotion(edge:-1,lift:0,liftTime:0.1,emphasisDuration:1,emphasisScale:1,emphasisLift:0,emphasisGlow:0,glowRadius:0,release:0.1) }
    }
    @Test func snapshotsCarryLiftScaleAndGlow() throws {
        let i=Self.input(m)
        try i.validate()
        let s=i.evaluate(Time(34,10))
        #expect(s.spans[0].scale==1 && s.spans[0].glow==0 && abs(s.spans[0].displacement+m.lift)<0.01)
        #expect(s.spans[1].scale==m.emphasisScale && s.spans[1].glow==m.emphasisGlow)
        #expect(abs(s.spans[1].displacement+m.liftOffset(begin:1.4,at:3.4)+m.emphasisLift)<1e-9)
        #expect(Self.input(nil).evaluate(Time(34,10)).spans[1].scale==1)
        #expect(throws:SliceError.self) { try SliceInput(text:"A\nB",events:[],paragraphStyle:.latinStatic,motion:m).validate() }
    }
    @Test func softFillIsExactAtEndpointsAndDeterministic() throws {
        let moving=try SliceParagraph(Self.input(m)),hard=try SliceParagraph(Self.input(nil))
        // Before any word begins, output equals the hard wipe; afterwards both words are filled.
        let before=try moving.raw(Time(1,2)),hardBefore=try hard.raw(Time(1,2))
        #expect(before==hardBefore)
        let mid=try moving.raw(Time(115,100)),again=try moving.raw(Time(115,100)),hardMid=try hard.raw(Time(115,100))
        #expect(mid==again && mid != hardMid)
        // A partially filled word contains intermediate alpha from the soft edge.
        let alphas=Set(stride(from:3,to:mid.count,by:4).map { mid[$0] })
        #expect(alphas.count>20)
    }
}
