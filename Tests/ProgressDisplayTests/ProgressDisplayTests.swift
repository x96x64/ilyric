import Testing
@testable import ProgressDisplay

/// Stage-line layout, duration wording, terminal detection, and reporter behaviour. Synthetic stage names.
struct ProgressDisplayTests {
    let stages=["Reading audio", "Separating vocals", "Aligning lyrics", "Rendering video"]
    func style(_ width: Int, color: Bool = false, unicode: Bool = false) -> ProgressStyle {
        ProgressStyle(interactive: true, color: color, unicode: unicode, width: width)
    }

    @Test func statusColumnNeverShifts() {
        let width=stages.map(\.count).max()!
        for columns in [40, 60, 72, 80, 120, 200] {
            let states: [StageState]=[.fraction(0), .fraction(0.068), .fraction(0.68), .fraction(1), .done, .skip, .working(spinner: 3)]
            var ends=Set<Int>(), barStarts=Set<Int>()
            for (i, name) in stages.enumerated() {
                for state in states {
                    let line=StageLine.format(index: i+1, total: 4, name: name, nameWidth: width, state: state, style: style(columns))
                    #expect(StageLine.visibleWidth(line)==columns-1, "\(columns) \(state)")
                    #expect(line.hasPrefix("==> [\(i+1)/4] "))
                    ends.insert(StageLine.visibleWidth(line))
                    barStarts.insert(4+6+width+2)
                    let status=String(line.suffix(StageLine.statusWidth))
                    #expect(status==StageLine.status(state, unicode: false))
                }
            }
            #expect(ends.count==1 && barStarts.count==1)
        }
    }

    @Test func percentagesAreRightAligned() {
        #expect(StageLine.status(.fraction(0.68), unicode: false)==" 68.0%")
        #expect(StageLine.status(.fraction(1), unicode: false)=="100.0%")
        #expect(StageLine.status(.fraction(0), unicode: false)=="  0.0%")
        #expect(StageLine.status(.fraction(1.7), unicode: false)=="100.0%")
        #expect(StageLine.status(.done, unicode: false)=="  done")
        #expect(StageLine.status(.skip, unicode: false)=="  skip")
        #expect(StageLine.status(.working(spinner: 0), unicode: false)=="     |")
        #expect(StageLine.status(.working(spinner: 0), unicode: true)=="     ⠋")
    }

    @Test func barFillsTheFreeColumnsOnlyForFractions() {
        let w=stages.map(\.count).max()!
        let half=StageLine.format(index: 2, total: 4, name: stages[1], nameWidth: w, state: .fraction(0.5), style: style(80))
        let bar=half.dropFirst(4+6+w+2).dropLast(2+StageLine.statusWidth)
        #expect(bar.allSatisfy { $0=="#" || $0=="-" } && bar.filter { $0=="#" }.count==bar.count/2)
        let done=StageLine.format(index: 2, total: 4, name: stages[1], nameWidth: w, state: .done, style: style(80))
        #expect(!done.contains("#") && !done.contains("-"))
        // Too narrow for a useful bar: the bar is omitted but the status column stays at the edge.
        let narrow=StageLine.format(index: 2, total: 4, name: stages[1], nameWidth: w, state: .fraction(0.5), style: style(40))
        #expect(!narrow.contains("#") && narrow.hasSuffix(" 50.0%") && StageLine.visibleWidth(narrow)==39)
    }

    @Test func colourDoesNotChangeVisibleLayout() {
        let w=stages.map(\.count).max()!
        let plain=StageLine.format(index: 4, total: 4, name: stages[3], nameWidth: w, state: .fraction(0.25), style: style(90))
        let coloured=StageLine.format(index: 4, total: 4, name: stages[3], nameWidth: w, state: .fraction(0.25), style: style(90, color: true))
        #expect(coloured.contains("\u{1B}[1;34m==>") && StageLine.visibleWidth(coloured)==StageLine.visibleWidth(plain))
    }

    @Test func plainLinesCarryNoBarOrControlCharacters() {
        let line=StageLine.format(index: 2, total: 4, name: "Separating vocals", nameWidth: 17, state: .done, style: .plain)
        #expect(line=="==> [2/4] Separating vocals  done")
        #expect(!line.contains("\r") && !line.contains("\u{1B}"))
    }

    @Test func durationsInWords() {
        #expect(durationInWords(0.4)=="less than a second")
        #expect(durationInWords(1)=="1 second")
        #expect(durationInWords(42.9)=="42 seconds")
        #expect(durationInWords(60)=="1 minute")
        #expect(durationInWords(61)=="1 minute 1 second")
        #expect(durationInWords(309)=="5 minutes 9 seconds")
        #expect(durationInWords(3600)=="1 hour")
        #expect(durationInWords(3723)=="1 hour 2 minutes 3 seconds")
        #expect(durationInWords(7320)=="2 hours 2 minutes")
    }

    @Test func detection() {
        let tty=["TERM": "xterm-256color", "LANG": "en_US.UTF-8"]
        #expect(ProgressStyle.detect(environment: tty, isTerminal: true, columns: 100)==ProgressStyle(interactive: true, color: true, unicode: true, width: 100))
        #expect(!ProgressStyle.detect(environment: tty, isTerminal: false, columns: 100).interactive)
        #expect(!ProgressStyle.detect(environment: tty.merging(["CI": "true"]) { $1 }, isTerminal: true, columns: 100).interactive)
        #expect(!ProgressStyle.detect(environment: ["TERM": "dumb"], isTerminal: true, columns: 100).interactive)
        let noColor=ProgressStyle.detect(environment: tty.merging(["NO_COLOR": "1"]) { $1 }, isTerminal: true, columns: 100)
        #expect(noColor.interactive && !noColor.color)
        #expect(!ProgressStyle.detect(environment: ["TERM": "xterm"], isTerminal: true, columns: 100).unicode)
        #expect(ProgressStyle.detect(environment: ["COLUMNS": "132"], isTerminal: false, columns: nil).width==132)
    }

    /// A reporter writing to a buffer with a controllable clock.
    final class Capture: @unchecked Sendable {
        var now=0.0, out=""
        func reporter(_ style: ProgressStyle, quiet: Bool = false, verbose: Bool = false, stages: [String]) -> StageReporter {
            StageReporter(stages: stages, style: style, quiet: quiet, verbose: verbose, clock: { self.now }, sink: { self.out+=$0 })
        }
    }

    @Test func plainOutputHasOneLinePerFinishedStage() {
        let c=Capture(), r=c.reporter(.plain, stages: stages)
        r.begin(1); r.finish()
        r.begin(2); for i in 0...100 { r.update(fraction: Double(i)/100) }; r.finish()
        r.skip(3)
        r.begin(4); r.update(fraction: 0.5); r.indeterminate(); r.finish()
        r.summary("Generated out.mp4 in \(durationInWords(309))")
        #expect(c.out=="""
        ==> [1/4] Reading audio  done
        ==> [2/4] Separating vocals  done
        ==> [3/4] Aligning lyrics  skip
        ==> [4/4] Rendering video  done
        ==> Generated out.mp4 in 5 minutes 9 seconds

        """)
    }

    @Test func interactiveRedrawsAreThrottled() {
        let c=Capture(), r=c.reporter(style(80), stages: stages)
        r.begin(2)
        for i in 1...50 { c.now+=0.01; r.update(fraction: Double(i)/50) }
        // One spinner draw, one immediate switch to a fraction, then at most one redraw per 0.2 s.
        let draws=c.out.components(separatedBy: "\r").count-1
        #expect(draws<=4, "\(draws)")
        c.now+=1; r.finish()
        #expect(c.out.hasSuffix("  done\n") && !c.out.contains("\u{1B}"))
    }

    @Test func diagnosticsInterleaveWithoutCorruptingTheActiveLine() {
        let c=Capture(), r=c.reporter(style(80), stages: stages)
        r.begin(2); c.now+=1; r.update(fraction: 0.3)
        r.warning("Parenthesized backing choruses are unsupported.")
        #expect(c.out.contains("\r\u{1B}[KWarning: Parenthesized backing choruses are unsupported.\n\r==> [2/4]"))
        r.error("the lyrics cannot be aligned")
        #expect(c.out.hasSuffix("\r\u{1B}[KError: the lyrics cannot be aligned\n"))
    }

    @Test func quietShowsOnlyWarningsAndErrors() {
        for style in [ProgressStyle.plain, style(80)] {
            let c=Capture(), r=c.reporter(style, quiet: true, verbose: true, stages: stages)
            r.begin(1); r.info("info"); r.detail("detail"); r.finish()
            r.skip(2); r.warning("careful"); r.summary("Generated x in 1 second"); r.error("failed")
            #expect(c.out=="Warning: careful\nError: failed\n")
        }
    }

    @Test func verboseDetailsAreSeparateLines() {
        let c=Capture(), r=c.reporter(.plain, verbose: true, stages: stages)
        r.begin(4); r.detail("1800/7200 frames, 30 fps"); r.finish()
        #expect(c.out=="1800/7200 frames, 30 fps\n==> [4/4] Rendering video  done\n")
        let n=Capture(), q=n.reporter(.plain, stages: stages)
        q.begin(4); q.detail("hidden"); q.finish()
        #expect(!n.out.contains("hidden"))
    }

    @Test func spinnerTicksOnlyWhileIndeterminate() {
        let c=Capture(), r=c.reporter(style(80, unicode: true), stages: stages)
        r.begin(1)
        c.now+=0.25; r.tick()
        #expect(c.out.hasSuffix("⠙"))
        r.update(fraction: 0.5); let before=c.out
        c.now+=0.25; r.tick()
        #expect(c.out==before)
    }

    @Test func narrowTerminalsShortenNamesButKeepTheStatusColumn() {
        let line=StageLine.format(index: 2, total: 4, name: "Separating vocals", nameWidth: 17, state: .fraction(0.68), style: style(24))
        #expect(StageLine.visibleWidth(line)==23 && line.hasSuffix(" 68.0%") && line.contains("…"))
    }
}
