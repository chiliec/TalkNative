// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "EnhancerCore",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "EnhancerCore", targets: ["EnhancerCore"])
    ],
    targets: [
        .target(name: "EnhancerCore"),
        .testTarget(name: "EnhancerCoreTests", dependencies: ["EnhancerCore"])
    ]
)
