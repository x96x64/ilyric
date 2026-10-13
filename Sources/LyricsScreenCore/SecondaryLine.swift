import Foundation
import TimelineCore

/// Background vocals drawn as a smaller line under their associated paragraph.
/// Size and offset were measured on the reference capture (docs/reports/background-vocals.md).
public struct SecondaryLine: Equatable, Sendable {
    public let text: String
    public let begin, end: Time
    /// Inherited timing retains dim text without focus-dependent highlighting or fill.
    package let hasExplicitTiming: Bool
    /// Font size relative to the paragraph's size; width comparison of identical text at equal weight.
    public static let sizeRatio = 0.652
    /// First secondary baseline below the paragraph's last baseline, in native pixels.
    public static let baselineOffset = 138.0
    /// Opacity of filled and unfilled background-vocal ink relative to white; the native secondary line never
    /// reaches the main line's full white.
    public static let filledOpacity = 0.70, unfilledOpacity = 0.45
    /// Extra layout space reserved below a paragraph for its first secondary line, beyond the usual spacing.
    public static let firstLineSpace = 56.0
    public init(text: String, begin: Time, end: Time) throws {
        try self.init(text:text,begin:begin,end:end,hasExplicitTiming:true)
    }
    package init(text: String, begin: Time, end: Time, hasExplicitTiming: Bool) throws {
        guard !text.isEmpty, text.utf16.count<300, !text.contains("\n"), begin<end else { throw ScreenError.invalid("Secondary line") }
        self.text=text;self.begin=begin;self.end=end;self.hasExplicitTiming=hasExplicitTiming
    }
    /// Fill progress in [0, 1] over the supplied interval.
    public func progress(at time: Time) -> Double {
        guard hasExplicitTiming else { return 0 }
        return time<=begin ? 0 : time>=end ? 1 : (time-begin).seconds/(end-begin).seconds
    }
}
