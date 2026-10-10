import Testing
import Foundation
import SpikeCore
import LyricsInputCore
import LyricsInputMac
import LyricsSliceCore
import LyricsSliceMac

struct InputTests {
    func parse(_ value: String) throws -> LocalLyrics { try LRCParser.parse(Data(value.utf8)) }
    @Test func exactPrecisionOffsetUnicodeAndStructure() throws {
        let text="AV office: e\u{301}, café."
        let input=try parse("\u{FEFF}[offset:+125]\r\n[00:01.2][00:02.345]\(text)\r\n|青い点を二つ置く\r\n[00:04]\r\n")
        #expect(input.entries.map(\.time)==[Time(1325,1000),Time(2470,1000),Time(4125,1000)])
        #expect(input.entries[0].text.utf8.elementsEqual((text+"\n青い点を二つ置く").utf8))
        #expect(input.entries[0].suppliedBreaks)
        #expect(input.focus(at:Time(1324,1000))==nil)
        #expect(input.focus(at:Time(1325,1000))==0)
        #expect(input.focus(at:Time(4125,1000))==nil)
    }
    @Test func duplicatesOrderingAndMetadata() throws {
        let input=try parse("[ar:Fixture]\n[00:02.000]Second\n[00:01]First\n[00:01.000]First")
        #expect(input.entries.count==2 && input.entries[0].text=="First")
        #expect(input.diagnostics.count==3)
        #expect(throws:InputError.self) { try parse("[00:01]A\n[00:01]B") }
        // Canonically equivalent strings remain distinct source byte sequences.
        #expect(throws:InputError.self) { try parse("[00:01]é\n[00:01]e\u{301}") }
    }
    @Test func malformedAndResourceBounds() throws {
        for text in ["", "[00:01]", "[00:99]A", "[0:01]A", "[00:01.1234]A", "[foo:a]", "[offset:-1000]\n[00:00]A", "[offset:0]\n[offset:1]\n[00:01]A", "[00:01]<00:01.2>A", "|A", "[00:00]A\n|", "[00:00] ", "[00:00]A\rB", "[00:00]A\u{0}", "[00:00]"+String(repeating:"x",count:500)] {
            #expect(throws:InputError.self) { try parse(text) }
        }
        #expect(throws:InputError.self) { try LRCParser.parse(Data([0xff,0xfe])) }
        #expect(throws:InputError.self) { try LRCParser.parse(Data(repeating:65,count:65_537)) }
        #expect(throws:InputError.self) { try parse((0..<257).map{String(format:"[%02d:%02d.%03d]A",$0/600,($0/10)%60,($0%10)*100)}.joined(separator:"\n")) }
        #expect(throws:InputError.self) { try parse("[00:00]A\n|B\n|C\n|D\n|E") }
    }
    @Test func durationAndFocusPolicy() throws {
        let input=try parse("[00:00.100]First\n[00:01]\n[00:02]Last")
        let s=try input.validate(audioSamples:144_001)
        #expect(s.frames==181 && s.outputEnd==Time(181,60))
        #expect(s.audioEnd==Time(144_001,48_000))
        #expect(input.focus(at:Time(0))==nil && input.focus(at:Time(1))==nil)
        #expect(input.focus(at:Time(3))==2)
        let offFrame=try parse("[offset:125]\n[00:00.500]Exact event")
        #expect(offFrame.entries[0].time==Time(5,8))
        #expect(offFrame.focus(at:Time(37,60))==nil && offFrame.focus(at:Time(38,60))==0)
        #expect(throws:InputError.self) { try input.validate(audioSamples:96_000) }
        #expect(throws:InputError.self) { try OutputSchedule(audioSamples:28_800_001) }
        #expect(throws:InputError.self) { try OutputSchedule(audioSamples:0) }
    }
    @Test func staticJapaneseAndSuppliedShaping() throws {
        let jp=SliceInput.supplied(text:"青い点を置く\n次のページへ",japanese:true),r=try SliceParagraph(jp)
        #expect(r.lines.count==2 && r.lines[0].breakKind=="supplied-explicit")
        #expect(jp.events.isEmpty && jp.parameters.amplitude==0 && jp.appearance==nil)
        #expect(try r.raw(Time(0))==r.raw(Time(19,7)))
        let latin=try SliceParagraph(.supplied(text:"AV office: e\u{301}, café.",japanese:false))
        let previous=try SliceParagraph(.latin(text:"AV office: e\u{301}, café."))
        #expect(latin.lines.map(\.width)==previous.lines.map(\.width))
        #expect(try latin.raw(Time(0))==previous.raw(Time(0)))
    }
    @Test func sourceErrors() async throws {
        await #expect(throws:InputError.self) { try await LocalAudio.decode(URL(fileURLWithPath:"/nonexistent-ilyric-fixture.wav")) }
    }
}
