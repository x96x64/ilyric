import Foundation

/// A forced word span grouped from character spans, with its UTF-16 range in the line.
public struct WordSpan: Equatable, Sendable {
    public let startUTF16, lengthUTF16: Int
    public var interval: [Int]
    public init(startUTF16: Int, lengthUTF16: Int, interval: [Int]) {
        self.startUTF16 = startUTF16
        self.lengthUTF16 = lengthUTF16
        self.interval = interval
    }
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
    public init(
        id: Int, text: String, alignmentText: String, proposal: [Int]?, estimate: [Int]?, flags: [String],
        support: Double?,
        similarity: Double?, words: [WordSpan]?, wordEstimates: [WordSpan]?, onsetTrim: Int?, offsetExtension: Int?
    ) {
        self.id = id
        self.text = text
        self.alignmentText = alignmentText
        self.proposal = proposal
        self.estimate = estimate
        self.flags = flags
        self.support = support
        self.similarity = similarity
        self.words = words
        self.wordEstimates = wordEstimates
        self.onsetTrim = onsetTrim
        self.offsetExtension = offsetExtension
    }
}

/// Forced line proposals with speech-model diagnostics (Python `proposals`).
public func proposals(
    _ source: LyricSource, duration: Int, emissions: [[Double]], targets: TextTargets,
    spans: [[Int]]?, vocabulary: [String: Int], blank: Int = 0
) throws -> [LineAlignment] {
    // Special tokens such as <unk> are not text; greedy decoding skips them before the lexical comparison.
    let alphabet = Dictionary(
        uniqueKeysWithValues: vocabulary.compactMap { $0.key.count == 1 ? ($0.value, $0.key) : nil })
    let counts = Dictionary(source.lines.map { ($0.alignmentText, 1) }, uniquingKeysWith: +)
    let best = emissions.map { e -> Int in
        var index = 0
        for k in 1..<e.count where e[k] > e[index] { index = k }
        return index
    }
    var rows = [LineAlignment]()
    for line in source.lines {
        var row = LineAlignment(
            id: line.id, text: line.text, alignmentText: line.alignmentText, proposal: nil, estimate: nil, flags: [],
            support: nil, similarity: nil, words: nil, wordEstimates: nil, onsetTrim: nil, offsetExtension: nil)
        let indices = targets.owners.indices.filter { targets.owners[$0] == line.id && targets.tokens[$0] != "|" }
        if counts[line.alignmentText, default: 0] > 1 { row.flags.append("repeated_occurrence_requires_review") }
        // A Japanese line of only Latin words has nothing the model can align; it is placed like an untimed line.
        guard !indices.isEmpty else {
            row.flags.append("no_alignable_characters")
            rows.append(row)
            continue
        }
        guard let spans else {
            row.flags.append("no_complete_path")
            rows.append(row)
            continue
        }
        let a = spans[indices[0]][0]
        let b = spans[indices[indices.count - 1]][1]
        var proposal = [a * gridMicroseconds, min(duration, b * gridMicroseconds)]
        let expected: String
        if let units = targets.japaneseUnits?[line.id], let unitOf = targets.units {
            // Latin words around the aligned characters may extend the line up to its neighbours' spans.
            let previous = indices[0] > 0 ? spans[indices[0] - 1][1] * gridMicroseconds : 0
            let next =
                indices[indices.count - 1] + 1 < spans.count
                ? spans[indices[indices.count - 1] + 1][0] * gridMicroseconds : duration
            let words = japaneseWordProposals(
                units, labelUnits: indices.map { unitOf[$0]! }, indices: indices, spans: spans, duration: duration,
                bounds: [previous, next], text: line.text)
            row.words = words
            if let lo = words.map({ $0.interval[0] }).min(), let hi = words.map({ $0.interval[1] }).max() {
                proposal = [min(proposal[0], lo), max(proposal[1], hi)]
            }
            expected = indices.map { targets.tokens[$0] }.joined()
        } else {
            row.words = try wordProposals(line, indices: indices, spans: spans, duration: duration)
            expected = line.alignmentText
        }
        let observed = try canonical(greedy(best[a..<b], alphabet: alphabet, blank: blank))
        var support = 0.0
        for i in indices {
            var sum = 0.0
            for t in spans[i][0]..<spans[i][1] { sum += emissions[t][vocabulary[targets.tokens[i]]!] }
            support += sum / Double(spans[i][1] - spans[i][0])
        }
        support /= Double(indices.count)
        let ratio = sequenceRatio(expected, observed)
        row.proposal = proposal
        row.support = support
        row.similarity = ratio
        if support < -3.0 { row.flags.append("weak_acoustic_support") }
        if ratio < 0.55 { row.flags.append("weak_lexical_agreement") }
        if indices.contains(where: { (spans[$0][1] - spans[$0][0]) * gridMicroseconds > 1_500_000 }) {
            row.flags.append("extended_character_support")
        }
        if proposal[1] - proposal[0] > 20_000_000 { row.flags.append("extended_line_support") }
        if row.flags.allSatisfy({ $0 == "repeated_occurrence_requires_review" }) { row.estimate = proposal }
        rows.append(row)
    }
    return rows
}

/// Group a line's forced character spans into words (Python `word_proposals`).
func wordProposals(_ line: SourceLine, indices: [Int], spans: [[Int]], duration: Int) throws -> [WordSpan] {
    var runs = [[Int]]()
    var current = [Int]()
    for i in indices {
        if let last = current.last, i != last + 1 {
            runs.append(current)
            current = []
        }
        current.append(i)
    }
    if !current.isEmpty { runs.append(current) }
    let matches = words(in: line.text)
    guard matches.count == runs.count else {
        throw AlignmentError.invalid("Word segmentation differs from alignment targets")
    }
    return zip(matches, runs).map { m, r in
        let start = line.text[..<m.lowerBound].utf16.count
        let end = line.text[..<m.upperBound].utf16.count
        return WordSpan(
            startUTF16: start, lengthUTF16: end - start,
            interval: [spans[r[0]][0] * gridMicroseconds, min(duration, spans[r[r.count - 1]][1] * gridMicroseconds)])
    }
}

/// Japanese unit timing. Aligned units take the span of their labels and extend to the next unit's start, so that the
/// fill sweeps continuously instead of flashing character by character. A Latin unit, which the Japanese model cannot
/// hear, lasts its estimated syllables at the line's own pace; leading Latin words therefore start before the first
/// aligned character, within `bounds`, and trailing ones end after the last.
func japaneseWordProposals(
    _ units: [JapaneseUnit], labelUnits: [Int], indices: [Int], spans: [[Int]], duration: Int,
    bounds: [Int]? = nil, text: String = ""
) -> [WordSpan] {
    var intervals = [Int: [Int]]()
    for (k, u) in labelUnits.enumerated() {
        let span = spans[indices[k]]
        let interval = [span[0] * gridMicroseconds, min(duration, span[1] * gridMicroseconds)]
        intervals[u] = intervals[u].map { [min($0[0], interval[0]), max($0[1], interval[1])] } ?? interval
    }
    let aligned = intervals.keys.sorted()
    // The line's pace: median duration of an aligned unit, bounded to plausible sung syllables.
    let lengths = aligned.map { intervals[$0]![1] - intervals[$0]![0] }.sorted()
    let pace = min(400_000, max(120_000, lengths.isEmpty ? 200_000 : lengths[lengths.count / 2]))
    func syllables(_ u: Int) -> Int {
        let utf16 = Array(text.utf16)
        guard units[u].startUTF16 + units[u].lengthUTF16 <= utf16.count else { return 1 }
        let word = String(
            decoding: utf16[units[u].startUTF16..<(units[u].startUTF16 + units[u].lengthUTF16)], as: UTF16.self)
        var count = 0
        var vowel = false
        for c in word.lowercased() {
            let v = "aeiouy".contains(c)
            if v && !vowel { count += 1 }
            vowel = v
        }
        return max(1, count)
    }
    var result = [[Int]](repeating: [0, 0], count: units.count)
    for u in units.indices {
        if let known = intervals[u] {
            // Bridge only to an adjacent aligned unit; a following Latin unit keeps the gap for itself.
            let next = intervals[u + 1].map { $0[0] }
            result[u] = [known[0], max(known[1], min(next ?? known[1], known[1] + 1_000_000))]
        }
    }
    // Leading Latin units, right to left from the first aligned unit.
    let first = aligned.first ?? units.count
    var cursor = first < units.count ? result[first][0] : (bounds?[0] ?? 0)
    for u in stride(from: first - 1, through: 0, by: -1) where units[u].labels.isEmpty {
        let start = max(bounds?[0] ?? 0, cursor - syllables(u) * pace)
        result[u] = [start, cursor]
        cursor = start
    }
    // Inner and trailing Latin units, left to right.
    for u in units.indices where u > first && intervals[u] == nil {
        let before = result[u - 1][1]
        if let next = aligned.first(where: { $0 > u }) {
            result[u] = [before, max(before, intervals[next]![0])]
        } else {
            let end = min(bounds?[1] ?? duration, before + syllables(u) * pace)
            result[u] = [before, max(before, end)]
        }
    }
    return units.indices.map {
        WordSpan(startUTF16: units[$0].startUTF16, lengthUTF16: units[$0].lengthUTF16, interval: result[$0])
    }
}

/// Version 2 vocal rules for separated-vocal CTC (docs/reports/separated-vocal-acceptance.md).
public enum VocalRules {
    public static let frameMicroseconds = 20000
    public static let onsetActivityDB = 30.0, offsetActivityDB = 20.0
    public static let maximumOffsetExtension = 600_000
    public static let microsecondsPerCharacter = 40_000...400_000
    public static let minimumSupport = -3.5, minimumSimilarity = 0.15, uncertainRateRatio = 1.75

    /// Per-20-ms RMS level in dB and its 99th percentile with linear interpolation (Python `vocal_activity_db`).
    public static func activity(_ samples: [Float], rate: Int = 16000) throws -> (level: [Double], reference: Double) {
        let frame = rate * frameMicroseconds / 1_000_000
        let count = samples.count / frame
        guard count > 0 else { throw AlignmentError.invalid("Vocal stem shorter than one activity frame") }
        let level = (0..<count).map { f -> Double in
            var sum = 0.0
            for k in f * frame..<(f + 1) * frame {
                let v = Double(samples[k])
                sum += v * v
            }
            return 20 * log10((sum / Double(frame) + 1e-12).squareRoot())
        }
        let sorted = level.sorted()
        let position = 0.99 * Double(count - 1)
        let low = Int(position.rounded(.down))
        let high = min(count - 1, low + 1)
        return (level, sorted[low] + (sorted[high] - sorted[low]) * (position - Double(low)))
    }

    /// Version 3 neighbour acceptance: a rejected line whose nearest lines are both accepted by the version 2 evidence,
    /// or one of them is and its similarity is at least this, is accepted when its rate is at most `neighbourRate`
    /// (docs/reports/neighbour-acceptance.md).
    public static let neighbourSimilarity = 0.05, neighbourRate = 1_000_000

    /// Acceptance from separated-stem evidence and activity-refined boundaries (Python `apply_vocal_rules`). With
    /// `neighbours`, rejected lines framed by accepted neighbours are accepted as well (version 3); without it the
    /// result equals the Python reference.
    public static func apply(
        _ rows: inout [LineAlignment], level: [Double], reference: Double, neighbours: Bool = false
    ) {
        let onsetThreshold = reference - onsetActivityDB
        let offsetThreshold = reference - offsetActivityDB
        var rates = [Int: Double]()
        for k in rows.indices {
            rows[k].estimate = nil
            guard let p = rows[k].proposal else { continue }
            let rate = Double(p[1] - p[0]) / Double(rows[k].alignmentText.unicodeScalars.count)
            var reasons = [String]()
            if (rows[k].support ?? -.infinity) < minimumSupport { reasons.append("weak_separated_support") }
            if (rows[k].similarity ?? 0) < minimumSimilarity { reasons.append("weak_separated_lexical_agreement") }
            if rate < Double(microsecondsPerCharacter.lowerBound) { reasons.append("implausible_duration") }
            if rate > Double(microsecondsPerCharacter.upperBound) { reasons.append("implausible_rate") }
            if !reasons.isEmpty {
                rows[k].flags += reasons
                continue
            }
            rows[k].estimate = p
            rates[rows[k].id] = rate
        }
        if neighbours {
            // Decide against the version 2 acceptance only, so that neighbour acceptance does not chain.
            let base = rows.map { $0.estimate != nil }
            for k in rows.indices where !base[k] {
                guard let p = rows[k].proposal else { continue }
                let rate = Double(p[1] - p[0]) / Double(rows[k].alignmentText.unicodeScalars.count)
                let before = k > 0 && base[k - 1]
                let after = k + 1 < rows.count && base[k + 1]
                guard rate <= Double(neighbourRate),
                    (before && after) || ((before || after) && (rows[k].similarity ?? 0) >= neighbourSimilarity)
                else { continue }
                rows[k].flags.append("neighbour_supported")
                rows[k].estimate = p
            }
        }
        let values = rates.values.sorted()
        let median: Double? =
            values.isEmpty
            ? nil
            : values.count % 2 == 1
                ? values[values.count / 2] : (values[values.count / 2 - 1] + values[values.count / 2]) / 2
        for k in rows.indices {
            guard let e = rows[k].estimate else { continue }
            let a = e[0]
            let b = e[1]
            let first = a / frameMicroseconds
            let last = (b + frameMicroseconds - 1) / frameMicroseconds
            guard let active = (first..<max(first, min(last, level.count))).first(where: { level[$0] > onsetThreshold })
            else {
                rows[k].flags.append("no_vocal_activity")
                rows[k].estimate = nil
                continue
            }
            let onset = max(a, active * frameMicroseconds)
            let following = rows[(k + 1)...].first(where: { $0.proposal != nil })?.proposal?[0]
            let limit = min(b + maximumOffsetExtension, following ?? b + maximumOffsetExtension)
            var frame = last
            while frame < level.count && frame * frameMicroseconds < limit && level[frame] > offsetThreshold {
                frame += 1
            }
            let offset = min(max(b, frame * frameMicroseconds), max(b, limit))
            guard onset < offset else {
                rows[k].flags.append("no_vocal_activity")
                rows[k].estimate = nil
                continue
            }
            if onset > a { rows[k].onsetTrim = onset - a }
            if offset > b { rows[k].offsetExtension = offset - b }
            if let median, median > 0, let rate = rates[rows[k].id], rate > uncertainRateRatio * median {
                rows[k].flags.append("uncertain_boundary")
            }
            rows[k].estimate = [onset, offset]
            rows[k].wordEstimates = wordEstimates(rows[k].words, onset: onset, offset: offset)
        }
    }

    /// Clamp forced word spans into the refined line interval (Python `word_estimates`).
    public static func wordEstimates(_ words: [WordSpan]?, onset: Int, offset: Int) -> [WordSpan]? {
        guard let words, !words.isEmpty else { return nil }
        var out = [WordSpan]()
        var previous = onset
        for (k, w) in words.enumerated() {
            let a = k == 0 ? onset : max(w.interval[0], previous)
            let b = k == words.count - 1 ? offset : min(max(w.interval[1], a), offset)
            guard a < b else { return nil }
            out.append(WordSpan(startUTF16: w.startUTF16, lengthUTF16: w.lengthUTF16, interval: [a, b]))
            previous = b
        }
        return out
    }
}
