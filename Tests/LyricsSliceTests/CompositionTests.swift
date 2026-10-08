import Testing
import Foundation
import CoreGraphics
import SpikeCore
import LyricsSliceCore
import LyricsSliceMac

struct CompositionTests {
    @Test func focusBoundariesAndAnalyticMotion() throws {
        let c=try LyricsComposition.synthetic()
        #expect(c.evaluate(Time(59,60)).focus==0)
        #expect(c.evaluate(Time(1)).focus==1)
        #expect(c.evaluate(Time(1)).scroll==0)
        #expect(abs(c.evaluate(Time(1081,1000)).scroll-325*(1-2/exp(1)))<1e-9)
        #expect(c.evaluate(Time(3)).focus==2)
        #expect(abs(c.evaluate(Time(6)).scroll-650)<1e-8)
        #expect(c.evaluate(Time(1)).paragraphs.map(\.active)==[false,true,false])
        #expect(c.evaluate(Time(3)).paragraphs.map(\.active)==[false,false,true])
        #expect(c.evaluate(Time(6)).paragraphs.allSatisfy{!$0.active})
        for t in [Time(0),Time(6),Time(7,3),Time(1),Time(3)] {
            #expect(c.evaluate(t).paragraphs.map(\.index)==[0,1,2])
            #expect(c.evaluate(t).paragraphs[2].translationY > c.evaluate(t).paragraphs[0].translationY)
        }
    }
    @Test func interruptionAndSimultaneousOrder() throws {
        let source=try LyricsComposition.synthetic()
        let initial=FocusSegment(start:Time(1),position:0,velocity:0,target:325,tau:0.081)
        let event=Time(21,20),prior=initial.evaluate(event)
        let next=FocusSegment(start:event,position:prior.position,velocity:prior.velocity,target:0,tau:0.081)
        #expect(next.evaluate(event).position==prior.position)
        #expect(abs(next.evaluate(event).velocity-prior.velocity)<1e-10)
        let c=try LyricsComposition(paragraphs:source.paragraphs,events:[.init(Time(0),order:0,paragraph:0),.init(Time(1),order:2,paragraph:2),.init(Time(1),order:1,paragraph:1),.init(event,order:3,paragraph:0)])
        #expect(c.evaluate(Time(1)).focus==2)
        #expect(c.evaluate(event).focus==0)
        let position=c.evaluate(event).scroll
        #expect(abs(c.evaluate(event-Time(1,1_000_000)).scroll-position)<0.1)
    }
    @Test func independentClocksAndValidation() throws {
        let source=try LyricsComposition.synthetic()
        let c=try LyricsComposition(paragraphs:source.paragraphs,events:source.events,clocks:[
            .init(output:Time(0),media:Time(0),running:true),.init(output:Time(1),media:Time(1),running:false),
            .init(output:Time(2),media:Time(1,4),running:true)])
        #expect(c.evaluate(Time(3,2)).media==Time(1))
        #expect(c.evaluate(Time(2)).media==Time(1,4))
        #expect(c.evaluate(Time(3)).media==Time(5,4))
        #expect(c.evaluate(Time(3)).focus==2) // Explicit interface event, not inferred from seek.
        #expect(throws:SliceError.self) { try LyricsComposition(paragraphs:source.paragraphs,events:[.init(Time(1),order:0,paragraph:0)]) }
        #expect(throws:SliceError.self) { try LyricsComposition(paragraphs:source.paragraphs,events:[.init(Time(0),order:0,paragraph:0),.init(Time(1),order:0,paragraph:1)]) }
    }
    @Test func randomRasterLayoutAndClip() throws {
        let c=try LyricsComposition.synthetic(),r=try CompositionRenderer(c),fresh=try CompositionRenderer(c)
        let times=[Time(0),Time(1),Time(13,12),Time(2),Time(3),Time(37,12),Time(6)]
        let states=times.map(c.evaluate),pixels=try times.map{try r.frame($0).dataProvider!.data! as Data}
        for i in [5,1,4,0,6,3,2,1] {
            #expect(c.evaluate(times[i])==states[i])
            #expect(try fresh.frame(times[i]).dataProvider!.data! as Data == pixels[i])
        }
        #expect(pixels[1] != pixels[2])
        for (i,p) in c.paragraphs.enumerated() {
            let direct=try SliceParagraph(p.input)
            #expect(r.paragraphs[i].lines==direct.lines)
            #expect(try r.paragraphs[i].raw(Time(2))==direct.raw(Time(2)))
        }
        let image=try r.native(states[2],transparent:true),data=[UInt8](image.dataProvider!.data! as Data)
        for y in 0..<2556 where y<550 || y>=1550 {
            #expect(stride(from:y*image.bytesPerRow+3,to:(y+1)*image.bytesPerRow,by:4).allSatisfy { data[$0]==0 })
        }
        for i in 0..<360 { #expect(Time.frame(Int64(i))==Time(Int64(i),60)) }
        #expect(Time.frame(359)<Time(6))
    }
}
