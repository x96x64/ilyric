import Foundation
import TimelineCore

/// Native pixels, not inferred UIKit points. Bounds are half-open.
public struct ScreenBounds: Codable, Equatable, Sendable {
    public let x, y, width, height: Double
    public init(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
        self.x=x; self.y=y; self.width=width; self.height=height
    }
}
public enum ScreenPart: String, Codable, Sendable {
    case background, lyrics, artwork, title, artist, more, handle, progress, elapsed, remaining
    case previous, playback, next, volume, volumeLow, volumeHigh, bottomLeft, bottomCenter, bottomRight
    case translation, singCompact, singExpanded
}
public struct ScreenComponent: Codable, Equatable, Sendable {
    public let part: ScreenPart
    public let bounds: ScreenBounds
    public let z: Int
    public let visible: Bool
    public let clips: Bool
    public let evidence: String
}
public enum SingControl: String, Codable, Sendable { case hidden, compact, expanded }
public struct ScreenControls: Equatable, Sendable {
    public let lower, translation, handle: Bool
    public let sing: SingControl
    public init(lower: Bool = true, translation: Bool = false, handle: Bool = true, sing: SingControl = .hidden) {
        self.lower=lower; self.translation=translation; self.handle=handle; self.sing=sing
    }
}
public struct ScreenEvent: Sendable {
    public let time: Time
    public let order: Int
    public let controls: ScreenControls
    public init(_ time: Time, order: Int, controls: ScreenControls) { self.time=time; self.order=order; self.controls=controls }
}
/// Static component masks intersect authored events; they never remove layout nodes.
public struct ScreenVisibility: Equatable, Sendable {
    public let artwork, metadata, progress, transport, volume, bottom, handle, translation, sing: Bool
    public init(artwork: Bool = true, metadata: Bool = true, progress: Bool = true,
                transport: Bool = true, volume: Bool = true, bottom: Bool = true,
                handle: Bool = true, translation: Bool = true, sing: Bool = true) {
        self.artwork=artwork;self.metadata=metadata;self.progress=progress;self.transport=transport
        self.volume=volume;self.bottom=bottom;self.handle=handle;self.translation=translation;self.sing=sing
    }
    public func permits(_ part: ScreenPart) -> Bool {
        switch part {
        case .artwork: return artwork
        case .title,.artist,.more: return metadata
        case .progress,.elapsed,.remaining: return progress
        case .previous,.playback,.next: return transport
        case .volume,.volumeLow,.volumeHigh: return volume
        case .bottomLeft,.bottomCenter,.bottomRight: return bottom
        case .handle: return handle
        case .translation: return translation
        case .singCompact,.singExpanded: return sing
        case .background,.lyrics: return true
        }
    }
}
public struct ScreenSnapshot: Equatable, Sendable {
    public let lyrics: CompositionSnapshot
    public let components: [ScreenComponent]
    public let progress, volume: Double
    public let elapsed, remaining: Int
    public let playing: Bool
    /// Downward offset in pixels and opacity of the lower controls while they hide.
    public var lowerOffset = 0.0, lowerOpacity = 1.0
    /// Visibility of lyrics in the area that the lower controls vacate, from 0 to 1.
    public var lyricsReveal = 0.0
}
/// Lower-control hide transition sampled frame by frame from the reference capture at 60 fps
/// (docs/reports/control-auto-hide.md); values between samples are interpolated linearly.
public enum ControlTransition {
    public static let interval = 1.0/60
    public static let offsets: [Double] = [0,29,79,141,208,267,323,372,413,460,500,530,550]
    public static let opacities: [Double] = [1,0.85,0.65,0.46,0.31,0.21,0.13,0.08,0.05,0.03,0.02,0.01,0]
    public static var duration: Double { Double(offsets.count-1)*interval }
    public static func sample(_ t: Double) -> (offset: Double, opacity: Double) {
        let x=min(max(0,t/interval),Double(offsets.count-1)),i=min(Int(x),offsets.count-2),f=x-Double(i)
        return (offsets[i]+(offsets[i+1]-offsets[i])*f,opacities[i]+(opacities[i+1]-opacities[i])*f)
    }
}
/// Small fixed Music-like experimental composition, not a generic UI tree.
public struct LyricsScreen: Sendable {
    public let composition: LyricsComposition
    public var canvas: LyricsCanvas { composition.canvas }
    public let title, artist: String
    public let duration: Time
    public let volume: Double
    public let events: [ScreenEvent]
    public let visibility: ScreenVisibility
    /// Optional deterministic artwork-derived background; nil retains the original static gradient.
    public let background: ArtworkBackground?
    // Native boundaries remain unknown. This inset and smooth fade are provisional.
    public static let viewport = ScreenBounds(72,550,1040,950)
    public static let fadeLength = 80.0
    /// While lower controls are hidden, native lyrics extend to the bottom edge and fade over about
    /// 300 pixels (docs/reports/control-auto-hide.md); the top edge is unchanged.
    public static let expandedViewport = ScreenBounds(72,550,1040,2006)
    public static let expandedBottomFade = 300.0
    /// Opt-in: use the expanded viewport whenever lower controls are hidden.
    public let expandsLyrics: Bool
    /// Volume fill measured in eight reference screenshots: the fill ends at x = 576 on the bar [171, 982),
    /// that is 405 of 811 pixels, slightly below one half.
    public static let referenceVolume = 405.0/811.0
    public init(composition: LyricsComposition, title: String, artist: String, duration: Time,
                volume: Double, events: [ScreenEvent], visibility: ScreenVisibility = .init(),
                background: ArtworkBackground? = nil, expandsLyrics: Bool = false) throws {
        guard duration>Time(0), volume.isFinite, (0...1).contains(volume),
              !title.isEmpty, !artist.isEmpty, title.utf16.count<=80, artist.utf16.count<=80,
              !events.isEmpty, Set(events.map(\.order)).count==events.count,
              events.allSatisfy({$0.time>=Time(0)}) else { throw ScreenError.invalid("Experimental screen inputs") }
        let sorted=events.sorted { $0.time == $1.time ? $0.order<$1.order : $0.time<$1.time }
        guard sorted[0].time==Time(0) else { throw ScreenError.invalid("Initial screen controls required") }
        self.composition=composition; self.title=title; self.artist=artist; self.duration=duration
        self.volume=volume; self.events=sorted;self.visibility=visibility;self.background=background
        self.expandsLyrics=expandsLyrics
    }
    public static func fade(at y: Double) -> Double { fade(at:y,viewport:viewport,bottomFade:fadeLength) }
    public static func fade(at y: Double, viewport v: ScreenBounds, bottomFade: Double) -> Double {
        let q=min(1,max(0,min((y-v.y)/fadeLength,(v.y+v.height-y)/bottomFade)))
        return q*q*(3-2*q)
    }
    public static func contain(width: Double, height: Double, canvasWidth: Int, canvasHeight: Int = 2556) -> ScreenBounds {
        let h=Double(canvasHeight),s=min(width/Double(canvasWidth),height/h)
        return .init((width-Double(canvasWidth)*s)/2,(height-h*s)/2,Double(canvasWidth)*s,h*s)
    }
    public func evaluate(_ time: Time) -> ScreenSnapshot {
        let lyrics=composition.evaluate(time),current=events.lastIndex(where:{$0.time<=time}) ?? 0
        var ui=events[current].controls,lowerOffset=0.0,lowerOpacity=1.0
        // While the opt-in hide transition runs, the lower controls stay drawn and move out of view.
        let hiding=expandsLyrics && !ui.lower && current>0 && events[current-1].controls.lower &&
            (time-events[current].time).seconds<ControlTransition.duration
        if hiding {
            let s=ControlTransition.sample((time-events[current].time).seconds)
            lowerOffset=s.offset;lowerOpacity=s.opacity
            ui=ScreenControls(lower:true,translation:events[current-1].controls.translation,handle:ui.handle,sing:events[current-1].controls.sing)
        }
        let media=max(0,min(duration.seconds,lyrics.media.seconds))
        let playing=(composition.clocks.last(where:{$0.output<=time}) ?? composition.clocks[0]).running
        var parts=[ScreenComponent]()
        func add(_ id: ScreenPart,_ b: ScreenBounds,_ z: Int,_ visible: Bool = true,_ evidence: String = "provisional shape at approximate measured position") {
            let provenance=canvas == .video ? "synthetic 9:16 adaptation of: "+evidence : evidence
            parts.append(.init(part:id,bounds:canvas.bounds(b,for:id),z:z,visible:visible && visibility.permits(id),clips:true,evidence:provenance))
        }
        add(.background,.init(0,0,Double(composition.canvasWidth),Double(canvas.height)),0,true,background == nil ?
            "original static palette gradient; provisional material" :
            "fitted artwork-derived layers, blur, and color transfer; statistical reconstruction, unmatched phase")
        let expanded=expandsLyrics && (!ui.lower || hiding)
        add(.lyrics,expanded ? canvas.expandedViewport : canvas.viewport,1,true,expanded ?
            "measured expanded extent with controls hidden; provisional fade" : "provisional clip and fade; inherited fitted typography and motion")
        add(.artwork,.init(96,276,216,216),2,true,"measured bounds, approximately ±2 px; original artwork")
        add(.title,.init(352,338,650,58),2,true,"measured ink origin; provisional header typography and clipping")
        add(.artist,.init(352,398,650,58),2,true,"measured ink origin; provisional header typography and clipping")
        add(.more,.init(1007,378,56,12),3,true,"development-recording ink bounds, approximately ±1 px; persists during lower-control hiding; foreground order estimated")
        add(.handle,.init(500,198,180,12),2,ui.handle,"measured bounds, approximately ±1 px")
        add(.progress,.init(96,1683,987,21),2,ui.lower,"measured bounds, approximately ±1 px; supplied media progress")
        add(.elapsed,.init(96,1730,200,48),2,ui.lower,"provisional time-label geometry")
        add(.remaining,.init(883,1730,200,48),2,ui.lower,"provisional time-label geometry")
        add(.previous,.init(218,1894,106,106),2,ui.lower)
        add(.playback,.init(537,1894,106,106),2,ui.lower)
        add(.next,.init(856,1894,106,106),2,ui.lower)
        add(.volume,.init(171,2192,811,22),2,ui.lower,"measured bounds, approximately ±1 px; supplied level")
        add(.volumeLow,.init(96,2183,40,40),2,ui.lower,"original symbol; provisional geometry")
        add(.volumeHigh,.init(1020,2183,40,40),2,ui.lower,"original symbol; provisional geometry")
        add(.bottomLeft,.init(212,2323,72,72),2,ui.lower)
        add(.bottomCenter,.init(554,2323,72,72),2,ui.lower)
        add(.bottomRight,.init(896,2323,72,72),2,ui.lower)
        add(.translation,.init(111,1488,84,84),3,ui.translation)
        add(.singCompact,.init(984,1488,84,84),3,ui.sing == .compact)
        add(.singExpanded,.init(969,1353,114,234),3,ui.sing == .expanded,"measured bounds, approximately ±3 px; original control placeholder only")
        // The native elapsed label rounds to the nearest second (docs/reports/reference-clock-and-word-motion.md).
        var snapshot=ScreenSnapshot(lyrics:lyrics,components:parts,progress:media/duration.seconds,volume:volume,
                     elapsed:Int(media.rounded()),remaining:Int(max(0,duration.seconds-media).rounded()),playing:playing)
        snapshot.lowerOffset=lowerOffset;snapshot.lowerOpacity=lowerOpacity;snapshot.lyricsReveal=expanded ? 1-lowerOpacity*(hiding ? 1:0) : 0
        return snapshot
    }
    public static func synthetic(background: ArtworkBackground? = nil) throws -> LyricsScreen {
        try .init(composition:.synthetic(),title:"Paper Skies",artist:"Field Notes",duration:Time(180),volume:0.62,events:[
            .init(Time(0),order:0,controls:.init(translation:true)),
            .init(Time(2),order:1,controls:.init(translation:true,sing:.compact)),
            .init(Time(4),order:2,controls:.init(sing:.expanded)),
            .init(Time(5),order:3,controls:.init(lower:false))],background:background)
    }
}
