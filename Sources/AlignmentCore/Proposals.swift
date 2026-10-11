import Foundation

/// A forced word span grouped from character spans, with its UTF-16 range in the line.
public struct WordSpan: Equatable, Sendable {
    public let startUTF16, lengthUTF16: Int
    public var interval: [Int]
    public init(startUTF16: Int, lengthUTF16: Int, interval: [Int]) { self.startUTF16=startUTF16;self.lengthUTF16=lengthUTF16;self.interval=interval }
}

/// Line-level result of forced alignment and the vocal rules (Python row of `proposals`).
public struct LineAlignment: Equatable, Sendable {
    public let id: Int
    public let text, alignmentText: String
    public var proposal: [Int]?
    public var estimate: [Int]?
    public var flags: [String]
    public var support: Double?
    public var similarity: Double?
    public var words: [WordSpan]?
    public var wordEstimates: [WordSpan]?
    public var onsetTrim: Int?
    public var offsetExtension: Int?
    public init(id: Int, text: String, alignmentText: String, proposal: [Int]?, estimate: [Int]?, flags: [String], support: Double?,
                similarity: Double?, words: [WordSpan]?, wordEstimates: [WordSpan]?, onsetTrim: Int?, offsetExtension: Int?) {
        self.id=id;self.text=text;self.alignmentText=alignmentText;self.proposal=proposal;self.estimate=estimate;self.flags=flags
        self.support=support;self.similarity=similarity;self.words=words;self.wordEstimates=wordEstimates
        self.onsetTrim=onsetTrim;self.offsetExtension=offsetExtension
    }
}

/// Forced line proposals with speech-model diagnostics (Python `proposals`).
public func proposals(_ source: LyricSource, duration: Int, emissions: [[Double]], targets: TextTargets,
                      spans: [[Int]]?, vocabulary: [String:Int], blank: Int = 0) throws -> [LineAlignment] {
    let alphabet=Dictionary(uniqueKeysWithValues:vocabulary.map { ($0.value,$0.key) })
    let counts=Dictionary(source.lines.map { ($0.alignmentText,1) },uniquingKeysWith:+)
    let best=emissions.map { e -> Int in
        var index=0
        for k in 1..<e.count where e[k]>e[index] { index=k }
        return index
    }
    var rows=[LineAlignment]()
    for line in source.lines {
        var row=LineAlignment(id:line.id,text:line.text,alignmentText:line.alignmentText,proposal:nil,estimate:nil,flags:[],
                              support:nil,similarity:nil,words:nil,wordEstimates:nil,onsetTrim:nil,offsetExtension:nil)
        let indices=targets.owners.indices.filter { targets.owners[$0]==line.id && targets.tokens[$0] != "|" }
        if counts[line.alignmentText,default:0]>1 { row.flags.append("repeated_occurrence_requires_review") }
        guard let spans else { row.flags.append("no_complete_path");rows.append(row);continue }
        let a=spans[indices[0]][0],b=spans[indices[indices.count-1]][1]
        let proposal=[a*gridMicroseconds,min(duration,b*gridMicroseconds)]
        row.words=try wordProposals(line,indices:indices,spans:spans,duration:duration)
        let observed=try canonical(greedy(best[a..<b],alphabet:alphabet,blank:blank))
        var support=0.0
        for i in indices {
            var sum=0.0
            for t in spans[i][0]..<spans[i][1] { sum+=emissions[t][vocabulary[targets.tokens[i]]!] }
            support+=sum/Double(spans[i][1]-spans[i][0])
        }
        support/=Double(indices.count)
        let ratio=sequenceRatio(line.alignmentText,observed)
        row.proposal=proposal;row.support=support;row.similarity=ratio
        if support < -3.0 { row.flags.append("weak_acoustic_support") }
        if ratio<0.55 { row.flags.append("weak_lexical_agreement") }
        if indices.contains(where:{ (spans[$0][1]-spans[$0][0])*gridMicroseconds>1_500_000 }) { row.flags.append("extended_character_support") }
        if proposal[1]-proposal[0]>20_000_000 { row.flags.append("extended_line_support") }
        if row.flags.allSatisfy({ $0=="repeated_occurrence_requires_review" }) { row.estimate=proposal }
        rows.append(row)
    }
    return rows
}

/// Group a line's forced character spans into words (Python `word_proposals`).
func wordProposals(_ line: SourceLine, indices: [Int], spans: [[Int]], duration: Int) throws -> [WordSpan] {
    var runs=[[Int]](),current=[Int]()
    for i in indices {
        if let last=current.last,i != last+1 { runs.append(current);current=[] }
        current.append(i)
    }
    if !current.isEmpty { runs.append(current) }
    let matches=words(in:line.text)
    guard matches.count==runs.count else { throw AlignmentError.invalid("Word segmentation differs from alignment targets") }
    return zip(matches,runs).map { m,r in
        let start=line.text[..<m.lowerBound].utf16.count,end=line.text[..<m.upperBound].utf16.count
        return WordSpan(startUTF16:start,lengthUTF16:end-start,interval:[spans[r[0]][0]*gridMicroseconds,min(duration,spans[r[r.count-1]][1]*gridMicroseconds)])
    }
}

/// Version 2 vocal rules for separated-vocal CTC (docs/reports/separated-vocal-acceptance.md).
public enum VocalRules {
    public static let frameMicroseconds=20000
    public static let onsetActivityDB=30.0, offsetActivityDB=20.0
    public static let maximumOffsetExtension=600_000
    public static let microsecondsPerCharacter=40_000...400_000
    public static let minimumSupport = -3.5, minimumSimilarity=0.15, uncertainRateRatio=1.75

    /// Per-20-ms RMS level in dB and its 99th percentile with linear interpolation (Python `vocal_activity_db`).
    public static func activity(_ samples: [Float], rate: Int = 16000) throws -> (level: [Double], reference: Double) {
        let frame=rate*frameMicroseconds/1_000_000,count=samples.count/frame
        guard count>0 else { throw AlignmentError.invalid("Vocal stem shorter than one activity frame") }
        let level=(0..<count).map { f -> Double in
            var sum=0.0
            for k in f*frame..<(f+1)*frame { let v=Double(samples[k]);sum+=v*v }
            return 20*log10((sum/Double(frame)+1e-12).squareRoot())
        }
        let sorted=level.sorted(),position=0.99*Double(count-1),low=Int(position.rounded(.down)),high=min(count-1,low+1)
        return (level,sorted[low]+(sorted[high]-sorted[low])*(position-Double(low)))
    }

    /// Acceptance from separated-stem evidence and activity-refined boundaries (Python `apply_vocal_rules`).
    public static func apply(_ rows: inout [LineAlignment], level: [Double], reference: Double) {
        let onsetThreshold=reference-onsetActivityDB,offsetThreshold=reference-offsetActivityDB
        var rates=[Int:Double]()
        for k in rows.indices {
            rows[k].estimate=nil
            guard let p=rows[k].proposal else { continue }
            let rate=Double(p[1]-p[0])/Double(rows[k].alignmentText.unicodeScalars.count)
            var reasons=[String]()
            if (rows[k].support ?? -.infinity)<minimumSupport { reasons.append("weak_separated_support") }
            if (rows[k].similarity ?? 0)<minimumSimilarity { reasons.append("weak_separated_lexical_agreement") }
            if rate<Double(microsecondsPerCharacter.lowerBound) { reasons.append("implausible_duration") }
            if rate>Double(microsecondsPerCharacter.upperBound) { reasons.append("implausible_rate") }
            if !reasons.isEmpty { rows[k].flags+=reasons;continue }
            rows[k].estimate=p;rates[rows[k].id]=rate
        }
        let values=rates.values.sorted()
        let median:Double?=values.isEmpty ? nil : values.count%2==1 ? values[values.count/2] : (values[values.count/2-1]+values[values.count/2])/2
        for k in rows.indices {
            guard let e=rows[k].estimate else { continue }
            let a=e[0],b=e[1],first=a/frameMicroseconds,last=(b+frameMicroseconds-1)/frameMicroseconds
            guard let active=(first..<max(first,min(last,level.count))).first(where:{ level[$0]>onsetThreshold }) else {
                rows[k].flags.append("no_vocal_activity");rows[k].estimate=nil;continue
            }
            let onset=max(a,active*frameMicroseconds)
            let following=rows[(k+1)...].first(where:{ $0.proposal != nil })?.proposal?[0]
            let limit=min(b+maximumOffsetExtension,following ?? b+maximumOffsetExtension)
            var frame=last
            while frame<level.count && frame*frameMicroseconds<limit && level[frame]>offsetThreshold { frame+=1 }
            let offset=min(max(b,frame*frameMicroseconds),max(b,limit))
            guard onset<offset else { rows[k].flags.append("no_vocal_activity");rows[k].estimate=nil;continue }
            if onset>a { rows[k].onsetTrim=onset-a }
            if offset>b { rows[k].offsetExtension=offset-b }
            if let median,median>0,rates[rows[k].id]!>uncertainRateRatio*median { rows[k].flags.append("uncertain_boundary") }
            rows[k].estimate=[onset,offset]
            rows[k].wordEstimates=wordEstimates(rows[k].words,onset:onset,offset:offset)
        }
    }

    /// Clamp forced word spans into the refined line interval (Python `word_estimates`).
    public static func wordEstimates(_ words: [WordSpan]?, onset: Int, offset: Int) -> [WordSpan]? {
        guard let words,!words.isEmpty else { return nil }
        var out=[WordSpan](),previous=onset
        for (k,w) in words.enumerated() {
            let a=k==0 ? onset : max(w.interval[0],previous)
            let b=k==words.count-1 ? offset : min(max(w.interval[1],a),offset)
            guard a<b else { return nil }
            out.append(WordSpan(startUTF16:w.startUTF16,lengthUTF16:w.lengthUTF16,interval:[a,b]));previous=b
        }
        return out
    }
}
