import XCTest
@testable import GeometryKernel

final class SweepLoftTests: XCTestCase {

    // MARK: - Sweep Tests

    func testSweepAlongStraightPath() {
        let square = Polygon2D(points: [
            SIMD2<Float>(-5, -5), SIMD2<Float>(5, -5),
            SIMD2<Float>(5, 5), SIMD2<Float>(-5, 5)
        ])
        let path: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0, 0, 50)
        ]

        let mesh = SweepExtrudeOperation.sweep(polygon: square, path: path)
        XCTAssertFalse(mesh.isEmpty)
        XCTAssertGreaterThan(mesh.triangleCount, 0)
    }

    func testSweepAlongCurvedPath() {
        let circle = makeCircle(radius: 3, segments: 12)
        // Curved path: quarter circle in XZ plane
        var path: [SIMD3<Float>] = []
        for i in 0...10 {
            let angle = Float(i) / 10.0 * Float.pi / 2
            path.append(SIMD3<Float>(20 * cos(angle), 0, 20 * sin(angle)))
        }

        let mesh = SweepExtrudeOperation.sweep(polygon: circle, path: path)
        XCTAssertFalse(mesh.isEmpty)
        XCTAssertGreaterThan(mesh.triangleCount, 0)
    }

    func testSweepWithTwist() {
        let square = Polygon2D(points: [
            SIMD2<Float>(-5, -5), SIMD2<Float>(5, -5),
            SIMD2<Float>(5, 5), SIMD2<Float>(-5, 5)
        ])
        let path: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0, 0, 30),
            SIMD3<Float>(0, 0, 60)
        ]

        let mesh = SweepExtrudeOperation.sweep(polygon: square, path: path, twist: Float.pi / 2)
        XCTAssertFalse(mesh.isEmpty)
    }

    func testSweepEmptyPolygon() {
        let empty = Polygon2D()
        let path: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0, 0, 10)
        ]
        let mesh = SweepExtrudeOperation.sweep(polygon: empty, path: path)
        XCTAssertTrue(mesh.isEmpty)
    }

    func testSweepSinglePointPath() {
        let square = Polygon2D(points: [
            SIMD2<Float>(-5, -5), SIMD2<Float>(5, -5),
            SIMD2<Float>(5, 5), SIMD2<Float>(-5, 5)
        ])
        let path: [SIMD3<Float>] = [SIMD3<Float>(0, 0, 0)]
        let mesh = SweepExtrudeOperation.sweep(polygon: square, path: path)
        XCTAssertTrue(mesh.isEmpty)
    }

    // MARK: - Loft Tests

    func testLoftBetweenTwoSquares() {
        let bottom = Polygon2D(points: [
            SIMD2<Float>(-10, -10), SIMD2<Float>(10, -10),
            SIMD2<Float>(10, 10), SIMD2<Float>(-10, 10)
        ])
        let top = Polygon2D(points: [
            SIMD2<Float>(-5, -5), SIMD2<Float>(5, -5),
            SIMD2<Float>(5, 5), SIMD2<Float>(-5, 5)
        ])

        let mesh = LoftExtrudeOperation.loft(
            profiles: [bottom, top],
            heights: [0, 20]
        )
        XCTAssertFalse(mesh.isEmpty)
        XCTAssertGreaterThan(mesh.triangleCount, 0)

        // Should taper from larger bottom to smaller top
        let bb = mesh.boundingBox
        XCTAssertGreaterThan(bb.max.z - bb.min.z, 15)
    }

    func testLoftBetweenThreeProfiles() {
        let bottom = makeSquare(size: 20)
        let middle = makeSquare(size: 10)
        let top = makeSquare(size: 15)

        let mesh = LoftExtrudeOperation.loft(
            profiles: [bottom, middle, top],
            heights: [0, 10, 20]
        )
        XCTAssertFalse(mesh.isEmpty)
    }

    func testLoftMismatchedPointCountReturnsEmpty() {
        let triangle = Polygon2D(points: [
            SIMD2<Float>(0, 0), SIMD2<Float>(10, 0), SIMD2<Float>(5, 10)
        ])
        let square = makeSquare(size: 10)

        let mesh = LoftExtrudeOperation.loft(
            profiles: [triangle, square],
            heights: [0, 20]
        )
        XCTAssertTrue(mesh.isEmpty)
    }

    func testLoftSingleProfileReturnsEmpty() {
        let square = makeSquare(size: 10)
        let mesh = LoftExtrudeOperation.loft(
            profiles: [square],
            heights: [0]
        )
        XCTAssertTrue(mesh.isEmpty)
    }

    // MARK: - Helpers

    private func makeCircle(radius: Float, segments: Int) -> Polygon2D {
        var points: [SIMD2<Float>] = []
        for i in 0..<segments {
            let angle = Float(i) / Float(segments) * 2 * Float.pi
            points.append(SIMD2<Float>(radius * cos(angle), radius * sin(angle)))
        }
        return Polygon2D(points: points)
    }

    private func makeSquare(size: Float) -> Polygon2D {
        let h = size / 2
        return Polygon2D(points: [
            SIMD2<Float>(-h, -h), SIMD2<Float>(h, -h),
            SIMD2<Float>(h, h), SIMD2<Float>(-h, h)
        ])
    }
}
