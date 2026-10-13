import Foundation

/// Spoken English for numbers written in lyrics, used only for alignment; display text keeps the digits.
///
/// Supported forms are cardinals with optional thousands separators (40, 1,000), four-digit years (1999 →
/// nineteen ninety-nine, 2005 → two thousand five), clock times (3:00 → three o'clock, 3:15 → three fifteen,
/// 3:05 → three oh five), ordinals (1st, 22nd), and decades (90s, '90s, 1980s). These are the readings common in
/// sung lyrics; a different reading is written out in words by the user. Other forms return nil.
public enum SpokenNumbers {
    /// Pattern of one numeric lyric token, matched on folded text.
    static let token = "'?[0-9]+(?:[,:][0-9]+)*(?:st|nd|rd|th|s)?"
    /// A whole numeric token: not part of a longer word, and not followed by more digits after a point or
    /// separator, so that a decimal such as 3.5 stays unsupported rather than being read as two numbers.
    public static let pattern = "(?<![A-Za-z0-9.,:])" + token + "(?![A-Za-z0-9]|[.,:][0-9])"

    static let ones = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven",
        "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
    ]
    static let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]

    /// The spoken words of a numeric token, or nil for an unsupported form.
    public static func spoken(_ token: String) -> String? {
        var text = token
        let decade = text.hasPrefix("'")
        if decade { text.removeFirst() }
        if text.contains(":") {
            let parts = text.split(separator: ":", omittingEmptySubsequences: false)
            guard !decade, parts.count == 2, let h = Int(parts[0]), (0...24).contains(h), parts[1].count == 2,
                let m = Int(parts[1]), m < 60
            else { return nil }
            let hour = cardinal(h)
            if m == 0 { return "\(hour) o'clock" }
            return m < 10 ? "\(hour) oh \(ones[m])" : "\(hour) \(cardinal(m))"
        }
        for suffix in ["st", "nd", "rd", "th"] where text.hasSuffix(suffix) {
            guard !decade, let n = integer(String(text.dropLast(2))), n > 0, ordinalSuffix(n) == suffix else {
                return nil
            }
            return ordinal(n)
        }
        if text.hasSuffix("s") {
            guard let n = Int(text.dropLast()), !text.contains(","), n % 10 == 0 else { return nil }
            if decade || n < 100 {
                guard (10...90).contains(n) else { return nil }
                return plural(tens[n / 10])
            }
            guard (1000...2090).contains(n) else { return nil }
            if n % 100 == 0 { return plural(year(n)) }
            return "\(cardinal(n / 100)) \(plural(tens[(n % 100) / 10]))"
        }
        guard !decade, let n = integer(text) else { return nil }
        if !text.contains(","), text.count == 4, (1100...2099).contains(n) { return year(n) }
        return cardinal(n)
    }

    /// Replaces every supported numeric token in `text` by its spoken words; unsupported tokens stay unchanged.
    public static func expand(_ text: String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern)
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: text), let words = spoken(String(text[range])) else { continue }
            result.replaceSubrange(Range(match.range, in: result)!, with: words)
        }
        return result
    }

    /// Digits with optional groups of three after commas, up to 999,999,999.
    static func integer(_ text: String) -> Int? {
        let groups = text.split(separator: ",", omittingEmptySubsequences: false)
        guard !groups.isEmpty, groups.dropFirst().allSatisfy({ $0.count == 3 }),
            groups.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCII) }),
            let n = Int(groups.joined()), n < 1_000_000_000
        else { return nil }
        if groups.count == 1 && text.count > 1 && text.hasPrefix("0") { return nil }
        return n
    }

    static func cardinal(_ n: Int) -> String {
        if n < 20 { return ones[n] }
        if n < 100 { return tens[n / 10] + (n % 10 == 0 ? "" : "-" + ones[n % 10]) }
        if n < 1000 { return ones[n / 100] + " hundred" + (n % 100 == 0 ? "" : " " + cardinal(n % 100)) }
        for (size, name) in [(1_000_000, "million"), (1000, "thousand")] where n >= size {
            return cardinal(n / size) + " " + name + (n % size == 0 ? "" : " " + cardinal(n % size))
        }
        return ""
    }

    /// Years as usually sung: 1999 nineteen ninety-nine, 1905 nineteen oh five, 1900 nineteen hundred,
    /// 2000 two thousand, 2005 two thousand five, 2015 twenty fifteen.
    static func year(_ n: Int) -> String {
        let high = n / 100
        let low = n % 100
        if (2000...2009).contains(n) { return cardinal(n) }
        if low == 0 { return cardinal(high) + " hundred" }
        return cardinal(high) + " " + (low < 10 ? "oh " + ones[low] : cardinal(low))
    }

    static func ordinalSuffix(_ n: Int) -> String {
        if (11...13).contains(n % 100) { return "th" }
        switch n % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    static func ordinal(_ n: Int) -> String {
        let words = cardinal(n)
        let irregular = [
            "one": "first", "two": "second", "three": "third", "five": "fifth", "eight": "eighth",
            "nine": "ninth", "twelve": "twelfth",
        ]
        var parts = words.components(separatedBy: CharacterSet(charactersIn: " -"))
        let separators = words.filter { $0 == " " || $0 == "-" }.map(String.init)
        let last = parts.removeLast()
        let ending: String
        if let word = irregular[last] {
            ending = word
        } else if last.hasSuffix("y") {
            ending = String(last.dropLast()) + "ieth"
        } else {
            ending = last + "th"
        }
        parts.append(ending)
        var result = parts[0]
        for (i, part) in parts.dropFirst().enumerated() { result += separators[i] + part }
        return result
    }

    static func plural(_ words: String) -> String {
        words.hasSuffix("y") ? String(words.dropLast()) + "ies" : words + "s"
    }
}
