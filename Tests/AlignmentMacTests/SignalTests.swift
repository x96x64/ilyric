import Testing
import Foundation
@testable import AlignmentMac

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
