// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ParametricEngine",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ParametricEngine", targets: ["ParametricEngine"]),
    ],
    dependencies: [
        .package(path: "../GeometryKernel"),
    ],
    targets: [
        .target(name: "ParametricEngine", dependencies: ["GeometryKernel"]),
        .testTarget(name: "ParametricEngineTests", dependencies: ["ParametricEngine"]),
    ]
)
