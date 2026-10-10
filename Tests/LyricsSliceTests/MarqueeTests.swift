import Testing
import Foundation
import CoreGraphics
import SpikeCore
import LyricsSliceCore
import LyricsSliceMac

struct MarqueeTests {
    let m=TitleMarquee.measured
    @Test func easingMatchesFittedCurve() {
        #expect(m.ease(0)==0 && m.ease(1)==1 && m.ease(-1)==0 && m.ease(2)==1)
        // Reference values from an independent dense evaluation of cubic-bezier(0.296, 0.340, 0.567, 1.0).
        #expect(abs(m.ease(0.25)-0.344026)<1e-5 && abs(m.ease(0.5)-0.692206)<1e-5 && abs(m.ease(0.75)-0.923682)<1e-5)
        let samples=(0...200).map { m.ease(Double($0)/200) }
        #expect(zip(samples,samples.dropFirst()).allSatisfy { $0<$1 })
    }
    @Test func scrollingCycleIsPeriodicAndRandomAccess() {
        let width=804.0,distance=width+m.gap,duration=distance/m.speed,period=duration+m.pause
        #expect(m.offset(at:0,origin:352,inkWidth:width)==0 && m.offset(at:m.delay,origin:352,inkWidth:width)==0)
        // Displacements observed by direct frame matching in the reference capture: 254 and 442 pixels.
        #expect(abs(m.offset(at:9.91,origin:352,inkWidth:width)-254)<3)
        #expect(abs(m.offset(at:11.11,origin:352,inkWidth:width)-442)<3)
        #expect(m.offset(at:m.delay+duration+m.pause/2,origin:352,inkWidth:width)==0)
        for t in stride(from:m.delay+0.1,to:m.delay+period,by:0.37) {
            let a=m.offset(at:t,origin:352,inkWidth:width)
            #expect(a>=0 && a<distance && abs(a-m.offset(at:t+3*period,origin:352,inkWidth:width))<1e-6)
            #expect(a==m.offset(at:t,origin:352,inkWidth:width))
        }
    }
    @Test func fittingLabelsAndEdgesStayStatic() throws {
        #expect(!m.overflows(origin:352,inkWidth:600) && m.overflows(origin:352,inkWidth:610))
        #expect(m.offset(at:12,origin:352,inkWidth:400)==0)
        #expect(m.opacity(at:311)==0 && m.opacity(at:322)==0.5 && m.opacity(at:600)==1 && m.opacity(at:966)==0.5 && m.opacity(at:977)==0)
        #expect(throws:SliceError.self) { try TitleMarquee(clipMinX:10,clipMaxX:5,leadingFade:0,trailingFade:0,gap:1,speed:1,delay:0,pause:0,curve:[0,0,1,1]) }
        #expect(throws:SliceError.self) { try TitleMarquee(clipMinX:0,clipMaxX:100,leadingFade:0,trailingFade:0,gap:1,speed:0,delay:0,pause:0,curve:[0,0,1,1]) }
    }
    static func screen(title: String) throws -> LyricsScreen {
        let base=try LyricsScreen.synthetic()
        return try LyricsScreen(composition:base.composition,title:title,artist:base.artist,duration:Time(60),
                                volume:0.5,events:[.init(Time(0),order:0,controls:.init(lower:false))])
    }
    /// Maximum luma over title rows in a column range; the synthetic composition draws no lyrics there.
    static func ink(_ image: CGImage,_ columns: Range<Int>) -> Int {
        let bytes=[UInt8](image.dataProvider!.data! as Data)
        var best=0
        for y in 340..<392 { for x in columns { let i=(y*image.width+x)*4; best=max(best,Int(bytes[i])+Int(bytes[i+1])+Int(bytes[i+2])) } }
        return best
    }
    @Test func rendererScrollsOnlyOverflowingTitles() throws {
        let long=try Self.screen(title:"Original Fixture Title With Many Long Words"),short=try Self.screen(title:"Paper Skies")
        let moving=try ScreenRenderer(long,diagnosticMarkers:false,marquee:.measured)
        // At rest, ink starts at the measured origin; the clip edge beyond 977 stays empty.
        let rest=try moving.native(long.evaluate(Time(0)))
        #expect(Self.ink(rest,316..<348)<Self.ink(rest,360..<400)-200 && Self.ink(rest,980..<1060)<Self.ink(rest,360..<400)-200)
        // Mid-scroll, ink enters the leading margin left of the resting origin.
        let mid=try moving.native(long.evaluate(Time(11)))
        #expect(Self.ink(mid,334..<348)>Self.ink(rest,334..<348)+200)
        // Short titles render identically with or without the marquee.
        let a=try ScreenRenderer(short,diagnosticMarkers:false,marquee:.measured).native(short.evaluate(Time(11)))
        let b=try ScreenRenderer(short,diagnosticMarkers:false).native(short.evaluate(Time(11)))
        #expect(a.dataProvider!.data! as Data == b.dataProvider!.data! as Data)
    }
}
