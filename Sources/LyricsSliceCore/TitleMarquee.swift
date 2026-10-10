import Foundation

/// Horizontal scrolling of a header label whose ink exceeds its clip, evaluated from output time.
///
/// Constants were fitted to one reference capture of one overflowing title (docs/title-marquee.md).
/// Scrolling duration is assumed proportional to the cycle distance; that scaling, the overflow
/// threshold, and the trigger of the initial delay are unmeasured.
public struct TitleMarquee: Equatable, Sendable {
    /// Native pixels; the clip extends left of the resting ink origin, over the artwork margin.
    public let clipMinX, clipMaxX, leadingFade, trailingFade: Double
    /// Ink distance between the end of one copy and the start of the next.
    public let gap: Double
    /// Mean scrolling speed in pixels per second over one cycle.
    public let speed: Double
    public let delay, pause: Double
    /// CSS-style cubic Bézier control points (x1, y1, x2, y2) of normalized displacement.
    public let curve: [Double]
    public init(clipMinX: Double, clipMaxX: Double, leadingFade: Double, trailingFade: Double, gap: Double,
                speed: Double, delay: Double, pause: Double, curve: [Double]) throws {
        guard [clipMinX,clipMaxX,leadingFade,trailingFade,gap,speed,delay,pause].allSatisfy(\.isFinite),
              clipMinX<clipMaxX, leadingFade>=0, trailingFade>=0, leadingFade+trailingFade<clipMaxX-clipMinX,
              gap>0, speed>0, delay>=0, pause>=0, curve.count==4, curve.allSatisfy(\.isFinite),
              (0...1).contains(curve[0]), (0...1).contains(curve[2]) else { throw SliceError.invalid("Title marquee") }
        self.clipMinX=clipMinX;self.clipMaxX=clipMaxX;self.leadingFade=leadingFade;self.trailingFade=trailingFade
        self.gap=gap;self.speed=speed;self.delay=delay;self.pause=pause;self.curve=curve
    }
    /// Fitted to iPhone 16, reported iOS 27.0.1: 0.54-pixel RMS displacement residual over two cycles.
    public static let measured = try! TitleMarquee(clipMinX:312,clipMaxX:977,leadingFade:20,trailingFade:22,gap:104,
        speed:104.3,delay:8.11,pause:4.42,curve:[0.296,0.340,0.567,1.0])

    /// Provisional rule: scrolling starts only when resting ink would enter the trailing fade.
    public func overflows(origin: Double, inkWidth: Double) -> Bool { origin+inkWidth>clipMaxX-trailingFade }
    /// Leftward displacement in [0, inkWidth + gap); zero while resting or when the label fits.
    public func offset(at seconds: Double, origin: Double, inkWidth: Double) -> Double {
        guard seconds.isFinite, inkWidth>0, overflows(origin:origin,inkWidth:inkWidth), seconds>delay else { return 0 }
        let distance=inkWidth+gap,duration=distance/speed,period=duration+pause
        let phase=(seconds-delay).truncatingRemainder(dividingBy:period)
        return phase<duration ? distance*ease(phase/duration) : 0
    }
    /// Deterministic bisection on the monotone x(s) of the Bézier, then y(s).
    public func ease(_ u: Double) -> Double {
        if u<=0 { return 0 }; if u>=1 { return 1 }
        func bezier(_ a: Double,_ b: Double,_ s: Double) -> Double { 3*(1-s)*(1-s)*s*a+3*(1-s)*s*s*b+s*s*s }
        var low=0.0,high=1.0
        for _ in 0..<48 { let mid=(low+high)/2; if bezier(curve[0],curve[2],mid)<u { low=mid } else { high=mid } }
        return bezier(curve[1],curve[3],(low+high)/2)
    }
    /// Horizontal opacity of the clip's edge fades at native x.
    public func opacity(at x: Double) -> Double {
        guard x>=clipMinX, x<clipMaxX else { return 0 }
        let left=leadingFade>0 ? (x-clipMinX)/leadingFade : 1, right=trailingFade>0 ? (clipMaxX-x)/trailingFade : 1
        return min(1,left,right)
    }
}
