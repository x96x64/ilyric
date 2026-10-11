import Foundation
import SpikeCore

/// Background vocals drawn as a smaller line under a paragraph while it holds focus.
/// Size and offset were measured on the reference capture (docs/background-vocals.md).
public struct SecondaryLine: Equatable, Sendable {
    public let text: String
    public let begin, end: Time
    /// Font size relative to the paragraph's size; width comparison of identical text at equal weight.
    public static let sizeRatio = 0.652
    /// First secondary baseline below the paragraph's last baseline, in native pixels.
    public static let baselineOffset = 138.0
    /// Extra layout space reserved below a paragraph for its first secondary line, beyond the usual spacing.
    public static let firstLineSpace = 56.0
    public init(text: String, begin: Time, end: Time) throws {
        guard !text.isEmpty, text.utf16.count<300, !text.contains("\n"), begin<end else { throw SliceError.invalid("Secondary line") }
        self.text=text;self.begin=begin;self.end=end
    }
    /// Fill progress in [0, 1] over the supplied interval.
    public func progress(at time: Time) -> Double {
        time<=begin ? 0 : time>=end ? 1 : (time-begin).seconds/(end-begin).seconds
    }
}
