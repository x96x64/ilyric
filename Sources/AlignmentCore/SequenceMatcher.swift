/// Port of CPython `difflib.SequenceMatcher(None, a, b, autojunk=False).ratio()`, over Unicode scalars,
/// following `find_longest_match` and `get_matching_blocks` step by step so that ratios agree exactly.
public func sequenceRatio(_ a: String, _ b: String) -> Double {
    let x = Array(a.unicodeScalars)
    let y = Array(b.unicodeScalars)
    let total = x.count + y.count
    guard total > 0 else { return 1 }
    var b2j = [Unicode.Scalar: [Int]]()
    for (j, s) in y.enumerated() { b2j[s, default: []].append(j) }
    func longest(_ alo: Int, _ ahi: Int, _ blo: Int, _ bhi: Int) -> (Int, Int, Int) {
        var besti = alo
        var bestj = blo
        var bestsize = 0
        var j2len = [Int: Int]()
        for i in alo..<ahi {
            var newj2len = [Int: Int]()
            for j in b2j[x[i]] ?? [] {
                if j < blo { continue }
                if j >= bhi { break }
                let k = (j2len[j - 1] ?? 0) + 1
                newj2len[j] = k
                if k > bestsize {
                    besti = i - k + 1
                    bestj = j - k + 1
                    bestsize = k
                }
            }
            j2len = newj2len
        }
        // With no junk, CPython's extension loops grow the match over equal neighbors.
        while besti > alo && bestj > blo && x[besti - 1] == y[bestj - 1] {
            besti -= 1
            bestj -= 1
            bestsize += 1
        }
        while besti + bestsize < ahi && bestj + bestsize < bhi && x[besti + bestsize] == y[bestj + bestsize] {
            bestsize += 1
        }
        return (besti, bestj, bestsize)
    }
    var queue = [(0, x.count, 0, y.count)]
    var matched = 0
    while let (alo, ahi, blo, bhi) = queue.popLast() {
        let (i, j, k) = longest(alo, ahi, blo, bhi)
        if k > 0 {
            matched += k
            if alo < i && blo < j { queue.append((alo, i, blo, j)) }
            if i + k < ahi && j + k < bhi { queue.append((i + k, ahi, j + k, bhi)) }
        }
    }
    return 2 * Double(matched) / Double(total)
}
