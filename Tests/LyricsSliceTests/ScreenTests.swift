import Testing
import Foundation
import CoreGraphics
import SpikeCore
import LyricsSliceCore
import LyricsSliceMac

struct ScreenTests {
    @Test func componentEvidenceAndVisibility() throws {
        let s=try LyricsScreen.synthetic(),a=s.evaluate(Time(0)),b=s.evaluate(Time(2)),c=s.evaluate(Time(4)),d=s.evaluate(Time(5))
        func part(_ state:ScreenSnapshot,_ id:ScreenPart) -> ScreenComponent { state.components.first{$0.part==id}! }
        #expect(part(a,.artwork).bounds == ScreenBounds(96,276,216,216))
        #expect(part(a,.progress).bounds == ScreenBounds(96,1683,987,21))
        #expect(part(a,.volume).bounds == ScreenBounds(171,2192,811,22))
        #expect(part(a,.translation).visible && !part(a,.singCompact).visible)
        #expect(part(b,.singCompact).visible && !part(b,.singExpanded).visible)
        #expect(part(c,.singExpanded).visible && !part(c,.translation).visible)
        #expect(!part(d,.progress).visible && !part(d,.playback).visible && part(d,.title).visible)
        #expect(a.components.allSatisfy { $0.clips })
        #expect(part(a,.lyrics).z < part(c,.singExpanded).z)
        #expect(Set(a.components.map(\.part)).count==a.components.count)
        #expect(s.evaluate(Time(6)).progress==6.0/180)
        #expect(s.evaluate(Time(200)).progress==1)
        #expect(s.evaluate(Time(-1)).progress==0)
    }
    @Test func clocksAndEventBoundaries() throws {
        let base=try LyricsComposition.synthetic()
        let composition=try LyricsComposition(paragraphs:base.paragraphs,events:base.events,clocks:[
            .init(output:Time(0),media:Time(60),running:true),.init(output:Time(2),media:Time(62),running:false)])
        let screen=try LyricsScreen(composition:composition,title:"A",artist:"B",duration:Time(180),volume:0.3,events:[
            .init(Time(0),order:0,controls:.init()),.init(Time(2),order:1,controls:.init(translation:true)),
            .init(Time(2),order:2,controls:.init(sing:.expanded))])
        #expect(screen.evaluate(Time(3)).elapsed==62 && !screen.evaluate(Time(3)).playing)
        #expect(screen.evaluate(Time(3)).lyrics.focus==2) // Independent interface clock.
        #expect(screen.evaluate(Time(2)).components.first{$0.part == .singExpanded}!.visible)
        #expect(!screen.evaluate(Time(119,60)).components.first{$0.part == .singExpanded}!.visible)
        #expect(throws:SliceError.self) { try LyricsScreen(composition:base,title:"",artist:"B",duration:Time(6),volume:0.3,events:[]) }
    }
    @Test func referenceVolumeFillEndsAtMeasuredPixel() throws {
        let base=try LyricsScreen.synthetic()
        let screen=try LyricsScreen(composition:base.composition,title:base.title,artist:base.artist,duration:base.duration,
                                    volume:LyricsScreen.referenceVolume,events:[.init(Time(0),order:0,controls:.init())])
        let bytes=[UInt8](try ScreenRenderer(screen).native(screen.evaluate(Time(0))).dataProvider!.data! as Data)
        func luma(_ x:Int) -> Int { let i=(2203*1179+x)*4;return Int(bytes[i])+Int(bytes[i+1])+Int(bytes[i+2]) }
        // The bright fill occupies columns up to 575 and the dimmer track begins at 576.
        #expect(luma(574)>luma(577)+60 && abs(luma(577)-luma(600))<10)
    }
    @Test func nativeCoordinatesAndFade() {
        let a=LyricsScreen.contain(width:1080,height:1920,canvasWidth:1179)
        let b=LyricsScreen.contain(width:1080,height:1920,canvasWidth:1180)
        #expect(abs(a.x-97.1830985915)<1e-8)
        #expect(a.height==1920 && b.height==1920 && a.width != b.width)
        #expect(LyricsScreen.fade(at:549)==0 && LyricsScreen.fade(at:1500)==0)
        #expect(LyricsScreen.fade(at:590)==0.5 && LyricsScreen.fade(at:1460)==0.5)
        #expect(LyricsScreen.fade(at:800)==1)
    }
    @Test func deterministicRasterAndLocalNonregression() throws {
        let s=try LyricsScreen.synthetic(),r=try ScreenRenderer(s),fresh=try ScreenRenderer(s)
        let times=[Time(0),Time(13,12),Time(3,2),Time(4),Time(5)]
        let states=times.map(s.evaluate),pixels=try times.map{try r.native(s.evaluate($0)).dataProvider!.data! as Data}
        for i in [3,1,4,0,2,1] {
            #expect(s.evaluate(times[i])==states[i])
            #expect(try fresh.native(states[i]).dataProvider!.data! as Data == pixels[i])
            #expect(states[i].lyrics==s.composition.evaluate(times[i]))
        }
        for (i,p) in s.composition.paragraphs.enumerated() {
            let independent=try SliceParagraph(p.input)
            #expect(r.lyrics.paragraphs[i].lines==independent.lines)
            #expect(try r.lyrics.paragraphs[i].raw(Time(3,2))==independent.raw(Time(3,2)))
        }
        let layer=try r.lyricLayer(states[2].lyrics),old=try r.lyrics.native(states[2].lyrics,transparent:true)
        let a=layer.dataProvider!.data! as Data,b=old.dataProvider!.data! as Data,row=layer.bytesPerRow
        #expect(a[(630*row)..<(1420*row)]==b[(630*row)..<(1420*row)])
        #expect([UInt8](a)[0..<550*row].allSatisfy{$0==0})
        #expect([UInt8](a)[1500*row..<2556*row].allSatisfy{$0==0})
        // Header and time labels must produce visible ink; catches text-position leakage.
        let bytes=[UInt8](pixels[2]),w=1179
        for box in [ScreenBounds(352,338,650,58),.init(352,398,650,58),.init(96,1730,200,48)] {
            var bright=0
            for y in Int(box.y)..<Int(box.y+box.height) { for x in Int(box.x)..<Int(box.x+box.width) {
                if bytes[(y*w+x)*4]>130 { bright+=1 }
            }}
            #expect(bright>100)
        }
    }
}
