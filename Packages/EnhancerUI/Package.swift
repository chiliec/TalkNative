// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "EnhancerUI",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "EnhancerUI", targets: ["EnhancerUI"])],
    dependencies: [
        .package(path: "../EnhancerCore"),
        .package(path: "../PresetKit")
    ],
    targets: [
        .target(name: "EnhancerUI", dependencies: [
            .product(name: "EnhancerCore", package: "EnhancerCore"),
            .product(name: "PresetKit", package: "PresetKit")
        ]),
        .testTarget(name: "EnhancerUITests", dependencies: ["EnhancerUI"])
    ]
)
