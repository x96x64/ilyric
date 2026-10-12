import Testing
import Foundation
import CoreGraphics
import SpikeCore
@testable import LyricsSliceCore
import LyricsSliceMac

/// Original fixtures only; no private references or stored system-symbol pixels.
struct MoreTests {
    static func screen(metadata: Bool = true) throws -> LyricsScreen {
        let base=try LyricsScreen.synthetic()
        return try LyricsScreen(composition:base.composition,
            title:"Original Fixture Title With Many Long Words",artist:base.artist,duration:Time(60),volume:0.5,
            events:[.init(Time(0),order:0,controls:.init()),
                    .init(Time(4),order:1,controls:.init(lower:false,handle:false))],
            visibility:.init(metadata:metadata),expandsLyrics:true)
    }
    static func part(_ state:ScreenSnapshot,_ id:ScreenPart) -> ScreenComponent {
        state.components.first { $0.part == id }!
    }
    static func withoutMore(_ state:ScreenSnapshot) -> ScreenSnapshot {
        var result=ScreenSnapshot(lyrics:state.lyrics,components:state.components.filter { $0.part != .more },
            progress:state.progress,volume:state.volume,elapsed:state.elapsed,remaining:state.remaining,playing:state.playing)
        result.lowerOffset=state.lowerOffset;result.lowerOpacity=state.lowerOpacity;result.lyricsReveal=state.lyricsReveal
        return result
    }
    @Test func placementAndHeaderVisibility() throws {
        let s=try Self.screen()
        for time in [Time(0),Time(239,60),Time(4),Time(243,60),Time(21,5),Time(11)] {
            let state=s.evaluate(time),more=Self.part(state,.more)
            #expect(more.visible && more.bounds == ScreenBounds(1007,378,56,12))
            #expect(more.z>Self.part(state,.title).z && more.z>Self.part(state,.artist).z)
            #expect(more.bounds.x-TitleMarquee.measured.clipMaxX == 30)
            #expect(Self.part(state,.title).bounds == ScreenBounds(352,338,650,58))
            #expect(Self.part(state,.artist).bounds == ScreenBounds(352,398,650,58))
        }
        #expect(!Self.part(s.evaluate(Time(11)),.playback).visible)
        #expect(!Self.part(s.evaluate(Time(11)),.handle).visible)
        #expect(!Self.part(try Self.screen(metadata:false).evaluate(Time(0)),.more).visible)
        let symbol=ControlSymbols.symbol(for:.more,playing:true)!
        #expect(symbol.name == "ellipsis" && symbol.pointSize == 20 && symbol.weight == .medium)
        #expect(symbol.centerX == 1035 && symbol.centerY == 384 && symbol.opacity == 1)
        #expect(symbol.disc == nil && !symbol.knockout)
        #expect(symbol == ControlSymbols.symbol(for:.more,playing:false))
    }
    @Test func originalInkAndTitleInteractionDoNotChangeOtherPixels() throws {
        let s=try Self.screen(),r=try ScreenRenderer(s,diagnosticMarkers:false,marquee:.measured)
        var buttonPixels: Data?
        for time in [Time(0),Time(243,60),Time(11),Time(20)] {
            let state=s.evaluate(time),image=try r.native(state),plain=try r.native(Self.withoutMore(state))
            let a=image.dataProvider!.data! as Data,b=plain.dataProvider!.data! as Data,row=image.bytesPerRow
            // All title, artist, artwork, lyrics, and lower-control pixels remain identical.
            for y in 0..<image.height {
                if (378..<390).contains(y) {
                    #expect(a[y*row..<y*row+1007*4] == b[y*row..<y*row+1007*4])
                    #expect(a[y*row+1063*4..<(y+1)*row] == b[y*row+1063*4..<(y+1)*row])
                } else { #expect(a[y*row..<(y+1)*row] == b[y*row..<(y+1)*row]) }
            }
            let patch=Data((378..<390).flatMap { Array(a[$0*row+1007*4..<$0*row+1063*4]) })
            if let buttonPixels { #expect(patch == buttonPixels) } else { buttonPixels=patch }
            for x in [1013,1035,1057] {
                let i=384*row+x*4
                #expect(a[i] == 255 && a[i+1] == 255 && a[i+2] == 255)
            }
            #expect(a != b)
        }
    }
    @Test func randomAccessPreservesSnapshotsAndRastersAcrossHideBoundaries() throws {
        let s=try Self.screen(),r=try ScreenRenderer(s,diagnosticMarkers:false,marquee:.measured)
        let times=[Time(0),Time(239,60),Time(4),Time(243,60),Time(21,5),Time(11)]
        let states=times.map(s.evaluate)
        let pixels=try states.map { try r.native($0).dataProvider!.data! as Data }
        let fresh=try ScreenRenderer(s,diagnosticMarkers:false,marquee:.measured)
        for i in [5,3,0,4,1,2,3,5] {
            #expect(s.evaluate(times[i]) == states[i])
            #expect(try r.native(s.evaluate(times[i])).dataProvider!.data! as Data == pixels[i])
            #expect(try fresh.native(states[i]).dataProvider!.data! as Data == pixels[i])
        }
        #expect(states[1].lowerOpacity == 1 && states[2].lowerOpacity == 1)
        #expect(states[3].lowerOpacity<0.5 && states[3].lowerOffset>100)
        #expect(!Self.part(states[4],.progress).visible && states[4].lyricsReveal == 1)
    }
}
