import Foundation

/// Bounded, normalized rational time for this synthetic experiment, not an input format.
public struct Time: Hashable, Comparable, Sendable {
    public let numerator: Int64
    public let denominator: Int64
    public init(_ numerator: Int64, _ denominator: Int64 = 1) {
        precondition(denominator > 0 && numerator != Int64.min)
        func gcd(_ a: Int64, _ b: Int64) -> Int64 { b == 0 ? a : gcd(b, a % b) }
        let divisor = gcd(abs(numerator), denominator)
        self.numerator = numerator / divisor
        self.denominator = denominator / divisor
    }
    public var seconds: Double { Double(numerator) / Double(denominator) }
    public static func < (a: Self, b: Self) -> Bool {
        let left = a.numerator.multipliedFullWidth(by: b.denominator)
        let right = b.numerator.multipliedFullWidth(by: a.denominator)
        return left.high == right.high ? left.low < right.low : left.high < right.high
    }
    public static func + (a: Self, b: Self) -> Self {
        let d = a.denominator / gcd(a.denominator, b.denominator) * b.denominator
        return Time(a.numerator * (d / a.denominator) + b.numerator * (d / b.denominator), d)
    }
    public static func - (a: Self, b: Self) -> Self { a + Time(-b.numerator, b.denominator) }
    private static func gcd(_ a: Int64, _ b: Int64) -> Int64 { b == 0 ? a : gcd(b, a % b) }
    public static func frame(_ n: Int64, fpsNumerator: Int64 = 60, fpsDenominator: Int64 = 1) -> Self {
        Time(n * fpsDenominator, fpsNumerator)
    }
}

public struct Fit: Equatable {
    public let scale: Double
    public let x: Double
    public let y: Double
    public init(width: Double, height: Double) {
        precondition(width > 0 && height > 0)
        scale = min(width / 402, height / 874)
        x = (width - 402 * scale) / 2
        y = (height - 874 * scale) / 2
    }
}

public struct Event: Equatable, Sendable {
    public let time: Time
    public let order: Int
    public let focus: Double
    public let seek: Time?
    public init(time: Time, order: Int, focus: Double, seek: Time? = nil) {
        self.time = time; self.order = order; self.focus = focus; self.seek = seek
    }
}

/// All timing, motion, geometry, colors and text in this fixture are synthetic.
public struct Snapshot: Equatable, Sendable {
    public let output: Time
    public let media: Time
    public let focus: Double
    public let velocity: Double
    public let highlights: [Double]
    public let marker: Bool
    public let gap: Bool
}

private struct Segment {
    let start: Time
    let position: Double
    let velocity: Double
    let target: Double
    // Synthetic cubic Hermite easing; interruption preserves position and velocity.
    func evaluate(_ time: Time) -> (Double, Double) {
        let duration = 0.8
        let u = max(0, min(1, (time - start).seconds / duration))
        let p = (2*u*u*u - 3*u*u + 1)*position + (u*u*u - 2*u*u + u)*duration*velocity
            + (-2*u*u*u + 3*u*u)*target
        let v = ((6*u*u - 6*u)*position + (3*u*u - 4*u + 1)*duration*velocity
            + (-6*u*u + 6*u)*target) / duration
        return (p, u == 1 ? 0 : v)
    }
}

public struct Timeline {
    public static let markerTimes = [Time(0), Time(1), Time(5, 4), Time(3)]
    public static let text = "Silver morning carries\nquiet light across the sea."
    public static let japanese = "朝の光が海を渡る。\n静かな波を見つめる。"
    public let events: [Event]
    private let segments: [Segment]
    public init(events: [Event] = [
        Event(time: Time(1), order: 0, focus: 1),
        Event(time: Time(5, 4), order: 1, focus: 0, seek: Time(1, 4)),
        Event(time: Time(3), order: 2, focus: 1)
    ]) {
        precondition(Set(events.map(\.order)).count == events.count)
        self.events = events.sorted { $0.time == $1.time ? $0.order < $1.order : $0.time < $1.time }
        var result = [Segment(start: Time(0), position: 0, velocity: 0, target: 0)]
        for event in self.events {
            precondition(event.time >= Time(0))
            let prior = result.last!.evaluate(event.time)
            result.append(Segment(start: event.time, position: prior.0, velocity: prior.1, target: event.focus))
        }
        segments = result
    }
    public func mediaTime(_ time: Time) -> Time {
        guard let event = events.last(where: { $0.time <= time && $0.seek != nil }) else { return time }
        return event.seek! + (time - event.time)
    }
    public func evaluate(_ time: Time) -> Snapshot {
        precondition(time >= Time(0))
        let segment = segments.last(where: { $0.start <= time })!
        let (focus, velocity) = segment.evaluate(time)
        let media = mediaTime(time)
        let highlights = (0..<8).map { index in
            max(0, min(1, (media - Time(Int64(index), 4)).seconds / 0.25))
        }
        let marker = Self.markerTimes.contains { time >= $0 && time < $0 + Time(1, 20) }
        return Snapshot(output: time, media: media, focus: focus, velocity: velocity,
                        highlights: highlights, marker: marker, gap: time >= Time(18, 5))
    }
    /// Output-time sync markers plus media-time tone make the seek audible and testable.
    public func audioSample(_ index: Int) -> Int16 {
        let time = Time(Int64(index), 48_000)
        let marker = Self.markerTimes.contains { time >= $0 && time < $0 + Time(1, 50) }
        let tone = sin(2 * Double.pi * 223.25 * mediaTime(time).seconds) * 0.04
        let click = marker ? sin(2 * Double.pi * 1000 * time.seconds) * 0.7 : 0
        return Int16((tone + click) * 32767)
    }
}
