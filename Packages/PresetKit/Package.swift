// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "PresetKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "PresetKit", targets: ["PresetKit"])],
    targets: [
        .target(name: "PresetKit"),
        .testTarget(name: "PresetKitTests", dependencies: ["PresetKit"]),
    ]
)
