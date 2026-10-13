import Foundation
import Accelerate
import CoreML
import AlignmentCore

/// Unscaled real DFT of a power-of-two length through vDSP, returning bins 0...N/2.
public final class RealFFT {
    public let count: Int
    let log2n: vDSP_Length
    let setup: FFTSetupD
    public init(log2n: Int) {
        self.log2n=vDSP_Length(log2n);count=1<<log2n
        setup=vDSP_create_fftsetupD(vDSP_Length(log2n),FFTRadix(kFFTRadix2))!
    }
    deinit { vDSP_destroy_fftsetupD(setup) }
    /// X[k] = Σ x[n] e^{-2πikn/N}, k = 0...N/2.
    public func forward(_ x: [Double]) -> (re: [Double], im: [Double]) {
        let half=count/2
        var re=[Double](repeating:0,count:half),im=[Double](repeating:0,count:half)
        for k in 0..<half { re[k]=x[2*k];im[k]=x[2*k+1] }
        re.withUnsafeMutableBufferPointer { r in im.withUnsafeMutableBufferPointer { i in
            var split=DSPDoubleSplitComplex(realp:r.baseAddress!,imagp:i.baseAddress!)
            vDSP_fft_zripD(setup,&split,1,log2n,FFTDirection(kFFTDirection_Forward))
        }}
        // vDSP returns twice the DFT, with the Nyquist bin packed into the imaginary part of bin 0.
        var outRe=[Double](repeating:0,count:half+1),outIm=[Double](repeating:0,count:half+1)
        outRe[0]=re[0]/2;outRe[half]=im[0]/2
        for k in 1..<half { outRe[k]=re[k]/2;outIm[k]=im[k]/2 }
        return (outRe,outIm)
    }
    /// x[n] = (1/N) Σ X[k] e^{2πikn/N} for a Hermitian spectrum given by bins 0...N/2.
    public func inverse(re: [Double], im: [Double]) -> [Double] {
        let half=count/2
        var r=[Double](repeating:0,count:half),i=[Double](repeating:0,count:half)
        r[0]=re[0];i[0]=re[half]
        for k in 1..<half { r[k]=re[k];i[k]=im[k] }
        r.withUnsafeMutableBufferPointer { rp in i.withUnsafeMutableBufferPointer { ip in
            var split=DSPDoubleSplitComplex(realp:rp.baseAddress!,imagp:ip.baseAddress!)
            vDSP_fft_zripD(setup,&split,1,log2n,FFTDirection(kFFTDirection_Inverse))
        }}
        var x=[Double](repeating:0,count:count),scale=1/Double(2*count)
        for k in 0..<half { x[2*k]=r[k]*2*scale;x[2*k+1]=i[k]*2*scale }
        return x
    }
}

/// PyTorch reflect padding (edge sample excluded), with Demucs `pad1d` zero extension for short input.
func reflectPad(_ x: [Double], left: Int, right: Int) -> [Double] {
    var x=x,left=left,right=right
    let maxPad=max(left,right)
    if x.count<=maxPad {
        let extra=maxPad-x.count+1,extraRight=min(right,extra),extraLeft=extra-extraRight
        x=[Double](repeating:0,count:extraLeft)+x+[Double](repeating:0,count:extraRight)
        left-=extraLeft;right-=extraRight
    }
    let n=x.count
    return (0..<left).map { x[left-$0] }+x+(0..<right).map { x[n-2-$0] }
}

/// The STFT conventions of HTDemucs: 4096-point periodic Hann window, hop 1024, normalized, centered,
/// with the model's extra reflect padding so that frames align with the waveform branch.
public struct DemucsSpectrogram {
    public let nfft=4096, hop=1024
    let fft=RealFFT(log2n:12)
    let window: [Double]
    public init() { window=(0..<4096).map { 0.5-0.5*cos(2*Double.pi*Double($0)/4096) } }

    /// Bins 0..<2048 by frames 0..<ceil(L/hop) of one channel (HTDemucs `_spec`).
    public func spec(_ x: [Double]) -> (re: [[Double]], im: [[Double]]) {
        let length=x.count,le=(length+hop-1)/hop,pad=hop/2*3
        let padded=reflectPad(x,left:pad,right:pad+le*hop-length)
        let centered=reflectPad(padded,left:nfft/2,right:nfft/2)
        let scale=1/Double(nfft).squareRoot()
        var re=[[Double]](repeating:[],count:le),im=[[Double]](repeating:[],count:le)
        for t in 0..<le {
            let frame=t+2,start=frame*hop
            let windowed=(0..<nfft).map { centered[start+$0]*window[$0] }
            let (r,i)=fft.forward(windowed)
            re[t]=(0..<2048).map { r[$0]*scale };im[t]=(0..<2048).map { i[$0]*scale }
        }
        return (re,im)
    }

    /// Inverse of `spec` for a target length (HTDemucs `_ispec` with `torch.istft`).
    public func ispec(re: [[Double]], im: [[Double]], length: Int) -> [Double] {
        let frames=re.count+4,pad=hop/2*3,le=hop*((length+hop-1)/hop)+2*pad
        let total=nfft+hop*(frames-1)
        var signal=[Double](repeating:0,count:total),envelope=[Double](repeating:0,count:total)
        let scale=Double(nfft).squareRoot()
        for f in 0..<frames {
            let t=f-2
            var r=[Double](repeating:0,count:nfft/2+1),i=[Double](repeating:0,count:nfft/2+1)
            if t>=0 && t<re.count { for k in 0..<2048 { r[k]=re[t][k]*scale;i[k]=im[t][k]*scale } }
            let x=fft.inverse(re:r,im:i),start=f*hop
            for n in 0..<nfft { signal[start+n]+=x[n]*window[n];envelope[start+n]+=window[n]*window[n] }
        }
        // torch.istft divides by the window envelope, removes nfft/2 of centering, and fixes the length.
        let begin=nfft/2
        var out=[Double](repeating:0,count:le)
        for n in 0..<le where begin+n<total { out[n]=envelope[begin+n]>1e-11 ? signal[begin+n]/envelope[begin+n] : 0 }
        return Array(out[pad..<pad+length])
    }
}

/// HTDemucs vocal separation with the converted network between the STFT and inverse STFT, following
/// `demucs.apply.apply_model` with shifts 0, split, and overlap 0.25, then the pipeline's normalization,
/// mean downmix, and 44.1-to-16-kHz polyphase resampling.
public final class VocalSeparator {
    let model: MLModel
    let spectrogram=DemucsSpectrogram()
    public static let sourceRate=44100, segment=343_980, vocalsIndex=3

    /// `modelURL` is the converted network (`.mlpackage` compiled on load, or `.mlmodelc`). The CPU default is
    /// deterministic; GPU execution produced run-to-run differences that moved some estimates.
    public init(modelURL: URL, computeUnits: MLComputeUnits = .cpuOnly) throws {
        let compiled=modelURL.pathExtension=="mlmodelc" ? modelURL : try MLModel.compileModel(at:modelURL)
        let configuration=MLModelConfiguration();configuration.computeUnits=computeUnits
        model=try MLModel(contentsOf:compiled,configuration:configuration)
    }

    /// Mono 16-kHz vocals from a 44.1-kHz stereo mixture, trimmed or padded to `expectedSamples`.
    /// `progress` receives (completed, total) segments after each segment is accumulated; it never affects the result.
    public func vocals16k(left: [Float], right: [Float], expectedSamples: Int, progress: ((Int, Int) -> Void)? = nil) throws -> [Float] {
        let n=left.count
        guard right.count==n,n>0 else { throw AlignmentError.invalid("Stereo channels differ in length") }
        // Track normalization over the channel mean, with the unbiased standard deviation as torch computes it.
        let reference=(0..<n).map { (Double(left[$0])+Double(right[$0]))/2 }
        let mean=reference.reduce(0,+)/Double(n)
        let std=(reference.reduce(0.0) { $0+($1-mean)*($1-mean) }/Double(n-1)).squareRoot()
        guard std.isFinite,std>0 else { throw AlignmentError.invalid("Silent or invalid separation input") }
        let mix=[left.map { (Double($0)-mean)/std },right.map { (Double($0)-mean)/std }]
        let stem=try separate(mix,progress:progress)
        let mono=(0..<n).map { ((stem[0][$0]*std+mean)+(stem[1][$0]*std+mean))/2 }
        let resampled=resamplePoly(mono,up:160,down:441).map { Float($0) }
        guard abs(resampled.count-expectedSamples)<=2 else { throw AlignmentError.invalid("Separated recognition input duration differs from the mixture") }
        return resampled.count>=expectedSamples ? Array(resampled[..<expectedSamples]) : resampled+[Float](repeating:0,count:expectedSamples-resampled.count)
    }

    /// Vocal stem of a normalized stereo mixture by overlapping, triangularly weighted segments.
    func separate(_ mix: [[Double]], progress: ((Int, Int) -> Void)? = nil) throws -> [[Double]] {
        let length=mix[0].count,segment=Self.segment,stride=Int(0.75*Double(segment))
        let segments=(length+stride-1)/stride
        let weight:[Double]={
            let w=(1...(segment/2)).map(Double.init)+(Swift.stride(from:segment-segment/2,through:1,by:-1)).map(Double.init)
            let peak=w.max()!;return w.map { $0/peak }
        }()
        var out=[[Double]](repeating:[Double](repeating:0,count:length),count:2),sum=[Double](repeating:0,count:length)
        for offset in Swift.stride(from:0,to:length,by:stride) {
            let chunkLength=min(segment,length-offset)
            // Core ML outputs are autoreleased; draining them per segment bounds peak memory.
            let chunk=try autoreleasepool { try runSegment(mix,offset:offset,chunkLength:chunkLength) }
            for c in 0..<2 { for k in 0..<chunkLength { out[c][offset+k]+=weight[k]*chunk[c][k] } }
            for k in 0..<chunkLength { sum[offset+k]+=weight[k] }
            progress?(offset/stride+1,segments)
        }
        for c in 0..<2 { for k in 0..<length { out[c][k]/=sum[k] } }
        return out
    }

    /// One centered, zero-extended segment through the network, trimmed back to the chunk (`TensorChunk.padded`,
    /// `center_trim`).
    func runSegment(_ mix: [[Double]], offset: Int, chunkLength: Int) throws -> [[Double]] {
        let segment=Self.segment,length=mix[0].count,delta=segment-chunkLength,start=offset-delta/2
        let padded=(0..<2).map { c in (0..<segment).map { k -> Double in let i=start+k;return i>=0 && i<length ? mix[c][i] : 0 } }
        let specs=padded.map { spectrogram.spec($0) }
        let frames=specs[0].re.count,bins=2048
        let mag=try MLMultiArray(shape:[1,4,NSNumber(value:bins),NSNumber(value:frames)],dataType:.float32)
        let wave=try MLMultiArray(shape:[1,2,NSNumber(value:segment)],dataType:.float32)
        let mp=mag.dataPointer.assumingMemoryBound(to:Float.self),wp=wave.dataPointer.assumingMemoryBound(to:Float.self)
        let ms=mag.strides.map(\.intValue),ws=wave.strides.map(\.intValue)
        for c in 0..<2 { for f in 0..<bins { for t in 0..<frames {
            mp[(2*c)*ms[1]+f*ms[2]+t*ms[3]]=Float(specs[c].re[t][f]);mp[(2*c+1)*ms[1]+f*ms[2]+t*ms[3]]=Float(specs[c].im[t][f])
        }}}
        for c in 0..<2 { for k in 0..<segment { wp[c*ws[1]+k*ws[2]]=Float(padded[c][k]) } }
        let output=try model.prediction(from:MLDictionaryFeatureProvider(dictionary:["mag":mag,"mix":wave]))
        guard let spec=output.featureValue(for:"spec_out")?.multiArrayValue,let time=output.featureValue(for:"wave_out")?.multiArrayValue else {
            throw AlignmentError.invalid("Separation model output is missing")
        }
        let s=Self.vocalsIndex,ss=spec.strides.map(\.intValue),ts=time.strides.map(\.intValue)
        func value(_ a: MLMultiArray,_ index: Int) -> Double {
            a.dataType == .float32 ? Double(a.dataPointer.assumingMemoryBound(to:Float.self)[index]) : a[index].doubleValue
        }
        var result=[[Double]]()
        for c in 0..<2 {
            var re=[[Double]](repeating:[Double](repeating:0,count:bins),count:frames),im=re
            for t in 0..<frames { for f in 0..<bins {
                re[t][f]=value(spec,s*ss[1]+(2*c)*ss[2]+f*ss[3]+t*ss[4]);im[t][f]=value(spec,s*ss[1]+(2*c+1)*ss[2]+f*ss[3]+t*ss[4])
            }}
            let x=spectrogram.ispec(re:re,im:im,length:segment)
            let full=(0..<segment).map { x[$0]+value(time,s*ts[1]+c*ts[2]+$0*ts[3]) }
            let trim=delta/2
            result.append(Array(full[trim..<trim+chunkLength]))
        }
        return result
    }
}

/// Port of `scipy.signal.resample_poly(x, up, down)` with its default Kaiser (β = 5) FIR design and zero padding.
public func resamplePoly(_ x: [Double], up: Int, down: Int) -> [Double] {
    func gcd(_ a: Int,_ b: Int) -> Int { b==0 ? a : gcd(b,a%b) }
    let g=gcd(up,down),up=up/g,down=down/g
    if up==1 && down==1 { return x }
    let nIn=x.count,nOut=(nIn*up)/down+((nIn*up)%down != 0 ? 1:0)
    let maxRate=max(up,down),cutoff=1/Double(maxRate),halfLength=10*maxRate,taps=2*halfLength+1
    func bessel0(_ v: Double) -> Double {
        var sum=1.0,term=1.0,k=1.0
        while true { term*=(v/2)/k;term*=(v/2)/k;sum+=term;if term<sum*1e-17 { break };k+=1 }
        return sum
    }
    let alpha=Double(taps-1)/2,beta=5.0
    var h=(0..<taps).map { n -> Double in
        let m=Double(n)-alpha,arg=cutoff*m
        let sinc=arg==0 ? 1 : sin(Double.pi*arg)/(Double.pi*arg)
        let r=2*Double(n)/Double(taps-1)-1
        return cutoff*sinc*bessel0(beta*(1-r*r).squareRoot())/bessel0(beta)
    }
    let s=h.reduce(0,+);h=h.map { $0/s*Double(up) }
    let preRemove=(halfLength+(down-halfLength%down))/down
    let filter=[Double](repeating:0,count:down-halfLength%down)+h
    // y[k] = Σ_i x[i]·filter[k·down − i·up] over the upsampled full convolution.
    var y=[Double](repeating:0,count:nOut)
    for k in 0..<nOut {
        let m=(k+preRemove)*down
        var i=max(0,(m-filter.count)/up),acc=0.0
        while i<nIn {
            let j=m-i*up
            if j<0 { break }
            if j<filter.count { acc+=x[i]*filter[j] }
            i+=1
        }
        y[k]=acc
    }
    return y
}
