// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WikipediaKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WikipediaKit", targets: ["WikipediaKit"]),
        .library(name: "WikipediaUI", targets: ["WikipediaUI"]),
    ],
    targets: [
        .target(name: "WikipediaKit"),
        .target(name: "WikipediaUI", dependencies: ["WikipediaKit"]),
        .testTarget(
            name: "WikipediaKitTests",
            dependencies: ["WikipediaKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
