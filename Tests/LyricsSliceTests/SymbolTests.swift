import Testing
import Foundation
import CoreGraphics
import SpikeCore
import LyricsSliceCore
import LyricsSliceMac

// Symbol pixels are compared only within one run; no SF Symbols raster is stored or published.
struct SymbolTests {
    static let parts: [ScreenPart] = [.previous,.playback,.next,.volumeLow,.volumeHigh,.bottomLeft,.bottomCenter,.bottomRight,.translation,.singCompact]

    @Test func symbolTableIsCompleteAndBounded() {
        for part in Self.parts { for playing in [true,false] {
            let s=ControlSymbols.symbol(for:part,playing:playing)!
            #expect(!s.name.isEmpty && s.pointSize>0 && s.pointSize<100)
            #expect((0...1).contains(s.opacity) && (0...1).contains(s.discOpacity))
            #expect((0..<1179).contains(s.centerX) && (0..<2556).contains(s.centerY))
        }}
        #expect(ControlSymbols.symbol(for:.playback,playing:true)!.name=="pause.fill")
        #expect(ControlSymbols.symbol(for:.playback,playing:false)!.name=="play.fill")
        #expect(ControlSymbols.symbol(for:.lyrics,playing:true)==nil && ControlSymbols.symbol(for:.singExpanded,playing:true)==nil)
        #expect(ControlSymbols.symbol(for:.bottomLeft,playing:true)!.knockout)
    }
    @Test func originalIconsRemainDefault() throws {
        let s=try LyricsScreen.synthetic()
        #expect(try ScreenRenderer(s).icons == .original)
    }
    @Test func runtimeSymbolsAreDeterministicAndChangeOnlyControls() throws {
        let s=try LyricsScreen.synthetic(),time=Time(2)
        let a=[UInt8](try ScreenRenderer(s,icons:.systemSymbols).native(s.evaluate(time)).dataProvider!.data! as Data)
        let b=[UInt8](try ScreenRenderer(s,icons:.systemSymbols).native(s.evaluate(time)).dataProvider!.data! as Data)
        let o=[UInt8](try ScreenRenderer(s).native(s.evaluate(time)).dataProvider!.data! as Data)
        #expect(a==b && a != o)
        // The lyric viewport (rows 600–1450) is untouched by icon selection.
        let row=1179*4
        #expect(a[(600*row)..<(1450*row)]==o[(600*row)..<(1450*row)])
    }
}
