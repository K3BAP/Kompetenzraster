// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RasterExtractor",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "RasterExtractor", path: "Sources/RasterExtractor")
    ]
)
