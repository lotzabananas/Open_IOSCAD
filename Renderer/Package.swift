// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Renderer",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Renderer", targets: ["Renderer"]),
    ],
    dependencies: [
        .package(path: "../GeometryKernel"),
    ],
    targets: [
        .target(
            name: "Renderer",
            dependencies: ["GeometryKernel"],
            resources: [.process("Shaders")]
        ),
    ]
)
