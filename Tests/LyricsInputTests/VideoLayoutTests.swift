import Foundation
import CoreGraphics
import Testing
import TimelineCore
import LyricsInputCore
import LyricsInputMac
import LyricsScreenCore
import LyricsScreenMac

/// Original generated identifiers and silent PCM; no private text, media, or symbol assets.
private enum VideoFixture {
    static let word = String((0..<5).map { Character(UnicodeScalar(65 + $0 % 26)!) })
    static func scene(_ canvas: LyricsCanvas, background: ArtworkBackground? = nil) throws -> LocalScene {
        let rows = (0..<4).map { i in
            let main = Array(repeating: word, count: 3).joined(separator: " ") + (i == 1 ? "<br/>" + word : "")
            let timing = i == 2 ? " begin=\"1s\" dur=\"1s\"" : ""
            return
                "<p begin=\"\(6+i*3)s\" end=\"\(8+i*3)s\"><span begin=\"0s\" end=\"2s\">\(main)</span><span ttm:role=\"x-bg\"\(timing)>\(word.lowercased())</span></p>"
        }.joined()
        let xml =
            "<tt xmlns=\"http://www.w3.org/ns/ttml\" xmlns:ttm=\"http://www.w3.org/ns/ttml#metadata\" xml:space=\"preserve\"><body><div>\(rows)</div></body></tt>"
        let audio = LocalAudio(
            samples: Array(repeating: 0, count: 18 * 48_000), sourceRate: 48_000, sourceChannels: 1, sourceFormat: 0)
        var p = LocalPresentation(
            background: background, icons: .original, minimumGap: Time(4),
            focusLead: LocalPresentation.measuredMotion.focusLead, stagger: .measured, marquee: .measured,
            wordMotion: .measured, fillLead: LocalPresentation.measuredFillLead,
            hideControls: LocalPresentation.measuredControlHide, canvas: canvas)
        p.holdsFinishedLine = true
        p.collapsesGaps = true
        return try LocalScene(
            lyrics: TTMLParser.parse(Data(xml.utf8)), audio: audio, presentation: p,
            title: Array(repeating: word, count: 3).joined(separator: " "), artist: "Synthetic")
    }
    static func frame(_ renderer: ScreenRenderer, _ time: Time) throws -> Data {
        let c = CGContext(
            data: nil, width: 1080, height: 1920, bitsPerComponent: 8, bytesPerRow: 4320,
            space: CGColorSpace(name: CGColorSpace.itur_709)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
        try renderer.draw(time, into: c)
        return Data(bytes: c.data!, count: 4320 * 1920)
    }
}

struct VideoLayoutTests {
    @Test func sharedAnchorsPreserveSizesAndPlaceAllControlsInsideCanvas() throws {
        let base = try LyricsScreen.synthetic()
        let canvas = LyricsCanvas.video
        let fit = LyricsScreen.contain(
            width: 1080, height: 1920, canvasWidth: canvas.width, canvasHeight: canvas.height)
        #expect(fit == ScreenBounds(0, 0, 1080, 1920))
        for time in [Time(0), Time(2), Time(4)] {
            for component in base.evaluate(time).components {
                let b = canvas.bounds(component.bounds, for: component.part)
                let shift = canvas.offset(for: component.part)
                #expect(b.x == component.bounds.x + shift.x && b.y == component.bounds.y + shift.y)
                if component.part != .background && component.part != .lyrics {
                    #expect(b.x >= 0 && b.y >= 0 && b.x + b.width <= 1440 && b.y + b.height <= 2560)
                    #expect(b.height == component.bounds.height)
                }
                for playing in [false, true] {
                    if let native = ControlSymbols.symbol(for: component.part, playing: playing),
                        let adapted = ControlSymbols.symbol(for: component.part, playing: playing, canvas: canvas)
                    {
                        #expect(
                            adapted.centerX == native.centerX + shift.x && adapted.centerY == native.centerY + shift.y)
                        #expect(
                            adapted.name == native.name && adapted.pointSize == native.pointSize
                                && adapted.weight == native.weight)
                        #expect(
                            adapted.disc == native.disc && adapted.opacity == native.opacity
                                && adapted.discOpacity == native.discOpacity)
                        let radius = (adapted.disc ?? 0) / 2
                        #expect(adapted.centerX - radius >= 0 && adapted.centerX + radius <= 1440)
                        #expect(adapted.centerY - radius >= 0 && adapted.centerY + radius <= 2560)
                    }
                }
            }
        }
        #expect(canvas.viewport == ScreenBounds(72, 550, 1301, 954))
        #expect(canvas.expandedViewport == ScreenBounds(72, 550, 1301, 2010))
        #expect(canvas.bounds(.init(1007, 378, 56, 12), for: .more) == ScreenBounds(1268, 378, 56, 12))
        #expect(canvas.bounds(.init(500, 198, 180, 12), for: .handle) == ScreenBounds(630.5, 198, 180, 12))
    }

    @Test func reflowPreservesEverySourceRangeExplicitBreakAndTimingEvent() throws {
        let native = try VideoFixture.scene(.native)
        let video = try VideoFixture.scene(.video)
        #expect(native.lyrics.entries == video.lyrics.entries)
        #expect(native.schedule.frames == video.schedule.frames && native.schedule.audioEnd == video.schedule.audioEnd)
        let a = native.renderer.screen.composition
        let b = video.renderer.screen.composition
        #expect(a.paragraphs.count == 4 && b.paragraphs.count == 4 && b.canvasWidth == 1440)
        #expect(a.events.count == b.events.count)
        for (x, y) in zip(a.events, b.events) {
            #expect(x.time == y.time && x.order == y.order && x.paragraph == y.paragraph && x.gap == y.gap)
        }
        var fewerRows = false
        for i in a.paragraphs.indices {
            let x = a.paragraphs[i]
            let y = b.paragraphs[i]
            let layout = video.renderer.lyrics.paragraphs[i]
            #expect(
                x.begin == y.begin && x.end == y.end && x.input.text == y.input.text && x.input.events == y.input.events
            )
            #expect(y.input.parameters.width == 1248 && y.input.parameters.size == x.input.parameters.size)
            #expect(
                layout.lines.first!.start == 0
                    && layout.lines.last!.start + layout.lines.last!.length == y.input.text.utf16.count)
            #expect(zip(layout.lines, layout.lines.dropFirst()).allSatisfy { $0.start + $0.length == $1.start })
            #expect(layout.lines.filter { $0.breakKind == "supplied-explicit" }.count == (i == 1 ? 1 : 0))
            #expect(layout.lines.allSatisfy { $0.width <= 1248 })
            fewerRows = fewerRows || layout.lines.count < native.renderer.lyrics.paragraphs[i].lines.count
        }
        #expect(fewerRows)
        for time in [
            Time(0), Time(5_099_999, 1_000_000), Time(51, 10), Time(6), Time(778, 100), Time(8), Time(9), Time(15),
        ] {
            let x = a.evaluate(time)
            let y = b.evaluate(time)
            #expect(x.media == y.media && x.focus == y.focus)
            #expect(x.paragraphs.map(\.appearance) == y.paragraphs.map(\.appearance))
        }
        let m = video.renderer.marquee!
        let n = native.renderer.marquee!
        #expect(m.clipMinX == n.clipMinX && m.clipMaxX == 1238 && m.gap == n.gap && m.speed == n.speed)
        #expect(m.delay == n.delay && m.pause == n.pause && m.curve == n.curve)
        #expect(n.overflows(origin: 352, inkWidth: 700) && !m.overflows(origin: 352, inkWidth: 700))
        for time in [Time(3_789_999, 1_000_000), Time(379, 100), Time(3_790_001, 1_000_000), Time(399, 100)] {
            let x = native.renderer.screen.evaluate(time)
            let y = video.renderer.screen.evaluate(time)
            #expect(
                x.lowerOffset == y.lowerOffset && x.lowerOpacity == y.lowerOpacity && x.lyricsReveal == y.lyricsReveal)
            #expect(x.components.map(\.visible) == y.components.map(\.visible))
        }
    }

    @Test func cpuAndGPUCoverWholeFramesAndEvaluateDeterministically() throws {
        for background in [nil, ArtworkBackground.fitted] {
            let scene = try VideoFixture.scene(.video, background: background)
            for gpu in [false, true] {
                let r = try scene.makeRenderer()
                let fresh = try scene.makeRenderer()
                if gpu {
                    r.enableGPUScaling()
                    fresh.enableGPUScaling()
                }
                let times = [
                    Time(0), Time(51, 10), Time(6), Time(3_789_999, 1_000_000), Time(379, 100),
                    Time(3_790_001, 1_000_000),
                ]
                let frames = try times.map { try VideoFixture.frame(r, $0) }
                for frame in frames {
                    let pixels = [UInt8](frame)
                    let covered = stride(from: 0, to: pixels.count, by: 4).allSatisfy { i in
                        let sum = Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])
                        return pixels[i + 3] == 255 && sum > 0
                    }
                    #expect(covered)
                }
                for i in [4, 0, 5, 2, 1, 3, 4] {
                    #expect(try VideoFixture.frame(r, times[i]) == frames[i])
                    #expect(try VideoFixture.frame(fresh, times[i]) == frames[i])
                }
            }
        }
    }

    @Test func fullFrameBackingAndOpeningGapPoliciesSurviveAdaptation() throws {
        let scene = try VideoFixture.scene(.video)
        let r = scene.renderer
        let saved = r.secondary
        #expect(r.screen.composition.evaluate(Time(0)).gaps[0].state != nil)
        #expect(r.screen.composition.evaluate(Time(51, 10)).gaps[0].state == nil)
        #expect(saved.count == 4 && saved[2]!.hasExplicitTiming)
        for time in [
            Time(0), Time(5_099_999, 1_000_000), Time(51, 10), Time(6), Time(809, 100), Time(81, 10), Time(15),
        ] {
            let state = r.screen.evaluate(time)
            let with = try r.native(state).dataProvider!.data! as Data
            r.secondary = saved.filter { $0.value.hasExplicitTiming || $0.key == state.lyrics.focus }
            #expect(try r.native(state).dataProvider!.data! as Data == with)
            r.secondary = saved
            for (i, cue) in saved where !cue.hasExplicitTiming {
                #expect(cue.progress(at: time) == 0)
                if i != state.lyrics.focus {
                    r.secondary = [:]
                    let main = try r.native(state).dataProvider!.data! as Data
                    r.secondary = [i: cue]
                    #expect(try r.native(state).dataProvider!.data! as Data == main)
                    r.secondary = saved
                }
            }
        }
        #expect(saved[2]!.progress(at: saved[2]!.begin) == 0 && saved[2]!.progress(at: saved[2]!.end) == 1)
        let native = try r.native(r.screen.evaluate(Time(6)))
        #expect(native.width == 1440 && native.height == 2560)
        #expect(r.screen.evaluate(Time(6)).components.first { $0.part == .more }!.visible)
    }

    @Test func reelsSafeAreaKeepsTheLayoutInsideTheCroppedWidth() throws {
        let canvas = LyricsCanvas.reels
        #expect(canvas.width == 1304 && canvas.height == 2560 && canvas.inset == 68 && canvas.widthExtension == 125)
        #expect(LyricsCanvas.forWidth(1304) == .reels && LyricsCanvas.video.inset == 0)
        let video = try VideoFixture.scene(.video, background: .fitted)
        let reels = try VideoFixture.scene(.reels, background: .fitted)
        let screen = reels.renderer.screen
        #expect(screen.composition.canvasWidth == 1304 && screen.frameWidth == 1440)
        #expect(video.renderer.screen.frameWidth == 1440)
        for (x, y) in zip(video.renderer.screen.composition.paragraphs, screen.composition.paragraphs) {
            #expect(x.input.text == y.input.text && x.input.events == y.input.events && x.begin == y.begin)
            #expect(y.input.parameters.width == 1112)
        }
        #expect(reels.renderer.lyrics.paragraphs.allSatisfy { $0.lines.allSatisfy { $0.width <= 1112 } })
        // Every component except the background lies within the 978 output pixels that remain after the crop.
        for time in [Time(0), Time(51, 10), Time(6)] {
            for part in screen.evaluate(time).components {
                if part.part == .background {
                    #expect(part.bounds == ScreenBounds(-68, 0, 1440, 2560))
                    continue
                }
                let left = (part.bounds.x + canvas.inset) * 0.75
                let right = (part.bounds.x + part.bounds.width + canvas.inset) * 0.75
                #expect(left >= 51 && right <= 1029)
                for playing in [false, true] {
                    if let symbol = ControlSymbols.symbol(for: part.part, playing: playing, canvas: canvas) {
                        let radius = (symbol.disc ?? 0) / 2
                        #expect((symbol.centerX - radius + canvas.inset) * 0.75 >= 51)
                        #expect((symbol.centerX + radius + canvas.inset) * 0.75 <= 1029)
                    }
                }
            }
        }
        // The background fills the frame, and the uncropped side margins show the same background as `.video`.
        let image = try reels.renderer.native(screen.evaluate(Time(6)))
        #expect(image.width == 1440 && image.height == 2560)
        let a = [UInt8](try VideoFixture.frame(video.renderer, Time(6)))
        let b = [UInt8](try VideoFixture.frame(reels.renderer, Time(6)))
        var covered = true
        var margins = true
        for y in 0..<1920 {
            for x in 0..<1080 {
                let i = y * 4320 + x * 4
                covered = covered && b[i + 3] == 255 && Int(b[i]) + Int(b[i + 1]) + Int(b[i + 2]) > 0
                if x < 40 || x >= 1040 { margins = margins && a[i..<(i + 4)] == b[i..<(i + 4)] }
            }
        }
        #expect(covered && margins)
        #expect(a != b)
    }

    @Test func projectMoreKeepsCircularInkAndNativeDefaultsRemainAvailable() throws {
        let native = try VideoFixture.scene(.native)
        let video = try VideoFixture.scene(.video)
        #expect(native.renderer.screen.composition.canvasWidth == 1179)
        #expect(try native.renderer.native(native.renderer.screen.evaluate(Time(0))).height == 2556)
        for (scene, x) in [(native, 1007), (video, 1268)] {
            let image = try scene.renderer.native(scene.renderer.screen.evaluate(Time(0)))
            let bytes = [UInt8](image.dataProvider!.data! as Data)
            for left in [x, x + 22, x + 44] {
                var xs = [Int]()
                var ys = [Int]()
                for y in 378..<390 {
                    for xx in left..<(left + 12) {
                        let i = y * image.bytesPerRow + xx * 4
                        if bytes[i] > 245 && bytes[i + 1] > 245 && bytes[i + 2] > 245 {
                            xs.append(xx)
                            ys.append(y)
                        }
                    }
                }
                let width = xs.max()! - xs.min()! + 1
                let height = ys.max()! - ys.min()! + 1
                #expect(width == height && (10...12).contains(width))
            }
        }
        var input = ParagraphInput.supplied(text: VideoFixture.word, japanese: false)
        input.rightAligned = true
        #expect(input.adapted(to: .video).rightAligned == true)
    }
}
