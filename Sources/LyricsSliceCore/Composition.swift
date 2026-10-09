import Foundation
import SpikeCore

/// Bounded experimental inputs. Capture onset is not inferred from media time.
public struct FocusEvent: Sendable {
    public let time: Time
    public let order, paragraph: Int
    /// When set, focus moves to this gap slot and no paragraph is focused (`paragraph` is -1).
    public let gap: Int?
    public init(_ time: Time, order: Int, paragraph: Int) { self.time=time;self.order=order;self.paragraph=paragraph;gap=nil }
    public init(_ time: Time, order: Int, gap: Int) { self.time=time;self.order=order;paragraph = -1;self.gap=gap }
}
public struct PlaybackAnchor: Sendable {
    public let output, media: Time
    public let running: Bool
    public init(output: Time, media: Time, running: Bool) { self.output=output;self.media=media;self.running=running }
}
public struct CompositionParagraph: Sendable {
    public let input: SliceInput
    public let position: Double
    public let begin, end: Time
    public init(input: SliceInput, position: Double, begin: Time, end: Time) {
        self.input=input;self.position=position;self.begin=begin;self.end=end
    }
}
public struct ParagraphPresentation: Equatable, Sendable {
    public let index: Int
    public let translationY, opacity: Double
    public let active: Bool
    public let appearance: SliceSnapshot
}
public struct CompositionSnapshot: Equatable, Sendable {
    public let output, media: Time
    public let focus: Int
    public let scroll, velocity: Double
    public let paragraphs: [ParagraphPresentation]
    public let gaps: [GapPresentation]
}
/// Analytic critical response with explicit initial position and velocity.
/// Continuity under interruption is an internal synthetic contract, not native evidence.
public struct FocusSegment: Sendable {
    public let start: Time
    public let position, velocity, target, tau: Double
    public init(start: Time, position: Double, velocity: Double, target: Double, tau: Double) {
        precondition(tau > 0 && [position,velocity,target,tau].allSatisfy(\.isFinite))
        self.start=start;self.position=position;self.velocity=velocity;self.target=target;self.tau=tau
    }
    public func evaluate(_ time: Time) -> (position: Double, velocity: Double) {
        let t=max(0,(time-start).seconds),a=position-target,b=velocity+a/tau,e=exp(-t/tau)
        return (target+(a+b*t)*e,(b-(a+b*t)/tau)*e)
    }
}
public struct LyricsComposition: Sendable {
    public let paragraphs: [CompositionParagraph]
    public let gaps: [CompositionGap]
    public let events: [FocusEvent]
    public let clocks: [PlaybackAnchor]
    public let canvasWidth: Int
    public let tau: Double
    private let segments: [FocusSegment]
    public init(paragraphs: [CompositionParagraph], events: [FocusEvent], clocks: [PlaybackAnchor] = [.init(output:Time(0),media:Time(0),running:true)], tau: Double = 0.081,
                gaps: [CompositionGap] = []) throws {
        guard (1...64).contains(paragraphs.count),(0.04...0.3).contains(tau),tau.isFinite,
              Set(events.map(\.order)).count==events.count, !events.isEmpty,
              !clocks.isEmpty, clocks[0].output==Time(0),
              zip(clocks,clocks.dropFirst()).allSatisfy({$0.output<$1.output}),
              events.allSatisfy({$0.time>=Time(0) && ($0.paragraph == -1 || paragraphs.indices.contains($0.paragraph))}),
              events.allSatisfy({ $0.gap.map { gaps.indices.contains($0) } ?? true }),
              gaps.count<=64, gaps.allSatisfy({ $0.begin<$0.end && $0.position.isFinite }),
              Set(paragraphs.map(\.position)+gaps.map(\.position)).count==paragraphs.count+gaps.count else { throw SliceError.invalid("Composition event constraints") }
        for p in paragraphs { try p.input.validate() }
        guard paragraphs.allSatisfy({ $0.input.canvasWidth==paragraphs[0].input.canvasWidth && $0.begin<$0.end && $0.position.isFinite }),
              zip(paragraphs,paragraphs.dropFirst()).allSatisfy({$0.position<$1.position}) else { throw SliceError.invalid("Ordered paragraph layout required") }
        let sorted=events.sorted { $0.time == $1.time ? $0.order<$1.order : $0.time<$1.time }
        guard sorted[0].time==Time(0) else { throw SliceError.invalid("Initial focus required") }
        func target(_ e: FocusEvent, hold: Double) -> Double {
            if let g=e.gap { return gaps[g].position }
            return e.paragraph == -1 ? hold : paragraphs[e.paragraph].position
        }
        let firstTarget=target(sorted[0],hold:paragraphs[0].position)
        var compiled=[FocusSegment(start:Time(0),position:firstTarget,velocity:0,target:firstTarget,tau:tau)]
        for event in sorted.dropFirst() {
            let initial=compiled.last!.evaluate(event.time)
            compiled.append(FocusSegment(start:event.time,position:initial.position,velocity:initial.velocity,target:target(event,hold:compiled.last!.target),tau:tau))
        }
        self.paragraphs=paragraphs;self.gaps=gaps;self.events=sorted;self.clocks=clocks;self.canvasWidth=paragraphs[0].input.canvasWidth;self.tau=tau;segments=compiled
    }
    public func mediaTime(_ output: Time) -> Time {
        let clock=clocks.last(where:{$0.output<=output}) ?? clocks[0]
        return clock.media+(clock.running ? output-clock.output : Time(0))
    }
    public func evaluate(_ time: Time) -> CompositionSnapshot {
        let index=events.lastIndex(where:{$0.time<=time}) ?? 0
        let movement=segments[index].evaluate(time),media=mediaTime(time),focus=events[index].paragraph
        let states=paragraphs.enumerated().map { i,p in
            // First-baseline alignment is an explicit synthetic composition anchor.
            // Individual paragraph typography and appearance are untouched.
            ParagraphPresentation(index:i,translationY:791.25-p.input.parameters.originY-p.input.parameters.size+p.position-movement.position,
                opacity:i==focus ? 1:0.38,active:p.begin<=media && media<p.end,appearance:p.input.evaluate(media))
        }
        let gapStates=gaps.enumerated().map { i,g in
            GapPresentation(index:i,translationY:g.position-movement.position,
                state:g.indicator.evaluate(elapsed:(media-g.begin).seconds,duration:(g.end-g.begin).seconds))
        }
        return CompositionSnapshot(output:time,media:media,focus:focus,scroll:movement.position,velocity:movement.velocity,paragraphs:states,gaps:gapStates)
    }
    /// Synthetic PCM uses the explicit media clock; diagnostic clicks use output time.
    public func audioSample(_ index: Int) -> Int16 {
        let time=Time(Int64(index),48_000)
        let phase=Time(time.numerator % (4*time.denominator),time.denominator)
        let marker=Timeline.markerTimes.contains { phase >= $0 && phase < $0+Time(1,50) }
        let tone=sin(2*Double.pi*223.25*mediaTime(time).seconds)*0.04
        let click=marker ? sin(2*Double.pi*1000*time.seconds)*0.7 : 0
        return Int16((tone+click)*32767)
    }
    /// Original text; explicit timing, spacing, clipping and opacity are synthetic.
    public static func synthetic() throws -> LyricsComposition {
        try LyricsComposition(paragraphs:[
            .init(input:.latin(text:"A careful draft—\nwith room to revise."),position:0,begin:Time(0),end:Time(1)),
            .init(input:.synthetic(softened:true),position:325,begin:Time(1),end:Time(3)),
            .init(input:.latin(text:"Keep each shaped line\nsteady as pages move."),position:650,begin:Time(3),end:Time(6))
        ],events:[.init(Time(0),order:0,paragraph:0),.init(Time(1),order:1,paragraph:1),.init(Time(3),order:2,paragraph:2)])
    }
    /// Original synthetic gap fixture: a paragraph, an eight-second instrumental gap, and a paragraph.
    /// Slot spacing between the gap and the following paragraph uses the measured indicator slot height.
    public static func gapDemonstration() throws -> LyricsComposition {
        let gapPosition=325.0
        return try LyricsComposition(paragraphs:[
            .init(input:.latin(text:"A careful draft—\nwith room to revise."),position:0,begin:Time(0),end:Time(3)),
            .init(input:.latin(text:"Keep each shaped line\nsteady as pages move."),position:gapPosition+GapIndicator.slotHeight,begin:Time(11),end:Time(14))
        ],events:[.init(Time(0),order:0,paragraph:0),.init(Time(3),order:1,gap:0),.init(Time(11),order:2,paragraph:1)],
        gaps:[.init(position:gapPosition,begin:Time(3),end:Time(11))])
    }
    /// Separate demonstration: complete both supplied glyph-event lines before departure.
    /// The original six-second benchmark is preserved unchanged.
    public static func progressionDemonstration() throws -> LyricsComposition {
        try LyricsComposition(paragraphs:[
            .init(input:.latin(text:"A careful draft—\nwith room to revise."),position:0,begin:Time(0),end:Time(1)),
            .init(input:.synthetic(softened:true),position:325,begin:Time(1),end:Time(6)),
            .init(input:.latin(text:"Keep each shaped line\nsteady as pages move."),position:650,begin:Time(6),end:Time(8))
        ],events:[.init(Time(0),order:0,paragraph:0),.init(Time(1),order:1,paragraph:1),.init(Time(6),order:2,paragraph:2)])
    }

}
