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
/// Latin word-fill motion for supplied word timing; nil keeps the original hard wipe without motion.
/// Constants are fitted to one reference capture (docs/reference-clock-and-word-motion.md).
public struct WordMotion: Codable, Equatable, Sendable {
    /// Width, in pixels, of the linear ramp between filled and unfilled ink.
    public var edge: Double
    /// Upward offset, in pixels, that a word approaches once its interval begins.
    public var lift: Double
    /// Time constant, in seconds, of the critically damped lift response.
    public var liftTime: Double
    /// Words lasting at least this long, in seconds, receive emphasis.
    public var emphasisDuration: Double
    /// Peak scale, additional lift in pixels, and glow opacity of an emphasized word.
    public var emphasisScale, emphasisLift, emphasisGlow: Double
    /// Glow blur radius in pixels and emphasis release time constant in seconds.
    public var glowRadius, release: Double
    public init(edge: Double, lift: Double, liftTime: Double, emphasisDuration: Double, emphasisScale: Double,
                emphasisLift: Double, emphasisGlow: Double, glowRadius: Double, release: Double) throws {
        guard [edge,lift,liftTime,emphasisDuration,emphasisScale,emphasisLift,emphasisGlow,glowRadius,release].allSatisfy(\.isFinite),
              (0...200).contains(edge), (0...20).contains(lift), (0.01...2).contains(liftTime), emphasisDuration>0,
              (1...1.3).contains(emphasisScale), (0...40).contains(emphasisLift), (0...1).contains(emphasisGlow),
              (0...60).contains(glowRadius), (0.01...3).contains(release) else { throw SliceError.invalid("Word motion") }
        self.edge=edge;self.lift=lift;self.liftTime=liftTime;self.emphasisDuration=emphasisDuration;self.emphasisScale=emphasisScale
        self.emphasisLift=emphasisLift;self.emphasisGlow=emphasisGlow;self.glowRadius=glowRadius;self.release=release
    }
    /// Fitted to V17 (iPhone 16, reported iOS 27.0.1): 1,783 fill events for lift, one sustained word for emphasis.
    public static let measured = try! WordMotion(edge:30,lift:3.5,liftTime:0.17,emphasisDuration:1.0,emphasisScale:1.05,
        emphasisLift:8.5,emphasisGlow:0.5,glowRadius:18,release:0.3)
    /// Emphasis strength in [0, 1]: rises over the word's interval and decays after it.
    public func emphasis(begin: Double, end: Double, at t: Double) -> Double {
        guard end-begin>=emphasisDuration, t>begin else { return 0 }
        let rise={ (u: Double) -> Double in let v=min(1,max(0,u)); return v*v*(3-2*v) }
        if t<=end { return rise((t-begin)/(end-begin)) }
        return exp(-(t-end)/release)
    }
    /// Critically damped approach to the lift from the word's beginning; continuous at the beginning.
    public func liftOffset(begin: Double, at t: Double) -> Double {
        guard t>begin else { return 0 }
        let u=(t-begin)/liftTime
        return lift*(1-(1+u)*exp(-u))
    }
}
/// Static styles do not infer fine-grained timing from line-level inputs.
public enum ParagraphStyle: String, Codable, Sendable { case latinStatic, japaneseStatic, latinTimed, japaneseTimed
    public var timed: Bool { self == .latinTimed || self == .japaneseTimed } }
public struct SliceInput: Codable, Sendable {
    public let text: String
    public let paragraphStyle: ParagraphStyle?
    public let canvasWidth: Int // 1179 screenshot or 1180 recording; no rescaling.
    public let breakEvidence: String
    public let parameters: SliceParameters
    public let appearance: SoftAppearance?
    public let events: [AppearanceEvent]
    /// Applies only to Latin paragraphs with supplied timing.
    public let motion: WordMotion?
    public init(text: String, canvasWidth: Int = 1179, parameters: SliceParameters = .init(), events: [AppearanceEvent], appearance: SoftAppearance? = nil, paragraphStyle: ParagraphStyle? = nil, breakEvidence: String = "observed-structure-source-semantics-unknown", motion: WordMotion? = nil) {
        self.text = text; self.canvasWidth = canvasWidth; self.breakEvidence = breakEvidence
        self.parameters = parameters; self.events = events; self.appearance = appearance; self.paragraphStyle = paragraphStyle
        self.motion = motion
    }
    public func validate() throws {
        let p = parameters
        try appearance?.validate()
        guard motion == nil || paragraphStyle == .latinTimed else { throw SliceError.invalid("Word motion requires supplied Latin timing") }
        let count = text.split(separator:"\n",omittingEmptySubsequences:false).count
        let structureValid = paragraphStyle != nil ? (1...4).contains(count) : count == 2
        if let style=paragraphStyle,style.timed {
            guard !events.isEmpty,p.amplitude==0 else { throw SliceError.invalid("Supplied timing requires ranges without inferred vertical events") }
            guard events.allSatisfy({$0.begin != nil && $0.end != nil && $0.verticalEvent == nil}) else { throw SliceError.invalid("Complete supplied intervals required") }
        } else if paragraphStyle != nil {
            guard events.isEmpty, appearance == nil, p.amplitude == 0 else {
                throw SliceError.invalid("Static paragraph integration; timed appearance and vertical treatment are unvalidated")
            }
        }
        guard [1179,1180].contains(canvasWidth), text.utf16.count < 500,
              structureValid, !text.isEmpty, !text.contains("\n\n"),
              !text.hasPrefix("\n"), !text.hasSuffix("\n"),
              ["observed-structure-source-semantics-unknown","supplied-explicit-structure"].contains(breakEvidence),
              [p.size,p.width,p.originX,p.originY,p.lineAdvance,p.amplitude,p.tau,p.dimOpacity].allSatisfy({ $0.isFinite }),
              (90...110).contains(p.size), (900...1000).contains(p.width),
              (0...150).contains(p.originX), (500...900).contains(p.originY),
              (110...140).contains(p.lineAdvance), (0...10).contains(p.amplitude),
              (0.08...0.4).contains(p.tau), (0...1).contains(p.dimOpacity) else { throw SliceError.invalid("Experimental paragraph constraints") }
        var boundaries=Set([0]),boundary=0
        for c in text { boundary+=String(c).utf16.count;boundaries.insert(boundary) }
        var previous = 0
        for e in events {
            guard e.start >= previous, e.length > 0, e.start <= text.utf16.count - e.length else { throw SliceError.invalid("Ordered nonoverlapping event ranges required") }
            if paragraphStyle?.timed == true {
                guard boundaries.contains(e.start),boundaries.contains(e.start+e.length) else { throw SliceError.invalid("Timed range splits an extended grapheme cluster") }
            }
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
            var displacement=p.amplitude*(1+u)*exp(-u),scale=1.0,glow=0.0
            if let motion,let begin=e.begin,let end=e.end {
                let a=Time(begin.numerator,begin.denominator).seconds,b=Time(end.numerator,end.denominator).seconds,t=time.seconds
                let k=motion.emphasis(begin:a,end:b,at:t)
                displacement -= motion.liftOffset(begin:a,at:t)+motion.emphasisLift*k
                scale=1+(motion.emphasisScale-1)*k;glow=motion.emphasisGlow*k
            }
            return SpanPresentation(start:e.start,length:e.length,progress:progress,
                displacement:displacement,phase:phase,scale:scale,glow:glow)
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
    /// Line-level local input keeps measured base metrics but supplies no glyph timing.
    public static func supplied(text: String, japanese: Bool) -> SliceInput {
        var p = japanese ? SliceParameters() : latin().parameters
        p.amplitude=0;p.dimOpacity=1
        return SliceInput(text:text,parameters:p,events:[],paragraphStyle:japanese ? .japaneseStatic : .latinStatic,
            breakEvidence:"supplied-explicit-structure")
    }
    /// Supplied segment intervals; the appearance mapping is a synthetic visualization.
    public static func suppliedTimed(text:String,japanese:Bool,events:[AppearanceEvent],motion:WordMotion?=nil) -> SliceInput {
        var p=supplied(text:text,japanese:japanese).parameters;p.dimOpacity=0.42
        var soft=SoftAppearance();soft.intervalScale=1;soft.softness=0.25;soft.completedOpacity=1
        return SliceInput(text:text,parameters:p,events:events,appearance:japanese ? soft : nil,
            paragraphStyle:japanese ? .japaneseTimed : .latinTimed,breakEvidence:"supplied-explicit-structure",motion:japanese ? nil : motion)
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
    /// Word emphasis about the word's ink center, and glow opacity; 1 and 0 without word motion.
    public var scale = 1.0, glow = 0.0
}
public struct SliceSnapshot: Equatable, Sendable {
    public let time: Time
    public let spans: [SpanPresentation]
}
