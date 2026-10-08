import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import SpikeCore
import LyricsInputCore
import LyricsInputMac
import LyricsSliceCore
import LyricsSliceMac

struct ProjectTests {
    let base=URL(fileURLWithPath:"/tmp/ilyric-fixture/project.json")
    func parse(_ extra:String="") throws -> ExperimentalProject {
        try ExperimentalProject.parse(Data(("{\"version\":1,\"inputs\":{\"audio\":\"source.wav\",\"lyrics\":\"lines.lrc\"}"+extra+"}").utf8),at:base)
    }
    @Test func versionsTypesAndStrictKeys() throws {
        for json in ["{\"version\":1,}","{/*comment*/\"version\":1}","{\"version\":01}","{\"version\":1}true","{\"version\":1,\"inputs\":[]}", "{}", "[]", "{\"version\":2,\"inputs\":{}}", "{\"version\":true,\"inputs\":{}}", "{\"version\":1,\"inputs\":{\"audio\":\"a\"}}"] {
            #expect(throws:InputError.self) { try ExperimentalProject.parse(Data(json.utf8),at:base) }
        }
        for extra in [",\"metadata\":{\"unknown\":false}",",\"output\":{\"future\":true}",",\"future\":1",",\"metadata\":null",",\"metadata\":{\"title\":3}",",\"visibility\":{\"progress\":1}",",\"output\":{\"delivery\":\"adapt\"}",",\"output\":{\"fps\":30}",",\"timing\":{\"durationPolicy\":\"trim\"}",",\"timing\":{\"offsetMilliseconds\":1.5}",",\"visibility\":{\"sing\":\"enabled\"}",",\"metadata\":{\"title\":\"\"}",",\"output\":{\"height\":null}"] {
            #expect(throws:InputError.self) { try parse(extra) }
        }
        for json in ["{\"version\":1,\"version\":1}","{\"version\":1,\"inputs\":{\"audio\":\"a\",\"\\u0061udio\":\"b\",\"lyrics\":\"c\"}}"] {
            #expect(throws:InputError.self) { try ExperimentalProject.parse(Data(json.utf8),at:base) }
        }
        #expect(throws:InputError.self) { try ExperimentalProject.parse(Data([255]),at:base) }
        #expect(throws:InputError.self) { try ExperimentalProject.parse(Data([0xef,0xbb,0xbf])+Data("{}".utf8),at:base) }
        #expect(throws:InputError.self) { try ExperimentalProject.parse(Data(repeating:32,count:65_537),at:base) }
        let nested="{\"version\":"+String(repeating:"[",count:17)+"1"+String(repeating:"]",count:17)+"}"
        #expect(throws:InputError.self) { try ExperimentalProject.parse(Data(nested.utf8),at:base) }
    }
    @Test func pathsUnicodeAndExactOffset() throws {
        let p=try parse(",\"metadata\":{\"title\":\"e\\u0301・青\",\"artist\":\"Original Artist\"},\"timing\":{\"offsetMilliseconds\":-25}")
        #expect(p.audio.path=="/tmp/ilyric-fixture/source.wav" && p.lyrics.path=="/tmp/ilyric-fixture/lines.lrc")
        #expect(p.title.utf8.elementsEqual("e\u{301}・青".utf8))
        #expect(try parse()==parse())
        let absolute=try ExperimentalProject.parse(Data("{\"version\":1,\"inputs\":{\"audio\":\"/tmp/source.wav\",\"lyrics\":\"../lines.lrc\"}}".utf8),at:base)
        #expect(absolute.audio.path=="/tmp/source.wav" && absolute.lyrics.path=="/tmp/lines.lrc")
        let lyrics=try LRCParser.parse(Data("[offset:125]\n[00:00.500]First\n|Second\n[00:02]Next".utf8)).applyingProjectOffset(-25)
        #expect(lyrics.entries[0].time==Time(3,5) && lyrics.offsetMilliseconds==100)
        #expect(lyrics.entries[0].text=="First\nSecond")
        #expect(throws:InputError.self) { try lyrics.applyingProjectOffset(-601) }
        #expect(throws:InputError.self) { try lyrics.applyingProjectOffset(600_001) }
    }
    @Test func visibilityIntersectionDoesNotChangeTimeline() throws {
        let original=try LyricsScreen.synthetic(),mask=ScreenVisibility(artwork:false,metadata:false,progress:false,transport:false,volume:false,bottom:false,handle:false,translation:false,sing:false)
        let hidden=try LyricsScreen(composition:original.composition,title:original.title,artist:original.artist,duration:original.duration,volume:original.volume,events:original.events,visibility:mask)
        for i in [0,119,120,239,240,299,300,359,120] {
            let a=original.evaluate(Time.frame(Int64(i))),b=hidden.evaluate(Time.frame(Int64(i)))
            #expect(a.lyrics==b.lyrics && a.progress==b.progress && a.playing==b.playing)
            #expect(a.components.map(\.bounds)==b.components.map(\.bounds))
            #expect(b.components.filter{$0.visible}.map{$0.part}==[ScreenPart.background,ScreenPart.lyrics])
        }
        for v in [ScreenVisibility(artwork:false),.init(metadata:false),.init(progress:false),.init(transport:false),.init(volume:false),.init(bottom:false)] {
            let screen=try LyricsScreen(composition:original.composition,title:original.title,artist:original.artist,duration:original.duration,volume:original.volume,events:original.events,visibility:v)
            let a=original.evaluate(Time(4)),b=screen.evaluate(Time(4))
            #expect(a.lyrics==b.lyrics)
            for i in a.components.indices { #expect(b.components[i].visible == (a.components[i].visible && v.permits(a.components[i].part))) }
        }
        let renderer=try ScreenRenderer(original),other=try ScreenRenderer(hidden)
        #expect(try renderer.lyricLayer(original.evaluate(Time(3,2)).lyrics).dataProvider!.data! as Data==other.lyricLayer(hidden.evaluate(Time(3,2)).lyrics).dataProvider!.data! as Data)
    }
    func png(_ url:URL) throws {
        let c=CGContext(data:nil,width:48,height:32,bitsPerComponent:8,bytesPerRow:192,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(CGColor(srgbRed:0.8,green:0.2,blue:0.4,alpha:1));c.fill(CGRect(x:0,y:0,width:48,height:32))
        let writer=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(writer,c.makeImage()!,nil);#expect(CGImageDestinationFinalize(writer))
    }
    @Test func artworkValidationAndProjectLoading() async throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:dir)}
        let wav=try AudioSceneTests().wav();defer{try? FileManager.default.removeItem(at:wav)}
        try FileManager.default.copyItem(at:wav,to:dir.appendingPathComponent("source.wav"))
        let art=dir.appendingPathComponent("art.png");try png(art)
        let decoded=try LocalArtwork.decode(art)
        #expect(decoded.info.width==48 && decoded.info.height==32 && decoded.image.colorSpace?.name==CGColorSpace.sRGB)
        let lrc="[offset:125]\n[00:00.250]AV office: e\u{301}.\n|Room to revise.\n[00:01]\n[00:01.5]青い点を置く\n|次のページへ\n[00:02]A final hold."
        try Data(lrc.utf8).write(to:dir.appendingPathComponent("lines.lrc"))
        let url=dir.appendingPathComponent("project.json")
        try Data("{\"version\":1,\"inputs\":{\"audio\":\"source.wav\",\"lyrics\":\"lines.lrc\",\"artwork\":\"art.png\"},\"metadata\":{\"title\":\"e\\u0301・青\",\"artist\":\"Original\"},\"timing\":{\"offsetMilliseconds\":25},\"visibility\":{\"volume\":false,\"translation\":true,\"sing\":\"compact\"}}".utf8).write(to:url)
        let a=try await PreparedProject.load(url),b=try await PreparedProject.load(url)
        #expect(a.project==b.project && a.scene.schedule.frames==180 && a.scene.lyrics.entries[0].time==Time(2,5))
        let times=[Time(0),Time(2,5),Time(5,4),Time(7,4),Time(29,10)]
        let states=times.map(a.scene.renderer.screen.evaluate),raw=try times.map { try a.scene.renderer.frame($0).dataProvider!.data! as Data }
        for i in [4,1,0,3,2,1] {
            #expect(b.scene.renderer.screen.evaluate(times[i])==states[i])
            #expect(try b.scene.renderer.frame(times[i]).dataProvider!.data! as Data==raw[i])
        }
        #expect(states[0].components.first{$0.part == .volume}!.visible==false)
        #expect(states[0].components.first{$0.part == .translation}!.visible)
        let plain=try LocalScene(lyrics:a.scene.lyrics,audio:a.scene.audio)
        let defaults=try LocalScene(lyrics:a.scene.lyrics,audio:a.scene.audio,project:parse())
        #expect(defaults.renderer.screen.evaluate(times[2])==plain.renderer.screen.evaluate(times[2]))
        #expect(try defaults.renderer.frame(times[2]).dataProvider!.data! as Data==plain.renderer.frame(times[2]).dataProvider!.data! as Data)
        #expect(try plain.renderer.lyricLayer(states[2].lyrics).dataProvider!.data! as Data==a.scene.renderer.lyricLayer(states[2].lyrics).dataProvider!.data! as Data)
        try Data("bad image".utf8).write(to:art)
        #expect(throws:InputError.self) { try LocalArtwork.decode(art) }
        await #expect(throws:InputError.self) { try await PreparedProject.load(url) }
        #expect(throws:InputError.self) { try LocalFile.boundedData(dir,limit:100,label:"Fixture") }
    }
    @Test func artworkResourceAndOrientationBounds() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:dir)}
        let url=dir.appendingPathComponent("oriented.jpg")
        let c=CGContext(data:nil,width:48,height:32,bitsPerComponent:8,bytesPerRow:192,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(CGColor(gray:0.5,alpha:1));c.fill(CGRect(x:0,y:0,width:48,height:32))
        let writer=CGImageDestinationCreateWithURL(url as CFURL,UTType.jpeg.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(writer,c.makeImage()!,[kCGImagePropertyOrientation:6] as CFDictionary)
        #expect(CGImageDestinationFinalize(writer))
        let link=dir.appendingPathComponent("link.jpg")
        try FileManager.default.createSymbolicLink(at:link,withDestinationURL:url)
        #expect(throws:InputError.self) { try LocalArtwork.decode(link) }
        let artwork=try LocalArtwork.decode(url)
        #expect(artwork.info.width==48 && artwork.info.height==32)
        #expect(artwork.image.width==32 && artwork.image.height==48)
        let large=dir.appendingPathComponent("large.png"),wide=CGContext(data:nil,width:4097,height:1,bitsPerComponent:8,bytesPerRow:4097*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        let output=CGImageDestinationCreateWithURL(large as CFURL,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(output,wide.makeImage()!,nil);#expect(CGImageDestinationFinalize(output))
        #expect(throws:InputError.self) { try LocalArtwork.decode(large) }
        let huge=dir.appendingPathComponent("huge.bin")
        try Data(repeating:0,count:16*1024*1024+1).write(to:huge)
        #expect(throws:InputError.self) { try LocalArtwork.decode(huge) }
        let animated=dir.appendingPathComponent("multiple.gif"),gif=CGImageDestinationCreateWithURL(animated as CFURL,UTType.gif.identifier as CFString,2,nil)!
        CGImageDestinationAddImage(gif,c.makeImage()!,nil);CGImageDestinationAddImage(gif,c.makeImage()!,nil);#expect(CGImageDestinationFinalize(gif))
        #expect(throws:InputError.self) { try LocalArtwork.decode(animated) }
    }
}
