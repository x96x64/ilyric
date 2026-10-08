import Foundation
import CoreGraphics
import LyricsInputCore
import LyricsSliceCore
import LyricsSliceMac
import SpikeCore

/// Experimental line-level presentation: no word timing is manufactured.
public final class LocalScene {
    public let lyrics: LocalLyrics
    public let audio: LocalAudio
    public let schedule: OutputSchedule
    public let renderer: ScreenRenderer
    public init(lyrics: LocalLyrics, audio: LocalAudio, project: ExperimentalProject? = nil, artwork: CGImage? = nil) throws {
        self.lyrics=lyrics;self.audio=audio;schedule=try lyrics.validate(audioSamples:audio.sampleCount)
        var paragraphs:[CompositionParagraph]=[],events=[FocusEvent(Time(0),order:0,paragraph:-1)],position=0.0
        for (i,entry) in lyrics.entries.enumerated() {
            let end=i+1<lyrics.entries.count ? lyrics.entries[i+1].time : schedule.audioEnd
            if entry.text.isEmpty { events.append(.init(entry.time,order:i+1,paragraph:-1));continue }
            let japanese=entry.text.unicodeScalars.contains { (0x3040...0x30ff).contains($0.value) || (0x3400...0x9fff).contains($0.value) || (0xff66...0xff9d).contains($0.value) }
            let input=SliceInput.supplied(text:entry.text,japanese:japanese)
            let layout=try SliceParagraph(input)
            events.append(.init(entry.time,order:i+1,paragraph:paragraphs.count))
            paragraphs.append(.init(input:input,position:position,begin:entry.time,end:end))
            // Provisional inter-paragraph spacing; measured line advances remain unchanged.
            position += Double(layout.lines.count)*input.parameters.lineAdvance+110
        }
        let composition=try LyricsComposition(paragraphs:paragraphs,events:events)
        let v=project?.visibility
        let visibility=ScreenVisibility(artwork:v?.artwork ?? true,metadata:v?.metadata ?? true,
            progress:v?.progress ?? true,transport:v?.transport ?? true,volume:v?.volume ?? true,
            bottom:v?.bottom ?? true,handle:v?.handle ?? true,translation:v?.translation ?? true,sing:true)
        let controls=ScreenControls(translation:v?.translation ?? false,handle:v?.handle ?? true,
            sing:SingControl(rawValue:v?.sing ?? "hidden")!)
        let screen=try LyricsScreen(composition:composition,title:project?.title ?? "Local Lyrics",artist:project?.artist ?? "Supplied Recording",duration:schedule.audioEnd,volume:0.62,
            events:[.init(Time(0),order:0,controls:controls)],visibility:visibility)
        renderer=try ScreenRenderer(screen,calibratedInactive:true,diagnosticMarkers:false,boundedCache:true,suppliedArtwork:artwork)
    }
}
