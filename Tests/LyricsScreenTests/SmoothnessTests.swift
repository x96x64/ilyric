import Testing
import Foundation
import CoreGraphics
import TimelineCore
import LyricsScreenCore
import LyricsScreenMac

struct SmoothnessTests {
    /// A one-row white image drawn at a fractional row splits its coverage between two rows.
    @Test func subpixelDrawingInterpolatesRows() {
        let src=CGContext(data:nil,width:4,height:1,bitsPerComponent:8,bytesPerRow:16,space:CGColorSpace(name:CGColorSpace.sRGB)!,
                          bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        src.setFillColor(CGColor(gray:1,alpha:1));src.fill(CGRect(x:0,y:0,width:4,height:1))
        let image=src.makeImage()!
        func alphas(_ y:Double) -> [Int] {
            let c=CGContext(data:nil,width:4,height:8,bitsPerComponent:8,bytesPerRow:16,space:CGColorSpace(name:CGColorSpace.sRGB)!,
                            bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.drawSubpixel(image,in:CGRect(x:0,y:y,width:4,height:1))
            let bytes=[UInt8](Data(bytes:c.data!,count:4*8*4))
            return (0..<8).map { Int(bytes[$0*16+3]) }   // memory rows run top to bottom
        }
        let whole=alphas(3),quarter=alphas(3.25)
        #expect(whole.filter { $0>0 }.count==1)
        // Row 3 (from the bottom) keeps 75% and row 4 receives 25%.
        #expect(abs(quarter[8-1-3]-191)<=2 && abs(quarter[8-1-4]-64)<=2)
    }
    @Test func controlsSlideAndFadeWhileHiding() throws {
        let base=try LyricsScreen.synthetic()
        let screen=try LyricsScreen(composition:base.composition,title:base.title,artist:base.artist,duration:base.duration,volume:0.5,
            events:[.init(Time(0),order:0,controls:.init()),.init(Time(4),order:1,controls:.init(lower:false))],expandsLyrics:true)
        func part(_ s:ScreenSnapshot,_ id:ScreenPart) -> ScreenComponent { s.components.first{$0.part==id}! }
        let before=screen.evaluate(Time(399,100)),mid=screen.evaluate(Time(4)+Time(1,20)),after=screen.evaluate(Time(5))
        #expect(before.lowerOpacity==1 && before.lyricsReveal==0 && part(before,.progress).visible)
        #expect(part(mid,.progress).visible && mid.lowerOpacity<0.5 && mid.lowerOffset>100 && mid.lyricsReveal>0.5)
        #expect(!part(after,.progress).visible && after.lyricsReveal==1)
        #expect(ControlTransition.sample(0)==(0,1) && ControlTransition.sample(10).opacity==0)
        // The elapsed label rounds to the nearest second.
        #expect(screen.evaluate(Time(3,2)).elapsed==2 && screen.evaluate(Time(7,5)).elapsed==1)
    }
    @Test func timeLabelsDoNotMoveAsDigitsChange() throws {
        let base=try LyricsScreen.synthetic()
        let screen=try LyricsScreen(composition:base.composition,title:base.title,artist:base.artist,duration:Time(180),volume:0.5,
            events:[.init(Time(0),order:0,controls:.init())])
        let r=try ScreenRenderer(screen,diagnosticMarkers:false)
        func edges(_ t:Time) throws -> (Int,Int) {
            let image=try r.native(screen.evaluate(t)),bytes=[UInt8](image.dataProvider!.data! as Data),w=image.width
            func leftmost(_ x0:Int,_ x1:Int) -> Int {
                for x in x0..<x1 { for y in 1735..<1775 where Int(bytes[(y*w+x)*4])>140 { return x } }
                return -1
            }
            return (leftmost(90,300),leftmost(860,1090))
        }
        let samples=try (1...6).map { try edges(Time(Int64($0))) }
        #expect(samples.allSatisfy { $0.0>0 && $0.1>0 })
        #expect(Set(samples.map(\.0)).count==1 && Set(samples.map(\.1)).count==1)
    }
    @Test func secondaryLineDrawsOnlyUnderTheFocusedParagraph() throws {
        let screen=try LyricsScreen.synthetic()
        let plain=try ScreenRenderer(screen,diagnosticMarkers:false),backed=try ScreenRenderer(screen,diagnosticMarkers:false)
        backed.secondary[2]=try SecondaryLine(text:"original backing phrase",begin:Time(3),end:Time(5))
        func data(_ r:ScreenRenderer,_ t:Time) throws -> Data { try r.native(screen.evaluate(t)).dataProvider!.data! as Data }
        // Paragraph 2 holds focus from 3 s; before that the secondary line is invisible.
        #expect(try data(backed,Time(2)) == data(plain,Time(2)))
        #expect(try data(backed,Time(4)) != data(plain,Time(4)))
        #expect(throws:ScreenError.self) { try SecondaryLine(text:"",begin:Time(0),end:Time(1)) }
        #expect(try SecondaryLine(text:"a",begin:Time(1),end:Time(3)).progress(at:Time(2))==0.5)
    }
    @Test func gpuDownscaleMatchesCoreGraphicsClosely() throws {
        let screen=try LyricsScreen.synthetic(),cpu=try ScreenRenderer(screen,diagnosticMarkers:false),gpu=try ScreenRenderer(screen,diagnosticMarkers:false)
        gpu.enableGPUScaling()
        guard gpu.usesGPUScaling else { return }   // No Metal device: the CPU path is used.
        func frame(_ r:ScreenRenderer) throws -> [UInt8] {
            let c=CGContext(data:nil,width:1080,height:1920,bitsPerComponent:8,bytesPerRow:1080*4,space:CGColorSpace(name:CGColorSpace.itur_709)!,
                            bitmapInfo:CGBitmapInfo.byteOrder32Little.rawValue|CGImageAlphaInfo.premultipliedFirst.rawValue)!
            try r.draw(Time(3,2),into:c);return [UInt8](Data(bytes:c.data!,count:1080*1920*4))
        }
        let a=try frame(cpu),b=try frame(gpu)
        let diffs=zip(a,b).map { abs(Int($0)-Int($1)) }
        let mean=Double(diffs.reduce(0,+))/Double(diffs.count)
        #expect(mean<1.0 && diffs.max()!<=64)
        #expect(try frame(gpu)==b)
    }
}
