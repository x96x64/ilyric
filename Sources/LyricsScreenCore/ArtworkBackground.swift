import Foundation
import TimelineCore

/// One enlarged artwork layer at a single output time, in native canvas pixels.
public struct ArtworkLayerState: Equatable, Sendable {
    public let centerX, centerY, side, angle: Double
}

/// Deterministic artwork-derived background, evaluated from explicit output time.
///
/// The model is an iLyrics reconstruction fitted to phase-independent statistics of
/// physical recordings: rotating, orbiting enlarged artwork layers, a large Gaussian
/// blur, and a color transfer with vertical darkening. It is not Apple's implementation,
/// and its phase is not matched to any native recording.
public struct ArtworkBackground: Equatable, Sendable {
    /// Layer side relative to canvas height.
    public let scale: Double
    /// Orbit radius relative to canvas height.
    public let orbit: Double
    /// Orbit angular velocity, radians per second.
    public let orbitRate: Double
    /// Layer rotation angular velocity, radians per second.
    public let rotationRate: Double
    /// Gaussian blur standard deviation in native pixels.
    public let blur: Double
    /// Saturation multiplier around Rec. 709 luma.
    public let saturation: Double
    /// Uniform gain before vertical darkening.
    public let gain: Double
    /// Linear darkening from top (0) to bottom (`gradient`).
    public let gradient: Double
    /// Constant added after the gain and before vertical darkening, in encoded sRGB units.
    public let lift: Double
    /// Artwork mean CIELAB chroma at which saturation is halved; 0 disables adaptation.
    public let chromaHalf: Double
    /// Spread adaptation: deviations from the artwork's mean colour scale by (spreadReference/c)^spreadExponent, where
    /// c is the lightness standard deviation of the artwork at 16×16; an exponent of 0 disables it.
    public let spreadReference: Double, spreadExponent: Double

    public init(scale: Double, orbit: Double, orbitRate: Double, rotationRate: Double,
                blur: Double, saturation: Double, gain: Double, gradient: Double, lift: Double = 0, chromaHalf: Double = 0,
                spreadReference: Double = 0, spreadExponent: Double = 0) throws {
        let values=[scale,orbit,orbitRate,rotationRate,blur,saturation,gain,gradient,lift,chromaHalf,spreadReference,spreadExponent]
        guard values.allSatisfy(\.isFinite), (0.5...4).contains(scale), (0...1).contains(orbit),
              abs(orbitRate)<=2, abs(rotationRate)<=2, (1...600).contains(blur),
              (0...8).contains(saturation), (0...2).contains(gain), (0..<1).contains(gradient),
              (0...0.5).contains(lift), lift==0 || gain>0, (0...200).contains(chromaHalf),
              (0...1).contains(spreadReference), (0...2).contains(spreadExponent), spreadExponent==0 || spreadReference>0
        else { throw ScreenError.invalid("Artwork background parameters") }
        self.scale=scale;self.orbit=orbit;self.orbitRate=orbitRate;self.rotationRate=rotationRate
        self.blur=blur;self.saturation=saturation;self.gain=gain;self.gradient=gradient;self.lift=lift
        self.chromaHalf=chromaHalf;self.spreadReference=spreadReference;self.spreadExponent=spreadExponent
    }
    /// Contrast factor for artwork whose coarse lightness has standard deviation `c` (encoded units, 0 to 1).
    public func spreadFactor(coarseLightnessDeviation c: Double) -> Double {
        spreadExponent>0 && c.isFinite ? pow(spreadReference/max(c,0.001),spreadExponent) : 1
    }
    /// Saturation for artwork of the given mean chroma: nearly neutral artwork keeps little color.
    public func saturation(artworkChroma c: Double) -> Double {
        chromaHalf>0 && c.isFinite && c>=0 ? saturation*c/(c+chromaHalf) : saturation
    }
    /// Mean CIELAB (D65) chroma of interleaved 8-bit sRGB pixels, matching the fitting model.
    public static func meanChroma(rgb: [UInt8]) -> Double {
        guard rgb.count>=3 else { return 0 }
        func linear(_ v: UInt8) -> Double { let x=Double(v)/255; return x<=0.04045 ? x/12.92 : pow((x+0.055)/1.055,2.4) }
        func f(_ t: Double) -> Double { t>0.008856 ? cbrt(t) : 7.787*t+16/116 }
        var total=0.0
        let n=rgb.count/3
        for i in 0..<n {
            let r=linear(rgb[3*i]),g=linear(rgb[3*i+1]),b=linear(rgb[3*i+2])
            let x=(0.4124*r+0.3576*g+0.1805*b)/0.95047,y=0.2126*r+0.7152*g+0.0722*b,z=(0.0193*r+0.1192*g+0.9505*b)/1.08883
            let a=500*(f(x)-f(y)),bb=200*(f(y)-f(z))
            total+=(a*a+bb*bb).squareRoot()
        }
        return total/Double(n)
    }

    /// Current experimental parameter set; see docs/reports/artwork-background.md for its provenance.
    /// Appearance from docs/reference-data/background/fit.json (fold "all"); orbit and rotation refitted to
    /// paused-playback recordings with matched durations (docs/reference-data/background/motion.json).
    /// Spread adaptation fitted on development captures A to D (docs/reports/background-spread-adaptation.md).
    public static let fitted = try! ArtworkBackground(scale:1.385,orbit:0.0865,orbitRate:0.1233,rotationRate:-0.0259,
                                                       blur:100.0,saturation:4.898,gain:0.3971,gradient:0.4239,lift:0.2212,chromaHalf:7.83,
                                                       spreadReference:0.285,spreadExponent:0.683)

    /// Fixed layer phases and directions. Two counter-moving layers avoid a single rigid rotation.
    public static let phases: [(phase: Double, direction: Double)] = [(0, 1), (2.1, -1)]
    public static let angleOffsetFactor = 1.7

    public func layers(at time: Time, width: Double, height: Double) -> [ArtworkLayerState] {
        let t=time.seconds
        return Self.phases.map { p in
            let orbitAngle=p.direction*orbitRate*t+p.phase
            return ArtworkLayerState(centerX:width/2+orbit*height*cos(orbitAngle),
                                     centerY:height/2+orbit*height*sin(orbitAngle),
                                     side:scale*height,
                                     angle:p.direction*rotationRate*t+p.phase*Self.angleOffsetFactor)
        }
    }
}
