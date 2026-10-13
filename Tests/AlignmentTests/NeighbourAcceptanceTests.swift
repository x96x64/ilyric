import Testing
@testable import AlignmentCore

/// Version 3 neighbour acceptance on synthetic evidence.
struct NeighbourAcceptanceTests {
    func row(_ id: Int, _ text: String, _ proposal: [Int], support: Double, similarity: Double) -> LineAlignment {
        LineAlignment(
            id: id, text: text, alignmentText: text.lowercased().filter(\.isLetter), proposal: proposal, estimate: nil,
            flags: [],
            support: support, similarity: similarity, words: nil, wordEstimates: nil, onsetTrim: nil,
            offsetExtension: nil)
    }
    @Test func acceptsFramedLinesOnlyWithVersion3() {
        let rows = [
            row(0, "paper skies above", [0, 2_000_000], support: -1, similarity: 0.9),
            row(1, "lanterns drifting", [2_000_000, 4_000_000], support: -5, similarity: 0.3),
            row(2, "out to the sea", [4_000_000, 6_000_000], support: -1, similarity: 0.8),
            row(3, "hold the light now", [6_000_000, 30_000_000], support: -5, similarity: 0.3),
        ]
        let level = [Double](repeating: 0, count: 1600)
        var v2 = rows
        var v3 = rows
        VocalRules.apply(&v2, level: level, reference: 0)
        VocalRules.apply(&v3, level: level, reference: 0, neighbours: true)
        #expect(v2.map { $0.estimate != nil } == [true, false, true, false])
        // Line 1 is framed by accepted lines; line 3 has one accepted neighbour but an implausible rate.
        #expect(v3.map { $0.estimate != nil } == [true, true, true, false])
        #expect(v3[1].flags.contains("neighbour_supported") && v3[1].flags.contains("weak_separated_support"))
    }
}
