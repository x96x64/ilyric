import Foundation
import SpikeCore

/// Three-dot instrumental-gap indicator, evaluated from elapsed media time within a supplied gap.
///
/// Fitted to three private iPhone 16 recordings (docs/gap-indicator.md). Dots fill in order across the
/// gap minus a fixed lead; the whole group pulses in scale with a phase that restarts at the gap.
/// The pulse period differs between songs for an unidentified reason; `period` is a median default.
public struct GapIndicator: Equatable, Sendable {
    /// Seconds before the gap end by which the third dot completes its fill.
    public let lead: Double
    /// Fraction of each dot's third of the fill interval spent rising.
    public let ramp: Double
    /// Unlit dot opacity relative to a lit dot.
    public let unlit: Double
    public let amplitude, period, phase: Double
    public let fadeIn, fadeOut: Double

    public init(lead: Double, ramp: Double, unlit: Double, amplitude: Double, period: Double, phase: Double,
                fadeIn: Double, fadeOut: Double) throws {
        let values=[lead,ramp,unlit,amplitude,period,phase,fadeIn,fadeOut]
        guard values.allSatisfy(\.isFinite), (0...10).contains(lead), ramp>0, ramp<=1, (0...1).contains(unlit),
              (0..<0.5).contains(amplitude), period>0, fadeIn>=0, fadeOut>=0 else { throw SliceError.invalid("Gap indicator parameters") }
        self.lead=lead;self.ramp=ramp;self.unlit=unlit;self.amplitude=amplitude;self.period=period;self.phase=phase
        self.fadeIn=fadeIn;self.fadeOut=fadeOut
    }

    public static let fitted = try! GapIndicator(lead:2.22,ramp:0.72,unlit:0.14,amplitude:0.11,period:4.92,phase:-0.46,
                                                  fadeIn:0.4,fadeOut:0.15)
    /// Measured native geometry: dot diameter, center spacing, first-dot center x, and focused center y.
    public static let diameter = 42.0, spacing = 67.0, firstCenterX = 107.0, focusedCenterY = 760.0
    /// Layout height reserved for the indicator, from dot center to the following paragraph's slot.
    public static let slotHeight = 226.0

    /// Half-open state over `[0, duration)`; outside that interval the indicator is absent.
    public func evaluate(elapsed: Double, duration: Double) -> GapIndicatorState? {
        guard duration>0, elapsed>=0, elapsed<duration else { return nil }
        // Short gaps keep at least half their duration for filling; native short-gap behavior is unmeasured.
        let interval=max(duration-lead,duration/2),u=3*elapsed/interval
        let fills=(0..<3).map { k in min(1,max(0,(u-(Double(k)+0.5-ramp/2))/ramp)) }
        let entry=fadeIn>0 ? min(1,elapsed/fadeIn) : 1
        let exit=fadeOut>0 ? min(1,(duration-elapsed)/fadeOut) : 1
        let smooth={ (x:Double) in x*x*(3-2*x) }
        return GapIndicatorState(fills:fills,opacities:fills.map { unlit+(1-unlit)*$0 },
                                 scale:1+amplitude*sin(2*Double.pi*elapsed/period+phase),
                                 visibility:smooth(entry)*smooth(exit))
    }
}

public struct GapIndicatorState: Equatable, Sendable {
    public let fills, opacities: [Double]
    public let scale, visibility: Double
}

/// A supplied instrumental gap occupying one layout slot in media time.
public struct CompositionGap: Sendable {
    public let position: Double
    public let begin, end: Time
    public let indicator: GapIndicator
    public init(position: Double, begin: Time, end: Time, indicator: GapIndicator = .fitted) {
        self.position=position;self.begin=begin;self.end=end;self.indicator=indicator
    }
}

public struct GapPresentation: Equatable, Sendable {
    public let index: Int
    /// Vertical offset of the dot centers from the focused native center.
    public let translationY: Double
    public let state: GapIndicatorState?
}
