import Foundation

/// Serializes all progress and diagnostics for one command on standard error.
///
/// Stages are known in advance so that names, bars, and status columns align. An interactive terminal
/// shows the active stage on one line redrawn in place, at most `interval` apart except on state changes;
/// files, pipes, and CI receive one line per finished or skipped stage and nothing in between. `quiet`
/// suppresses stage lines, informational messages, details, and the summary, but never warnings or errors.
/// The display clock is wall time for presentation only; it never influences media or alignment results.
public final class StageReporter: @unchecked Sendable {
    /// The current style; its width follows the terminal while the command runs.
    public private(set) var style: ProgressStyle
    public let quiet, verbose: Bool
    public let stages: [String]
    let nameWidth: Int
    let interval: Double
    let clock: () -> Double
    let sink: (String) -> Void
    let columns: () -> Int?
    let lock=NSLock()
    /// Visible columns of the line currently drawn in place.
    var drawnWidth=0

    var active: (index: Int, state: StageState)?
    var drawn=false
    var lastDraw = -Double.infinity
    var spinner=0
    var ticker: DispatchSourceTimer?

    public init(stages: [String], style: ProgressStyle, quiet: Bool, verbose: Bool, interval: Double = 0.2,
                clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime },
                sink: @escaping (String) -> Void = { FileHandle.standardError.write(Data($0.utf8)) },
                columns: @escaping () -> Int? = terminalColumns) {
        self.stages=stages; self.style=style; self.quiet=quiet; self.verbose=verbose && !quiet
        self.interval=interval; self.clock=clock; self.sink=sink; self.columns=columns
        nameWidth=stages.map(\.count).max() ?? 0
    }
    deinit { ticker?.cancel() }

    var showsStages: Bool { !quiet }

    /// Starts stage `index` (1-based) without a known fraction; interactive terminals show a spinner.
    public func begin(_ index: Int) {
        lock.lock(); defer { lock.unlock() }
        precondition(stages.indices.contains(index-1), "Unknown stage \(index)")
        active=(index, .working(spinner: spinner))
        draw(force: true)
    }

    /// Reports the active stage's completed fraction; redraws are throttled.
    public func update(fraction: Double) {
        lock.lock(); defer { lock.unlock() }
        guard let a=active else { return }
        let changed: Bool
        if case .fraction=a.state { changed=false } else { changed=true }
        active=(a.index, .fraction(min(max(fraction, 0), 1)))
        draw(force: changed)
    }

    /// Returns the active stage to an indeterminate spinner, for finishing work after counted units.
    public func indeterminate() {
        lock.lock(); defer { lock.unlock() }
        guard let a=active else { return }
        active=(a.index, .working(spinner: spinner))
        draw(force: true)
    }

    /// Marks the active stage done and leaves its line in place.
    public func finish() {
        lock.lock(); defer { lock.unlock() }
        guard let a=active else { return }
        active=nil
        settle(a.index, .done)
    }

    /// Records a stage that this invocation does not perform.
    public func skip(_ index: Int) {
        lock.lock(); defer { lock.unlock() }
        precondition(stages.indices.contains(index-1), "Unknown stage \(index)")
        settle(index, .skip)
    }

    /// Advances the spinner; call periodically while a stage is indeterminate.
    public func tick() {
        lock.lock(); defer { lock.unlock() }
        guard let a=active, style.interactive else { return }
        if resized() { draw(force: true); return }
        guard case .working=a.state else { return }
        let now=clock()
        guard now-lastDraw>=interval else { return }
        spinner+=1
        active=(a.index, .working(spinner: spinner))
        draw(force: true)
    }

    /// Ticks from a background timer while the reporter lives; does nothing for plain output.
    public func startTicker() {
        guard style.interactive, !quiet else { return }
        let t=DispatchSource.makeTimerSource(queue: DispatchQueue(label: "ilyrics.progress"))
        t.schedule(deadline: .now()+interval, repeating: interval)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        lock.lock(); ticker=t; lock.unlock()
    }

    /// An informational line, hidden by `--quiet`.
    public func info(_ message: String) { emit(message, show: !quiet) }
    /// A detail line, shown only with `--verbose` (and never with `--quiet`).
    public func detail(_ message: String) { emit(message, show: verbose) }
    /// A warning, always shown.
    public func warning(_ message: String) { emit("Warning: "+message, show: true) }
    /// An error, always shown; it also closes any active stage line.
    public func error(_ message: String) {
        lock.lock(); defer { lock.unlock() }
        clearActive()
        active=nil
        sink("Error: "+message+"\n")
    }

    /// The closing line, e.g. `Generated output.mp4 in 5 minutes 9 seconds`; hidden by `--quiet`.
    public func summary(_ text: String) {
        lock.lock(); defer { lock.unlock() }
        guard !quiet else { return }
        clearActive()
        active=nil
        sink(StageLine.summary(text, style: style)+"\n")
    }

    /// Clears a half-drawn line, for unwinding after a failure reported elsewhere.
    public func close() {
        lock.lock(); defer { lock.unlock() }
        ticker?.cancel(); ticker=nil
        clearActive()
        active=nil
        // Restore automatic wrapping in case a draw was interrupted; harmless when it is already on.
        if style.interactive && showsStages && lastDraw > -Double.infinity { sink(Self.wrap) }
    }

    // MARK: Drawing (lock held)

    func line(_ index: Int, _ state: StageState) -> String {
        StageLine.format(index: index, total: stages.count, name: stages[index-1], nameWidth: nameWidth, state: state, style: style)
    }

    func draw(force: Bool) {
        guard showsStages, style.interactive, let a=active else { return }
        let now=clock()
        let changed=resized()
        guard force || changed || now-lastDraw>=interval else { return }
        let text=line(a.index, a.state)
        sink(Self.noWrap+rewind()+text+Self.wrap)
        drawn=true; drawnWidth=StageLine.visibleWidth(text); lastDraw=now
    }

    func settle(_ index: Int, _ state: StageState) {
        guard showsStages else { return }
        if style.interactive { _=resized(); sink(Self.noWrap+rewind()+line(index, state)+Self.wrap+"\n"); drawn=false; drawnWidth=0 }
        else { sink(line(index, state)+"\n") }
        lastDraw=clock()
    }

    func clearActive() {
        if drawn { sink(rewind()); drawn=false; drawnWidth=0 }
    }

    /// Automatic wrapping is off while a stage line is written, so a line that is momentarily wider than a
    /// terminal being resized is clipped at the edge instead of spilling onto a second row.
    static let noWrap="\u{1B}[?7l", wrap="\u{1B}[?7h"

    /// Updates the width from the terminal; true when it changed.
    func resized() -> Bool {
        guard style.interactive, let w=columns(), w>0 else { return false }
        let target=max(20, w)
        guard target != style.width else { return false }
        style.width=target
        return true
    }

    /// Returns the cursor to the start of the line drawn in place. A terminal narrowed since the last draw
    /// reflows that line onto several rows; those rows are cleared so that the new line stays on one row.
    func rewind() -> String {
        guard drawn else { return "\r" }
        let rows=style.reflows ? (drawnWidth+style.width-1)/max(1, style.width) : 1
        return rows>1 ? "\r\u{1B}[\(rows-1)A\u{1B}[J" : "\r\u{1B}[K"
    }

    func emit(_ message: String, show: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard show else { return }
        clearActive()
        sink(message+"\n")
        draw(force: true)
    }
}
