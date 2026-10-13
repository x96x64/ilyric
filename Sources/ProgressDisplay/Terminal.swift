import Foundation
#if canImport(Darwin)
import Darwin
#endif

extension ProgressStyle {
    /// Decides the style for standard error from the environment.
    ///
    /// Progress is interactive only when standard error is a terminal whose type is set and not `dumb`
    /// and no CI marker is present; redirected standard output does not matter. `NO_COLOR` (any non-empty
    /// value) disables colour, which non-interactive output never uses. Unicode spinners require a UTF-8
    /// locale. The width comes from the terminal, falling back to `COLUMNS` and then 80.
    public static func detect(environment: [String: String] = ProcessInfo.processInfo.environment,
                              isTerminal: Bool = isatty(STDERR_FILENO) != 0,
                              columns: Int? = terminalColumns()) -> ProgressStyle {
        let term=environment["TERM"] ?? ""
        let ci=["CI", "GITHUB_ACTIONS", "BUILDKITE", "TF_BUILD"].contains { !(environment[$0] ?? "").isEmpty }
        let interactive=isTerminal && !term.isEmpty && term != "dumb" && !ci
        let noColor = !(environment["NO_COLOR"] ?? "").isEmpty
        let locale=[environment["LC_ALL"], environment["LC_CTYPE"], environment["LANG"]].compactMap { $0 }.first { !$0.isEmpty } ?? ""
        let utf8=locale.uppercased().contains("UTF-8") || locale.uppercased().contains("UTF8")
        let width=columns ?? Int(environment["COLUMNS"] ?? "") ?? 80
        return ProgressStyle(interactive: interactive, color: interactive && !noColor, unicode: interactive && utf8, width: max(20, width))
    }
}

/// Columns of the terminal attached to standard error, or nil when unavailable.
public func terminalColumns() -> Int? {
    var size=winsize()
    guard ioctl(STDERR_FILENO, TIOCGWINSZ, &size)==0, size.ws_col>0 else { return nil }
    return Int(size.ws_col)
}
