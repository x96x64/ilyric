import Foundation

/// Icon source for interface controls.
///
/// `original` draws iLyric's own vector placeholders and is used by every public fixture and test.
/// `systemSymbols` resolves SF Symbols at runtime on the rendering Mac; symbols are never bundled.
/// Apple's terms do not expressly license symbols in exported videos (docs/sf-symbols-rights-assessment.md).
public enum ScreenIconSet: String, Codable, Sendable { case original, systemSymbols }

public enum SymbolWeight: String, Codable, Sendable { case regular, medium, semibold }

/// A runtime-resolved symbol drawn with its ink bounds centered on a measured native point.
public struct ControlSymbol: Equatable, Sendable {
    public let name: String
    /// Point size; native canvas pixels are three times points on the reference iPhone.
    public let pointSize: Double
    public let weight: SymbolWeight
    /// White ink opacity over the background.
    public let opacity: Double
    /// Measured ink-bounds center in native screenshot pixels, top-left origin.
    public let centerX, centerY: Double
    /// Optional translucent white disc behind the symbol, diameter in native pixels.
    public let disc: Double?
    public let discOpacity: Double
    /// When true the symbol is cut out of the disc rather than drawn over it.
    public let knockout: Bool
}

/// Fits to eight private iPhone 16 screenshots (docs/control-symbols.md). Ink extents repeat within ±1 px.
/// The Sing glyph has no public symbol equivalent; `music.mic` is a disclosed approximation.
public enum ControlSymbols {
    public static let nativeScale = 3.0
    public static func symbol(for part: ScreenPart, playing: Bool) -> ControlSymbol? {
        switch part {
        case .previous: return .init(name:"backward.fill",pointSize:29,weight:.semibold,opacity:1,centerX:269.5,centerY:1948,disc:nil,discOpacity:0,knockout:false)
        case .next: return .init(name:"forward.fill",pointSize:29,weight:.semibold,opacity:1,centerX:910,centerY:1948,disc:nil,discOpacity:0,knockout:false)
        case .playback:
            return playing ? .init(name:"pause.fill",pointSize:47,weight:.semibold,opacity:1,centerX:590,centerY:1948.5,disc:nil,discOpacity:0,knockout:false)
                           : .init(name:"play.fill",pointSize:40,weight:.semibold,opacity:1,centerX:595.5,centerY:1949.5,disc:nil,discOpacity:0,knockout:false)
        case .volumeLow: return .init(name:"speaker.fill",pointSize:13.5,weight:.medium,opacity:0.56,centerX:114,centerY:2203.5,disc:nil,discOpacity:0,knockout:false)
        case .volumeHigh: return .init(name:"speaker.wave.3.fill",pointSize:13.5,weight:.medium,opacity:0.58,centerX:1048.5,centerY:2203.5,disc:nil,discOpacity:0,knockout:false)
        case .bottomLeft: return .init(name:"quote.bubble.fill",pointSize:21,weight:.regular,opacity:1,centerX:248,centerY:2361,disc:114,discOpacity:0.57,knockout:true)
        case .bottomCenter: return .init(name:"airplay.audio",pointSize:21,weight:.medium,opacity:0.69,centerX:590.5,centerY:2358,disc:nil,discOpacity:0,knockout:false)
        case .bottomRight: return .init(name:"list.bullet",pointSize:21,weight:.medium,opacity:0.57,centerX:931.5,centerY:2358.5,disc:nil,discOpacity:0,knockout:false)
        case .translation: return .init(name:"translate",pointSize:17,weight:.medium,opacity:1,centerX:153,centerY:1531,disc:84,discOpacity:0.30,knockout:false)
        case .singCompact: return .init(name:"music.mic",pointSize:20,weight:.semibold,opacity:1,centerX:1026,centerY:1532.5,disc:84,discOpacity:0.30,knockout:false)
        default: return nil
        }
    }
}
