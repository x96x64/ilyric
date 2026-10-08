import Foundation
import SpikeCore

public struct InactiveAppearance: Equatable, Sendable {
    public let blur, opacity: Double
}
/// Experimental Latin reconstruction. Eight-pixel blur and 0.15-second ingress
/// are bounded fits; contrast ratio 0.42 is qualified, not measured native alpha.
public enum InactiveTreatment {
    public static func evaluate(_ time: Time, paragraph: Int, events: [FocusEvent]) -> InactiveAppearance {
        var focus=events[0].paragraph
        var start=events[0].time, initial=paragraph==focus ? 1.0:0.0
        var target=initial
        func value(_ t: Time) -> Double {
            let x=max(0,min(1,(t-start).seconds/0.15)),u=x*x*(3-2*x)
            return initial+(target-initial)*u
        }
        for event in events.dropFirst() where event.time<=time {
            let current=value(event.time)
            focus=event.paragraph;initial=current;start=event.time;target=paragraph==focus ? 1:0
        }
        let amount=value(time)
        return InactiveAppearance(blur:8*(1-amount),opacity:0.42+0.58*amount)
    }
}
