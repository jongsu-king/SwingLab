// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwingLabCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "SwingLabCore", targets: ["SwingLabCore"])],
    targets: [
        .target(name: "SwingLabCore"),
        .testTarget(name: "SwingLabCoreTests", dependencies: ["SwingLabCore"])
    ]
)
