// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iLyrics",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ilyrics", targets: ["ilyrics"])],
    targets: [
        .target(name: "TimelineCore"),
        .target(name: "ProgressDisplay"),
        .testTarget(name: "ProgressDisplayTests", dependencies: ["ProgressDisplay"]),
        .target(name: "VideoExport", dependencies: ["TimelineCore"]),
        .executableTarget(
            name: "ilyrics",
            dependencies: [
                "ProgressDisplay", "AlignmentCore", "AlignmentMac", "LyricsInputCore", "LyricsInputMac",
                "LyricsScreenCore", "LyricsScreenMac", "TimelineCore", "VideoExport",
            ]),
        .executableTarget(name: "ReferenceProbe", dependencies: ["TimelineCore", "VideoExport"]),
        .target(name: "LyricsScreenCore", dependencies: ["TimelineCore"]),
        .target(name: "LyricsScreenMac", dependencies: ["LyricsScreenCore", "TimelineCore"]),
        .executableTarget(
            name: "LyricsSliceProbe", dependencies: ["LyricsScreenCore", "LyricsScreenMac", "TimelineCore"]),
        .executableTarget(
            name: "LyricsCompositionProbe",
            dependencies: ["LyricsScreenCore", "LyricsScreenMac", "TimelineCore", "VideoExport"]),
        .executableTarget(
            name: "LyricsScreenProbe",
            dependencies: ["LyricsScreenCore", "LyricsScreenMac", "TimelineCore", "VideoExport"]),
        .testTarget(name: "LyricsScreenTests", dependencies: ["LyricsScreenCore", "LyricsScreenMac", "TimelineCore"]),
        .target(name: "LyricsInputCore", dependencies: ["TimelineCore"]),
        .target(
            name: "LyricsInputMac",
            dependencies: ["LyricsInputCore", "LyricsScreenCore", "LyricsScreenMac", "TimelineCore", "VideoExport"]),
        .testTarget(
            name: "LyricsInputTests",
            dependencies: [
                "AlignmentCore", "LyricsInputCore", "LyricsInputMac", "LyricsScreenCore", "LyricsScreenMac",
                "TimelineCore",
            ]),
        .testTarget(name: "TimelineTests", dependencies: ["TimelineCore", "VideoExport"]),
        .target(name: "AlignmentCore"),
        .target(name: "AlignmentMac", dependencies: ["AlignmentCore"]),
        .executableTarget(
            name: "DocumentationMedia",
            dependencies: ["LyricsInputCore", "LyricsInputMac", "LyricsScreenCore", "TimelineCore"]),
        .testTarget(
            name: "AlignmentMacTests", dependencies: ["AlignmentCore", "AlignmentMac"], resources: [.copy("Fixtures")]),
        .testTarget(name: "AlignmentTests", dependencies: ["AlignmentCore"], resources: [.copy("Fixtures")]),
    ],
    swiftLanguageModes: [.v5]
)
