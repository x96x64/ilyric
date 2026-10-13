import Foundation

/// Capabilities of the stream that receives progress, decided once per invocation.
public struct ProgressStyle: Equatable, Sendable {
    /// An interactive terminal: the active stage line is redrawn in place.
    public var interactive: Bool
    /// ANSI colour and weight for the `==>` marker and stage names.
    public var color: Bool
    /// Braille spinner frames instead of the ASCII fallback.
    public var unicode: Bool
    /// Terminal columns; lines are drawn one column narrower to avoid automatic wrapping.
    public var width: Int
    public init(interactive: Bool, color: Bool, unicode: Bool, width: Int) {
        self.interactive=interactive; self.color=color; self.unicode=unicode; self.width=width
    }
    /// Plain append-only output for files, pipes, and CI logs.
    public static let plain = ProgressStyle(interactive: false, color: false, unicode: false, width: 80)
}

/// The state shown in a stage line's right-hand status column.
public enum StageState: Equatable, Sendable {
    /// Work with a known fraction in [0, 1]; drawn with a bar and a percentage.
    case fraction(Double)
    /// Work without a supportable fraction; drawn with a spinner frame.
    case working(spinner: Int)
    case done
    case skip
}

/// Formats stage and summary lines in the shape `==> [2/4] Separating vocals   ####----  68.0%`.
public enum StageLine {
    /// Width of the right-aligned status column: "100.0%" is the widest entry.
    public static let statusWidth = 6
    /// Bars narrower than this are omitted rather than drawn uselessly short.
    public static let minimumBar = 10
    static let unicodeSpinner = Array("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏")
    static let asciiSpinner = Array("|/-\\")

    /// One stage line. `nameWidth` pads names so that bars and status columns align across stages.
    /// Interactive lines fill `style.width - 1` columns with the status at the right edge; plain lines
    /// are `==> [n/t] Name  status` and never carry a bar.
    public static func format(index: Int, total: Int, name: String, nameWidth: Int, state: StageState, style: ProgressStyle) -> String {
        let status=Self.status(state, unicode: style.unicode)
        let label="[\(index)/\(total)] "
        guard style.interactive else {
            return marker(style)+" "+label+bold(name, style)+"  "+status.trimmingCharacters(in: .whitespaces)
        }
        // "==> " + label + name + two spaces + bar + two spaces + status, in `width - 1` columns. A narrow
        // terminal loses the bar first and then shortens the name; the status column stays at the edge.
        let room=style.width-1-(4+label.count+2+2+statusWidth)
        let columns=min(nameWidth, max(1, room))
        let name=fit(name, columns)
        let padded=name+String(repeating: " ", count: max(0, columns-name.count))
        let available=room-columns
        var middle=String(repeating: " ", count: max(0, available))
        if case .fraction(let f)=state, available>=minimumBar {
            let filled=Int((min(max(f, 0), 1)*Double(available)).rounded(.down))
            middle=String(repeating: "#", count: filled)+String(repeating: "-", count: available-filled)
        }
        return marker(style)+" "+label+bold(padded, style)+"  "+middle+"  "+status
    }

    /// The closing line, `==> Generated output.mp4 in 5 minutes 9 seconds`.
    public static func summary(_ text: String, style: ProgressStyle) -> String {
        marker(style)+" "+text
    }

    /// The status column text, right-aligned to `statusWidth`.
    public static func status(_ state: StageState, unicode: Bool) -> String {
        let text: String
        switch state {
        case .fraction(let f): text=String(format: "%.1f%%", min(max(f, 0), 1)*100)
        case .working(let n): let frames=unicode ? unicodeSpinner : asciiSpinner; text=String(frames[((n%frames.count)+frames.count)%frames.count])
        case .done: text="done"
        case .skip: text="skip"
        }
        return String(repeating: " ", count: max(0, statusWidth-text.count))+text
    }

    /// Shortens a name that cannot fit a narrow terminal, keeping the status column intact.
    static func fit(_ name: String, _ width: Int) -> String {
        name.count<=width ? name : String(name.prefix(max(1, width-1)))+"…"
    }
    static func marker(_ style: ProgressStyle) -> String { style.color ? "\u{1B}[1;34m==>\u{1B}[0m" : "==>" }
    static func bold(_ s: String, _ style: ProgressStyle) -> String { style.color ? "\u{1B}[1m\(s)\u{1B}[0m" : s }

    /// Visible columns of a line, excluding ANSI escape sequences.
    public static func visibleWidth(_ line: String) -> Int {
        var count=0, escape=false
        for c in line {
            if escape { if c.isLetter { escape=false }; continue }
            if c=="\u{1B}" { escape=true; continue }
            count+=1
        }
        return count
    }
}

/// Elapsed time in words: "42 seconds", "1 minute 3 seconds", "1 hour 2 minutes".
public func durationInWords(_ seconds: Double) -> String {
    let total=Int(max(0, seconds).rounded(.down))
    if total==0 { return "less than a second" }
    let h=total/3600, m=(total%3600)/60, s=total%60
    func unit(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n==1 ? "" : "s")" }
    var parts=[String]()
    if h>0 { parts.append(unit(h, "hour")) }
    if m>0 { parts.append(unit(m, "minute")) }
    if s>0 { parts.append(unit(s, "second")) }
    return parts.joined(separator: " ")
}
