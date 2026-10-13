import Foundation
import Testing
@testable import AlignmentCore

/// Original numerical activity fixtures; no recordings or model inference are required.
struct FallbackPlacementTests {
    static func row(_ id: Int, _ estimate: [Int]? = nil) -> LineAlignment {
        LineAlignment(
            id: id, text: String(id), alignmentText: String(id), proposal: estimate, estimate: estimate,
            flags: [], support: nil, similarity: nil, words: nil, wordEstimates: nil, onsetTrim: nil,
            offsetExtension: nil)
    }
    static func levels(_ duration: Int, _ regions: [[Int]]) -> [Double] {
        (0..<duration / VocalRules.frameMicroseconds).map { frame in
            regions.contains {
                $0[0] <= frame * VocalRules.frameMicroseconds && frame * VocalRules.frameMicroseconds < $0[1]
            } ? 0 : -120
        }
    }
    func moved(_ rows: [LineAlignment], _ duration: Int, _ regions: [[Int]], protected: Set<Int> = []) -> [Int: [Int]] {
        TTMLExport.relocateBoundaryFallbacks(
            rows, fills: TTMLExport.fillUnresolved(rows, duration: duration),
            duration: duration, level: Self.levels(duration, regions), reference: 0, protectedLines: protected)
    }

    @Test func positiveLeadingAndTrailingUseTheClosestComponent() {
        let leading = [Self.row(0), Self.row(1, [20_000_000, 22_000_000])]
        #expect(
            moved(leading, 24_000_000, [[4_000_000, 8_000_000], [12_000_000, 18_000_000]])[0] == [
                12_000_001, 14_500_000,
            ])
        let trailing = [Self.row(0, [2_000_000, 4_000_000]), Self.row(1)]
        #expect(
            moved(trailing, 24_000_000, [[8_000_000, 12_000_000], [16_000_000, 22_000_000]])[1] == [
                8_000_001, 10_500_000,
            ])
    }
    @Test func insufficientClosestComponentNeverSearchesFarther() {
        let leading = [Self.row(0), Self.row(1, [20_000_000, 22_000_000])]
        #expect(
            moved(leading, 24_000_000, [[8_000_000, 14_000_000], [16_000_000, 18_000_000]])
                == TTMLExport.fillUnresolved(leading, duration: 24_000_000))
        let trailing = [Self.row(0, [2_000_000, 4_000_000]), Self.row(1)]
        #expect(
            moved(trailing, 24_000_000, [[6_000_000, 8_000_000], [12_000_000, 18_000_000]])
                == TTMLExport.fillUnresolved(trailing, duration: 24_000_000))
    }
    @Test func absentActivityAndAcceptedAttackOrTailKeepSavedPlacements() {
        let leading = [Self.row(0), Self.row(1, [8_120_000, 10_280_000])]
        let trailing = [Self.row(0, [2_100_000, 4_200_000]), Self.row(1)]
        for (rows, regions) in [
            (leading, [[8_020_000, 9_040_000], [9_100_000, 9_560_000], [9_600_000, 10_280_000]]),
            (trailing, [[2_020_000, 3_040_000], [3_100_000, 3_560_000], [3_600_000, 4_280_000]]),
        ] {
            let baseline = TTMLExport.fillUnresolved(rows, duration: 20_000_000)
            #expect(moved(rows, 20_000_000, regions) == baseline)
            #expect(moved(rows, 20_000_000, []) == baseline)
            #expect(
                TTMLExport.relocateBoundaryFallbacks(
                    rows, fills: baseline, duration: 20_000_000,
                    level: Array(repeating: -120, count: 1000), reference: -120) == baseline)
        }
    }
    @Test func multipleBoundaryRunsPreserveSpacingInteriorAndAcceptedRows() throws {
        let rows = [
            Self.row(0), Self.row(1), Self.row(2, [20_000_000, 22_000_000]), Self.row(3),
            Self.row(4, [24_000_000, 26_000_000]), Self.row(5), Self.row(6),
        ]
        let baseline = TTMLExport.fillUnresolved(rows, duration: 40_000_000)
        let result = moved(rows, 40_000_000, [[12_000_000, 18_000_000], [30_000_000, 36_000_000]])
        #expect(result[0] == [12_000_001, 14_500_000] && result[1] == [14_500_001, 17_000_000])
        #expect(result[5] == [30_000_001, 32_500_000] && result[6] == [32_500_001, 35_000_000])
        #expect(result[3] == baseline[3] && result[2] == nil && result[4] == nil)
        for id in [0, 1, 3, 5, 6] {
            #expect(result[id]![1] - result[id]![0] == baseline[id]![1] - baseline[id]![0])
        }
        let before = try TTMLExport.ttml(rows, fills: baseline)
        let after = try TTMLExport.ttml(rows, fills: result)
        let expression = try NSRegularExpression(pattern: "<p\\b[^>]*>[\\s\\S]*?</p>")
        func paragraphs(_ xml: String) -> [String] {
            expression.matches(in: xml, range: NSRange(xml.startIndex..., in: xml)).map {
                (xml as NSString).substring(with: $0.range)
            }
        }
        let a = paragraphs(before)
        let b = paragraphs(after)
        #expect(a.count == rows.count && b.count == rows.count && a[2] == b[2] && a[4] == b[4])
        #expect(rows[2].estimate == [20_000_000, 22_000_000] && rows[4].estimate == [24_000_000, 26_000_000])
    }
    @Test func omittedAndBackingAttachedRunsAndAnchorlessRowsAreProtected() {
        let rows = [Self.row(0, [2_000_000, 4_000_000]), Self.row(1), Self.row(2)]
        let baseline = TTMLExport.fillUnresolved(rows, duration: 20_000_000)
        for protected: Set<Int> in [[1], [2]] {
            #expect(moved(rows, 20_000_000, [[10_000_000, 18_000_000]], protected: protected) == baseline)
        }
        let anchorless = [Self.row(0), Self.row(1)]
        #expect(
            moved(anchorless, 20_000_000, [[4_000_000, 18_000_000]])
                == TTMLExport.fillUnresolved(anchorless, duration: 20_000_000))
    }
    @Test func halfOpenExactCapacityAudioBoundsAndStrictThresholdAreDeterministic() {
        let rows = [Self.row(0, [0, 4_000_000]), Self.row(1)]
        let baseline = TTMLExport.fillUnresolved(rows, duration: 10_000_000)
        let regions = [[7_500_000, 10_000_000]]
        let expected = moved(rows, 10_000_000, regions)
        #expect(expected[1] == [7_500_001, 10_000_000])
        for _ in 0..<5 { #expect(moved(rows, 10_000_000, regions) == expected) }
        #expect(moved(rows, 10_000_000, [[7_520_000, 10_000_000]]) == baseline)
        #expect(moved(rows, 10_000_000, [[4_000_000, 10_000_000]]) == baseline)
        #expect(
            TTMLExport.relocateBoundaryFallbacks(
                rows, fills: baseline, duration: 10_000_000,
                level: Array(repeating: -30, count: 500), reference: 0) == baseline)
        let outside = Self.levels(12_000_000, [[8_000_000, 12_000_000]])
        #expect(
            TTMLExport.relocateBoundaryFallbacks(
                rows, fills: baseline, duration: 10_000_000, level: outside, reference: 0) == baseline)
    }
}
