// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GeometryKernel",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "GeometryKernel", targets: ["GeometryKernel"]),
    ],
    targets: [
        .target(name: "GeometryKernel"),
        .testTarget(name: "GeometryKernelTests", dependencies: ["GeometryKernel"]),
    ]
)
