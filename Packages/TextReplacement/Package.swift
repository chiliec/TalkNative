// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "TextReplacement",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "TextReplacement", targets: ["TextReplacement"])],
    targets: [
        .target(name: "TextReplacement"),
        .testTarget(name: "TextReplacementTests", dependencies: ["TextReplacement"]),
    ]
)
