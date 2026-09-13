// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FLACMetadata",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FLACMetadata", targets: ["FLACMetadata"]),
    ],
    targets: [
        .target(name: "FLACMetadata"),
        .testTarget(name: "FLACMetadataTests", dependencies: ["FLACMetadata"]),
    ]
)
