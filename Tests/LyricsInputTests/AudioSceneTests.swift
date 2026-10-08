import Testing
import Foundation
import SpikeCore
import LyricsInputCore
import LyricsInputMac
import LyricsSliceCore
import LyricsSliceMac

struct AudioSceneTests {
    /// Independently generated RIFF PCM, avoiding a binary fixture in public history.
    func wav(rate: Int=44_100, channels: Int=2) throws -> URL {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".wav")
        var pcm=Data()
        func append<T:FixedWidthInteger>(_ n:T,to data:inout Data) { var little=n.littleEndian;withUnsafeBytes(of:&little){data.append(contentsOf:$0)} }
        for i in 0..<rate*3 {
            let sample=Int16(sin(2*Double.pi*330*Double(i)/Double(rate))*8000)
            for _ in 0..<channels { append(sample,to:&pcm) }
        }
        var data=Data("RIFF".utf8);append(UInt32(36+pcm.count),to:&data);data.append(Data("WAVEfmt ".utf8))
        append(UInt32(16),to:&data);append(UInt16(1),to:&data);append(UInt16(channels),to:&data)
        append(UInt32(rate),to:&data);append(UInt32(rate*channels*2),to:&data);append(UInt16(channels*2),to:&data);append(UInt16(16),to:&data)
        data.append(Data("data".utf8));append(UInt32(pcm.count),to:&data);data.append(pcm);try data.write(to:url);return url
    }
    @Test func decodeAndRandomScene() async throws {
        let url=try wav();defer{try? FileManager.default.removeItem(at:url)}
        let audio=try await LocalAudio.decode(url)
        #expect(try await LocalAudio.decode(url).samples==audio.samples)
        #expect(audio.sourceRate==44_100 && audio.sourceChannels==2 && audio.sampleCount==144_000)
        #expect(audio.samples.contains{$0>5000} && audio.sample(144_000)==0)
        let input=try LRCParser.parse(Data("[offset:125]\n[00:00.125]AV office: e\u{301}.\n|Room to revise.\n[00:01]\n[00:01.5]青い点を置く\n[00:02]A final hold.".utf8))
        let scene=try LocalScene(lyrics:input,audio:audio),fresh=try LocalScene(lyrics:input,audio:audio)
        let times=[Time(0),Time(1,4),Time(9,8),Time(13,8),Time(19,8),Time(2999,1000)]
        let states=times.map(scene.renderer.screen.evaluate)
        #expect(states[0].lyrics.focus == -1 && states[1].lyrics.focus==0 && states[2].lyrics.focus == -1)
        #expect(states[3].lyrics.focus==1 && states.last!.lyrics.focus==2)
        #expect(states.map{ $0.components.map(\.visible) }.allSatisfy{$0==states[0].components.map(\.visible)})
        let raw=try times.map{try scene.renderer.frame($0).dataProvider!.data! as Data}
        for i in [5,2,0,4,1,3,2] {
            #expect(scene.renderer.screen.evaluate(times[i])==states[i])
            #expect(try fresh.renderer.frame(times[i]).dataProvider!.data! as Data==raw[i])
        }
        let noMarkers=try ScreenRenderer(scene.renderer.screen,calibratedInactive:true,diagnosticMarkers:false,boundedCache:true)
        #expect(try noMarkers.frame(Time(0)).dataProvider!.data! as Data==raw[0])
        let marked=try ScreenRenderer(scene.renderer.screen,calibratedInactive:true,diagnosticMarkers:true,boundedCache:true)
        #expect(try marked.frame(Time(0)).dataProvider!.data! as Data != raw[0])
        #expect(scene.renderer.lyrics.paragraphs[0].lines[0].breakKind=="supplied-explicit")
    }
    @Test func boundedCacheEvictionAndFullSchedule() async throws {
        let url=try wav(rate:48_000,channels:1);defer{try? FileManager.default.removeItem(at:url)}
        let audio=try await LocalAudio.decode(url)
        let text=(0..<10).map { String(format:"[00:%02d.%03d]Draft %d: AV office.",$0*280/1000,$0*280%1000,$0) }.joined(separator:"\n")
        let input=try LRCParser.parse(Data(text.utf8)),scene=try LocalScene(lyrics:input,audio:audio)
        let times=[Time(0),Time(28,100),Time(14,10),Time(252,100),Time(29,10)]
        let states=times.map(scene.renderer.screen.evaluate)
        #expect(states.last!.lyrics.focus==9)
        let raw=try times.map { try scene.renderer.frame($0).dataProvider!.data! as Data }
        for i in [4,0,3,1,2,4,0] { #expect(try scene.renderer.frame(times[i]).dataProvider!.data! as Data==raw[i]) }
        let unbounded=try ScreenRenderer(scene.renderer.screen,calibratedInactive:true,diagnosticMarkers:false)
        for i in [0,3,4] { #expect(try unbounded.frame(times[i]).dataProvider!.data! as Data==raw[i]) }
    }
    @Test func monoAndInvalidAudio() async throws {
        let url=try wav(rate:48_000,channels:1);defer{try? FileManager.default.removeItem(at:url)}
        #expect(try await LocalAudio.decode(url).sampleCount==144_000)
        let bad=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".wav")
        defer{try? FileManager.default.removeItem(at:bad)}
        try Data("not audio".utf8).write(to:bad)
        await #expect(throws:InputError.self) { try await LocalAudio.decode(bad) }
        let surround=try wav(rate:48_000,channels:3);defer{try? FileManager.default.removeItem(at:surround)}
        await #expect(throws:InputError.self) { try await LocalAudio.decode(surround) }
    }
}
