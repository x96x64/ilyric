import Testing
import Foundation
@testable import AlignmentCore

/// Japanese alignment units of original text.
struct JapaneseUnitTests {
    let vocabulary = Set("今日はがるふ雨2".map(String.init))
    func words(_ s: String, _ pairs: [(String, String)]) -> [(range: Range<String.Index>, reading: String)] {
        pairs.map { (s.range(of: $0.0)!, $0.1) }
    }

    @Test func knownCharactersAreUnitsAndUnknownWordsUseReadings() throws {
        let line = "今日は雨が降る"
        let units = try japaneseUnits(line, vocabulary: vocabulary, words: words(line, [("降る", "ふる")]))
        #expect(units.map(\.labels) == [["今"], ["日"], ["は"], ["雨"], ["が"], ["ふ", "る"]])
        #expect(units.last!.startUTF16 == 5 && units.last!.lengthUTF16 == 2)
    }

    @Test func latinRunsAreInterpolatedAndKnownDigitsAligned() throws {
        let line = "Good morning 2 今日"
        let units = try japaneseUnits(line, vocabulary: vocabulary, words: [])
        #expect(units.map(\.labels) == [[], [], ["2"], ["今"], ["日"]])
        #expect(units[0].lengthUTF16 == 4 && units[1].lengthUTF16 == 7)
    }

    @Test func latinUnitsTakeTheGapBetweenAlignedNeighbours() {
        let units = [
            JapaneseUnit(startUTF16: 0, lengthUTF16: 1, labels: ["今"]),
            JapaneseUnit(startUTF16: 1, lengthUTF16: 4, labels: []),
            JapaneseUnit(startUTF16: 5, lengthUTF16: 1, labels: ["日"]),
        ]
        let words = japaneseWordProposals(
            units, labelUnits: [0, 2], indices: [0, 1], spans: [[10, 20], [40, 50]], duration: 10_000_000)
        #expect(words.map(\.interval) == [[200_000, 400_000], [400_000, 800_000], [800_000, 1_000_000]])
    }

    @Test func linesOfOnlyLatinWordsHaveNoLabels() throws {
        let source = try LyricSource(Data("Yeah\n今日\n".utf8))
        let targets = try japaneseTextTargets(source, vocabulary: vocabulary) { _ in [] }
        #expect(targets.tokens == ["今", "日"] && targets.owners == [1, 1])
        #expect(targets.japaneseUnits?[0]?.map(\.labels) == [[]])
    }
}
