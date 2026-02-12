// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SCADEngine",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SCADEngine", targets: ["SCADEngine"]),
    ],
    dependencies: [
        .package(path: "../GeometryKernel"),
    ],
    targets: [
        .target(name: "SCADEngine", dependencies: ["GeometryKernel"]),
        .testTarget(name: "SCADEngineTests", dependencies: ["SCADEngine"]),
    ]
)
