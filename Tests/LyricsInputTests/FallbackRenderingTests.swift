import Foundation
import CoreGraphics
import Testing
import AlignmentCore
import SpikeCore
import LyricsInputCore
import LyricsInputMac
import LyricsSliceCore
import LyricsSliceMac

// The existing CI filter includes AudioSceneTests; numerical fixtures contain no source lyrics.
extension AudioSceneTests {
    @Test func relocatedFallbacksPreserveImportedParagraphsStyleControlsAndRandomRaster() throws {
        func row(_ id: Int,_ estimate: [Int]? = nil) -> LineAlignment {
            LineAlignment(id:id,text:String(id),alignmentText:String(id),proposal:estimate,estimate:estimate,
                flags:[],support:nil,similarity:nil,words:nil,wordEstimates:nil,onsetTrim:nil,offsetExtension:nil)
        }
        let rows=[row(0),row(1,[8_000_000,10_000_000]),row(2)],duration=20_000_000
        let baseline=TTMLExport.fillUnresolved(rows,duration:duration)
        let level=(0..<1000).map { frame in (50..<200).contains(frame) || (800..<1000).contains(frame) ? 0.0 : -120.0 }
        let relocated=TTMLExport.relocateBoundaryFallbacks(rows,fills:baseline,duration:duration,level:level,reference:0)
        let before=try TTMLParser.parse(Data(TTMLExport.ttml(rows,fills:baseline).utf8))
        let after=try TTMLParser.parse(Data(TTMLExport.ttml(rows,fills:relocated).utf8))
        #expect(before.entries.count==3 && after.entries.count==3)
        #expect(before.entries.map(\.text)==after.entries.map(\.text))
        #expect(before.entries[1].time==after.entries[1].time && before.entries[1].intervalEnd==after.entries[1].intervalEnd)
        let audio=LocalAudio(samples:Array(repeating:0,count:20*48_000),sourceRate:48_000,sourceChannels:1,sourceFormat:0)
        var p=LocalPresentation(icons:.original,minimumGap:Time(4),focusLead:LocalPresentation.measuredMotion.focusLead,
            stagger:LocalPresentation.measuredMotion.stagger,marquee:.measured,wordMotion:.measured,
            fillLead:LocalPresentation.measuredFillLead,hideControls:LocalPresentation.measuredControlHide)
        p.holdsFinishedLine=true;p.collapsesGaps=true
        let a=try LocalScene(lyrics:before,audio:audio,presentation:p,title:"Numerical Fixture",artist:"Synthetic")
        let b=try LocalScene(lyrics:after,audio:audio,presentation:p,title:"Numerical Fixture",artist:"Synthetic")
        let renderer=b.renderer,fresh=try b.makeRenderer(),encoder=JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(b.renderer.screen.composition.paragraphs.count==rows.count)
        for i in after.entries.indices {
            let old=a.renderer.screen.composition.paragraphs[i],new=b.renderer.screen.composition.paragraphs[i]
            #expect(try encoder.encode(old.input)==encoder.encode(new.input))
            let x=try SliceParagraph(old.input),y=try SliceParagraph(new.input)
            #expect(try x.render(x.input.evaluate(Time(0))).dataProvider!.data! as Data == y.render(y.input.evaluate(Time(0))).dataProvider!.data! as Data)
            let onset=after.entries[i].time,end=after.entries[i].intervalEnd!
            #expect(!renderer.screen.composition.evaluate(onset-Time(1,1_000_000)).paragraphs[i].active)
            #expect(renderer.screen.composition.evaluate(onset).paragraphs[i].active)
            #expect(!renderer.screen.composition.evaluate(end).paragraphs[i].active)
            #expect(renderer.screen.evaluate(onset+Time(1,2)).lyrics.focus==i)
        }
        let times=[Time(2),Time(379,100),Time(71,10),after.entries[2].time-p.focusLead-Time(1,1_000_000),
                   after.entries[2].time-p.focusLead,Time(18)]
        let states=times.map(renderer.screen.evaluate)
        let images=try states.map { try renderer.native($0).dataProvider!.data! as Data }
        for i in [5,0,4,2,1,3,0] {
            #expect(renderer.screen.evaluate(times[i])==states[i])
            #expect(try renderer.native(states[i]).dataProvider!.data! as Data == images[i])
            #expect(try fresh.native(states[i]).dataProvider!.data! as Data == images[i])
            let old=a.renderer.screen.evaluate(times[i])
            #expect(old.components.filter { $0.part != .lyrics && $0.part != .background } == states[i].components.filter { $0.part != .lyrics && $0.part != .background })
            let oldImage=try a.renderer.native(old),data=oldImage.dataProvider!.data! as Data
            #expect(data.prefix(oldImage.bytesPerRow*400)==images[i].prefix(oldImage.bytesPerRow*400))
        }
    }
}
