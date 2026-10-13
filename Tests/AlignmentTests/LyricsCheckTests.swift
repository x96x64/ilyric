import Testing
import Foundation
@testable import AlignmentCore

/// Characters that alignment rejects, and the input line numbers used to report them. Synthetic text.
extension LyricsTextTests {
    @Test func unsupportedCharactersAreFoundOrAccepted() {
        for accepted in ["Plain words here", "Don’t stop, won't stop!", "Café au lait", "na-na (echo)", "Wait… “quoted” — dash", "Tab\there"] {
            #expect(unsupportedCharacter(in: accepted)==nil, "\(accepted)")
        }
        #expect(unsupportedCharacter(in: "We were 40 days")=="4")
        #expect(unsupportedCharacter(in: "at 3:00")=="3")
        #expect(unsupportedCharacter(in: "Pay $5")=="$")
        #expect(unsupportedCharacter(in: "One + one")=="+")
        #expect(unsupportedCharacter(in: "Hello 日本")=="日")
        #expect(unsupportedCharacter(in: "Привет")=="П")
    }

    @Test func lyricLinesKeepTheirInputLineNumbers() {
        let raw="[Verse 1]\nFirst line\n\n(only echo)\nSecond line (echo)\nWritten by: Somebody\n\n...\nThird line\n"
        let n=NormalizedLyrics(raw)
        #expect(n.sourceLines==[2,5,9])
        let lines=n.text.components(separatedBy:"\n").filter { !$0.isEmpty }
        #expect(lines.count==n.sourceLines.count)
        // Balanced splitting of a long paragraph keeps the order of the numbers.
        let long=NormalizedLyrics((1...9).map { "Line number \($0)" }.joined(separator:"\n"))
        #expect(long.sourceLines==Array(1...9))
        #expect(NormalizedLyrics("").sourceLines.isEmpty && NormalizedLyrics("[Chorus]\n...\n").sourceLines.isEmpty)
    }
}
