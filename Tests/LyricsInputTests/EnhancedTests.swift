import Testing
import Foundation
import SpikeCore
import LyricsInputCore
import LyricsInputMac
import LyricsSliceCore
import LyricsSliceMac

struct EnhancedTests {
    func parse(_ text:String) throws -> LocalLyrics { try EnhancedLRCParser.parse(Data(text.utf8)) }
    @Test func precisionTextOffsetsAndContinuations() throws {
        let text="[offset:125]\n[00:00.500]<00:00.601>AV office: <00:01.203>e\u{301}, café.<00:01.899>\n|<00:02.003>青い点、<00:02.777>二つ。<00:03.001>\n[00:03.500]\n[00:04]Final"
        let input=try parse(text),e=input.entries[0]
        #expect(e.text.utf8.elementsEqual("AV office: e\u{301}, café.\n青い点、二つ。".utf8))
        #expect(e.time==Time(5,8) && e.segments.count==4)
        #expect(e.segments[0].begin==Time(726,1000) && e.segments.last!.end==Time(3126,1000))
        #expect(e.segments[2].start=="AV office: e\u{301}, café.\n".utf16.count)
        let shifted=try input.applyingProjectOffset(25)
        #expect(shifted.entries[0].segments[0].begin==Time(751,1000))
        #expect(shifted.entries[0].text.utf8.elementsEqual(e.text.utf8))
        #expect(input.focus(at:Time(3))==0 && input.focus(at:Time(3625,1000))==nil)
        #expect(throws:InputError.self) { try input.validate(audioSamples:120_000) }
    }
    @Test func ordinaryCompatibilityDuplicatesAndIntervals() throws {
        let ordinary="[ar:Original]\n[offset:100]\n[00:01][00:02]Text\n|Second line\n[00:03]\n[00:04]Last"
        let old=try LRCParser.parse(Data(ordinary.utf8)),new=try parse(ordinary)
        #expect(old.entries==new.entries && old.diagnostics==new.diagnostics)
        let duplicate="[00:00]<00:00>A <00:01>B<00:02>"
        #expect(try parse(duplicate+"\n"+duplicate).entries.count==1)
        for invalid in [duplicate+"\n[00:00]<00:00.1>A <00:01>B<00:02>",
            "[00:00][00:01]A\n[00:01]<00:01>A<00:02>",
            "[00:00]<00:00>A<00:02>\n[00:01]Next"] {
            #expect(throws:InputError.self) { try parse(invalid) }
        }
        let end=try parse("[00:00]<00:00>A<00:01>\n[00:01]Next")
        #expect(try end.validate(audioSamples:96_000).frames==120)
    }
    @Test func syntaxBoundsAndGraphemes() throws {
        for invalid in ["[00:00]<00:00>A", "[00:00] <00:00>A<00:01>","[00:00]<00:00>A<00:01> ",
            "[00:00]<00:00><00:01>A<00:02>","[00:00]<00:00>A<00:00>",
            "[00:00]<00:01>A<00:00.5>","[00:00]<-00:00>A<00:01>","[00:00]<00:00.0001>A<00:01>",
            "[00:00]<00:00>A[00:01]B<00:02>","[00:01]<00:00>A<00:02>",
            "[offset:-1]\n[00:00]<00:00>A<00:01>","[00:00]<00:00>A<00:01>\n|Untimed",
            "[00:00]Untimed\n|<00:01>A<00:02>","[00:00]<00:00>A<00:02>\n|<00:01>B<00:03>",
            "[00:00]<00:00>e<00:01>\u{301}<00:02>","[00:00]<00:00>👩<00:01>‍💻<00:02>",
            "[00:00]<00:00>✈<00:01>️<00:02>"] {
            #expect(throws:InputError.self) { try parse(invalid) }
        }
        let unicode="e\u{301} 👩‍💻 ✈️"
        #expect(try parse("[00:00]<00:00>\(unicode)<00:01>").entries[0].text.utf8.elementsEqual(unicode.utf8))
        #expect(throws:InputError.self) { try EnhancedLRCParser.parse(Data([0xff])) }
        #expect(throws:InputError.self) { try EnhancedLRCParser.parse(Data(repeating:65,count:65537)) }
        func segments(_ last:Int) -> String {
            var text="[00:00]"
            for index in 0...last {
                let suffix:String=index==last ? "" : "a"
                text+=String(format:"<00:%02d.%03d>%@",index/10,index%10*100,suffix)
            }
            return text
        }
        let tooManySegments=segments(129)
        #expect(throws:InputError.self) { try parse(tooManySegments) }
        #expect(throws:InputError.self) { try parse(String(repeating:"[00:00]",count:1000)+"A") }
        let row=segments(128)
        #expect(throws:InputError.self) { try parse(Array(repeating:row,count:5).joined(separator:"\n")) }
    }
    @Test func projectCompatibility() throws {
        let url=URL(fileURLWithPath:"/tmp/example/project.json")
        func project(_ json:String) throws -> ExperimentalProject { try .parse(Data(json.utf8),at:url) }
        let v2=try project(#"{"version":2,"inputs":{"audio":"audio.wav","lyrics":"lines.lrc","lyricsFormat":"enhanced-lrc"},"timing":{"highlighting":"disabled","offsetMilliseconds":125}}"#)
        #expect(v2.version==2 && v2.lyricsFormat == .enhancedLRC && v2.highlighting == .disabled)
        #expect(v2.lyrics.path=="/tmp/example/lines.lrc")
        for invalid in [#"{"version":2,"inputs":{"audio":"a","lyrics":"b"}}"#,
            #"{"version":1,"inputs":{"audio":"a","lyrics":"b","lyricsFormat":"enhanced-lrc"}}"#,
            #"{"version":2,"inputs":{"audio":"a","lyrics":"b","lyricsFormat":"ttml"}}"#,
            #"{"version":2,"inputs":{"audio":"a","lyrics":"b","lyricsFormat":"lrc"},"timing":{"highlighting":"enabled"}}"#,
            #"{"version":2,"inputs":{"audio":"a","lyrics":"b","lyricsFormat":"enhanced-lrc"},"timing":{"highlighting":"automatic"}}"#] {
            #expect(throws:InputError.self) { try project(invalid) }
        }
    }
    @Test func wrappedRangesClusterMappingAndRandomRaster() throws {
        let text="AV office, careful pages move into clear daylight."
        let events=[AppearanceEvent(start:0,length:text.utf16.count,begin:.init(601,1000),end:.init(2003,1000),verticalEvent:nil)]
        let input=SliceInput.suppliedTimed(text:text,japanese:false,events:events),timed=try SliceParagraph(input)
        let plain=try SliceParagraph(.supplied(text:text,japanese:false))
        #expect(timed.lines==plain.lines && timed.lines.count>1)
        #expect(timed.lines[0].breakKind=="automatic")
        #expect(input.evaluate(Time(601,1000)).spans[0].progress==0)
        #expect(input.evaluate(Time(2003,1000)).spans[0].progress==1)
        let times=[Time(0),Time(601,1000),Time(7,6),Time(2003,1000)]
        let raw=try times.map { try timed.raw($0) },states=times.map(input.evaluate)
        for i in [3,1,0,2,1,3] { #expect(try timed.raw(times[i])==raw[i]);#expect(input.evaluate(times[i])==states[i]) }
        #expect(raw[0] != raw[2] && raw[2] != raw[3])
        #expect(try timed.raw(Time(3),coverage:true)==plain.raw(Time(3)))
        // A ligature-prone case remains whole-paragraph shaped. This system font resolves the tested boundary separately.
        let split=[AppearanceEvent(start:0,length:2,begin:.init(0),end:.init(1),verticalEvent:nil),AppearanceEvent(start:2,length:4,begin:.init(1),end:.init(2),verticalEvent:nil)]
        do {
            let splitLayout=try SliceParagraph(.suppliedTimed(text:"office",japanese:false,events:split))
            #expect(splitLayout.lines == (try SliceParagraph(.supplied(text:"office",japanese:false))).lines)
        } catch SliceError.invalid(let message) { #expect(message=="Event splits a shaped cluster") }
        // An independently supplied cluster map exercises the rejection policy without assuming a font's ligatures.
        #expect(throws:SliceError.self) { try SliceParagraph.validateShapedRange(0,2,boundaries:[0,3,6]) }
        try SliceParagraph.validateShapedRange(0,3,boundaries:[0,3,6])
    }
    @Test func unicodeShapingAndAppearanceEndpoints() throws {
        let lyrics=try parse("[00:00]<00:00.601>e\u{301}, <00:01.003>👩‍💻 <00:01.777>✈️, <00:02.501>AV office.<00:03.001>")
        let entry=lyrics.entries[0]
        let events=entry.segments.map { AppearanceEvent(start:$0.start,length:$0.length,begin:.init($0.begin.numerator,$0.begin.denominator),end:.init($0.end.numerator,$0.end.denominator),verticalEvent:nil) }
        for japanese in [false,true] {
            let input=SliceInput.suppliedTimed(text:entry.text,japanese:japanese,events:events)
            #expect(throws:SliceError.self) { try SliceParagraph(input) }
        }
        // Color glyphs preserve source and graphemes, but progressive raster support is explicitly unqualified.
        let original="e\u{301}, AV office."
        let event=AppearanceEvent(start:0,length:original.utf16.count,begin:.init(601,1000),end:.init(3001,1000),verticalEvent:nil)
        for japanese in [false,true] {
            let input=SliceInput.suppliedTimed(text:original,japanese:japanese,events:[event])
            let renderer=try SliceParagraph(input),staticRenderer=try SliceParagraph(.supplied(text:original,japanese:japanese))
            #expect(renderer.lines==staticRenderer.lines)
            #expect(try renderer.raw(Time(4),coverage:true)==staticRenderer.raw(Time(4)))
            #expect(try renderer.raw(Time(4))==staticRenderer.raw(Time(4)))
            let boundary=Time(601,1000),before=Time(600,1000),after=Time(602,1000)
            #expect(input.evaluate(before).spans[0].progress==0 && input.evaluate(boundary).spans[0].progress==0)
            #expect(input.evaluate(after).spans[0].progress>0)
            let raw=try renderer.raw(Time(777,500))
            #expect(try SliceParagraph(input).raw(Time(777,500))==raw)
        }
    }
    @Test func multilineFocusAndDisabledNonregression() async throws {
        let url=try AudioSceneTests().wav();defer { try? FileManager.default.removeItem(at:url) }
        let audio=try await LocalAudio.decode(url)
        let enhanced=try parse("[00:00.125]<00:00.200>青い点<00:00.900>\n|<00:01.001>二つ置く<00:02.200>\n[00:02.500]<00:02.600>Final<00:02.900>")
        let plain=try LRCParser.parse(Data("[00:00.125]青い点\n|二つ置く\n[00:02.500]Final".utf8))
        let on=try LocalScene(lyrics:enhanced,audio:audio),off=try LocalScene(lyrics:enhanced,audio:audio,highlighting:.disabled),old=try LocalScene(lyrics:plain,audio:audio)
        #expect(on.lyrics.entries[0].segments==off.lyrics.entries[0].segments)
        #expect(on.renderer.lyrics.paragraphs[0].lines==off.renderer.lyrics.paragraphs[0].lines)
        for time in [Time(0),Time(1),Time(3,2),Time(12,5),Time(5,2)] {
            let a=on.renderer.screen.evaluate(time),b=off.renderer.screen.evaluate(time)
            #expect(a.lyrics.focus==b.lyrics.focus && a.lyrics.scroll==b.lyrics.scroll && a.components==b.components && a.progress==b.progress)
            #expect(try off.renderer.frame(time).dataProvider!.data! as Data==old.renderer.frame(time).dataProvider!.data! as Data)
        }
        #expect(on.renderer.screen.evaluate(Time(12,5)).lyrics.paragraphs[0].appearance.spans.allSatisfy{$0.progress==1})
        #expect(on.renderer.screen.evaluate(Time(12,5)).lyrics.focus==0)
        #expect(on.renderer.screen.evaluate(Time(5,2)).lyrics.focus==1)
        let times=[Time(0),Time(1),Time(3,2),Time(12,5),Time(5,2)]
        let rasters=try times.map { try on.renderer.frame($0).dataProvider!.data! as Data }
        for i in [4,2,0,3,1,4] { #expect(try on.renderer.frame(times[i]).dataProvider!.data! as Data==rasters[i]) }
    }
}
