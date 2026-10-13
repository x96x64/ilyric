import Testing
import Foundation
@testable import AlignmentCore

/// Characters that alignment rejects, and the input line numbers used to report them. Synthetic text.
extension LyricsTextTests {
    @Test func unsupportedCharactersAreFoundOrAccepted() {
        for accepted in [
            "Plain words here", "Don’t stop, won't stop!", "Café au lait", "na-na (echo)", "Wait… “quoted” — dash",
            "Tab\there",
        ] {
            #expect(unsupportedCharacter(in: accepted) == nil, "\(accepted)")
        }
        #expect(unsupportedCharacter(in: "We were 40 days") == nil && unsupportedCharacter(in: "at 3:00") == nil)
        #expect(unsupportedCharacter(in: "It was 3.5 miles") == "3")
        #expect(unsupportedCharacter(in: "Room 007") == "0")
        #expect(unsupportedCharacter(in: "Pay $5") == "$")
        #expect(unsupportedCharacter(in: "One + one") == "+")
        #expect(unsupportedCharacter(in: "Hello 日本") == "日")
        #expect(unsupportedCharacter(in: "Привет") == "П")
    }

    @Test func numbersAreSpokenAsInLyrics() {
        let cases = [
            "7": "seven", "40": "forty", "101": "one hundred one", "1,000": "one thousand", "21": "twenty-one",
            "1999": "nineteen ninety-nine", "1984": "nineteen eighty-four", "1905": "nineteen oh five",
            "1900": "nineteen hundred",
            "2000": "two thousand", "2005": "two thousand five", "2015": "twenty fifteen",
            "999": "nine hundred ninety-nine",
            "3:00": "three o'clock", "3:15": "three fifteen", "3:05": "three oh five", "12:30": "twelve thirty",
            "1st": "first", "2nd": "second", "3rd": "third", "12th": "twelfth", "21st": "twenty-first",
            "40th": "fortieth",
            "90s": "nineties", "'90s": "nineties", "1980s": "nineteen eighties", "2000s": "two thousands",
        ]
        for (token, words) in cases { #expect(SpokenNumbers.spoken(token) == words, "\(token)") }
        for token in ["3.5", "1th", "2st", "3:7", "007", "1,00", "25:00", "5s"] {
            #expect(SpokenNumbers.spoken(token) == nil, "\(token)")
        }
        #expect(
            SpokenNumbers.expand("We walked 40 miles at 3:00 in '90s")
                == "We walked forty miles at three o'clock in nineties")
    }

    @Test func numbersAlignAsSpokenWordsButDisplayAsDigits() throws {
        let source = try LyricSource(Data("We walked 40 miles\nBack at 3:00".utf8))
        #expect(source.lines[0].text == "We walked 40 miles" && source.lines[0].alignmentText == "wewalkedfortymiles")
        #expect(source.lines[1].alignmentText == "backatthreeoclock")
        let targets = try textTargets(source)
        #expect(targets.tokens.joined() == "WE|WALKED|FORTY|MILES|BACK|AT|THREEO'CLOCK")
        // One display word per spoken number, so word timing maps back to the digits.
        let ranges = words(in: source.lines[0].text).map { String(source.lines[0].text[$0]) }
        #expect(ranges == ["We", "walked", "40", "miles"])
    }

    @Test func lyricLinesKeepTheirInputLineNumbers() {
        let raw = "[Verse 1]\nFirst line\n\n(only echo)\nSecond line (echo)\nWritten by: Somebody\n\n...\nThird line\n"
        let n = NormalizedLyrics(raw)
        #expect(n.sourceLines == [2, 5, 9])
        let lines = n.text.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == n.sourceLines.count)
        // Balanced splitting of a long paragraph keeps the order of the numbers.
        let long = NormalizedLyrics((1...9).map { "Line number \($0)" }.joined(separator: "\n"))
        #expect(long.sourceLines == Array(1...9))
        #expect(NormalizedLyrics("").sourceLines.isEmpty && NormalizedLyrics("[Chorus]\n...\n").sourceLines.isEmpty)
    }
}
