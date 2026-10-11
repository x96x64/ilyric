import Foundation

/// Untimed lyrics as people write them, normalized for alignment (docs/command-line-interface.md): section labels
/// are dropped, parenthesized phrases become background vocals, lines without letters are dropped, whitespace is
/// collapsed, apostrophe variants become ’, and paragraphs are split evenly into at most four lines and fewer than
/// 500 UTF-16 units.
public struct NormalizedLyrics: Equatable, Sendable {
    /// Text for `LyricSource`: paragraphs separated by blank lines.
    public let text: String
    /// Background vocals by line index, in the order of `LyricSource.lines`.
    public let background: [Int:String]
    /// Lines of the input that were dropped, with the reason, for reporting.
    public let dropped: [String]

    public init(_ raw: String) {
        func collapse(_ s: String) -> String { s.split(whereSeparator:\.isWhitespace).joined(separator:" ") }
        let phrase=try! NSRegularExpression(pattern:"\\(([^()]*)\\)")
        let label=try! NSRegularExpression(pattern:"^\\s*\\[[^\\]]*\\]\\s*$")
        var paragraphs=[[String]](),current=[String](),background=[Int:String](),dropped=[String](),count=0
        func flush() { if !current.isEmpty { paragraphs.append(current);current=[] } }
        // Apostrophe variants become the typographic apostrophe, which alignment supports in contractions.
        var body=raw.hasPrefix("\u{FEFF}") ? String(raw.dropFirst()) : raw
        for variant in ["\u{02BC}","\u{2018}","\u{0060}","\u{00B4}","\u{FF07}"] { body=body.replacingOccurrences(of:variant,with:"\u{2019}") }
        for line in body.replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\r",with:"\n").components(separatedBy:"\n") {
            let ns=line as NSString,range=NSRange(location:0,length:ns.length)
            if line.trimmingCharacters(in:.whitespaces).isEmpty { flush();continue }
            if label.firstMatch(in:line,range:range) != nil { dropped.append(line+" (section label)");continue }
            let phrases=phrase.matches(in:line,range:range).map { collapse(ns.substring(with:$0.range(at:1))) }.filter { !$0.isEmpty }
            let main=collapse(phrase.stringByReplacingMatches(in:line,range:range,withTemplate:" "))
                .replacingOccurrences(of:" ([,.;:!?])",with:"$1",options:.regularExpression)
            let hasLetters=main.unicodeScalars.contains { CharacterSet.letters.contains($0) }
            if !hasLetters {
                if !phrases.isEmpty,count>0 { background[count-1]=((background[count-1].map { [$0] } ?? [])+phrases).joined(separator:" ") }
                else { dropped.append(line+(phrases.isEmpty ? " (no letters)" : " (background vocals without a preceding line)")) }
                continue
            }
            if !phrases.isEmpty { background[count]=phrases.joined(separator:" ") }
            current.append(main);count+=1
        }
        flush()
        // Split long paragraphs into the fewest balanced chunks of at most four lines, earlier chunks taking the extra
        // line (six lines become three and three); a chunk reaching 500 UTF-16 units is split further.
        var split=[[String]]()
        for p in paragraphs {
            let parts=(p.count+3)/4
            var start=0
            for k in 0..<parts {
                let size=p.count/parts+(k<p.count%parts ? 1 : 0)
                var chunk=[String]()
                for line in p[start..<start+size] {
                    if !chunk.isEmpty && (chunk+[line]).joined(separator:"\n").utf16.count>=500 { split.append(chunk);chunk=[] }
                    chunk.append(line)
                }
                split.append(chunk);start+=size
            }
        }
        text=split.map { $0.joined(separator:"\n") }.joined(separator:"\n\n")+"\n"
        self.background=background;self.dropped=dropped
    }
}
