// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "KeyboardUI",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "KeyboardUI", targets: ["KeyboardUI"])],
    dependencies: [
        .package(path: "../EnhancerCore"),
        .package(path: "../PresetKit"),
        .package(path: "../EnhancerUI"),
        .package(path: "../TextReplacement"),
    ],
    targets: [
        .target(
            name: "KeyboardUI",
            dependencies: [
                .product(name: "EnhancerCore", package: "EnhancerCore"),
                .product(name: "PresetKit", package: "PresetKit"),
                .product(name: "EnhancerUI", package: "EnhancerUI"),
                .product(name: "TextReplacement", package: "TextReplacement"),
            ]),
        .testTarget(name: "KeyboardUITests", dependencies: ["KeyboardUI"]),
    ]
)
