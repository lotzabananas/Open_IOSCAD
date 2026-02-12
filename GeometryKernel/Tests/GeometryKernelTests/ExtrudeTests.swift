import XCTest
import simd
@testable import GeometryKernel

final class ExtrudeTests: XCTestCase {
    func testLinearExtrudeSquare() {
        let square = Polygon2D(points: [
            SIMD2<Float>(0, 0), SIMD2<Float>(1, 0),
            SIMD2<Float>(1, 1), SIMD2<Float>(0, 1)
        ])
        let params = ExtrudeParams(height: 1.0)
        let mesh = LinearExtrudeOperation.extrude(polygon: square, params: params)
        XCTAssertGreaterThan(mesh.triangleCount, 0)
        // Should produce a box-like shape
        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.z, 0.0, accuracy: 0.001)
        XCTAssertEqual(bb.max.z, 1.0, accuracy: 0.001)
        XCTAssertEqual(bb.max.x - bb.min.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(bb.max.y - bb.min.y, 1.0, accuracy: 0.001)
    }

    func testLinearExtrudeCentered() {
        let square = Polygon2D(points: [
            SIMD2<Float>(0, 0), SIMD2<Float>(1, 0),
            SIMD2<Float>(1, 1), SIMD2<Float>(0, 1)
        ])
        let params = ExtrudeParams(height: 10.0, center: true)
        let mesh = LinearExtrudeOperation.extrude(polygon: square, params: params)
        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.z, -5.0, accuracy: 0.001)
        XCTAssertEqual(bb.max.z, 5.0, accuracy: 0.001)
    }

    func testLinearExtrudeWithTwist() {
        let square = Polygon2D(points: [
            SIMD2<Float>(-1, -1), SIMD2<Float>(1, -1),
            SIMD2<Float>(1, 1), SIMD2<Float>(-1, 1)
        ])
        let params = ExtrudeParams(height: 5.0, twist: 90.0, slices: 10)
        let mesh = LinearExtrudeOperation.extrude(polygon: square, params: params)
        XCTAssertGreaterThan(mesh.triangleCount, 0)
        // With twist, the top should be rotated
        let bb = mesh.boundingBox
        XCTAssertEqual(bb.max.z, 5.0, accuracy: 0.001)
    }

    func testRotateExtrudeRectangle() {
        // Rectangle offset from Y axis -> torus-like shape
        let rect = Polygon2D(points: [
            SIMD2<Float>(5, -1), SIMD2<Float>(7, -1),
            SIMD2<Float>(7, 1), SIMD2<Float>(5, 1)
        ])
        let params = ExtrudeParams(angle: 360.0, fn: 24)
        let mesh = RotateExtrudeOperation.extrude(polygon: rect, params: params)
        XCTAssertGreaterThan(mesh.triangleCount, 0)
        // Should be symmetric around Y axis
        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.x, -bb.max.x, accuracy: 0.5)
    }

    func testLinearExtrudeEmptyPolygon() {
        let empty = Polygon2D()
        let params = ExtrudeParams(height: 1.0)
        let mesh = LinearExtrudeOperation.extrude(polygon: empty, params: params)
        XCTAssertTrue(mesh.isEmpty)
    }

    func testRotateExtrudePartial() {
        let rect = Polygon2D(points: [
            SIMD2<Float>(3, 0), SIMD2<Float>(5, 0),
            SIMD2<Float>(5, 2), SIMD2<Float>(3, 2)
        ])
        let params = ExtrudeParams(angle: 180.0, fn: 16)
        let mesh = RotateExtrudeOperation.extrude(polygon: rect, params: params)
        XCTAssertGreaterThan(mesh.triangleCount, 0)
    }
}
