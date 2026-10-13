import Foundation

/// TTML export of aligned lines, mirroring `to_ttml` in scripts/alignment/full_song.py with word granularity.
public enum TTMLExport {
    static let vocable=try! NSRegularExpression(pattern:"^(?:h?m+(?:h?m+)*|mh?m+|a+h*|o+h*|u+h+|e+y+|a+y+|la+|na+|da+|whoa+|ha+|w?h?o+o+|ow+|hee+|ye+a+h*|hey+|shamone)$")
    /// Lines below this greedy similarity, or with these flags, fill steadily instead of word by word.
    public static let lowConfidenceSimilarity=0.4
    public static let lowConfidenceFlags:Set<String>=["uncertain_boundary","weak_acoustic_support","weak_separated_support"]

    /// True when every word of a line is a vocable or interjection (Python `nonlexical`).
    public static func nonlexical(_ text: String) -> Bool {
        let letters=try! NSRegularExpression(pattern:"[A-Za-z]+")
        let words=letters.matches(in:text,range:NSRange(text.startIndex...,in:text)).map { (text as NSString).substring(with:$0.range).lowercased() }
        return !words.isEmpty && words.allSatisfy { vocable.firstMatch(in:$0,range:NSRange($0.startIndex...,in:$0)) != nil }
    }
    public static func lowConfidence(_ row: LineAlignment) -> Bool {
        (row.similarity ?? 1)<lowConfidenceSimilarity || !lowConfidenceFlags.isDisjoint(with:row.flags)
    }

    /// Parenthesized phrases of a lyrics text attached to the aligned lines (Python `background_vocals`).
    public static func backgroundVocals(_ text: String, rows: [LineAlignment]) -> [Int:String] {
        func norm(_ s: String) -> String { s.split(whereSeparator:\.isWhitespace).joined(separator:" ") }
        let phrase=try! NSRegularExpression(pattern:"\\(([^()]*)\\)")
        var pointer=0,last:Int?=nil,out=[Int:String]()
        for raw in text.components(separatedBy:"\n") {
            let ns=raw as NSString,range=NSRange(location:0,length:ns.length)
            let phrases=phrase.matches(in:raw,range:range).map { norm(ns.substring(with:$0.range(at:1))) }.filter { !$0.isEmpty }
            let main=norm(phrase.stringByReplacingMatches(in:raw,range:range,withTemplate:" "))
            if !main.isEmpty {
                guard let match=(pointer..<rows.count).first(where:{ norm(rows[$0].text)==main }) else { continue }
                pointer=match+1;last=rows[match].id
            }
            if !phrases.isEmpty,let last { out[last]=((out[last].map { [$0] } ?? [])+phrases).joined(separator:" ") }
        }
        return out
    }

    /// Intervals for lines without an estimate, spread evenly between neighbouring estimates; leading and trailing
    /// runs take at most 2.5 s per line. These are placements, not estimates, and export as line-level timing.
    public static func fillUnresolved(_ rows: [LineAlignment], duration: Int) -> [Int:[Int]] {
        var fills=[Int:[Int]](),i=0
        while i<rows.count {
            if rows[i].estimate != nil { i+=1;continue }
            var j=i
            while j<rows.count && rows[j].estimate==nil { j+=1 }
            let n=j-i
            var b=j<rows.count ? rows[j].estimate![0] : duration
            let a=i>0 ? rows[i-1].estimate![1] : max(0,b-n*2_500_000)
            if j==rows.count { b=min(b,a+n*2_500_000) }
            let step=(b-a)/n
            for k in 0..<n { fills[rows[i+k].id]=[a+k*step+1,a+(k+1)*step] }
            i=j
        }
        return fills
    }

    /// Translate a boundary run into its nearest wholly unclaimed activity component, when the complete
    /// existing span fits. Activity hints do not accept a line or establish its textual identity.
    /// Interior, anchorless and protected runs retain their original placements.
    public static func relocateBoundaryFallbacks(_ rows: [LineAlignment], fills: [Int:[Int]], duration: Int,
                                                  level: [Double], reference: Double,
                                                  protectedLines: Set<Int> = []) -> [Int:[Int]] {
        // The activity calculation's 1e-12 power floor is -120 dB; silence supplies no placement hint.
        guard reference.isFinite,reference > -120 else { return fills }
        let threshold=reference-VocalRules.onsetActivityDB,frame=VocalRules.frameMicroseconds
        var components=[[Int]](),start:Int?
        for i in 0...level.count {
            let active=i<level.count && level[i]>threshold
            if active && start==nil { start=i*frame }
            if !active,let begin=start { components.append([begin,i*frame]);start=nil }
        }
        let accepted=rows.compactMap(\.estimate)
        var result=fills,i=0
        while i<rows.count {
            if rows[i].estimate != nil { i+=1;continue }
            var j=i+1
            while j<rows.count && rows[j].estimate==nil { j+=1 }
            defer { i=j }
            let leading=i==0 && j<rows.count,trailing=i>0 && j==rows.count
            guard leading || trailing,!rows[i..<j].contains(where:{ protectedLines.contains($0.id) }),
                  let first=fills[rows[i].id],let last=fills[rows[j-1].id],first.count==2,last.count==2,
                  rows[i..<j].allSatisfy({ row in
                      guard let interval=fills[row.id],interval.count==2 else { return false }
                      return interval[0]>=0 && interval[0]<interval[1] && interval[1]<=duration
                  }) else { continue }
            let lower=leading ? 0 : rows[i-1].estimate![1]
            let upper=leading ? rows[j].estimate![0] : duration
            // Select by temporal proximity before checking capacity; never search farther components.
            let candidates=components.filter { $0[0]>=lower && $0[1]<=upper }
            guard let component=leading ? candidates.last : candidates.first else { continue }
            let span=last[1]-first[0]
            guard span>0,component[1]-component[0]>=span+1,
                  !accepted.contains(where:{ max(component[0],$0[0])<min(component[1],$0[1]) }) else { continue }
            if component[0]<=first[0] && last[1]<=component[1] { continue }
            // Preserve the existing one-microsecond boundary guard, lengths and relative spacing.
            let shift=component[0]+1-first[0]
            for row in rows[i..<j] { result[row.id]=fills[row.id]!.map { $0+shift } }
        }
        return result
    }

    /// Word-granularity TTML: one paragraph per line; untimed vocable-only lines are omitted.
    /// Lines in `secondVoice` carry `ttm:agent="v2"`, a duet's second singer.
    public static func ttml(_ rows: [LineAlignment], fills: [Int:[Int]], background: [Int:String] = [:], dropNonlexical: Bool = true,
                            secondVoice: Set<Int> = []) throws -> String {
        func stamp(_ t: Int) -> String {
            var s=String(format:"%d.%06d",t/1_000_000,t%1_000_000)
            while s.hasSuffix("0") { s.removeLast() };if s.hasSuffix(".") { s.removeLast() }
            return s+"s"
        }
        func escape(_ s: String) -> String { s.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;") }
        func extra(_ row: LineAlignment) -> String { background[row.id].map { "<span ttm:role=\"x-bg\">\(escape($0))</span>" } ?? "" }
        func agent(_ row: LineAlignment) -> String { secondVoice.contains(row.id) ? " ttm:agent=\"v2\"" : "" }
        var paragraphs=[String]()
        for row in rows {
            if dropNonlexical && row.estimate==nil && nonlexical(row.text) { continue }
            guard let interval=row.estimate ?? fills[row.id] else { throw AlignmentError.invalid("Line \(row.id) has neither an estimate nor a placement") }
            let (a,b)=(interval[0],interval[1])
            let words=row.estimate != nil ? row.wordEstimates : nil
            if let words,!words.isEmpty,!lowConfidence(row) {
                let units=Array(row.text.utf16)
                let cuts=[0]+words.dropFirst().map(\.startUTF16)+[units.count]
                let spans=words.enumerated().map { k,w in
                    "<span begin=\"\(stamp(w.interval[0]-a))\" end=\"\(stamp(w.interval[1]-a))\">\(escape(String(decoding:units[cuts[k]..<cuts[k+1]],as:UTF16.self)))</span>"
                }
                paragraphs.append("<p begin=\"\(stamp(a))\" end=\"\(stamp(b))\"\(agent(row))>"+spans.joined()+extra(row)+"</p>")
            } else if let words,!words.isEmpty {
                paragraphs.append("<p begin=\"\(stamp(a))\" end=\"\(stamp(b))\"\(agent(row))><span begin=\"0s\" end=\"\(stamp(b-a))\">\(escape(row.text))</span>\(extra(row))</p>")
            } else {
                paragraphs.append("<p begin=\"\(stamp(a))\" end=\"\(stamp(b))\"\(agent(row))>\(escape(row.text))\(extra(row))</p>")
            }
        }
        let namespace=background.isEmpty && secondVoice.isEmpty ? "" : " xmlns:ttm=\"http://www.w3.org/ns/ttml#metadata\""
        let xml="<tt xmlns=\"http://www.w3.org/ns/ttml\"\(namespace) xml:space=\"preserve\"><body><div>"+paragraphs.joined()+"</div></body></tt>\n"
        guard xml.utf8.count<=65536 else { throw AlignmentError.invalid("Prepared TTML exceeds the importer limit") }
        return xml
    }
}
