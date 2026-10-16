import Testing
import Foundation
import TimelineCore
import LyricsScreenCore
import LyricsScreenMac

struct ParagraphTests {
    @Test func derivedTimeBoundsDoNotAuthorizeExternalInput() throws {
        let derived = ParagraphTime(derived: Time(1, 2_000_000))
        #expect(try derived.validated() == Time(1, 2_000_000))
        #expect(ParagraphTime(derived: Time(1, 1000)) == ParagraphTime(1, 1000))
        let encoded = try JSONEncoder().encode(derived)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(Set(object.keys) == Set(["numerator", "denominator"]))
        let decoded = try JSONDecoder().decode(ParagraphTime.self, from: encoded)
        #expect(throws: ScreenError.self) { try decoded.validated() }
        for value in [
            ParagraphTime(1, 2_000_000), ParagraphTime(1_000_000_001), ParagraphTime(1, 0),
            ParagraphTime(1, -1), ParagraphTime(Int64.min),
        ] {
            #expect(throws: ScreenError.self) { try value.validated() }
        }
        let spoofed = Data("{\"numerator\":1,\"denominator\":2000000,\"isDerived\":true}".utf8)
        let external = try JSONDecoder().decode(ParagraphTime.self, from: spoofed)
        #expect(throws: ScreenError.self) { try external.validated() }
    }
    @Test func generatedFillDeadlineDoesNotEnterExternalInput() throws {
        var input = ParagraphInput.synthetic()
        input.fillDeadline = Time(1, 2_000_000)
        #expect(input.adapted(to: .video).fillDeadline == input.fillDeadline)
        let encoded = try JSONEncoder().encode(input)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object["fillDeadline"] == nil)
        #expect(try JSONDecoder().decode(ParagraphInput.self, from: encoded).fillDeadline == nil)
        object["fillDeadline"] = ["numerator": 1, "denominator": 2_000_000]
        let spoofed = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(ParagraphInput.self, from: spoofed).fillDeadline == nil)
    }
    @Test func boundariesAndBounds() throws {
        let input = ParagraphInput.synthetic()
        try input.validate()
        let begin = try input.events[0].begin!.validated()
        let end = try input.events[0].end!.validated()
        #expect(input.evaluate(begin).spans[0].progress == 0)
        #expect(input.evaluate(end).spans[0].progress == 1)
        #expect(input.evaluate(Time(1)).spans[0].progress == 0.5)
        #expect(input.evaluate(Time(0)).spans[0].displacement == 6)
        for t in [Time(-1), Time(0), Time(1), Time(7, 6), Time(100)] {
            #expect(
                input.evaluate(t).spans.allSatisfy {
                    (0...6).contains($0.displacement) && (0...1).contains($0.progress)
                })
        }
    }
    @Test func randomAccessAndFreshRaster() throws {
        let input = ParagraphInput.synthetic()
        let a = try ParagraphLayout(input)
        let b = try ParagraphLayout(input)
        let times = [Time(0), Time(1), Time(7, 4), Time(3), Time(5)]
        let states = times.map(input.evaluate)
        let pixels = try times.map { try a.raw($0) }
        for i in [4, 1, 0, 3, 2, 1] {
            #expect(input.evaluate(times[i]) == states[i])
            #expect(try b.raw(times[i]) == pixels[i])
        }
        #expect(pixels[0] != pixels[2])
    }
    @Test func layoutAndCaptureGeometry() throws {
        let a = try ParagraphLayout(.synthetic())
        let b = try ParagraphLayout(.synthetic(canvasWidth: 1180))
        #expect(a.lines == b.lines)
        #expect(a.lines.count == 2)
        #expect(a.lines[0].breakKind == "observed-explicit")
        #expect(a.lines[1].baseline - a.lines[0].baseline == 123)
        #expect(a.lines.allSatisfy { $0.width <= 987 })
        #expect(try a.render(a.input.evaluate(Time(0))).width == 1179)
        #expect(try b.render(b.input.evaluate(Time(0))).width == 1180)
    }
    @Test func coverageDoesNotDependOnHighlight() throws {
        let source = ParagraphInput.synthetic()
        var p = source.parameters
        p.amplitude = 0
        let input = ParagraphInput(text: source.text, parameters: p, events: source.events)
        let renderer = try ParagraphLayout(input)
        #expect(try renderer.raw(Time(0), coverage: true) == renderer.raw(Time(10), coverage: true))
        #expect(try renderer.raw(Time(0)) != renderer.raw(Time(10)))
    }
    @Test func invalidBreaksRangesAndTimes() throws {
        #expect(throws: ScreenError.self) { try ParagraphTime(1, 0).validated() }
        #expect(throws: ScreenError.self) { try ParagraphLayout(ParagraphInput(text: "一行だけ", events: [])) }
        #expect(throws: ScreenError.self) { try ParagraphLayout(ParagraphInput(text: "未設定\n範囲", events: [])) }
        let invalid = AppearanceEvent(
            start: 0, length: 1, begin: ParagraphTime(1), end: ParagraphTime(1), verticalEvent: nil)
        #expect(throws: ScreenError.self) { try ParagraphLayout(ParagraphInput(text: "あ\nい", events: [invalid])) }
    }
    @Test func combinedGlyphCannotBeSplit() throws {
        let text = "か\u{3099}\n点"
        let events = [
            AppearanceEvent(start: 0, length: 1, begin: nil, end: nil, verticalEvent: nil),
            AppearanceEvent(start: 1, length: 1, begin: nil, end: nil, verticalEvent: nil),
            AppearanceEvent(start: 3, length: 1, begin: nil, end: nil, verticalEvent: nil),
        ]
        #expect(throws: ScreenError.self) { try ParagraphLayout(ParagraphInput(text: text, events: events)) }
    }
    @Test func softenedAppearanceBoundaries() throws {
        let model = SoftAppearance()
        try model.validate()
        #expect(model.fraction(position: 0.5, phase: nil) == 0)
        #expect(model.fraction(position: 0.5, phase: -1.5) == 0)
        #expect(model.fraction(position: 0.5, phase: 0) == 0.5)
        #expect(model.fraction(position: 0.5, phase: 1.5) == 1)
        #expect(model.fraction(position: 0.2, phase: 0) > model.fraction(position: 0.8, phase: 0))
        var invalid = model
        invalid.softness = 0
        #expect(throws: ScreenError.self) { try invalid.validate() }
        let input = ParagraphInput.synthetic(softened: true)
        #expect(input.evaluate(Time(1)).spans[0].phase == 0)
        #expect(input.evaluate(Time(0)).spans[0].phase! < -0.5)
    }
    @Test func softenedAppearancePreservesGeometryAndRandomAccess() throws {
        let plain = ParagraphInput.synthetic()
        let soft = ParagraphInput.synthetic(softened: true)
        let a = try ParagraphLayout(plain)
        let b = try ParagraphLayout(soft)
        let fresh = try ParagraphLayout(soft)
        #expect(a.lines == b.lines)
        let times = [Time(0), Time(9, 10), Time(1), Time(11, 10), Time(5)]
        let pixels = try times.map { try b.raw($0) }
        let states = times.map(soft.evaluate)
        for i in [4, 1, 3, 0, 2, 1] {
            #expect(try b.raw(times[i], coverage: true) == a.raw(times[i], coverage: true))
            #expect(try fresh.raw(times[i]) == pixels[i])
            #expect(soft.evaluate(times[i]) == states[i])
        }
        #expect(pixels[1] != pixels[3])
    }
}

struct LatinParagraphTests {
    @Test func structuresAndPunctuation() throws {
        for text in [
            "AVATAR office.", "A careful draft—\nwith room to revise.",
            "An office proof pairs AV and To, then checks punctuation and spacing.",
        ] {
            let input = ParagraphInput.latin(text: text)
            let paragraph = try ParagraphLayout(input)
            #expect(paragraph.lines.count >= 1 && paragraph.lines.count <= 4)
            #expect(paragraph.lines.map(\.length).reduce(0, +) == text.utf16.count)
            if text.contains("\n") {
                #expect(paragraph.lines[0].breakKind == "observed-explicit")
            } else if paragraph.lines.count > 1 {
                #expect(paragraph.lines[0].breakKind == "automatic")
            }
            #expect(paragraph.lines.last?.breakKind == "end")
        }
    }
    @Test func staticLatinIsRandomAccess() throws {
        let input = ParagraphInput.latin()
        let a = try ParagraphLayout(input)
        let b = try ParagraphLayout(input)
        let reference = try a.raw(Time(0))
        let times = [Time(7, 3), Time(-1), Time(0), Time(11, 7)]
        let states = times.map(input.evaluate)
        for i in [3, 1, 0, 2, 0] {
            #expect(b.input.evaluate(times[i]) == states[i])
            #expect(states[i].spans.isEmpty)
            #expect(try b.raw(times[i]) == reference)
        }
        #expect(input.parameters.amplitude == 0)
        #expect(input.appearance == nil)
    }
    @Test func latinCannotInheritJapaneseTiming() throws {
        let latin = ParagraphInput.latin()
        let japanese = ParagraphInput.synthetic(softened: true)
        #expect(throws: ScreenError.self) {
            try ParagraphLayout(
                ParagraphInput(
                    text: latin.text, parameters: latin.parameters, events: japanese.events,
                    paragraphStyle: .latinStatic))
        }
        #expect(throws: ScreenError.self) {
            try ParagraphLayout(
                ParagraphInput(
                    text: latin.text, parameters: latin.parameters, events: [], appearance: SoftAppearance(),
                    paragraphStyle: .latinStatic))
        }
        #expect(throws: ScreenError.self) {
            try ParagraphLayout(ParagraphInput(text: latin.text, events: [], paragraphStyle: .latinStatic))
        }
    }
}
