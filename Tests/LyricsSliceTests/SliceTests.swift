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
    @Test func softenedAppearanceBoundaries() throws {
        let model=SoftAppearance();try model.validate()
        #expect(model.fraction(position:0.5,phase:nil) == 0)
        #expect(model.fraction(position:0.5,phase:-1.5) == 0)
        #expect(model.fraction(position:0.5,phase:0) == 0.5)
        #expect(model.fraction(position:0.5,phase:1.5) == 1)
        #expect(model.fraction(position:0.2,phase:0) > model.fraction(position:0.8,phase:0))
        var invalid=model;invalid.softness=0
        #expect(throws: SliceError.self) { try invalid.validate() }
        let input=SliceInput.synthetic(softened:true)
        #expect(input.evaluate(Time(1)).spans[0].phase == 0)
        #expect(input.evaluate(Time(0)).spans[0].phase! < -0.5)
    }
    @Test func softenedAppearancePreservesGeometryAndRandomAccess() throws {
        let plain=SliceInput.synthetic(),soft=SliceInput.synthetic(softened:true)
        let a=try SliceParagraph(plain),b=try SliceParagraph(soft),fresh=try SliceParagraph(soft)
        #expect(a.lines == b.lines)
        let times=[Time(0),Time(9,10),Time(1),Time(11,10),Time(5)]
        let pixels=try times.map { try b.raw($0) },states=times.map(soft.evaluate)
        for i in [4,1,3,0,2,1] {
            #expect(try b.raw(times[i],coverage:true) == a.raw(times[i],coverage:true))
            #expect(try fresh.raw(times[i]) == pixels[i])
            #expect(soft.evaluate(times[i]) == states[i])
        }
        #expect(pixels[1] != pixels[3])
    }
}

struct LatinSliceTests {
    @Test func structuresAndPunctuation() throws {
        for text in ["AVATAR office.", "A careful draft—\nwith room to revise.",
                     "An office proof pairs AV and To, then checks punctuation and spacing."] {
            let input=SliceInput.latin(text:text),paragraph=try SliceParagraph(input)
            #expect(paragraph.lines.count >= 1 && paragraph.lines.count <= 4)
            #expect(paragraph.lines.map(\.length).reduce(0,+) == text.utf16.count)
            if text.contains("\n") { #expect(paragraph.lines[0].breakKind == "observed-explicit") }
            else if paragraph.lines.count>1 { #expect(paragraph.lines[0].breakKind == "automatic") }
            #expect(paragraph.lines.last?.breakKind == "end")
        }
    }
    @Test func staticLatinIsRandomAccess() throws {
        let input=SliceInput.latin(),a=try SliceParagraph(input),b=try SliceParagraph(input)
        let reference=try a.raw(Time(0))
        let times=[Time(7,3),Time(-1),Time(0),Time(11,7)]
        let states=times.map(input.evaluate)
        for i in [3,1,0,2,0] {
            #expect(b.input.evaluate(times[i]) == states[i])
            #expect(states[i].spans.isEmpty)
            #expect(try b.raw(times[i]) == reference)
        }
        #expect(input.parameters.amplitude == 0)
        #expect(input.appearance == nil)
    }
    @Test func latinCannotInheritJapaneseTiming() throws {
        let latin=SliceInput.latin(),japanese=SliceInput.synthetic(softened:true)
        #expect(throws: SliceError.self) {
            try SliceParagraph(SliceInput(text:latin.text,parameters:latin.parameters,events:japanese.events,paragraphStyle:.latinStatic))
        }
        #expect(throws: SliceError.self) {
            try SliceParagraph(SliceInput(text:latin.text,parameters:latin.parameters,events:[],appearance:SoftAppearance(),paragraphStyle:.latinStatic))
        }
        #expect(throws: SliceError.self) {
            try SliceParagraph(SliceInput(text:latin.text,events:[],paragraphStyle:.latinStatic))
        }
    }
}
