import Foundation
import AppKit
import CoreML
import AlignmentMac
import LyricsSliceCore

/// The `doctor` subcommand: environment checks, each with its recovery step.
enum Doctor {
    static let help="""
    Usage: ilyrics doctor

    Reports the macOS version, compute units, SF Symbols, the model cache, and the toolchain.
    """

    static func command(_ arguments: ArraySlice<String>) throws {
        let options=try Options(arguments,valued:[],flags:["help"],short:["h":"help"])
        if options.has("help") { print(help);return }
        guard options.operands.isEmpty else { throw UsageError(message:"doctor takes no operands") }
        var problems=0
        func report(_ ok: Bool, _ label: String, _ detail: String, fix: String? = nil) {
            print("\(ok ? "ok  " : "FAIL") \(label): \(detail)")
            if !ok,let fix { print("     \(fix)");problems+=1 }
        }
        let version=ProcessInfo.processInfo.operatingSystemVersion
        report(version.majorVersion>=14,"macOS","\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",fix:"iLyrics requires macOS 14 or later")
        let devices=MLComputeDevice.allComputeDevices.map { device -> String in
            switch device { case .cpu: "CPU"; case .gpu: "GPU"; case .neuralEngine: "Neural Engine"; @unknown default: "other" }
        }
        report(true,"Compute units","\(devices.joined(separator:", ")); alignment uses the CPU unless --fast is given")
        let parts:[ScreenPart]=[.previous,.next,.playback,.volumeLow,.volumeHigh,.bottomLeft,.bottomCenter,.bottomRight,.translation,.singCompact,.singExpanded]
        let names=Set(parts.flatMap { p in [true,false].compactMap { ControlSymbols.symbol(for:p,playing:$0)?.name } })
        let missing=names.filter { NSImage(systemSymbolName:$0,accessibilityDescription:nil)==nil }.sorted()
        report(missing.isEmpty,"SF Symbols",missing.isEmpty ? "all \(names.count) control symbols resolve" : "missing \(missing.joined(separator:", "))",
               fix:"update macOS; control symbols are resolved from the system at render time")
        let templates=try? Models.templates()
        report(templates != nil,"Model templates",templates?.path ?? "not found",fix:"set ILYRICS_TEMPLATES to the directory of the weightless model templates")
        let installed=try templates.flatMap { try InstalledModels.existing(in:Models.directory,templates:$0) } != nil
        report(installed,"Alignment models",installed ? "installed in \(Models.directory.path) (\(Models.size(Models.directory)))" : "not installed",
               fix:"run 'ilyrics models install' (about 460 MB is downloaded), or let 'render' or 'align' install them on first use")
        #if compiler(>=6.3)
        let swift="Swift 6.3 or later"
        #elseif compiler(>=6.0)
        let swift="Swift 6.0 to 6.2"
        #else
        let swift="Swift 5"
        #endif
        report(true,"Toolchain","built with \(swift); iLyrics \(CLI.version)")
        print(problems==0 ? "\nNo problems found." : "\n\(problems) problem\(problems==1 ? "" : "s") found.")
        if problems>0 { exit(1) }
    }
}
