import Foundation

/// Fixed internal layouts. The video layouts are synthetic 9:16 adaptations, not native device geometry.
public enum LyricsCanvas: Sendable, Equatable {
    /// The native iPhone canvas, the full-width 9:16 video, and the 9:16 video whose controls and lyrics keep a
    /// margin on both sides for players that crop the sides of a full-screen video.
    case native, video, reels

    /// Width of the layout that holds every control and lyric line.
    public var width: Int {
        switch self {
        case .native: 1179
        case .video: 1440
        case .reels: 1304
        }
    }
    public var height: Int { self == .native ? 2556 : 2560 }
    /// Horizontal distance from the frame's left edge to the layout.
    ///
    /// Instagram Reels on an iPhone with a 1179 × 2556 display scales a 1080 × 1920 video to the height of the
    /// player and crops 51 video pixels from each side, measured on one screenshot. That is 68 pixels of this
    /// 1440-pixel frame; the measurement is provisional, and other devices and players may crop differently.
    public var inset: Double { self == .reels ? 68 : 0 }
    public var widthExtension: Double { Double(width - 1179) }
    public var bottomExtension: Double { self == .native ? 0 : 4 }
    public static func forWidth(_ width: Int) -> Self {
        switch width {
        case 1440: .video
        case 1304: .reels
        default: .native
        }
    }

    /// The same anchors position component rectangles and runtime symbol ink centers.
    public func offset(for part: ScreenPart) -> (x: Double, y: Double) {
        let x: Double
        switch part {
        case .more, .remaining, .next, .volumeHigh, .bottomRight, .singCompact, .singExpanded:
            x = widthExtension
        case .handle, .playback, .bottomCenter:
            x = widthExtension / 2
        default: x = 0
        }
        let y: Double
        switch part {
        case .progress, .elapsed, .remaining, .previous, .playback, .next, .volume, .volumeLow, .volumeHigh,
            .bottomLeft, .bottomCenter, .bottomRight, .translation, .singCompact, .singExpanded:
            y = bottomExtension
        default: y = 0
        }
        return (x, y)
    }

    public func bounds(_ native: ScreenBounds, for part: ScreenPart) -> ScreenBounds {
        let shift = offset(for: part)
        let grows = [.title, .artist, .progress, .volume].contains(part)
        return .init(
            native.x + shift.x, native.y + shift.y,
            native.width + (grows ? widthExtension : 0), native.height)
    }
    public var viewport: ScreenBounds { .init(72, 550, 1040 + widthExtension, 950 + bottomExtension) }
    public var expandedViewport: ScreenBounds { .init(72, 550, 1040 + widthExtension, Double(height) - 550) }
}
