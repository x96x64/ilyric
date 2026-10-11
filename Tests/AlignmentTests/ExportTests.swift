import Testing
import Foundation
@testable import AlignmentCore

/// TTML export rules mirrored from scripts/alignment/full_song.py `to_ttml` (word granularity).
struct ExportTests {
    func row(_ id: Int,_ text: String,_ estimate: [Int]?,words: [WordSpan]?=nil,similarity: Double=0.9,flags: [String]=[]) -> LineAlignment {
        LineAlignment(id:id,text:text,alignmentText:text.lowercased(),proposal:estimate,estimate:estimate,flags:flags,support:-1,
                      similarity:similarity,words:nil,wordEstimates:words,onsetTrim:nil,offsetExtension:nil)
    }
    @Test func exportsWordsSteadyFillsPlacementsAndBackgroundVocals() throws {
        let rows=[
            row(0,"Mm-hmm",nil),
            row(1,"Paper skies",[1_000_000,2_500_000],words:[.init(startUTF16:0,lengthUTF16:5,interval:[1_000_000,1_500_000]),.init(startUTF16:6,lengthUTF16:5,interval:[1_600_000,2_500_000])]),
            row(2,"Quiet & low",[3_000_000,4_000_000],words:[.init(startUTF16:0,lengthUTF16:5,interval:[3_000_000,3_400_000])],similarity:0.2),
            row(3,"Open rooms",nil),
            row(4,"Na-na-na",[6_000_000,7_000_000])]
        let fills=TTMLExport.fillUnresolved(rows,duration:10_000_000)
        #expect(fills[0]==[1,1_000_000] && fills[3]==[4_000_001,6_000_000])
        let background=TTMLExport.backgroundVocals("Paper skies (high above)\n(far away)\nOpen rooms",rows:rows)
        #expect(background==[1:"high above far away"])
        let xml=try TTMLExport.ttml(rows,fills:fills,background:background)
        #expect(!xml.contains("Mm-hmm"))   // untimed vocable line omitted
        #expect(xml.contains("<p begin=\"1s\" end=\"2.5s\"><span begin=\"0s\" end=\"0.5s\">Paper </span><span begin=\"0.6s\" end=\"1.5s\">skies</span><span ttm:role=\"x-bg\">high above far away</span></p>"))
        #expect(xml.contains("<p begin=\"3s\" end=\"4s\"><span begin=\"0s\" end=\"1s\">Quiet &amp; low</span></p>"))  // low confidence: steady fill
        #expect(xml.contains("<p begin=\"4.000001s\" end=\"6s\">Open rooms</p>"))  // placement, line-level
        #expect(xml.contains(">Na-na-na</p>") && xml.contains("xmlns:ttm="))     // timed vocable line kept
        #expect(TTMLExport.nonlexical("Hoo, hoo, hoo") && !TTMLExport.nonlexical("Yeah, make that change"))
    }
}
