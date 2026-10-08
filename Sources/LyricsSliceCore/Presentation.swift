import Foundation
import SpikeCore

/// Internal experiment inputs, not a public project schema or native font specification.
public struct SliceTime: Codable, Equatable, Sendable {
    public let numerator, denominator: Int64
    public init(_ n: Int64, _ d: Int64 = 1) { numerator = n; denominator = d }
    public func validated() throws -> Time {
        guard abs(numerator == Int64.min ? Int64.max : numerator) <= 1_000_000_000,
              denominator > 0, denominator <= 1_000_000 else { throw SliceError.invalid("Timestamp bounds") }
        return Time(numerator, denominator)
    }
}
public enum SliceError: Error { case invalid(String) }
public struct AppearanceEvent: Codable, Equatable, Sendable {
    public let start, length: Int // UTF-16 source range; must align with shaped clusters.
    public let begin, end, verticalEvent: SliceTime?
    public init(start: Int, length: Int, begin: SliceTime?, end: SliceTime?, verticalEvent: SliceTime?) {
        self.start = start; self.length = length; self.begin = begin; self.end = end; self.verticalEvent = verticalEvent
    }
}
public struct SliceParameters: Codable, Equatable, Sendable {
    public var size = 103.25, width = 987.0, originX = 98.0, originY = 686.0
    public var lineAdvance = 123.0, amplitude = 6.0, tau = 0.195, dimOpacity = 0.42
    public init() {}
}
/// Optional experimental spatial appearance; nil preserves the original hard wipe.
/// Intervals remain explicit inputs, not inferred native lyric timestamps.
public struct SoftAppearance: Codable, Equatable, Sendable {
    public var intervalScale = 3.0, phaseOffset = 0.0, softness = 1.0, completedOpacity = 0.981
    public init() {}
    public func validate() throws {
        guard [intervalScale,phaseOffset,softness,completedOpacity].allSatisfy({ $0.isFinite }),
              (1...6).contains(intervalScale), (-1...1).contains(phaseOffset),
              (0.25...3).contains(softness), (0.9...1).contains(completedOpacity) else {
            throw SliceError.invalid("Experimental appearance bounds")
        }
    }
    public func fraction(position: Double, phase: Double?) -> Double {
        guard let phase else { return 0 }
        let q = (phase-phaseOffset)/intervalScale
        let v = min(1,max(0,0.5+(q+0.5-position)/softness))
        return v*v*(3-2*v)
    }
}
/// Only static Latin layout is enabled; Japanese appearance parameters do not transfer.
public enum ParagraphStyle: String, Codable, Sendable { case latinStatic }
public struct SliceInput: Codable, Sendable {
    public let text: String
    public let paragraphStyle: ParagraphStyle?
    public let canvasWidth: Int // 1179 screenshot or 1180 recording; no rescaling.
    public let breakEvidence: String
    public let parameters: SliceParameters
    public let appearance: SoftAppearance?
    public let events: [AppearanceEvent]
    public init(text: String, canvasWidth: Int = 1179, parameters: SliceParameters = .init(), events: [AppearanceEvent], appearance: SoftAppearance? = nil, paragraphStyle: ParagraphStyle? = nil) {
        self.text = text; self.canvasWidth = canvasWidth; breakEvidence = "observed-structure-source-semantics-unknown"
        self.parameters = parameters; self.events = events; self.appearance = appearance; self.paragraphStyle = paragraphStyle
    }
    public func validate() throws {
        let p = parameters
        try appearance?.validate()
        let count = text.split(separator:"\n",omittingEmptySubsequences:false).count
        let structureValid = paragraphStyle == .latinStatic ? (1...4).contains(count) : count == 2
        if paragraphStyle == .latinStatic {
            guard events.isEmpty, appearance == nil, p.amplitude == 0 else {
                throw SliceError.invalid("Latin integration is static; timed appearance and vertical treatment are unvalidated")
            }
        }
        guard [1179,1180].contains(canvasWidth), text.utf16.count < 500,
              structureValid, !text.isEmpty, !text.contains("\n\n"),
              !text.hasPrefix("\n"), !text.hasSuffix("\n"),
              breakEvidence == "observed-structure-source-semantics-unknown",
              [p.size,p.width,p.originX,p.originY,p.lineAdvance,p.amplitude,p.tau,p.dimOpacity].allSatisfy({ $0.isFinite }),
              (90...110).contains(p.size), (900...1000).contains(p.width),
              (0...150).contains(p.originX), (500...900).contains(p.originY),
              (110...140).contains(p.lineAdvance), (0...10).contains(p.amplitude),
              (0.08...0.4).contains(p.tau), (0...1).contains(p.dimOpacity) else { throw SliceError.invalid("Experimental paragraph constraints") }
        var previous = 0
        for e in events {
            guard e.start >= previous, e.length > 0, e.start <= text.utf16.count - e.length else { throw SliceError.invalid("Ordered nonoverlapping event ranges required") }
            previous = e.start + e.length
            if let begin = e.begin, let end = e.end {
                guard try begin.validated() < end.validated() else { throw SliceError.invalid("Positive appearance interval required") }
            } else if e.begin != nil || e.end != nil { throw SliceError.invalid("Incomplete appearance interval") }
            _ = try e.verticalEvent?.validated()
        }
    }
    public func evaluate(_ time: Time) -> SliceSnapshot {
        let p = parameters
        let states = events.map { e -> SpanPresentation in
            let progress: Double
            let phase: Double?
            if let begin = e.begin, let end = e.end {
                let a = Time(begin.numerator,begin.denominator), b = Time(end.numerator,end.denominator)
                phase = (time-a).seconds/(b-a).seconds-0.5
                progress = time <= a ? 0 : time >= b ? 1 : (time-a).seconds/(b-a).seconds
            } else { progress = 0; phase = nil }
            let age = e.verticalEvent.map { (time-Time($0.numerator,$0.denominator)).seconds }
            let u = max(0,age ?? 0)/p.tau
            return SpanPresentation(start:e.start,length:e.length,progress:progress,
                displacement:p.amplitude*(1+u)*exp(-u),phase:phase)
        }
        return SliceSnapshot(time:time,spans:states)
    }
    /// Fitted static reconstruction, conditional on observed line structure.
    public static func latin(text: String = "A careful draft—\nwith room to revise.") -> SliceInput {
        var p = SliceParameters()
        p.size=104.25;p.width=987;p.originX=96;p.originY=687;p.lineAdvance=125.5
        p.amplitude=0;p.dimOpacity=1
        return SliceInput(text:text,parameters:p,events:[],paragraphStyle:.latinStatic)
    }
    /// Original synthetic text and timings, independent of commercial references.
    public static func synthetic(canvasWidth: Int = 1179, softened: Bool = false) -> SliceInput {
        let text = "小さな紙に丸を描く\n青い点を二つ置く"
        var index = 0, order = 0; var events: [AppearanceEvent] = []
        for c in text {
            let count = String(c).utf16.count
            if c != "\n" {
                let center = 600 + Int64(order)*150
                events.append(AppearanceEvent(start:index,length:count,begin:SliceTime(center-60,600),
                    end:SliceTime(center+60,600),verticalEvent:SliceTime(center,600)))
                order += 1
            }
            index += count
        }
        var parameters = SliceParameters()
        if softened { parameters.dimOpacity = 0.438 }
        return SliceInput(text:text,canvasWidth:canvasWidth,parameters:parameters,events:events,appearance:softened ? SoftAppearance() : nil)
    }
}
public struct SpanPresentation: Equatable, Codable, Sendable {
    public let start, length: Int
    public let progress, displacement: Double
    public let phase: Double?
}
public struct SliceSnapshot: Equatable, Sendable {
    public let time: Time
    public let spans: [SpanPresentation]
}
