// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iLyrics",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ilyrics", targets: ["ilyrics"])],
    targets: [
        .target(name: "SpikeCore"),
        .target(name: "RenderMac", dependencies: ["SpikeCore"]),
        .executableTarget(name: "ilyrics", dependencies: ["AlignmentCore", "AlignmentMac", "LyricsInputCore", "LyricsInputMac", "LyricsSliceCore", "LyricsSliceMac", "SpikeCore", "RenderMac"]),
        .executableTarget(name: "ReferenceProbe", dependencies: ["SpikeCore", "RenderMac"]),
        .target(name: "LyricsSliceCore", dependencies: ["SpikeCore"]),
        .target(name: "LyricsSliceMac", dependencies: ["LyricsSliceCore", "SpikeCore"]),
        .executableTarget(name: "LyricsSliceProbe", dependencies: ["LyricsSliceCore", "LyricsSliceMac", "SpikeCore"]),
        .executableTarget(name: "LyricsCompositionProbe", dependencies: ["LyricsSliceCore", "LyricsSliceMac", "SpikeCore", "RenderMac"]),
        .executableTarget(name: "LyricsScreenProbe", dependencies: ["LyricsSliceCore", "LyricsSliceMac", "SpikeCore", "RenderMac"]),
        .testTarget(name: "LyricsSliceTests", dependencies: ["LyricsSliceCore", "LyricsSliceMac", "SpikeCore"]),
        .target(name: "LyricsInputCore", dependencies: ["SpikeCore"]),
        .target(name: "LyricsInputMac", dependencies: ["LyricsInputCore", "LyricsSliceCore", "LyricsSliceMac", "SpikeCore", "RenderMac"]),
        .testTarget(name: "LyricsInputTests", dependencies: ["LyricsInputCore", "LyricsInputMac", "LyricsSliceCore", "LyricsSliceMac", "SpikeCore"]),
        .testTarget(name: "SpikeTests", dependencies: ["SpikeCore", "RenderMac"]),
        .target(name: "AlignmentCore"),
        .target(name: "AlignmentMac", dependencies: ["AlignmentCore"]),
        .executableTarget(name: "DocumentationMedia", dependencies: ["LyricsInputCore", "LyricsInputMac", "LyricsSliceCore", "SpikeCore"]),
        .testTarget(name: "AlignmentMacTests", dependencies: ["AlignmentCore", "AlignmentMac"], resources: [.copy("Fixtures")]),
        .testTarget(name: "AlignmentTests", dependencies: ["AlignmentCore"], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
