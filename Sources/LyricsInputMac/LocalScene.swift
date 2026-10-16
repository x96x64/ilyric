import Foundation
import CoreGraphics
import LyricsInputCore
import LyricsScreenCore
import LyricsScreenMac
import TimelineCore

/// Opt-in presentation features; defaults reproduce the established output exactly.
public struct LocalPresentation: Sendable {
    public var canvas: LyricsCanvas
    public var background: ArtworkBackground?
    public var icons: ScreenIconSet
    /// Insert the instrumental-gap indicator where supplied lyric timing leaves at least this much silence.
    /// The native minimum is unmeasured; this threshold is a provisional presentation choice.
    public var minimumGap: Time?
    /// Focus moves to a line this long before its supplied onset; highlighting keeps the supplied timing.
    public var focusLead: Time
    public var stagger: FocusStagger
    /// Header scrolling for labels that overflow; nil keeps the labels static and clipped.
    public var marquee: TitleMarquee?
    /// Soft fill, lift, and emphasis of supplied Latin word timing; nil keeps the hard wipe.
    public var wordMotion: WordMotion?
    /// Keep a finished line focused until the next line or gap takes focus, as the native screen does,
    /// instead of releasing focus at the line's supplied end.
    public var holdsFinishedLine = false
    /// Open an instrumental-gap slot only while the gap holds focus, instead of reserving it in advance.
    public var collapsesGaps = false
    /// Word fill begins this long before each supplied word interval; focus timing is unaffected.
    public var fillLead: Time = Time(0)
    /// Native word fill leads the sung onset by 0.22 s relative to iLyrics's estimates (docs/word-fill-lead.md).
    public static let measuredFillLead = Time(22, 100)
    /// Hide lower controls at this time and extend the lyrics to the bottom edge; nil keeps them visible.
    public var hideControls: Time?
    /// Native controls disappear 3.78 s after playback starts in the reference capture (docs/reports/control-auto-hide.md).
    public static let measuredControlHide = Time(379, 100)
    public init(
        background: ArtworkBackground? = nil, icons: ScreenIconSet = .original, minimumGap: Time? = nil,
        focusLead: Time = Time(0), stagger: FocusStagger = .rigid, marquee: TitleMarquee? = nil,
        wordMotion: WordMotion? = nil, fillLead: Time = Time(0), hideControls: Time? = nil,
        canvas: LyricsCanvas = .native
    ) {
        self.canvas = canvas
        self.background = background
        self.icons = icons
        self.minimumGap = minimumGap
        self.focusLead = focusLead
        self.stagger = stagger
        self.marquee = marquee
        self.wordMotion = wordMotion
        self.fillLead = fillLead
        self.hideControls = hideControls
    }
    /// Reference-measured presentation: 0.90-second focus lead and staggered motion
    /// (docs/reports/lyrics-motion-timing.md, lead corrected in docs/reports/reference-clock-and-word-motion.md).
    public static let measuredMotion = (focusLead: Time(9, 10), stagger: FocusStagger.measured)
}

/// A lyrics scene: paragraph focus, timing, and presentation for one recording.
public final class LocalScene {
    static let wrapLimit = "Paragraph wraps to more than eight lines"
    /// Whether a paragraph of untimed text fits the screen's eight rows on `canvas`, checked before any alignment.
    public static func fits(_ text: String, canvas: LyricsCanvas) -> Bool {
        let japanese = text.unicodeScalars.contains {
            (0x3040...0x30ff).contains($0.value) || (0x3400...0x9fff).contains($0.value)
                || (0xff66...0xff9d).contains($0.value)
        }
        var input = ParagraphInput.supplied(text: text, japanese: japanese)
        if canvas != .native { input = input.adapted(to: canvas) }
        do { _ = try ParagraphLayout(input) } catch ScreenError.invalid(let reason) {
            return reason != wrapLimit
        } catch { return true }
        return true
    }
    /// Space between consecutive paragraphs beyond the line advance, in native pixels.
    public static let paragraphSpacing = 75.0
    public let lyrics: LocalLyrics
    public let audio: LocalAudio
    public let schedule: OutputSchedule
    public let renderer: ScreenRenderer
    private let artwork: CGImage?
    private let presentation: LocalPresentation
    /// The artwork is iLyrics's placeholder, whose background uses a colour field instead of the artwork's shapes.
    private let placeholderArtwork: Bool
    /// An independent renderer of the same scene for parallel export; renderers hold caches and are not
    /// shared between threads. Every renderer produces identical frames.
    public func makeRenderer() throws -> ScreenRenderer {
        let r = try ScreenRenderer(
            renderer.screen, calibratedInactive: true, diagnosticMarkers: false, boundedCache: true,
            suppliedArtwork: artwork,
            icons: presentation.icons, marquee: presentation.marquee, sharing: renderer,
            placeholderArtwork: placeholderArtwork)
        r.secondary = renderer.secondary
        r.credits = renderer.credits
        return r
    }
    /// `title` and `artist` override the project's header labels; `credits` names the songwriters shown after the last line.
    public init(
        lyrics: LocalLyrics, audio: LocalAudio, project: ProjectSettings? = nil, artwork: CGImage? = nil,
        highlighting: Highlighting = .enabled,
        presentation: LocalPresentation = .init(), title: String? = nil, artist: String? = nil, credits: String? = nil,
        placeholderArtwork: Bool = false
    ) throws {
        self.placeholderArtwork = placeholderArtwork
        self.lyrics = lyrics
        self.audio = audio
        self.artwork = artwork
        self.presentation = presentation
        schedule = try lyrics.validate(audioSamples: audio.sampleCount)
        // Compile the existing focus schedule before deriving any presentation-only fill boundaries.
        // Empty entries, explicit releases, gaps, and simultaneous event order retain their original rules.
        var events = [FocusEvent(Time(0), order: 0, paragraph: -1)]
        var gapStarts: [Int: Time] = [:]
        var entryEnds: [Time] = []
        var previousFocus = Time(0)
        var priorOnset: Time?
        var lastEnd = Time(0)
        var paragraphIndex = 0
        let gapOrder = 3 * lyrics.entries.count + 2
        for (i, entry) in lyrics.entries.enumerated() {
            if let minimum = presentation.minimumGap, !entry.text.isEmpty, entry.time - lastEnd >= minimum {
                events.append(.init(lastEnd, order: gapOrder + gapStarts.count, gap: gapStarts.count))
                gapStarts[i] = lastEnd
            }
            let end =
                entry.intervalEnd ?? (i + 1 < lyrics.entries.count ? lyrics.entries[i + 1].time : schedule.audioEnd)
            entryEnds.append(end)
            if !presentation.holdsFinishedLine && entry.intervalEnd != nil
                && (i + 1 == lyrics.entries.count || end < lyrics.entries[i + 1].time - presentation.focusLead)
            {
                events.append(.init(end, order: lyrics.entries.count + i + 1, paragraph: -1))
            }
            if entry.text.isEmpty {
                events.append(.init(entry.time, order: i + 1, paragraph: -1))
                continue
            }
            var lead = presentation.focusLead
            if let priorOnset, priorOnset < entry.time {
                let interval = entry.time - priorOnset
                let half = Time(interval.numerator, interval.denominator * 2)
                if half < lead { lead = half }
            }
            let led = entry.time - lead
            let focus = led > previousFocus ? led : max(previousFocus, Time(0))
            events.append(.init(focus, order: i + 1, paragraph: paragraphIndex))
            previousFocus = focus
            priorOnset = entry.time
            paragraphIndex += 1
            lastEnd = end
        }
        let ordered = events.sorted { $0.time == $1.time ? $0.order < $1.order : $0.time < $1.time }
        var departures: [Int: Time] = [:]
        for (i, event) in ordered.enumerated() where event.paragraph >= 0 {
            let next = i + 1 < ordered.count ? ordered[i + 1].time : schedule.audioEnd
            departures[event.paragraph] = min(next, schedule.audioEnd)
        }
        var paragraphs: [CompositionParagraph] = []
        var position = 0.0
        var gaps: [CompositionGap] = []
        var secondary: [Int: SecondaryLine] = [:]
        for (i, entry) in lyrics.entries.enumerated() {
            if let begin = gapStarts[i] {
                gaps.append(.init(position: position, begin: begin, end: entry.time))
                position += GapIndicator.slotHeight
            }
            let end = entryEnds[i]
            if entry.text.isEmpty { continue }
            let japanese = entry.text.unicodeScalars.contains {
                (0x3040...0x30ff).contains($0.value) || (0x3400...0x9fff).contains($0.value)
                    || (0xff66...0xff9d).contains($0.value)
            }
            let lead = presentation.fillLead
            // A line with only line-level timing, as in LRC, fills steadily from its onset to its end as one segment.
            let segments =
                entry.segments.isEmpty
                ? [TimedSegment(start: 0, length: entry.text.utf16.count, begin: entry.time, end: end)] : entry.segments
            // Use actual departure, including release/gap events, and never extend fill past the audio.
            let deadline = departures[paragraphs.count]
            let timed = try Self.fillEvents(segments, lead: lead, deadline: deadline)
            let timedInput =
                timed.isEmpty
                ? nil
                : ParagraphInput.suppliedTimed(
                    text: entry.text, japanese: japanese, events: timed, motion: presentation.wordMotion)
            // Validate supplied cluster boundaries even when their visualization is disabled.
            if let timedInput, highlighting == .disabled { _ = try ParagraphLayout(timedInput) }
            var input =
                highlighting == .enabled && timedInput != nil
                ? timedInput! : ParagraphInput.supplied(text: entry.text, japanese: japanese)
            if entry.secondVoice { input.rightAligned = true }
            if presentation.canvas != .native { input = input.adapted(to: presentation.canvas) }
            if highlighting == .enabled, timedInput != nil, let deadline, deadline > Time(0) {
                input.fillDeadline = deadline
            }
            let layout: ParagraphLayout
            do { layout = try ParagraphLayout(input) } catch ScreenError.invalid(let reason) {
                guard reason == Self.wrapLimit else { throw ScreenError.invalid(reason) }
                let seconds = entry.time.seconds
                throw InputError.invalid(
                    String(
                        format:
                            "the lyric line at %d:%05.2f wraps to more than eight rows on screen; split it into shorter lines",
                        Int(seconds) / 60, seconds.truncatingRemainder(dividingBy: 60)))
            }
            if let bg = entry.background {
                let lead = presentation.fillLead
                let begin = max(Time(0), bg.begin - lead)
                secondary[paragraphs.count] = try SecondaryLine(
                    text: bg.text, begin: begin, end: max(begin + Time(1, 1000), bg.end - lead),
                    hasExplicitTiming: bg.hasExplicitTiming)
            }
            paragraphs.append(.init(input: input, position: position, begin: entry.time, end: end))
            // Inter-paragraph spacing: settled development capture V17 places consecutive paragraphs a median 200.5 px
            // apart against a 125-px line advance (docs/reports/paragraph-spacing.md).
            position += Double(layout.lines.count) * input.parameters.lineAdvance + Self.paragraphSpacing
            if let bg = entry.background {
                // Reserve the measured secondary offset and wrapped secondary lines, estimated from character count.
                let estimate = max(
                    1,
                    ceil(
                        Double(bg.text.count) * input.parameters.size * SecondaryLine.sizeRatio * 0.55
                            / input.parameters.width))
                position +=
                    SecondaryLine.firstLineSpace + estimate * input.parameters.lineAdvance * SecondaryLine.sizeRatio
            }
        }
        let composition = try LyricsComposition(
            paragraphs: paragraphs, events: events, gaps: gaps, stagger: presentation.stagger,
            collapsesGaps: presentation.collapsesGaps)
        let v = project?.visibility
        let visibility = ScreenVisibility(
            artwork: v?.artwork ?? true, metadata: v?.metadata ?? true,
            progress: v?.progress ?? true, transport: v?.transport ?? true, volume: v?.volume ?? true,
            bottom: v?.bottom ?? true, handle: v?.handle ?? true, translation: v?.translation ?? true, sing: true)
        let controls = ScreenControls(
            translation: v?.translation ?? false, handle: v?.handle ?? true,
            sing: SingControl(rawValue: v?.sing ?? "hidden")!)
        let screen = try LyricsScreen(
            composition: composition, title: title ?? project?.title ?? "Local Lyrics",
            artist: artist ?? project?.artist ?? "Supplied Recording", duration: schedule.audioEnd,
            volume: LyricsScreen.referenceVolume,
            events: [.init(Time(0), order: 0, controls: controls)]
                + (presentation.hideControls.map {
                    [
                        .init(
                            $0, order: 1,
                            controls: ScreenControls(
                                lower: false, translation: false, handle: controls.handle, sing: .hidden))
                    ]
                } ?? []),
            visibility: visibility, background: presentation.background, expandsLyrics: presentation.hideControls != nil
        )
        renderer = try ScreenRenderer(
            screen, calibratedInactive: true, diagnosticMarkers: false, boundedCache: true, suppliedArtwork: artwork,
            icons: presentation.icons, marquee: presentation.marquee, placeholderArtwork: placeholderArtwork)
        renderer.secondary = secondary
        renderer.credits = credits.map { "Written By: " + $0 }
    }
    /// Ordered presentation intervals, isolated from raster initialization and its floating-point state.
    package static func fillEvents(_ segments: [TimedSegment], lead: Time, deadline: Time?) throws -> [AppearanceEvent]
    {
        var intervals = segments.map { segment -> (begin: Time, end: Time) in
            let begin = max(Time(0), segment.begin - lead)
            return (begin, max(begin + Time(1, 1000), segment.end - lead))
        }
        // A replacement must not bypass validation of the supplied interval's original start.
        for interval in intervals {
            _ = try ParagraphTime(interval.begin.numerator, interval.begin.denominator).validated()
        }
        let originalIntervals = intervals
        if let deadline, deadline > Time(0),
            var first = intervals.firstIndex(where: { $0.end > deadline })
        {
            // Only a suffix that cannot fit is compressed. Include a preceding interval only when
            // the fallback start would overlap it; all earlier intervals remain exactly unchanged.
            func gcd(_ a: Int64, _ b: Int64) -> Int64 { b == 0 ? a : gcd(b, a % b) }
            func difference(_ a: Time, _ b: Time) -> Time? {
                let common = gcd(a.denominator, b.denominator)
                let leftScale = b.denominator / common
                let d = a.denominator.multipliedReportingOverflow(by: leftScale)
                let left = a.numerator.multipliedReportingOverflow(by: leftScale)
                let right = b.numerator.multipliedReportingOverflow(by: a.denominator / common)
                guard !d.overflow && !left.overflow && !right.overflow else { return nil }
                let n = left.partialValue.subtractingReportingOverflow(right.partialValue)
                guard !n.overflow else { return nil }
                return Time(n.partialValue, d.partialValue)
            }
            func fallbackStart() throws -> Time {
                if deadline <= Time(1, 1000) { return Time(0) }
                guard let value = difference(deadline, Time(1, 1000)) else {
                    throw InputError.invalid("Presentation boundary precision cannot represent a fill start")
                }
                return value
            }
            var begin = intervals[first].begin < deadline ? intervals[first].begin : try fallbackStart()
            while first > 0, intervals[first - 1].end > begin {
                first -= 1
                begin = intervals[first].begin < deadline ? intervals[first].begin : try fallbackStart()
            }
            let count = Int64(intervals.count - first)
            let available = difference(deadline, begin)
            var boundaries: [Time]? = nil
            if let available {
                let divisor = gcd(available.numerator, count)
                let denominator = available.denominator.multipliedReportingOverflow(by: count / divisor)
                if !denominator.overflow {
                    let step = Time(available.numerator / divisor, denominator.partialValue)
                    let common = gcd(begin.denominator, step.denominator)
                    let scale = step.denominator / common
                    let d = begin.denominator.multipliedReportingOverflow(by: scale)
                    let base = begin.numerator.multipliedReportingOverflow(by: scale)
                    let stride = step.numerator.multipliedReportingOverflow(by: begin.denominator / common)
                    if !d.overflow && !base.overflow && !stride.overflow {
                        var candidate = [begin]
                        for offset in 1..<count {
                            let advance = stride.partialValue.multipliedReportingOverflow(by: offset)
                            let value = base.partialValue.addingReportingOverflow(advance.partialValue)
                            if advance.overflow || value.overflow { break }
                            candidate.append(Time(value.partialValue, d.partialValue))
                        }
                        if candidate.count == Int(count) { boundaries = candidate + [deadline] }
                    }
                }
            }
            if boundaries == nil {
                // Extreme package-API leads can make an equal split unrepresentable in Int64.
                // Retain existing interior starts when they provide an exact ordered allocation.
                let existing = [begin] + originalIntervals.dropFirst(first + 1).map(\.begin) + [deadline]
                guard zip(existing, existing.dropFirst()).allSatisfy({ $0 < $1 }) else {
                    throw InputError.invalid(
                        "Presentation boundary precision cannot represent ordered fill intervals")
                }
                boundaries = existing
            }
            let allocated = boundaries!
            for index in first..<intervals.count {
                let offset = index - first
                intervals[index] = (allocated[offset], allocated[offset + 1])
            }
        }
        return segments.enumerated().map { index, segment -> AppearanceEvent in
            let interval = intervals[index]
            // Generated fractions retain their exact precision; external validation remains unchanged.
            return AppearanceEvent(
                start: segment.start, length: segment.length,
                begin: interval.begin != originalIntervals[index].begin
                    ? ParagraphTime(derived: interval.begin)
                    : ParagraphTime(interval.begin.numerator, interval.begin.denominator),
                end: interval.end != originalIntervals[index].end
                    ? ParagraphTime(derived: interval.end)
                    : ParagraphTime(interval.end.numerator, interval.end.denominator),
                verticalEvent: nil)
        }
    }

}
