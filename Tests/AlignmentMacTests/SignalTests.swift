import Testing
import Foundation
@testable import AlignmentMac
import AlignmentCore

/// Signal processing parity with Demucs, PyTorch, and SciPy (scripts/generate_separation_fixture.py).
struct SignalTests {
    struct Fixture: Decodable {
        let signal, spec_re, spec_im, ispec_re, ispec_im, ispec_out, resample_in, resample_out: String
        let frames: Int
    }
    static let f: Fixture = {
        let url=Bundle.module.url(forResource:"separation",withExtension:"json",subdirectory:"Fixtures")!
        return try! JSONDecoder().decode(Fixture.self,from:Data(contentsOf:url))
    }()
    static func doubles(_ s: String) -> [Double] { Data(base64Encoded:s)!.withUnsafeBytes { Array($0.bindMemory(to:Double.self)) } }
    /// (bins × frames) row-major from NumPy into frames × bins.
    static func byFrame(_ flat: [Double], frames: Int) -> [[Double]] { (0..<frames).map { t in (0..<2048).map { flat[$0*frames+t] } } }

    @Test func fftMatchesNaiveTransform() {
        let fft=RealFFT(log2n:4),x=(0..<16).map { sin(Double($0)*0.7)+Double($0%3) }
        let (re,im)=fft.forward(x)
        for k in 0...8 {
            let r=(0..<16).reduce(0.0) { $0+x[$1]*cos(2*Double.pi*Double(k*$1)/16) }
            let i=(0..<16).reduce(0.0) { $0-x[$1]*sin(2*Double.pi*Double(k*$1)/16) }
            #expect(abs(re[k]-r)<1e-9 && abs(im[k]-i)<1e-9)
        }
        let back=fft.inverse(re:re,im:im)
        #expect(zip(back,x).allSatisfy { abs($0-$1)<1e-12 })
    }
    @Test func spectrogramMatchesDemucs() {
        let (re,im)=DemucsSpectrogram().spec(Self.doubles(Self.f.signal))
        let er=Self.byFrame(Self.doubles(Self.f.spec_re),frames:Self.f.frames),ei=Self.byFrame(Self.doubles(Self.f.spec_im),frames:Self.f.frames)
        #expect(re.count==Self.f.frames)
        var worst=0.0
        for t in 0..<Self.f.frames { for k in 0..<2048 { worst=max(worst,abs(re[t][k]-er[t][k]),abs(im[t][k]-ei[t][k])) } }
        // PyTorch's and vDSP's FFTs differ only in rounding.
        #expect(worst<1e-6)
    }
    @Test func inverseSpectrogramMatchesDemucs() {
        let re=Self.byFrame(Self.doubles(Self.f.ispec_re),frames:Self.f.frames),im=Self.byFrame(Self.doubles(Self.f.ispec_im),frames:Self.f.frames)
        let y=DemucsSpectrogram().ispec(re:re,im:im,length:5000),expected=Self.doubles(Self.f.ispec_out)
        #expect(y.count==5000 && zip(y,expected).allSatisfy { abs($0-$1)<1e-6 })
        // No identity check: HTDemucs drops two frames at each end and the Nyquist bin by design.
    }
    @Test func polyphaseResamplingMatchesSciPy() {
        let y=resamplePoly(Self.doubles(Self.f.resample_in),up:160,down:441),expected=Self.doubles(Self.f.resample_out)
        #expect(y.count==expected.count && zip(y,expected).allSatisfy { abs($0-$1)<1e-12 })
    }
}

/// Native checkpoint reading and weight derivation (scripts/generate_checkpoint_fixture.py).
struct CheckpointTests {
    struct Expected: Decodable { let shape: [Int]; let values: [Float] }
    @Test func readsHalfAndFloatTensorsIncludingNonContiguousViews() throws {
        let dir=Bundle.module.url(forResource:"Fixtures",withExtension:nil)!
        let tensors=try TorchCheckpoint(Data(contentsOf:dir.appendingPathComponent("checkpoint.th"))).tensors
        let expected=try JSONDecoder().decode([String:Expected].self,from:Data(contentsOf:dir.appendingPathComponent("checkpoint.json")))
        #expect(Set(tensors.keys)==Set(expected.keys))
        for (k,e) in expected { #expect(tensors[k]?.shape==e.shape && tensors[k]?.values==e.values) }
    }
    @Test func derivesRowsPermutationsAndFrequencyEmbedding() throws {
        let t=TorchCheckpoint.Tensor(shape:[3,2],values:[1,2,3,4,5,6])
        func entry(_ kind:String,start:Int?=nil,end:Int?=nil,axes:[Int]?=nil,bins:Int?=nil,frames:Int?=nil,scale:Double?=nil,outer:Double?=nil) throws -> SeparationInstaller.Recipe.Entry {
            var d:[String:Any]=["offset":0,"size":0,"kind":kind,"key":"x"]
            if let start { d["start"]=start };if let end { d["end"]=end };if let axes { d["axes"]=axes }
            if let bins { d["bins"]=bins };if let frames { d["frames"]=frames };if let scale { d["scale"]=scale };if let outer { d["outer_scale"]=outer }
            return try JSONDecoder().decode(SeparationInstaller.Recipe.Entry.self,from:JSONSerialization.data(withJSONObject:d))
        }
        #expect(try SeparationInstaller.derive(entry("rows",start:1,end:3),t)==[3,4,5,6])
        #expect(try SeparationInstaller.derive(entry("permute",axes:[1,0]),t)==[1,3,5,2,4,6])
        // Embedding rows are bins, columns channels; the output is channels × bins × frames.
        #expect(try SeparationInstaller.derive(entry("frequency_embedding",bins:2,frames:2,scale:10,outer:0.5),t)==[5,5,15,15,10,10,20,20])
        #expect(throws:AlignmentError.self) { try SeparationInstaller.derive(entry("unknown"),t) }
    }
}

struct ModelStoreTests {
    @Test func downloadsVerifiesAndReuses() async throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("ilyric-store-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at:dir) }
        let source=Bundle.module.url(forResource:"Fixtures",withExtension:nil)!.appendingPathComponent("checkpoint.json")
        let hash=try ModelStore.digest(source)
        let first=try await ModelStore.fetch(source,sha256:hash,into:dir,name:"a.json")
        #expect(try Data(contentsOf:first)==Data(contentsOf:source))
        // A corrupted cached copy is replaced; a wrong pin is refused and nothing is kept.
        try Data("x".utf8).write(to:first)
        #expect(try Data(contentsOf:try await ModelStore.fetch(source,sha256:hash,into:dir,name:"a.json"))==Data(contentsOf:source))
        await #expect(throws:AlignmentError.self) { _=try await ModelStore.fetch(source,sha256:String(repeating:"0",count:64),into:dir,name:"b.json") }
        #expect(!FileManager.default.fileExists(atPath:dir.appendingPathComponent("b.json").path))
    }
    @Test func installedModelsRequireMatchingManifest() throws {
        let fm=FileManager.default,root=fm.temporaryDirectory.appendingPathComponent("ilyric-models-\(UUID().uuidString)")
        defer { try? fm.removeItem(at:root) }
        let templates=root.appendingPathComponent("templates"),cache=root.appendingPathComponent("cache")
        try fm.createDirectory(at:templates,withIntermediateDirectories:true)
        func recipe(_ skeleton: String) -> Data { Data("{\"checkpoint\":{\"file\":\"f\",\"sha256\":\"0\",\"url\":\"u\"},\"weights\":{\"skeleton_sha256\":\"\(skeleton)\"}}".utf8) }
        try recipe("a").write(to:templates.appendingPathComponent("weight-recipe.json"))
        try recipe("b").write(to:templates.appendingPathComponent("wav2vec2-recipe.json"))
        #expect(try InstalledModels.existing(in:cache,templates:templates)==nil)
        let models=InstalledModels(cache)
        for url in [models.separator,models.recognizer] { try fm.createDirectory(at:url,withIntermediateDirectories:true) }
        try Data("{}".utf8).write(to:models.vocabulary)
        try JSONEncoder().encode(try InstalledModels.manifest(templates)).write(to:cache.appendingPathComponent("installed.json"))
        #expect(try InstalledModels.existing(in:cache,templates:templates)==models)
        // Models built from other templates are not reused.
        try recipe("c").write(to:templates.appendingPathComponent("wav2vec2-recipe.json"))
        #expect(try InstalledModels.existing(in:cache,templates:templates)==nil)
        try InstalledModels.remove(from:cache)
        #expect(try fm.contentsOfDirectory(atPath:cache.path).isEmpty)
    }
}
