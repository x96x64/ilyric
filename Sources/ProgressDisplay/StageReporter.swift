import Foundation

/// Serializes all progress and diagnostics for one command on standard error.
///
/// Stages are known in advance so that names, bars, and status columns align. An interactive terminal
/// shows the active stage on one line redrawn in place, at most `interval` apart except on state changes;
/// files, pipes, and CI receive one line per finished or skipped stage and nothing in between. `quiet`
/// suppresses stage lines, informational messages, details, and the summary, but never warnings or errors.
/// The display clock is wall time for presentation only; it never influences media or alignment results.
public final class StageReporter: @unchecked Sendable {
    public let style: ProgressStyle
    public let quiet, verbose: Bool
    public let stages: [String]
    let nameWidth: Int
    let interval: Double
    let clock: () -> Double
    let sink: (String) -> Void
    let lock=NSLock()
    var active: (index: Int, state: StageState)?
    var drawn=false
    var lastDraw = -Double.infinity
    var spinner=0
    var ticker: DispatchSourceTimer?

    public init(stages: [String], style: ProgressStyle, quiet: Bool, verbose: Bool, interval: Double = 0.2,
                clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime },
                sink: @escaping (String) -> Void = { FileHandle.standardError.write(Data($0.utf8)) }) {
        self.stages=stages; self.style=style; self.quiet=quiet; self.verbose=verbose && !quiet
        self.interval=interval; self.clock=clock; self.sink=sink
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
        guard let a=active, case .working=a.state, style.interactive else { return }
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
    }

    // MARK: Drawing (lock held)

    func line(_ index: Int, _ state: StageState) -> String {
        StageLine.format(index: index, total: stages.count, name: stages[index-1], nameWidth: nameWidth, state: state, style: style)
    }

    func draw(force: Bool) {
        guard showsStages, style.interactive, let a=active else { return }
        let now=clock()
        guard force || now-lastDraw>=interval else { return }
        sink("\r"+line(a.index, a.state))
        drawn=true; lastDraw=now
    }

    func settle(_ index: Int, _ state: StageState) {
        guard showsStages else { return }
        if style.interactive { sink("\r"+line(index, state)+"\n"); drawn=false }
        else { sink(line(index, state)+"\n") }
        lastDraw=clock()
    }

    func clearActive() {
        if drawn { sink("\r\u{1B}[K"); drawn=false }
    }

    func emit(_ message: String, show: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard show else { return }
        clearActive()
        sink(message+"\n")
        draw(force: true)
    }
}
