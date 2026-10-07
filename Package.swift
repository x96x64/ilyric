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
        .testTarget(name: "SpikeTests", dependencies: ["SpikeCore", "RenderMac"])
    ],
    swiftLanguageModes: [.v5]
)
