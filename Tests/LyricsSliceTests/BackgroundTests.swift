import Testing
import Foundation
import CoreGraphics
import SpikeCore
import LyricsSliceCore
import LyricsSliceMac

struct BackgroundTests {
    static func model() throws -> ArtworkBackground {
        try ArtworkBackground(scale:1.6,orbit:0.18,orbitRate:0.12,rotationRate:0.03,blur:160,saturation:1.2,gain:0.8,gradient:0.35)
    }
    static func screen(_ background: ArtworkBackground?, hidden: Bool = false) throws -> LyricsScreen {
        let base=try LyricsScreen.synthetic()
        let visibility=hidden ? ScreenVisibility(artwork:false,metadata:false,progress:false,transport:false,volume:false,
                                                 bottom:false,handle:false,translation:false,sing:false) : base.visibility
        return try LyricsScreen(composition:base.composition,title:base.title,artist:base.artist,duration:base.duration,
                                volume:base.volume,events:base.events,visibility:visibility,background:background)
    }
    /// Rows below the lyric viewport with every optional component hidden contain only the background.
    static func backgroundRows(_ renderer: ScreenRenderer,_ screen: LyricsScreen,_ time: Time) throws -> [UInt8] {
        let bytes=[UInt8](try renderer.native(screen.evaluate(time)).dataProvider!.data! as Data)
        return Array(bytes[(1600*1179*4)..<(2556*1179*4)])
    }

    @Test func layerEvaluationIsAnalytic() throws {
        let m=try Self.model()
        let a=m.layers(at:Time(0),width:1179,height:2556),b=m.layers(at:Time(5,2),width:1179,height:2556)
        #expect(a.count==2 && a==m.layers(at:Time(0),width:1179,height:2556))
        #expect(abs(a[0].centerX-(1179/2+0.18*2556))<1e-9 && abs(a[0].centerY-2556/2)<1e-9)
        #expect(a[0].side==1.6*2556 && a[0].angle==0)
        #expect(abs(b[0].angle-0.075)<1e-12 && abs(b[1].angle-(-0.075+2.1*1.7))<1e-12)
    }
    @Test func invalidParametersAreRejected() {
        #expect(throws:SliceError.self) { try ArtworkBackground(scale:0.1,orbit:0.1,orbitRate:0,rotationRate:0,blur:100,saturation:1,gain:1,gradient:0) }
        #expect(throws:SliceError.self) { try ArtworkBackground(scale:1.6,orbit:0.1,orbitRate:0,rotationRate:0,blur:.nan,saturation:1,gain:1,gradient:0) }
        #expect(throws:SliceError.self) { try ArtworkBackground(scale:1.6,orbit:0.1,orbitRate:0,rotationRate:0,blur:100,saturation:1,gain:1,gradient:1) }
    }
    @Test func randomAccessDeterminismAndMotion() throws {
        let s=try Self.screen(Self.model(),hidden:true),r=try ScreenRenderer(s),fresh=try ScreenRenderer(s)
        let times=[Time(0),Time(3,2),Time(5),Time(59,60)]
        let first=try times.map { try Self.backgroundRows(r,s,$0) }
        for i in [2,0,3,1,2] { #expect(try Self.backgroundRows(fresh,s,times[i])==first[i]) }
        #expect(first[0] != first[2])
        // Large blur leaves no hard artwork edges: adjacent columns differ by at most a few code values.
        let row=400*1179*4
        let maxStep=(1..<1179).map { abs(Int(first[0][row+$0*4])-Int(first[0][row+($0-1)*4])) }.max()!
        #expect(maxStep<=4)
    }
    @Test func staticBackdropRemainsDefault() throws {
        let original=try LyricsScreen.synthetic(),explicit=try Self.screen(nil)
        let a=try ScreenRenderer(original).native(original.evaluate(Time(3,2))).dataProvider!.data! as Data
        let b=try ScreenRenderer(explicit).native(explicit.evaluate(Time(3,2))).dataProvider!.data! as Data
        #expect(a==b)
        #expect(original.evaluate(Time(0)).components[0].evidence.contains("static"))
        #expect(try Self.screen(Self.model()).evaluate(Time(0)).components[0].evidence.contains("unmatched phase"))
    }
}
