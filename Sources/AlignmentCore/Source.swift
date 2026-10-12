import Foundation

/// Native port of the full-song alignment core in `scripts/alignment`. Every function mirrors the Python
/// reference, including evaluation order and tie-breaking, so that results agree exactly on shared inputs.
public enum AlignmentError: Error, Equatable { case invalid(String) }

/// One explicit lyric line of a source text, with its UTF-16 range within its paragraph.
public struct SourceLine: Equatable, Sendable {
    public let id, paragraph, startUTF16, lengthUTF16: Int
    public let text: String
    /// Lowercased letters, digits, and marks used for alignment; punctuation and whitespace are removed.
    public let alignmentText: String
}

/// Untimed lyrics: paragraphs separated by blank lines, at most four explicit lines each.
public struct LyricSource: Equatable, Sendable {
    public let text: String
    public let paragraphs: [String]
    public let lines: [SourceLine]

    public init(_ data: Data) throws {
        guard data.count<=65536 else { throw AlignmentError.invalid("Lyrics exceed 64 KiB") }
        guard let text=String(data:data,encoding:.utf8) else { throw AlignmentError.invalid("Lyrics must be UTF-8") }
        var display=text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        display=display.replacingOccurrences(of:"\r\n",with:"\n")
        guard !display.unicodeScalars.contains(where:{ ($0.value<32 && $0 != "\n" && $0 != "\t") || $0.value==127 }) else {
            throw AlignmentError.invalid("Unsupported control character or bare CR")
        }
        let trimmed=display.trimmingCharacters(in:CharacterSet(charactersIn:"\n"))
        var paragraphs=[String]()
        for part in trimmed.components(separatedBy:"\n").split(separator:"",omittingEmptySubsequences:true).map({ $0.joined(separator:"\n") }) {
            let lines=part.components(separatedBy:"\n")
            guard part.utf16.count<500,lines.count<=4 else { throw AlignmentError.invalid("Paragraph exceeds 499 UTF-16 units or four explicit lines") }
            guard lines.allSatisfy({ !$0.trimmingCharacters(in:.whitespaces).isEmpty }) else { throw AlignmentError.invalid("Whitespace-only lines are unsupported") }
            paragraphs.append(part)
        }
        guard !paragraphs.isEmpty else { throw AlignmentError.invalid("Lyrics must contain nonempty paragraphs") }
        guard paragraphs.count<=256 else { throw AlignmentError.invalid("At most 256 paragraphs are supported") }
        var lines=[SourceLine]()
        for (p,paragraph) in paragraphs.enumerated() {
            var offset=0
            for line in paragraph.components(separatedBy:"\n") {
                lines.append(SourceLine(id:lines.count,paragraph:p,startUTF16:offset,lengthUTF16:line.utf16.count,text:line,alignmentText:try canonical(line)))
                offset+=line.utf16.count+1
            }
        }
        self.text=text;self.paragraphs=paragraphs;self.lines=lines
    }
}

/// Alignment-side case and punctuation filter, never a display rewrite (Python `canonical`).
public func canonical(_ text: String) throws -> String {
    var result=""
    for scalar in foldLatin(text).unicodeScalars {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter,.lowercaseLetter,.titlecaseLetter,.modifierLetter,.otherLetter,
             .decimalNumber,.letterNumber,.otherNumber,.nonspacingMark,.spacingMark,.enclosingMark:
            result+=String(scalar).lowercased()
        case .connectorPunctuation,.dashPunctuation,.openPunctuation,.closePunctuation,.initialPunctuation,.finalPunctuation,.otherPunctuation:
            continue
        default:
            guard scalar.properties.isWhitespace else { throw AlignmentError.invalid("Unsupported alignment symbol; source text is preserved") }
        }
    }
    return result
}

/// English words as used for CTC targets: ASCII letters with internal apostrophes, after `foldLatin`, as ranges of
/// the original text.
func words(in text: String) -> [Range<String.Index>] {
    let regex=try! NSRegularExpression(pattern:"[A-Za-z]+(?:['’][A-Za-z]+)*"),folded=foldLatin(text)
    // Folding replaces single BMP scalars by single ASCII letters, so UTF-16 offsets are shared with the original.
    return regex.matches(in:folded,range:NSRange(folded.startIndex...,in:folded)).compactMap { Range($0.range,in:text) }
}

/// Latin letters with diacritics become their ASCII base letters (é → e) for alignment only; a letter is folded when
/// it is one BMP scalar whose canonical decomposition is an ASCII letter followed by combining marks. Display text
/// is never changed.
public func foldLatin(_ text: String) -> String {
    var scalars=String.UnicodeScalarView()
    for scalar in text.unicodeScalars {
        guard scalar.value>127,scalar.value<=0xFFFF,scalar.properties.isAlphabetic else { scalars.append(scalar);continue }
        let parts=String(scalar).decomposedStringWithCanonicalMapping.unicodeScalars
        if let base=parts.first,base.isASCII,base.properties.isAlphabetic,parts.count>1,
           parts.dropFirst().allSatisfy({ $0.properties.generalCategory == .nonspacingMark }) { scalars.append(base) }
        else { scalars.append(scalar) }
    }
    return String(scalars)
}
