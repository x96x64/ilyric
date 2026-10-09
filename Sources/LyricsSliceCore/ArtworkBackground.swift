import Foundation
import SpikeCore

/// One enlarged artwork layer at a single output time, in native canvas pixels.
public struct ArtworkLayerState: Equatable, Sendable {
    public let centerX, centerY, side, angle: Double
}

/// Deterministic artwork-derived background, evaluated from explicit output time.
///
/// The model is an iLyric reconstruction fitted to phase-independent statistics of
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

    public init(scale: Double, orbit: Double, orbitRate: Double, rotationRate: Double,
                blur: Double, saturation: Double, gain: Double, gradient: Double) throws {
        let values=[scale,orbit,orbitRate,rotationRate,blur,saturation,gain,gradient]
        guard values.allSatisfy(\.isFinite), (0.5...4).contains(scale), (0...1).contains(orbit),
              abs(orbitRate)<=2, abs(rotationRate)<=2, (1...600).contains(blur),
              (0...3).contains(saturation), (0...2).contains(gain), (0..<1).contains(gradient)
        else { throw SliceError.invalid("Artwork background parameters") }
        self.scale=scale;self.orbit=orbit;self.orbitRate=orbitRate;self.rotationRate=rotationRate
        self.blur=blur;self.saturation=saturation;self.gain=gain;self.gradient=gradient
    }

    /// Current experimental parameter set; see docs/artwork-background.md for its provenance.
    /// Fitted jointly to three private recordings sets (docs/reference-data/background/fit.json, fold "all").
    /// Appearance parameters generalize to held-out songs; temporal rates remain provisional.
    public static let fitted = try! ArtworkBackground(scale:1.697,orbit:0.1300,orbitRate:0.1133,rotationRate:0.02231,
                                                       blur:139.1,saturation:1.900,gain:0.8225,gradient:0.4739)

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
