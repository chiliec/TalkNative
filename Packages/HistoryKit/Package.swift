// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "HistoryKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "HistoryKit", targets: ["HistoryKit"])],
    targets: [
        .target(name: "HistoryKit"),
        .testTarget(name: "HistoryKitTests", dependencies: ["HistoryKit"])
    ]
)
