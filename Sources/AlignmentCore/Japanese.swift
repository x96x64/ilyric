import Foundation

/// Language of untimed lyrics; it selects the recognition model and how text becomes alignment targets.
public enum LyricLanguage: String, Sendable, CaseIterable {
    case english = "en"
    case japanese = "ja"
}

/// One display span of a Japanese lyric line that receives its own timing.
///
/// A unit is a single Japanese character whose label the recognition model knows, a word whose characters the model
/// does not all know (aligned by its hiragana reading), a run of digits the model knows, or a run of Latin letters,
/// which the Japanese model cannot recognize and which is timed by interpolation between its neighbours.
public struct JapaneseUnit: Equatable, Sendable {
    public let startUTF16, lengthUTF16: Int
    /// CTC labels, or empty for a Latin run that is interpolated.
    public let labels: [String]
}

/// Whether a scalar is written Japanese: kana, the prolonged sound mark, kanji, or the iteration mark.
func isJapanese(_ s: Unicode.Scalar) -> Bool {
    switch s.value {
    case 0x3041...0x3096, 0x30A1...0x30FA, 0x30FC, 0x3005, 0x4E00...0x9FFF, 0x3400...0x4DBF, 0xF900...0xFAFF: true
    default: false
    }
}

/// Alignment units of one line. `words` are the line's morphological words with their hiragana readings, from the
/// platform tokenizer; a word containing a character outside `vocabulary` is aligned as one unit by its reading.
public func japaneseUnits(
    _ line: String, vocabulary: Set<String>, words: [(range: Range<String.Index>, reading: String)]
) throws -> [JapaneseUnit] {
    func utf16(_ i: String.Index) -> Int { line.utf16.distance(from: line.utf16.startIndex, to: i) }
    var units = [JapaneseUnit]()
    var index = line.startIndex
    while index < line.endIndex {
        let character = line[index]
        let next = line.index(after: index)
        let scalar = character.unicodeScalars.first!
        if character.unicodeScalars.count == 1, isJapanese(scalar) {
            if vocabulary.contains(String(character)) {
                units.append(
                    .init(
                        startUTF16: utf16(index), lengthUTF16: utf16(next) - utf16(index), labels: [String(character)]))
                index = next
                continue
            }
            // An unknown character is aligned with the reading of the whole word that contains it.
            guard let word = words.first(where: { $0.range.contains(index) }) else {
                throw AlignmentError.invalid("No reading is available for \"\(character)\"")
            }
            let labels = word.reading.map(String.init)
            guard !labels.isEmpty, labels.allSatisfy(vocabulary.contains) else {
                throw AlignmentError.invalid("The reading of \"\(line[word.range])\" cannot be aligned")
            }
            // Characters of the word already emitted as their own units are replaced by the word unit.
            let start = utf16(word.range.lowerBound)
            units.removeAll { $0.startUTF16 >= start }
            units.append(.init(startUTF16: start, lengthUTF16: utf16(word.range.upperBound) - start, labels: labels))
            index = word.range.upperBound
            continue
        }
        if character.isASCII, character.isLetter || character.isNumber {
            // A run of Latin letters, digits, and inner apostrophes forms one unit.
            var end = next
            while end < line.endIndex, line[end].isASCII,
                line[end].isLetter || line[end].isNumber || line[end] == "'"
            {
                end = line.index(after: end)
            }
            let run = String(line[index..<end])
            let digits = run.allSatisfy(\.isNumber) && run.allSatisfy { vocabulary.contains(String($0)) }
            units.append(
                .init(
                    startUTF16: utf16(index), lengthUTF16: utf16(end) - utf16(index),
                    labels: digits ? run.map(String.init) : []))
            index = end
            continue
        }
        index = next
    }
    return units
}

/// CTC targets of Japanese lyrics: the labels of every aligned unit in order, with no separators, because the
/// Japanese model rarely emits its word delimiter. `units` maps each label to its line's unit index.
public func japaneseTextTargets(
    _ source: LyricSource, vocabulary: Set<String>,
    words: (String) -> [(range: Range<String.Index>, reading: String)]
) throws -> TextTargets {
    var tokens = [String]()
    var owners = [Int?]()
    var unitOf = [Int?]()
    var lines = [Int: [JapaneseUnit]]()
    for line in source.lines {
        let units = try japaneseUnits(line.text, vocabulary: vocabulary, words: words(line.text))
        lines[line.id] = units
        for (u, unit) in units.enumerated() {
            for label in unit.labels {
                tokens.append(label)
                owners.append(line.id)
                unitOf.append(u)
            }
        }
    }
    guard !tokens.isEmpty else { throw AlignmentError.invalid("The lyrics contain no Japanese text to align") }
    guard tokens.count <= 12000 else { throw AlignmentError.invalid("Full-song text exceeds 12,000 CTC labels") }
    return TextTargets(tokens: tokens, owners: owners, units: unitOf, japaneseUnits: lines)
}
