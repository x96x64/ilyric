import Testing
import Foundation
import SpikeCore
import LyricsSliceCore
import LyricsSliceMac

struct ProgressionTests {
    @Test func secondLineCoverageAndAuthoredDeparture() throws {
        let old=try LyricsComposition.synthetic(),demo=try LyricsComposition.progressionDemonstration()
        let input=demo.paragraphs[1].input,paragraph=try SliceParagraph(input),split=paragraph.lines[1].start
        let second=input.events.filter{$0.start>=split}
        #expect(!second.isEmpty && paragraph.lines.count==2)
        #expect(old.evaluate(Time(4)).focus==2 && demo.evaluate(Time(4)).focus==1)
        #expect(second.allSatisfy{$0.begin != nil && $0.end != nil})
        let early=input.evaluate(Time(3)),late=input.evaluate(Time(23,4))
        #expect(early.spans.filter{$0.start>=split}.contains{$0.progress<1})
        #expect(late.spans.allSatisfy{$0.progress==1})
        #expect(late.spans.allSatisfy{ input.appearance!.fraction(position:1,phase:$0.phase)==1 })
        #expect(demo.evaluate(Time(5999,1000)).focus==1 && demo.evaluate(Time(6)).focus==2)
        #expect(try paragraph.raw(Time(3)) != paragraph.raw(Time(23,4)))
        // Line-only input has two complete shaped lines, but no fine-grained events.
        let lineOnly=SliceInput.supplied(text:input.text,japanese:true)
        #expect(lineOnly.events.isEmpty && lineOnly.evaluate(Time(3)).spans.isEmpty)
        #expect(try SliceParagraph(lineOnly).lines.count==2)
    }
}
