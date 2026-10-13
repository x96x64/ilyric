import Foundation
import CoreGraphics
import Testing
import SpikeCore
import LyricsInputCore
import LyricsInputMac
import LyricsSliceCore
import LyricsSliceMac

/// Original generated identifiers exercise import and drawing without storing lyric text.
private enum BackingPolicyFixture {
    static let primary=String((0..<18).map { Character(UnicodeScalar(65+$0%26)!) })
    static let secondary=String((0..<12).map { Character(UnicodeScalar(97+$0%26)!) })
    static func lyrics(_ attributes: String = "", opening: Bool = false) throws -> LocalLyrics {
        let begin=opening ? 6 : 2,end=opening ? 8 : 6
        let xml="<tt xmlns=\"http://www.w3.org/ns/ttml\" xmlns:ttm=\"http://www.w3.org/ns/ttml#metadata\" xml:space=\"preserve\"><body><div>" +
            "<p begin=\"\(begin)s\" end=\"\(end)s\"><span begin=\"0s\" end=\"\(end-begin)s\">\(primary)</span>" +
            "<span ttm:role=\"x-bg\"\(attributes)>\(secondary)</span></p><p begin=\"10s\" end=\"12s\">\(primary)</p></div></body></tt>"
        return try TTMLParser.parse(Data(xml.utf8))
    }
    static func scene(_ attributes: String = "", opening: Bool = false) throws -> LocalScene {
        let audio=LocalAudio(samples:Array(repeating:0,count:14*48_000),sourceRate:48_000,sourceChannels:1,sourceFormat:0)
        var p=LocalPresentation(icons:.original,minimumGap:Time(4),focusLead:LocalPresentation.measuredMotion.focusLead,
            stagger:LocalPresentation.measuredMotion.stagger,marquee:.measured,wordMotion:.measured,
            fillLead:LocalPresentation.measuredFillLead,hideControls:LocalPresentation.measuredControlHide)
        p.holdsFinishedLine=true;p.collapsesGaps=true
        return try LocalScene(lyrics:lyrics(attributes,opening:opening),audio:audio,presentation:p,title:"Numerical Policy Fixture",artist:"Synthetic")
    }
}

extension TTMLTests {
    @Test func backingTimingProvenanceDistinguishesInheritedAndExplicitEqualBounds() throws {
        for attributes in [""," begin=\"0s\""," end=\"4s\""," dur=\"4s\""] {
            let bg=try BackingPolicyFixture.lyrics(attributes).entries[0].background!
            #expect(!bg.hasExplicitTiming && bg.begin==Time(2) && bg.end==Time(6))
        }
        for attributes in [" begin=\"0s\" end=\"4s\""," begin=\"0s\" dur=\"4s\""] {
            let bg=try BackingPolicyFixture.lyrics(attributes).entries[0].background!
            #expect(bg.hasExplicitTiming && bg.begin==Time(2) && bg.end==Time(6))
        }
        let partial=try BackingPolicyFixture.lyrics(" begin=\"2s\"").entries[0].background!
        #expect(!partial.hasExplicitTiming && partial.begin==Time(4) && partial.end==Time(6))
        let supplied=try BackingPolicyFixture.lyrics(" begin=\"2s\" dur=\"1s\"").entries[0].background!
        #expect(supplied.hasExplicitTiming && supplied.begin==Time(4) && supplied.end==Time(5))
    }
    @Test func projectOffsetsPreserveBackingTimingProvenanceAndSourceOrder() throws {
        for attributes in [""," begin=\"0s\" end=\"4s\""] {
            let before=try BackingPolicyFixture.lyrics(attributes),after=try before.applyingProjectOffset(250)
            #expect(before.entries.map(\.text)==after.entries.map(\.text))
            #expect(before.entries[0].background!.text==after.entries[0].background!.text)
            #expect(before.entries[0].background!.hasExplicitTiming==after.entries[0].background!.hasExplicitTiming)
            #expect(after.entries[0].background!.begin==Time(9,4) && after.entries[0].background!.end==Time(25,4))
        }
    }
}

extension AudioSceneTests {
    @Test func inheritedBackingRetainsUnfilledInkAcrossLeadFocusAndBoundaries() throws {
        let scene=try BackingPolicyFixture.scene(),r=scene.renderer,bg=r.secondary[0]!
        #expect(!bg.hasExplicitTiming && r.screen.composition.paragraphs.count==2)
        #expect(scene.lyrics.entries[0].background!.text==bg.text)
        let times=[Time(0),Time(1_099_999,1_000_000),Time(11,10),Time(5,4),Time(1_779_999,1_000_000),
                   Time(178,100),Time(2),Time(3),Time(379,100),Time(4),Time(578,100),Time(6),Time(6_000_001,1_000_000),Time(31,5),Time(8)]
        for time in times { #expect(bg.progress(at:time)==0) }
        let input=r.screen.composition.paragraphs[0].input,p=input.parameters
        let count=r.lyrics.paragraphs[0].lines.count
        let baseline=p.originY+Double(count-1)*p.lineAdvance+p.size+SecondaryLine.baselineOffset
        let y0=Int((baseline-p.size*SecondaryLine.sizeRatio*1.1).rounded(.down))
        let y1=Int((baseline+p.size*SecondaryLine.sizeRatio*0.3).rounded(.up))
        func band(_ t: Time) throws -> Data {
            let image=try r.lyricLayer(r.screen.composition.evaluate(t))
            return (image.dataProvider!.data! as Data).subdata(in:y0*image.bytesPerRow..<y1*image.bytesPerRow)
        }
        let reference=try band(Time(5,4))
        #expect(reference.contains { $0 != 0 })
        for time in [Time(11,10),Time(178,100),Time(2),Time(3),Time(379,100),Time(4),Time(578,100),Time(6)] {
            #expect(try band(time)==reference)
        }
        for time in [Time(31,5),Time(8)] {
            let with=try r.lyricLayer(r.screen.composition.evaluate(time)).dataProvider!.data! as Data
            let saved=r.secondary;r.secondary=[:]
            let without=try r.lyricLayer(r.screen.composition.evaluate(time)).dataProvider!.data! as Data
            r.secondary=saved
            #expect(with != without)
        }
    }
    @Test func explicitBackingFillsItsOwnIntervalWithExactEndpoints() throws {
        let scene=try BackingPolicyFixture.scene(" begin=\"2s\" dur=\"1s\""),bg=scene.renderer.secondary[0]!
        #expect(bg.hasExplicitTiming && bg.begin==Time(378,100) && bg.end==Time(478,100))
        #expect(bg.progress(at:Time(3_779_999,1_000_000))==0 && bg.progress(at:bg.begin)==0)
        #expect(bg.progress(at:Time(428,100))==0.5)
        #expect(bg.progress(at:Time(4_779_999,1_000_000))<1 && bg.progress(at:bg.end)==1)
        let equal=try BackingPolicyFixture.scene(" begin=\"0s\" end=\"4s\"").renderer.secondary[0]!
        #expect(equal.hasExplicitTiming && equal.progress(at:Time(3))>0)
    }
    @Test func backingPolicyPreservesControlsMarkersAndRandomAccessRasters() throws {
        for opening in [false,true] {
            let scene=try BackingPolicyFixture.scene(opening:opening),r=scene.renderer,fresh=try scene.makeRenderer()
            let times=[Time(0),Time(11,10),Time(3),Time(379,100),Time(51,10),Time(6),Time(31,5),Time(8)]
            let states=times.map(r.screen.evaluate)
            let images=try states.map { try r.native($0).dataProvider!.data! as Data }
            for i in [6,0,4,2,7,1,5,3,6] {
                #expect(r.screen.evaluate(times[i])==states[i])
                #expect(try r.native(states[i]).dataProvider!.data! as Data==images[i])
                #expect(try fresh.native(states[i]).dataProvider!.data! as Data==images[i])
                let saved=r.secondary;r.secondary=[:]
                let plain=try r.native(states[i]),without=plain.dataProvider!.data! as Data;r.secondary=saved
                #expect(without.prefix(plain.bytesPerRow*400)==images[i].prefix(plain.bytesPerRow*400))
            }
            if opening {
                #expect(r.screen.composition.evaluate(Time(0)).gaps[0].state != nil)
                #expect(r.screen.composition.evaluate(Time(51,10)).gaps[0].state==nil)
            }
        }
    }
}
