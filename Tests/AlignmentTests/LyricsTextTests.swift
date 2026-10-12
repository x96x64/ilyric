import Testing
import Foundation
@testable import AlignmentCore

/// Normalization of untimed lyrics as people write them (docs/command-line-interface.md, Lyrics Input). Synthetic text.
struct LyricsTextTests {
    @Test func dropsLabelsAndAttachesBackgroundVocals() throws {
        let raw="\u{FEFF}[Verse 1]\r\nPaper  skies (high above)\n(far away)\n...\n\n[Chorus]\nOpen (wide) rooms, (ah) now\n"
        let n=NormalizedLyrics(raw)
        #expect(n.text=="Paper skies\n\nOpen rooms, now\n")
        #expect(n.background==[0:"high above far away",1:"wide ah"])
        #expect(n.dropped.count==3)
        let source=try LyricSource(Data(n.text.utf8))
        #expect(source.lines.map(\.text)==["Paper skies","Open rooms, now"])
    }
    @Test func splitsLongParagraphsKeepingLineOrder() throws {
        let raw=(1...9).map { "Line number \($0) (echo \($0))" }.joined(separator:"\n")
        let n=NormalizedLyrics(raw)
        let source=try LyricSource(Data(n.text.utf8))
        #expect(source.paragraphs.map { $0.split(separator:"\n").count }==[3,3,3] && source.lines.count==9)
        #expect(source.lines[8].text=="Line number 9" && n.background[8]=="echo 9")
    }
    @Test func splitsFiveLinesAsThreeAndTwo() throws {
        let n=NormalizedLyrics((1...5).map { "Line \($0)" }.joined(separator:"\n"))
        #expect(try LyricSource(Data(n.text.utf8)).paragraphs.map { $0.split(separator:"\n").count }==[3,2])
    }
    @Test func leadingBackgroundWithoutLineIsDropped() {
        let n=NormalizedLyrics("(intro hum)\nFirst line")
        #expect(n.text=="First line\n" && n.background.isEmpty && n.dropped.count==1)
    }
    @Test func apostropheVariantsBecomeAlignable() throws {
        let n=NormalizedLyrics("You\u{02BC}ll be fine\nDon\u{2018}t you go")
        #expect(n.text=="You\u{2019}ll be fine\nDon\u{2019}t you go\n")
        #expect(try textTargets(LyricSource(Data(n.text.utf8))).tokens.filter { $0=="'" }.count==2)
    }
    @Test func writtenByLinesBecomeCredits() throws {
        let n=NormalizedLyrics("Paper skies\nOpen rooms\n\nWritten by: Jane  Roe, John Doe\nWRITTEN BY:Ann Lee")
        #expect(n.text=="Paper skies\nOpen rooms\n" && n.credits=="Jane Roe, John Doe, Ann Lee")
        #expect(NormalizedLyrics("Paper skies").credits==nil)
    }
}
