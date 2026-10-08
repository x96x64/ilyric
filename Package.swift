// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iLyric",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ilyric", targets: ["ilyric"])],
    targets: [
        .target(name: "SpikeCore"),
        .target(name: "RenderMac", dependencies: ["SpikeCore"]),
        .executableTarget(name: "ilyric", dependencies: ["SpikeCore", "RenderMac"]),
        .executableTarget(name: "ReferenceProbe", dependencies: ["SpikeCore", "RenderMac"]),
        .target(name: "LyricsSliceCore", dependencies: ["SpikeCore"]),
        .target(name: "LyricsSliceMac", dependencies: ["LyricsSliceCore", "SpikeCore"]),
        .executableTarget(name: "LyricsSliceProbe", dependencies: ["LyricsSliceCore", "LyricsSliceMac", "SpikeCore"]),
        .executableTarget(name: "LyricsCompositionProbe", dependencies: ["LyricsSliceCore", "LyricsSliceMac", "SpikeCore", "RenderMac"]),
        .executableTarget(name: "LyricsScreenProbe", dependencies: ["LyricsSliceCore", "LyricsSliceMac", "SpikeCore", "RenderMac"]),
        .testTarget(name: "LyricsSliceTests", dependencies: ["LyricsSliceCore", "LyricsSliceMac", "SpikeCore"]),
        .testTarget(name: "SpikeTests", dependencies: ["SpikeCore", "RenderMac"])
    ],
    swiftLanguageModes: [.v5]
)
