import XCTest
import simd
@testable import GeometryKernel

final class ExportTests: XCTestCase {
    func testSTLBinaryHeader() {
        let cube = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(1, 1, 1)))
        let data = STLExporter.exportBinary(cube)

        // 80-byte header + 4 bytes triangle count + 50 bytes per triangle
        let expectedSize = 80 + 4 + 50 * cube.triangleCount
        XCTAssertEqual(data.count, expectedSize)

        // Check header starts with "OpeniOSCAD"
        let headerString = String(data: data.subdata(in: 0..<17), encoding: .ascii)
        XCTAssertEqual(headerString, "OpeniOSCAD Export")

        // Check triangle count
        let triangleCount = data.subdata(in: 80..<84).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(Int(triangleCount), cube.triangleCount)
    }

    func testSTLBinaryFirstTriangle() {
        let cube = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(1, 1, 1)))
        let data = STLExporter.exportBinary(cube)

        // First triangle starts at offset 84
        // 12 floats (48 bytes) + 2 bytes attribute = 50 bytes per triangle
        XCTAssertGreaterThanOrEqual(data.count, 84 + 50)

        // Verify attribute bytes are 0
        let attrOffset = 84 + 48
        let attr = data.subdata(in: attrOffset..<(attrOffset + 2)).withUnsafeBytes { $0.load(as: UInt16.self) }
        XCTAssertEqual(attr, 0)
    }

    func testSTLASCII() {
        let cube = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(1, 1, 1)))
        let ascii = STLExporter.exportASCII(cube)

        XCTAssertTrue(ascii.hasPrefix("solid OpeniOSCAD"))
        XCTAssertTrue(ascii.hasSuffix("endsolid OpeniOSCAD"))
        XCTAssertTrue(ascii.contains("facet normal"))
        XCTAssertTrue(ascii.contains("outer loop"))
        XCTAssertTrue(ascii.contains("vertex"))
    }

    func testThreeMFExport() {
        let cube = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(1, 1, 1)))
        let data = ThreeMFExporter.export(cube)

        // Should start with ZIP signature PK\x03\x04
        XCTAssertGreaterThan(data.count, 4)
        XCTAssertEqual(data[0], 0x50) // P
        XCTAssertEqual(data[1], 0x4B) // K
        XCTAssertEqual(data[2], 0x03)
        XCTAssertEqual(data[3], 0x04)
    }

    func testSTLEmptyMesh() {
        let mesh = TriangleMesh()
        let data = STLExporter.exportBinary(mesh)
        XCTAssertEqual(data.count, 84) // header + 0 triangles
    }

    func testSTLRoundTrip() {
        let cube = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(10, 10, 10)))
        let data = STLExporter.exportBinary(cube)
        // Verify triangle count matches
        let count = data.subdata(in: 80..<84).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(Int(count), 12)
    }
}
