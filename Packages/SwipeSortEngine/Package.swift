// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwipeSortEngine",
    platforms: [.watchOS("26.0"), .macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "SwipeSortEngine", targets: ["SwipeSortEngine"]),
    ],
    targets: [
        .target(name: "SwipeSortEngine"),
        .testTarget(name: "SwipeSortEngineTests", dependencies: ["SwipeSortEngine"]),
    ],
    swiftLanguageModes: [.v6]
)
