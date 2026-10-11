import Foundation
import CoreGraphics
import LyricsInputCore
import LyricsSliceCore
import LyricsSliceMac
import SpikeCore

/// Opt-in presentation features; defaults reproduce the established output exactly.
public struct LocalPresentation: Sendable {
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
    /// Native word fill leads the sung onset by 0.22 s relative to iLyric's estimates (docs/word-fill-lead.md).
    public static let measuredFillLead = Time(22,100)
    /// Hide lower controls at this time and extend the lyrics to the bottom edge; nil keeps them visible.
    public var hideControls: Time?
    /// Native controls disappear 3.78 s after playback starts in the reference capture (docs/control-auto-hide.md).
    public static let measuredControlHide = Time(379,100)
    public init(background: ArtworkBackground? = nil, icons: ScreenIconSet = .original, minimumGap: Time? = nil,
                focusLead: Time = Time(0), stagger: FocusStagger = .rigid, marquee: TitleMarquee? = nil, wordMotion: WordMotion? = nil, fillLead: Time = Time(0), hideControls: Time? = nil) {
        self.background=background;self.icons=icons;self.minimumGap=minimumGap;self.focusLead=focusLead;self.stagger=stagger
        self.marquee=marquee;self.wordMotion=wordMotion;self.fillLead=fillLead;self.hideControls=hideControls
    }
    /// Reference-measured presentation: 0.90-second focus lead and staggered motion
    /// (docs/lyrics-motion-timing.md, lead corrected in docs/reference-clock-and-word-motion.md).
    public static let measuredMotion = (focusLead: Time(9,10), stagger: FocusStagger.measured)
}

/// Experimental paragraph focus with optional explicitly supplied segment appearance.
public final class LocalScene {
    public let lyrics: LocalLyrics
    public let audio: LocalAudio
    public let schedule: OutputSchedule
    public let renderer: ScreenRenderer
    private let artwork: CGImage?
    private let presentation: LocalPresentation
    /// An independent renderer of the same scene for parallel export; renderers hold caches and are not
    /// shared between threads. Every renderer produces identical frames.
    public func makeRenderer() throws -> ScreenRenderer {
        let r=try ScreenRenderer(renderer.screen,calibratedInactive:true,diagnosticMarkers:false,boundedCache:true,suppliedArtwork:artwork,
                                 icons:presentation.icons,marquee:presentation.marquee,sharing:renderer)
        r.secondary=renderer.secondary;return r
    }
    /// `title` and `artist` override the project's header labels.
    public init(lyrics: LocalLyrics, audio: LocalAudio, project: ExperimentalProject? = nil, artwork: CGImage? = nil, highlighting: Highlighting = .enabled,
                presentation: LocalPresentation = .init(), title: String? = nil, artist: String? = nil) throws {
        self.lyrics=lyrics;self.audio=audio;self.artwork=artwork;self.presentation=presentation
        schedule=try lyrics.validate(audioSamples:audio.sampleCount)
        var paragraphs:[CompositionParagraph]=[],events=[FocusEvent(Time(0),order:0,paragraph:-1)],position=0.0
        var gaps:[CompositionGap]=[],lastEnd=Time(0),secondary:[Int:SecondaryLine]=[:]
        let gapOrder=3*lyrics.entries.count+2
        for (i,entry) in lyrics.entries.enumerated() {
            // A gap occupies its own layout slot; its focus event follows any simultaneous hold event.
            if let minimum=presentation.minimumGap,!entry.text.isEmpty,entry.time-lastEnd>=minimum {
                events.append(.init(lastEnd,order:gapOrder+gaps.count,gap:gaps.count))
                gaps.append(.init(position:position,begin:lastEnd,end:entry.time))
                position+=GapIndicator.slotHeight
            }
            let end=entry.intervalEnd ?? (i+1<lyrics.entries.count ? lyrics.entries[i+1].time : schedule.audioEnd)
            if !presentation.holdsFinishedLine && entry.intervalEnd != nil && (i+1==lyrics.entries.count || end<lyrics.entries[i+1].time-presentation.focusLead) {
                events.append(.init(end,order:lyrics.entries.count+i+1,paragraph:-1))
            }
            if entry.text.isEmpty { events.append(.init(entry.time,order:i+1,paragraph:-1));continue }
            let japanese=entry.text.unicodeScalars.contains { (0x3040...0x30ff).contains($0.value) || (0x3400...0x9fff).contains($0.value) || (0xff66...0xff9d).contains($0.value) }
            let lead=presentation.fillLead
            let timed=entry.segments.map { s -> AppearanceEvent in
                let begin=max(Time(0),s.begin-lead),end=max(begin+Time(1,1000),s.end-lead)
                return AppearanceEvent(start:s.start,length:s.length,begin:SliceTime(begin.numerator,begin.denominator),
                    end:SliceTime(end.numerator,end.denominator),verticalEvent:nil)
            }
            let timedInput=timed.isEmpty ? nil : SliceInput.suppliedTimed(text:entry.text,japanese:japanese,events:timed,motion:presentation.wordMotion)
            // Validate supplied cluster boundaries even when their visualization is disabled.
            if let timedInput,highlighting == .disabled { _=try SliceParagraph(timedInput) }
            let input=highlighting == .enabled && timedInput != nil ? timedInput! : SliceInput.supplied(text:entry.text,japanese:japanese)
            let layout=try SliceParagraph(input)
            // Lead never moves focus before the previous focus event or before zero.
            let previous=events.filter { $0.paragraph >= 0 }.map(\.time).max() ?? Time(0)
            let led=entry.time-presentation.focusLead
            events.append(.init(led>previous ? led : max(previous,Time(0)),order:i+1,paragraph:paragraphs.count))
            if let bg=entry.background {
                let lead=presentation.fillLead,begin=max(Time(0),bg.begin-lead)
                secondary[paragraphs.count]=try SecondaryLine(text:bg.text,begin:begin,end:max(begin+Time(1,1000),bg.end-lead))
            }
            paragraphs.append(.init(input:input,position:position,begin:entry.time,end:end))
            lastEnd=end
            // Provisional inter-paragraph spacing; measured line advances remain unchanged.
            position += Double(layout.lines.count)*input.parameters.lineAdvance+110
            if let bg=entry.background {
                // Reserve the measured secondary offset and wrapped secondary lines, estimated from character count.
                let estimate=max(1,ceil(Double(bg.text.count)*input.parameters.size*SecondaryLine.sizeRatio*0.55/input.parameters.width))
                position += SecondaryLine.firstLineSpace+estimate*input.parameters.lineAdvance*SecondaryLine.sizeRatio
            }
        }
        let composition=try LyricsComposition(paragraphs:paragraphs,events:events,gaps:gaps,stagger:presentation.stagger,collapsesGaps:presentation.collapsesGaps)
        let v=project?.visibility
        let visibility=ScreenVisibility(artwork:v?.artwork ?? true,metadata:v?.metadata ?? true,
            progress:v?.progress ?? true,transport:v?.transport ?? true,volume:v?.volume ?? true,
            bottom:v?.bottom ?? true,handle:v?.handle ?? true,translation:v?.translation ?? true,sing:true)
        let controls=ScreenControls(translation:v?.translation ?? false,handle:v?.handle ?? true,
            sing:SingControl(rawValue:v?.sing ?? "hidden")!)
        let screen=try LyricsScreen(composition:composition,title:title ?? project?.title ?? "Local Lyrics",artist:artist ?? project?.artist ?? "Supplied Recording",duration:schedule.audioEnd,volume:LyricsScreen.referenceVolume,
            events:[.init(Time(0),order:0,controls:controls)]+(presentation.hideControls.map { [.init($0,order:1,
                controls:ScreenControls(lower:false,translation:false,handle:controls.handle,sing:.hidden))] } ?? []),
            visibility:visibility,background:presentation.background,expandsLyrics:presentation.hideControls != nil)
        renderer=try ScreenRenderer(screen,calibratedInactive:true,diagnosticMarkers:false,boundedCache:true,suppliedArtwork:artwork,icons:presentation.icons,marquee:presentation.marquee)
        renderer.secondary=secondary
    }
}
