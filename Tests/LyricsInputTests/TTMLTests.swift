import Testing
import Foundation
import SpikeCore
import LyricsInputCore
import LyricsInputMac
import LyricsSliceCore
import LyricsSliceMac

struct TTMLTests {
    func parse(_ p:String,outer:String="") throws -> LocalLyrics {
        try TTMLParser.parse(Data("<tt xmlns=\"http://www.w3.org/ns/ttml\" xml:space=\"preserve\"><body \(outer)><div>\(p)</div></body></tt>".utf8))
    }
    @Test func exactExpressionsAndParentResolution() throws {
        #expect(try TTMLParser.time("00:00:01.000001")==Time(1_000_001,1_000_000))
        #expect(try TTMLParser.time("0.001ms")==Time(1,1_000_000))
        #expect(try TTMLParser.time("0.1m")==Time(6))
        #expect(try TTMLParser.time("0.01h")==Time(36))
        let input=try parse("<p begin=\"0.025s\" dur=\"2s\"><span begin=\"0.001234s\" end=\"0.201234s\">Paper </span><br/><span begin=\"1s\" dur=\"0.5s\">skies.</span></p>",outer:"begin=\"0.1s\" end=\"3s\"")
        let e=input.entries[0]
        #expect(e.time==Time(1,8) && e.intervalEnd==Time(17,8))
        #expect(e.segments[0].begin==Time(126234,1_000_000))
        #expect(e.segments[1].start==7 && e.text=="Paper \nskies." && e.suppliedBreaks)
        let offset=try input.applyingProjectOffset(125).entries[0]
        #expect(offset.time==Time(1,4) && offset.intervalEnd==Time(9,4))
        #expect(offset.segments[0].begin==Time(251234,1_000_000))
        for bad in ["1","1f","1t","wallclock(12:00:00)","-1s","+1s","1e2s",".1s","1.1234567s","00:00:60","00:00:01:01","0:00:01","600.000001s","9999999999h","1 s"] {
            #expect(throws:InputError.self) {try TTMLParser.time(bad)}
        }
    }
    @Test func xmlSafetyNamespacesAndLimits() throws {
        let doc="<tt xmlns=\"http://www.w3.org/ns/ttml\" xml:space=\"preserve\"><body><div><p begin=\"0s\" end=\"1s\">Paper</p></div></body></tt>"
        for bad in [Data([0xff]),Data(repeating:65,count:65537),Data("<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\(doc)".utf8),Data(("<!DOCTYPE tt SYSTEM \"file:///unavailable\">"+doc).utf8),Data(("<!DOCTYPE tt [<!ENTITY e 'expanded'>]>"+doc).utf8),Data(("<?resource href=\"https://invalid.example/\"?>"+doc).utf8),Data(doc.replacingOccurrences(of:"Paper",with:"&missing;").utf8),Data(doc.replacingOccurrences(of:"http://www.w3.org/ns/ttml",with:"urn:unsupported").utf8),Data(doc.replacingOccurrences(of:"</tt>",with:"").utf8),Data((doc+doc).utf8),Data(doc.replacingOccurrences(of:"xml:space=\"preserve\"",with:"").utf8),Data(doc.replacingOccurrences(of:"xml:space=\"preserve\"",with:"xml:space=\"default\"").utf8)] {
            #expect(throws:InputError.self) {try TTMLParser.parse(bad)}
        }
        let alias="<t:tt xmlns:t=\"http://www.w3.org/ns/ttml\" xmlns:q=\"http://www.w3.org/ns/ttml#parameter\" q:timeBase=\"media\" xml:space=\"preserve\"><t:body><t:div><t:p begin=\"0s\" dur=\"1s\">A&amp;B&#x301;</t:p></t:div></t:body></t:tt>"
        #expect(try TTMLParser.parse(Data(alias.utf8)).entries[0].text.utf8.elementsEqual("A&B\u{301}".utf8))
        #expect(throws:InputError.self) {try parse("<p begin=\"0s\" end=\"1s\">"+String(repeating:"<span>",count:20)+"A"+String(repeating:"</span>",count:20)+"</p>")}
        #expect(throws:InputError.self) {try parse(String(repeating:"<p begin=\"0s\" end=\"1s\">A</p>",count:65))}
        #expect(throws:InputError.self) {try parse("<p begin=\"0s\" end=\"1s\">"+String(repeating:"x",count:500)+"</p>")}
        #expect(throws:InputError.self) {try parse("<p begin=\"0s\" end=\"1s\">"+String(repeating:"<br/>",count:1024)+"A</p>")}
    }
    @Test func unsupportedIntervalsStructureAndUnicode() throws {
        for p in ["<p>Text</p>","<p begin=\"0s\">A</p>","<p begin=\"0s\" dur=\"0s\">A</p>","<p begin=\"0s\" end=\"1s\" dur=\"1s\">A</p>","<p begin=\"1s\" end=\"2s\">A</p><p begin=\"0s\" end=\"1s\">B</p>","<p begin=\"0s\" end=\"2s\">A</p><p begin=\"1s\" end=\"3s\">B</p>","<p begin=\"0s\" end=\"1s\" timeContainer=\"seq\">A</p>","<p begin=\"0s\" end=\"1s\" style=\"unimplemented\">A</p>","<p begin=\"0s\" end=\"1s\"><span begin=\"0s\" end=\"2s\">A</span></p>","<p begin=\"0s\" end=\"2s\"><span begin=\"0s\" end=\"1s\">A</span> <span begin=\"1s\" end=\"2s\">B</span></p>","<p begin=\"0s\" end=\"2s\"><span begin=\"0s\" end=\"1.1s\">A</span><span begin=\"1s\" end=\"2s\">B</span></p>","<p begin=\"0s\" end=\"2s\"><span begin=\"0s\" end=\"1s\">e</span><span begin=\"1s\" end=\"2s\">&#x301;</span></p>","<p begin=\"0s\" end=\"2s\"><span begin=\"0s\" end=\"1s\">👩</span><span begin=\"1s\" end=\"2s\">‍💻</span></p>","<p begin=\"0s\" end=\"2s\"><span begin=\"0s\" end=\"1s\">✈</span><span begin=\"1s\" end=\"2s\">️</span></p>","<p begin=\"0s\" end=\"1s\">A\nB</p>","<p begin=\"0s\" end=\"1s\"><![CDATA[A\tB]]></p>"] {
            #expect(throws:InputError.self) {try parse(p)}
        }
        #expect(throws:InputError.self) {try parse("<p begin=\"0s\" end=\"3s\">A</p>",outer:"end=\"2s\"")}
        let original="e\u{301} 👩‍💻 ✈️, AV office."
        #expect(try parse("<p begin=\"0s\" end=\"1s\"><![CDATA[\(original)]]></p>").entries[0].text.utf8.elementsEqual(original.utf8))
    }
    @Test func explicitEndsAndGapFocus() throws {
        let input=try parse("<p begin=\"0.125s\" end=\"1.003s\">A</p><p begin=\"2s\" end=\"2.5s\"/><p begin=\"2.5s\" end=\"3s\">B</p>")
        for (time,focus) in [(Time(0),nil),(Time(1,8),0),(Time(1),0),(Time(1003,1000),nil),(Time(2),nil),(Time(5,2),2),(Time(3),nil)] {
            #expect(input.focus(at:time)==focus)
        }
        #expect(try input.validate(audioSamples:144000).frames==180)
        #expect(throws:InputError.self) {try input.validate(audioSamples:143999)}
        #expect(throws:InputError.self) {try input.applyingProjectOffset(-126)}
    }
    @Test func configurationCompatibility() throws {
        func project(_ v:Int,_ format:String) throws -> ExperimentalProject {try .parse(Data("{\"version\":\(v),\"inputs\":{\"audio\":\"a.wav\",\"lyrics\":\"a.ttml\",\"lyricsFormat\":\"\(format)\"},\"timing\":{\"highlighting\":\"disabled\"}}".utf8),at:URL(fileURLWithPath:"/tmp/project.json"))}
        #expect(try project(3,"ttml").lyricsFormat == .ttml)
        #expect(try project(3,"enhanced-lrc").lyricsFormat == .enhancedLRC)
        #expect(try project(2,"enhanced-lrc").version==2)
        for (v,f) in [(1,"ttml"),(2,"ttml"),(4,"ttml"),(3,"unknown"),(3,"lrc")] {#expect(throws:InputError.self) {try project(v,f)}}
    }
    @Test func equivalenceWholeParagraphAndRandomRaster() async throws {
        let p="<p begin=\"0.125s\" end=\"2.5s\"><span begin=\"0.075s\" end=\"0.775s\">青い点</span><br/><span begin=\"0.876s\" end=\"2.075s\">二つ置く</span></p><p begin=\"2.5s\" end=\"3s\"><span begin=\"0.1s\" dur=\"0.3s\">Final</span></p>"
        let ttml=try parse(p),enhanced=try EnhancedTests().parse("[00:00.125]<00:00.200>青い点<00:00.900>\n|<00:01.001>二つ置く<00:02.200>\n[00:02.500]<00:02.600>Final<00:02.900>")
        let url=try AudioSceneTests().wav();defer {try? FileManager.default.removeItem(at:url)}
        let audio=try await LocalAudio.decode(url),a=try LocalScene(lyrics:ttml,audio:audio),b=try LocalScene(lyrics:enhanced,audio:audio),off=try LocalScene(lyrics:ttml,audio:audio,highlighting:.disabled)
        for (t,e) in zip(ttml.entries,enhanced.entries) {#expect(t.time==e.time && t.text==e.text && t.segments==e.segments)}
        let times=[Time(0),Time(1,8),Time(1),Time(3,2),Time(12,5),Time(5,2),Time(2999,1000)]
        let states=times.map(a.renderer.screen.evaluate),raw=try times.map {try a.renderer.frame($0).dataProvider!.data! as Data}
        for i in [6,2,0,4,3,1,5,2] {
            #expect(a.renderer.screen.evaluate(times[i])==states[i])
            #expect(try a.renderer.frame(times[i]).dataProvider!.data! as Data==raw[i])
            #expect(try b.renderer.frame(times[i]).dataProvider!.data! as Data==raw[i])
            let disabled=off.renderer.screen.evaluate(times[i])
            #expect(disabled.components==states[i].components && disabled.progress==states[i].progress && disabled.lyrics.focus==states[i].lyrics.focus && disabled.lyrics.scroll==states[i].lyrics.scroll)
        }
        #expect(states[4].lyrics.paragraphs[0].appearance.spans.allSatisfy{$0.progress==1} && states[4].lyrics.focus==0)
        #expect(a.renderer.lyrics.paragraphs[0].lines==off.renderer.lyrics.paragraphs[0].lines)
        let gap=try parse("<p begin=\"0s\" end=\"1s\">Paper</p><p begin=\"2s\" end=\"3s\">Skies</p>")
        let scene=try LocalScene(lyrics:gap,audio:audio)
        #expect(scene.renderer.screen.evaluate(Time(1)).lyrics.focus == -1)
        #expect(scene.renderer.screen.evaluate(Time(2)).lyrics.focus==1)
    }
    @Test func fixtureEquivalenceAndResourceBounds() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let xml=try Data(contentsOf:root.appendingPathComponent("fixtures/ttml/lines.ttml"))
        let lrc=try Data(contentsOf:root.appendingPathComponent("fixtures/enhanced-lrc/lines.lrc"))
        let a=try TTMLParser.parse(xml),b=try EnhancedLRCParser.parse(lrc)
        for (x,y) in zip(a.entries,b.entries) {#expect(x.time==y.time && x.text.utf8.elementsEqual(y.text.utf8) && x.segments==y.segments)}
        let prefix="<p begin=\"0s\" end=\"2s\">"
        let spans=(0..<129).map {"<span begin=\"\($0*10)ms\" dur=\"10ms\">a</span>"}.joined()
        #expect(throws:InputError.self) {try parse(prefix+spans+"</p>")}
        let paragraphs=(0..<6).map { j in
            "<p begin=\"\(j)s\" dur=\"1s\">"+(0..<86).map {"<span begin=\"\($0*10)ms\" dur=\"10ms\">a</span>"}.joined()+"</p>"
        }.joined()
        #expect(throws:InputError.self) {try parse(paragraphs)}
        // Wall-clock measurement is diagnostic only; timeline and export state never use it.
        for format in [LyricsFormat.enhancedLRC,.ttml] {
            let data=format == .ttml ? xml:lrc,start=Date()
            for _ in 0..<100 {#expect(try LyricsParser.parse(data,format:format).entries.count==4)}
            print("Bounded conversion diagnostic \(format.rawValue): 100 iterations, \(Date().timeIntervalSince(start)) seconds")
        }
    }

    @Test func spansCrossExplicitAndAutomaticLines() throws {
        for content in ["AV office,<br/>careful pages.","Careful pages move through clear daylight."] {
            let entry=try parse("<p begin=\"0s\" end=\"3s\"><span begin=\"0.001234s\" end=\"2.501s\">\(content)</span></p>").entries[0]
            let segment=entry.segments[0]
            let event=AppearanceEvent(start:segment.start,length:segment.length,begin:.init(segment.begin.numerator,segment.begin.denominator),end:.init(segment.end.numerator,segment.end.denominator),verticalEvent:nil)
            let renderer=try SliceParagraph(.suppliedTimed(text:entry.text,japanese:false,events:[event]))
            let plain=try SliceParagraph(.supplied(text:entry.text,japanese:false))
            #expect(renderer.lines.count>1 && renderer.lines==plain.lines)
            #expect(try renderer.raw(Time(3))==plain.raw(Time(3)))
            let raw=try renderer.raw(Time(1234567,1_000_000))
            #expect(raw != (try renderer.raw(Time(0))))
            #expect(try SliceParagraph(.suppliedTimed(text:entry.text,japanese:false,events:[event])).raw(Time(1234567,1_000_000))==raw)
        }
    }

}
