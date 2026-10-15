import Foundation
import AlignmentCore

/// Hiragana readings of Japanese words from the system tokenizer, for characters the recognition model does not know.
///
/// The tokenizer's Latin transcription is converted to hiragana. Readings depend on the installed macOS version, so the
/// readings used are recorded in the alignment report.
public enum JapaneseReadings {
    public static func words(_ line: String) -> [(range: Range<String.Index>, reading: String)] {
        let text = line as CFString
        let length = CFStringGetLength(text)
        guard
            let tokenizer = CFStringTokenizerCreate(
                nil, text, CFRange(location: 0, length: length), kCFStringTokenizerUnitWord,
                Locale(identifier: "ja_JP") as CFLocale)
        else { return [] }
        var words = [(range: Range<String.Index>, reading: String)]()
        while CFStringTokenizerAdvanceToNextToken(tokenizer).rawValue != 0 {
            let r = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            guard let range = Range(NSRange(location: r.location, length: r.length), in: line),
                let latin = CFStringTokenizerCopyCurrentTokenAttribute(
                    tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String
            else { continue }
            let reading = NSMutableString(string: latin)
            CFStringTransform(reading, nil, kCFStringTransformLatinHiragana, false)
            words.append((range, (reading as String).filter { !$0.isWhitespace }))
        }
        return words
    }
}
