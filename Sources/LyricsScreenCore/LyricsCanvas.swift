import Foundation

/// Fixed internal layouts. The video layout is a synthetic 9:16 adaptation, not native device geometry.
public enum LyricsCanvas: Sendable, Equatable {
    case native, video

    public var width: Int { self == .video ? 1440 : 1179 }
    public var height: Int { self == .video ? 2560 : 2556 }
    public var widthExtension: Double { self == .video ? 261 : 0 }
    public var bottomExtension: Double { self == .video ? 4 : 0 }
    public static func forWidth(_ width: Int) -> Self { width == 1440 ? .video : .native }

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
