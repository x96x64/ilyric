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
    public init(background: ArtworkBackground? = nil, icons: ScreenIconSet = .original, minimumGap: Time? = nil,
                focusLead: Time = Time(0), stagger: FocusStagger = .rigid) {
        self.background=background;self.icons=icons;self.minimumGap=minimumGap;self.focusLead=focusLead;self.stagger=stagger
    }
    /// Reference-measured presentation: 0.30-second focus lead and staggered motion (docs/lyrics-motion-timing.md).
    public static let measuredMotion = (focusLead: Time(3,10), stagger: FocusStagger.measured)
}

/// Experimental paragraph focus with optional explicitly supplied segment appearance.
public final class LocalScene {
    public let lyrics: LocalLyrics
    public let audio: LocalAudio
    public let schedule: OutputSchedule
    public let renderer: ScreenRenderer
    public init(lyrics: LocalLyrics, audio: LocalAudio, project: ExperimentalProject? = nil, artwork: CGImage? = nil, highlighting: Highlighting = .enabled, presentation: LocalPresentation = .init()) throws {
        self.lyrics=lyrics;self.audio=audio;schedule=try lyrics.validate(audioSamples:audio.sampleCount)
        var paragraphs:[CompositionParagraph]=[],events=[FocusEvent(Time(0),order:0,paragraph:-1)],position=0.0
        var gaps:[CompositionGap]=[],lastEnd=Time(0)
        let gapOrder=3*lyrics.entries.count+2
        for (i,entry) in lyrics.entries.enumerated() {
            // A gap occupies its own layout slot; its focus event follows any simultaneous hold event.
            if let minimum=presentation.minimumGap,!entry.text.isEmpty,entry.time-lastEnd>=minimum {
                events.append(.init(lastEnd,order:gapOrder+gaps.count,gap:gaps.count))
                gaps.append(.init(position:position,begin:lastEnd,end:entry.time))
                position+=GapIndicator.slotHeight
            }
            let end=entry.intervalEnd ?? (i+1<lyrics.entries.count ? lyrics.entries[i+1].time : schedule.audioEnd)
            if entry.intervalEnd != nil && (i+1==lyrics.entries.count || end<lyrics.entries[i+1].time-presentation.focusLead) {
                events.append(.init(end,order:lyrics.entries.count+i+1,paragraph:-1))
            }
            if entry.text.isEmpty { events.append(.init(entry.time,order:i+1,paragraph:-1));continue }
            let japanese=entry.text.unicodeScalars.contains { (0x3040...0x30ff).contains($0.value) || (0x3400...0x9fff).contains($0.value) || (0xff66...0xff9d).contains($0.value) }
            let timed=entry.segments.map { AppearanceEvent(start:$0.start,length:$0.length,
                begin:SliceTime($0.begin.numerator,$0.begin.denominator),end:SliceTime($0.end.numerator,$0.end.denominator),verticalEvent:nil) }
            let timedInput=timed.isEmpty ? nil : SliceInput.suppliedTimed(text:entry.text,japanese:japanese,events:timed)
            // Validate supplied cluster boundaries even when their visualization is disabled.
            if let timedInput,highlighting == .disabled { _=try SliceParagraph(timedInput) }
            let input=highlighting == .enabled && timedInput != nil ? timedInput! : SliceInput.supplied(text:entry.text,japanese:japanese)
            let layout=try SliceParagraph(input)
            // Lead never moves focus before the previous focus event or before zero.
            let previous=events.filter { $0.paragraph >= 0 }.map(\.time).max() ?? Time(0)
            let led=entry.time-presentation.focusLead
            events.append(.init(led>previous ? led : max(previous,Time(0)),order:i+1,paragraph:paragraphs.count))
            paragraphs.append(.init(input:input,position:position,begin:entry.time,end:end))
            lastEnd=end
            // Provisional inter-paragraph spacing; measured line advances remain unchanged.
            position += Double(layout.lines.count)*input.parameters.lineAdvance+110
        }
        let composition=try LyricsComposition(paragraphs:paragraphs,events:events,gaps:gaps,stagger:presentation.stagger)
        let v=project?.visibility
        let visibility=ScreenVisibility(artwork:v?.artwork ?? true,metadata:v?.metadata ?? true,
            progress:v?.progress ?? true,transport:v?.transport ?? true,volume:v?.volume ?? true,
            bottom:v?.bottom ?? true,handle:v?.handle ?? true,translation:v?.translation ?? true,sing:true)
        let controls=ScreenControls(translation:v?.translation ?? false,handle:v?.handle ?? true,
            sing:SingControl(rawValue:v?.sing ?? "hidden")!)
        let screen=try LyricsScreen(composition:composition,title:project?.title ?? "Local Lyrics",artist:project?.artist ?? "Supplied Recording",duration:schedule.audioEnd,volume:LyricsScreen.referenceVolume,
            events:[.init(Time(0),order:0,controls:controls)],visibility:visibility,background:presentation.background)
        renderer=try ScreenRenderer(screen,calibratedInactive:true,diagnosticMarkers:false,boundedCache:true,suppliedArtwork:artwork,icons:presentation.icons)
    }
}
