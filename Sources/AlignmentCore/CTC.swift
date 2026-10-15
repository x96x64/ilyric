import Foundation

/// Model frame duration of wav2vec2 at 16 kHz.
public let gridMicroseconds = 20000

/// One bounded inference window over 16-kHz samples; the central part between the keep bounds owns its frames.
public struct AnalysisWindow: Equatable, Sendable {
    public let id, startSample, endSample, keepStartSample, keepEndSample: Int
}

/// 30-second windows advancing by 26 seconds (Python `windows`).
public func analysisWindows(samples: Int) throws -> [AnalysisWindow] {
    let rate = 16000
    guard samples > 0, samples <= rate * 1200 else {
        throw AlignmentError.invalid("Full-song analysis requires 16-kHz audio of at most 1,200 seconds")
    }
    let size = rate * 30
    let stride = rate * 26
    var starts = [0]
    while starts[starts.count - 1] + size < samples { starts.append(starts[starts.count - 1] + stride) }
    return starts.enumerated().map { i, start in
        let end = min(samples, start + size)
        let left = i == 0 ? 0 : (start + min(samples, starts[i - 1] + size)) / 2
        let right = i + 1 == starts.count ? samples : (end + starts[i + 1]) / 2
        return AnalysisWindow(id: i, startSample: start, endSample: end, keepStartSample: left, keepEndSample: right)
    }
}

/// Frames of a window owned by its central part, checked for continuity (Python `owned_frames`).
public func ownedFrames(_ window: AnalysisWindow, frameCount: Int, expected: Int) throws -> [Int] {
    var selected = [Int]()
    for local in 0..<frameCount {
        let sample = window.startSample + local * 320
        if window.keepStartSample <= sample && sample < window.keepEndSample {
            guard sample / 320 == expected + selected.count else {
                throw AlignmentError.invalid("Window reconciliation introduced a missing or duplicate frame")
            }
            selected.append(local)
        }
    }
    return selected
}

/// CTC label sequence of all lines: uppercase letters and apostrophes, words separated by "|",
/// with the owning line of every label (nil for separators between lines).
public struct TextTargets: Equatable, Sendable {
    public let tokens: [String]
    public let owners: [Int?]
    /// Japanese only: the line unit of each label, and each line's units; nil for English, whose words are found
    /// from the text and separated by "|".
    public let units: [Int?]?
    public let japaneseUnits: [Int: [JapaneseUnit]]?
    public init(tokens: [String], owners: [Int?], units: [Int?]? = nil, japaneseUnits: [Int: [JapaneseUnit]]? = nil) {
        self.tokens = tokens
        self.owners = owners
        self.units = units
        self.japaneseUnits = japaneseUnits
    }
}

public func textTargets(_ source: LyricSource) throws -> TextTargets {
    var tokens = [String]()
    var owners = [Int?]()
    for line in source.lines {
        // A number is one word whose letters are its spoken form, so word timing still maps to the digits.
        let found = words(in: line.text).map { range -> String in
            let word = String(line.text[range])
            guard word.contains(where: \.isNumber), let spoken = SpokenNumbers.spoken(word) else { return word }
            return spoken.filter { $0.isLetter || $0 == "'" }
        }
        guard !found.isEmpty, try canonical(found.joined()) == line.alignmentText else {
            throw AlignmentError.invalid(
                "lyric line \(line.id+1) contains characters that cannot be aligned; only English letters, apostrophes, and punctuation are supported"
            )
        }
        let text = found.map { foldLatin($0).replacingOccurrences(of: "’", with: "'").uppercased() }.joined(
            separator: "|")
        if !tokens.isEmpty {
            tokens.append("|")
            owners.append(nil)
        }
        for c in text {
            tokens.append(String(c))
            owners.append(line.id)
        }
    }
    guard tokens.count <= 12000 else { throw AlignmentError.invalid("Full-song text exceeds 12,000 CTC labels") }
    return TextTargets(tokens: tokens, owners: owners)
}

/// Global monotonic CTC Viterbi path; returns half-open frame spans per target, or nil without a complete path
/// (Python `path`). Comparisons and accumulation order match the reference exactly.
public func ctcPath(_ emissions: [[Double]], targets: [Int], blank: Int = 0) throws -> [[Int]]? {
    let frames = emissions.count
    guard !targets.isEmpty, targets.count <= 12000, frames > 0, frames <= 60000 else {
        throw AlignmentError.invalid("Full-song frame or target limit")
    }
    let width = emissions[0].count
    guard blank >= 0, blank < width else { throw AlignmentError.invalid("Invalid blank label") }
    var labels = [blank]
    for target in targets {
        guard target != blank, target >= 0, target < width else { throw AlignmentError.invalid("Invalid CTC label") }
        labels.append(target)
        labels.append(blank)
    }
    let count = labels.count
    // Each choice (stay, advance, or skip) takes two bits, so the largest permitted input (60,000 frames by 24,001
    // states) needs at most 360 MB of trace.
    let cells = frames * count
    guard cells <= 1_440_060_000 else { throw AlignmentError.invalid("Full-song CTC trace exceeds 360 MB") }
    var scores = [Double](repeating: -.infinity, count: count)
    scores[0] = 0
    let skip = labels.enumerated().map { j, v in j > 1 && v != blank && v != labels[j - 2] }
    var trace = [UInt8](repeating: 0, count: (cells + 3) / 4)
    var next = [Double](repeating: -.infinity, count: count)
    for (f, emission) in emissions.enumerated() {
        guard emission.count == width, emission.allSatisfy(\.isFinite) else {
            throw AlignmentError.invalid("Nonfinite or inconsistent acoustic scores")
        }
        let base = f * count
        for j in 0..<count {
            var value = scores[j]
            var choice: UInt8 = 0
            if j > 0 && scores[j - 1] > value {
                value = scores[j - 1]
                choice = 1
            }
            if skip[j] && scores[j - 2] > value {
                value = scores[j - 2]
                choice = 2
            }
            next[j] = value + emission[labels[j]]
            if choice != 0 {
                let cell = base + j
                trace[cell >> 2] |= choice << UInt8((cell & 3) * 2)
            }
        }
        swap(&scores, &next)
    }
    var state = scores[count - 1] >= scores[count - 2] ? count - 1 : count - 2
    guard scores[state].isFinite else { return nil }
    var spans = targets.map { _ in [frames, 0] }
    for frame in stride(from: frames - 1, through: 0, by: -1) {
        if state % 2 == 1 {
            let k = state / 2
            spans[k][0] = frame
            spans[k][1] = max(spans[k][1], frame + 1)
        }
        let cell = frame * count + state
        state -= Int((trace[cell >> 2] >> UInt8((cell & 3) * 2)) & 3)
    }
    return spans.allSatisfy({ $0[0] < $0[1] }) ? spans : nil
}

/// Collapse repeats and drop blanks; "|" becomes a space (Python `greedy`).
public func greedy(_ ids: ArraySlice<Int>, alphabet: [Int: String], blank: Int = 0) -> String {
    var result = ""
    var prior: Int? = nil
    for value in ids {
        if value != prior && value != blank { result += alphabet[value] ?? "" }
        prior = value
    }
    return result.replacingOccurrences(of: "|", with: " ")
}
