import Testing
import Foundation
import SpikeCore
import LyricsSliceCore
import LyricsSliceMac

struct SliceTests {
    @Test func boundariesAndBounds() throws {
        let input=SliceInput.synthetic();try input.validate()
        let begin=try input.events[0].begin!.validated(),end=try input.events[0].end!.validated()
        #expect(input.evaluate(begin).spans[0].progress == 0)
        #expect(input.evaluate(end).spans[0].progress == 1)
        #expect(input.evaluate(Time(1)).spans[0].progress == 0.5)
        #expect(input.evaluate(Time(0)).spans[0].displacement == 6)
        for t in [Time(-1),Time(0),Time(1),Time(7,6),Time(100)] {
            #expect(input.evaluate(t).spans.allSatisfy { (0...6).contains($0.displacement) && (0...1).contains($0.progress) })
        }
    }
    @Test func randomAccessAndFreshRaster() throws {
        let input=SliceInput.synthetic(),a=try SliceParagraph(input),b=try SliceParagraph(input)
        let times=[Time(0),Time(1),Time(7,4),Time(3),Time(5)]
        let states=times.map(input.evaluate),pixels=try times.map { try a.raw($0) }
        for i in [4,1,0,3,2,1] {
            #expect(input.evaluate(times[i]) == states[i])
            #expect(try b.raw(times[i]) == pixels[i])
        }
        #expect(pixels[0] != pixels[2])
    }
    @Test func layoutAndCaptureGeometry() throws {
        let a=try SliceParagraph(.synthetic()),b=try SliceParagraph(.synthetic(canvasWidth:1180))
        #expect(a.lines == b.lines)
        #expect(a.lines.count == 2)
        #expect(a.lines[0].breakKind == "observed-explicit")
        #expect(a.lines[1].baseline-a.lines[0].baseline == 123)
        #expect(a.lines.allSatisfy { $0.width <= 987 })
        #expect(try a.render(a.input.evaluate(Time(0))).width == 1179)
        #expect(try b.render(b.input.evaluate(Time(0))).width == 1180)
    }
    @Test func coverageDoesNotDependOnHighlight() throws {
        let source=SliceInput.synthetic()
        var p=source.parameters;p.amplitude=0
        let input=SliceInput(text:source.text,parameters:p,events:source.events),renderer=try SliceParagraph(input)
        #expect(try renderer.raw(Time(0),coverage:true) == renderer.raw(Time(10),coverage:true))
        #expect(try renderer.raw(Time(0)) != renderer.raw(Time(10)))
    }
    @Test func invalidBreaksRangesAndTimes() throws {
        #expect(throws: SliceError.self) { try SliceTime(1,0).validated() }
        #expect(throws: SliceError.self) { try SliceParagraph(SliceInput(text:"一行だけ",events:[])) }
        #expect(throws: SliceError.self) { try SliceParagraph(SliceInput(text:"未設定\n範囲",events:[])) }
        let invalid=AppearanceEvent(start:0,length:1,begin:SliceTime(1),end:SliceTime(1),verticalEvent:nil)
        #expect(throws: SliceError.self) { try SliceParagraph(SliceInput(text:"あ\nい",events:[invalid])) }
    }
    @Test func combinedGlyphCannotBeSplit() throws {
        let text="か\u{3099}\n点"
        let events=[AppearanceEvent(start:0,length:1,begin:nil,end:nil,verticalEvent:nil),
                    AppearanceEvent(start:1,length:1,begin:nil,end:nil,verticalEvent:nil),
                    AppearanceEvent(start:3,length:1,begin:nil,end:nil,verticalEvent:nil)]
        #expect(throws: SliceError.self) { try SliceParagraph(SliceInput(text:text,events:events)) }
    }
}
