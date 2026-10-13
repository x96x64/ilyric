import Foundation
import CoreGraphics
import Testing
import TimelineCore
import LyricsInputCore
import LyricsInputMac
import LyricsScreenCore
import LyricsScreenMac

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
    static func adjacent(_ attributes:String,opening:Bool) throws -> LocalScene {
        let starts=opening ? [6,8,10,18]:[2,4,6,14]
        let rows=starts.enumerated().map { i,start in
            let main=String((0..<18).map { Character(UnicodeScalar(65+($0+i*3)%26)!) })
            let bg=String((0..<(i==2 ? 30:12)).map { Character(UnicodeScalar(97+($0+i*3)%26)!) })
            return "<p begin=\"\(start)s\" end=\"\(start+2)s\"><span begin=\"0s\" end=\"2s\">\(main)</span><span ttm:role=\"x-bg\"\(attributes)>\(bg)</span></p>"
        }.joined()
        let xml="<tt xmlns=\"http://www.w3.org/ns/ttml\" xmlns:ttm=\"http://www.w3.org/ns/ttml#metadata\" xml:space=\"preserve\"><body><div>\(rows)</div></body></tt>"
        let audio=LocalAudio(samples:Array(repeating:0,count:24*48_000),sourceRate:48_000,sourceChannels:1,sourceFormat:0)
        var p=LocalPresentation(icons:.original,minimumGap:Time(4),focusLead:LocalPresentation.measuredMotion.focusLead,
            stagger:LocalPresentation.measuredMotion.stagger,wordMotion:.measured,fillLead:LocalPresentation.measuredFillLead,
            hideControls:LocalPresentation.measuredControlHide)
        p.holdsFinishedLine=true;p.collapsesGaps=true
        return try LocalScene(lyrics:TTMLParser.parse(Data(xml.utf8)),audio:audio,presentation:p,title:"Numerical Policy Fixture",artist:"Synthetic")
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
    @Test func inheritedBackingHasNoUnfocusedInkAnywhereInFullFrame() throws {
        for attributes in [""," begin=\"0s\""," end=\"2s\""," dur=\"2s\""] {
            for opening in [false,true] {
                let scene=try BackingPolicyFixture.adjacent(attributes,opening:opening)
                let plain=try ScreenRenderer(scene.renderer.screen,calibratedInactive:false,diagnosticMarkers:false,icons:.original)
                plain.secondary=scene.renderer.secondary
                let events=scene.renderer.screen.composition.events
                let boundaries=events.flatMap { [$0.time-Time(1,1_000_000),$0.time,$0.time+Time(1,1_000_000),$0.time+Time(15,100)] }.filter {$0>=Time(0)}
                let times=boundaries+[Time(2),Time(3),Time(379,100),Time(6),Time(8),Time(14),Time(20)]
                for r in [scene.renderer,plain] {
                    let saved=r.secondary
                    #expect(saved.count==4 && scene.lyrics.entries.count==4)
                    #expect(scene.lyrics.entries.enumerated().allSatisfy { saved[$0.offset]?.text==$0.element.background?.text })
                    var frames=[Time:Data]()
                    for time in times {
                        let state=r.screen.evaluate(time),with=try r.native(state).dataProvider!.data! as Data
                        r.secondary=saved.filter {$0.key==state.lyrics.focus}
                        #expect(try r.native(state).dataProvider!.data! as Data==with)
                        r.secondary=[:];let main=try r.native(state).dataProvider!.data! as Data
                        for i in saved.keys where i != state.lyrics.focus {
                            r.secondary=[i:saved[i]!]
                            #expect(try r.native(state).dataProvider!.data! as Data==main)
                        }
                        r.secondary=saved
                        for cue in saved.values { #expect(cue.progress(at:time)==0) }
                        frames[time]=with
                    }
                    for time in Array(times.reversed())+Array(times.prefix(3)) {
                        #expect(try r.native(r.screen.evaluate(time)).dataProvider!.data! as Data==frames[time])
                    }
                }
            }
        }
    }
    @Test func inheritedBackingRetainsDimInkOnlyDuringLeadFocusAndBoundaries() throws {
        let scene=try BackingPolicyFixture.scene(),r=scene.renderer,bg=r.secondary[0]!
        #expect(!bg.hasExplicitTiming && r.screen.composition.paragraphs.count==2)
        #expect(scene.lyrics.entries[0].background!.text==bg.text)
        let times=[Time(0),Time(1_099_999,1_000_000),Time(11,10),Time(5,4),Time(1_779_999,1_000_000),
                   Time(178,100),Time(2),Time(3),Time(379,100),Time(4),Time(578,100),Time(6),Time(6_000_001,1_000_000),Time(31,5),Time(8)]
        for time in times { #expect(bg.progress(at:time)==0) }
        let saved=r.secondary
        for time in times {
            let state=r.screen.evaluate(time),with=try r.native(state).dataProvider!.data! as Data
            r.secondary=[:];let without=try r.native(state).dataProvider!.data! as Data;r.secondary=saved
            let a=InactiveTreatment.evaluate(time,paragraph:0,events:r.screen.composition.events)
            if state.lyrics.focus != 0 || a.blur==8 { #expect(with==without) }
            else { #expect(with != without) }
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
