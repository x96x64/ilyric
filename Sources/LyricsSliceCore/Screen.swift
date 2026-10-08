import Foundation
import SpikeCore

/// Native pixels, not inferred UIKit points. Bounds are half-open.
public struct ScreenBounds: Codable, Equatable, Sendable {
    public let x, y, width, height: Double
    public init(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
        self.x=x; self.y=y; self.width=width; self.height=height
    }
}
public enum ScreenPart: String, Codable, Sendable {
    case background, lyrics, artwork, title, artist, handle, progress, elapsed, remaining
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
public struct ScreenSnapshot: Equatable, Sendable {
    public let lyrics: CompositionSnapshot
    public let components: [ScreenComponent]
    public let progress, volume: Double
    public let elapsed, remaining: Int
    public let playing: Bool
}
/// Small fixed Music-like experimental composition, not a generic UI tree.
public struct LyricsScreen: Sendable {
    public let composition: LyricsComposition
    public let title, artist: String
    public let duration: Time
    public let volume: Double
    public let events: [ScreenEvent]
    // Native boundaries remain unknown. This inset and smooth fade are provisional.
    public static let viewport = ScreenBounds(72,550,1040,950)
    public static let fadeLength = 80.0
    public init(composition: LyricsComposition, title: String, artist: String, duration: Time,
                volume: Double, events: [ScreenEvent]) throws {
        guard duration>Time(0), volume.isFinite, (0...1).contains(volume),
              !title.isEmpty, !artist.isEmpty, title.utf16.count<=80, artist.utf16.count<=80,
              !events.isEmpty, Set(events.map(\.order)).count==events.count,
              events.allSatisfy({$0.time>=Time(0)}) else { throw SliceError.invalid("Experimental screen inputs") }
        let sorted=events.sorted { $0.time == $1.time ? $0.order<$1.order : $0.time<$1.time }
        guard sorted[0].time==Time(0) else { throw SliceError.invalid("Initial screen controls required") }
        self.composition=composition; self.title=title; self.artist=artist; self.duration=duration
        self.volume=volume; self.events=sorted
    }
    public static func fade(at y: Double) -> Double {
        let v=viewport, q=min(1,max(0,min(y-v.y,v.y+v.height-y)/fadeLength))
        return q*q*(3-2*q)
    }
    public static func contain(width: Double, height: Double, canvasWidth: Int) -> ScreenBounds {
        let s=min(width/Double(canvasWidth),height/2556)
        return .init((width-Double(canvasWidth)*s)/2,(height-2556*s)/2,Double(canvasWidth)*s,2556*s)
    }
    public func evaluate(_ time: Time) -> ScreenSnapshot {
        let lyrics=composition.evaluate(time),ui=(events.last(where:{$0.time<=time}) ?? events[0]).controls
        let media=max(0,min(duration.seconds,lyrics.media.seconds))
        let playing=(composition.clocks.last(where:{$0.output<=time}) ?? composition.clocks[0]).running
        var parts=[ScreenComponent]()
        func add(_ id: ScreenPart,_ b: ScreenBounds,_ z: Int,_ visible: Bool = true,_ evidence: String = "provisional shape at approximate measured position") {
            parts.append(.init(part:id,bounds:b,z:z,visible:visible,clips:true,evidence:evidence))
        }
        add(.background,.init(0,0,Double(composition.canvasWidth),2556),0,true,"original static palette gradient; provisional material")
        add(.lyrics,Self.viewport,1,true,"provisional clip and fade; inherited fitted typography and motion")
        add(.artwork,.init(96,276,216,216),2,true,"measured bounds, approximately ±2 px; original artwork")
        add(.title,.init(352,338,650,58),2,true,"measured ink origin; provisional header typography and clipping")
        add(.artist,.init(352,398,650,58),2,true,"measured ink origin; provisional header typography and clipping")
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
        return .init(lyrics:lyrics,components:parts,progress:media/duration.seconds,volume:volume,
                     elapsed:Int(media.rounded(.down)),remaining:Int(max(0,duration.seconds-media).rounded(.up)),playing:playing)
    }
    public static func synthetic() throws -> LyricsScreen {
        try .init(composition:.synthetic(),title:"Paper Skies",artist:"Field Notes",duration:Time(180),volume:0.62,events:[
            .init(Time(0),order:0,controls:.init(translation:true)),
            .init(Time(2),order:1,controls:.init(translation:true,sing:.compact)),
            .init(Time(4),order:2,controls:.init(sing:.expanded)),
            .init(Time(5),order:3,controls:.init(lower:false))])
    }
}
