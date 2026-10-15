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
        var paragraphs: [CompositionParagraph] = []
        var events = [FocusEvent(Time(0), order: 0, paragraph: -1)]
        var position = 0.0
        var gaps: [CompositionGap] = []
        var lastEnd = Time(0)
        var secondary: [Int: SecondaryLine] = [:]
        let gapOrder = 3 * lyrics.entries.count + 2
        for (i, entry) in lyrics.entries.enumerated() {
            // A gap occupies its own layout slot; its focus event follows any simultaneous hold event.
            if let minimum = presentation.minimumGap, !entry.text.isEmpty, entry.time - lastEnd >= minimum {
                events.append(.init(lastEnd, order: gapOrder + gaps.count, gap: gaps.count))
                gaps.append(.init(position: position, begin: lastEnd, end: entry.time))
                position += GapIndicator.slotHeight
            }
            let end =
                entry.intervalEnd ?? (i + 1 < lyrics.entries.count ? lyrics.entries[i + 1].time : schedule.audioEnd)
            if !presentation.holdsFinishedLine && entry.intervalEnd != nil
                && (i + 1 == lyrics.entries.count || end < lyrics.entries[i + 1].time - presentation.focusLead)
            {
                events.append(.init(end, order: lyrics.entries.count + i + 1, paragraph: -1))
            }
            if entry.text.isEmpty {
                events.append(.init(entry.time, order: i + 1, paragraph: -1))
                continue
            }
            let japanese = entry.text.unicodeScalars.contains {
                (0x3040...0x30ff).contains($0.value) || (0x3400...0x9fff).contains($0.value)
                    || (0xff66...0xff9d).contains($0.value)
            }
            let lead = presentation.fillLead
            // A line with only line-level timing, as in LRC, fills steadily from its onset to its end as one segment.
            let segments =
                entry.segments.isEmpty
                ? [TimedSegment(start: 0, length: entry.text.utf16.count, begin: entry.time, end: end)] : entry.segments
            // Fill completes before focus moves to the next line, so that a line is never seen filling while it
            // scrolls away; the next focus time uses the same lead limit as the focus events below.
            var deadline: Time? = nil
            if i + 1 < lyrics.entries.count, entry.time < lyrics.entries[i + 1].time {
                let next = lyrics.entries[i + 1].time
                let interval = next - entry.time
                let half = Time(interval.numerator, interval.denominator * 2)
                deadline = next - (half < presentation.focusLead ? half : presentation.focusLead)
            }
            let timed = segments.map { s -> AppearanceEvent in
                let begin = max(Time(0), s.begin - lead)
                var stop = s.end - lead
                if let deadline, deadline < stop { stop = deadline }
                let end = max(begin + Time(1, 1000), stop)
                return AppearanceEvent(
                    start: s.start, length: s.length, begin: ParagraphTime(begin.numerator, begin.denominator),
                    end: ParagraphTime(end.numerator, end.denominator), verticalEvent: nil)
            }
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
            // Lead never moves focus before the previous focus event or before zero. Between closely spaced lines it
            // shrinks to half the interval between onsets, so that the line being sung keeps focus for most of it.
            let previous = events.filter { $0.paragraph >= 0 }.map(\.time).max() ?? Time(0)
            var focusLead = presentation.focusLead
            if let prior = paragraphs.last?.begin, prior < entry.time {
                let half = entry.time - prior
                let limit = Time(half.numerator, half.denominator * 2)
                if limit < focusLead { focusLead = limit }
            }
            let led = entry.time - focusLead
            events.append(
                .init(led > previous ? led : max(previous, Time(0)), order: i + 1, paragraph: paragraphs.count))
            if let bg = entry.background {
                let lead = presentation.fillLead
                let begin = max(Time(0), bg.begin - lead)
                secondary[paragraphs.count] = try SecondaryLine(
                    text: bg.text, begin: begin, end: max(begin + Time(1, 1000), bg.end - lead),
                    hasExplicitTiming: bg.hasExplicitTiming)
            }
            paragraphs.append(.init(input: input, position: position, begin: entry.time, end: end))
            lastEnd = end
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
}
