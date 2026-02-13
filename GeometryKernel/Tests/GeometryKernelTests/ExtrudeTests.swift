import XCTest
@testable import GeometryKernel

final class ExtrudeTests: XCTestCase {

    // MARK: - Linear extrude

    func testLinearExtrudeRectangle() {
        let polygon = Polygon2D(points: [
            SIMD2<Float>(-5, -5),
            SIMD2<Float>(5, -5),
            SIMD2<Float>(5, 5),
            SIMD2<Float>(-5, 5),
        ])

        let params = ExtrudeParams(height: 20)
        let mesh = LinearExtrudeOperation.extrude(polygon: polygon, params: params)

        XCTAssertFalse(mesh.isEmpty)

        let bb = mesh.boundingBox
        let size = bb.max - bb.min
        XCTAssertEqual(size.x, 10, accuracy: 0.5)
        XCTAssertEqual(size.y, 10, accuracy: 0.5)
        XCTAssertEqual(size.z, 20, accuracy: 0.5)
    }

    func testLinearExtrudeCircle() {
        var points: [SIMD2<Float>] = []
        let segments = 32
        for i in 0..<segments {
            let angle = Float(i) / Float(segments) * 2.0 * .pi
            points.append(SIMD2<Float>(5 * cos(angle), 5 * sin(angle)))
        }
        let polygon = Polygon2D(points: points)

        let params = ExtrudeParams(height: 10)
        let mesh = LinearExtrudeOperation.extrude(polygon: polygon, params: params)

        XCTAssertFalse(mesh.isEmpty)

        let bb = mesh.boundingBox
        let size = bb.max - bb.min
        XCTAssertEqual(size.x, 10, accuracy: 1.0)
        XCTAssertEqual(size.y, 10, accuracy: 1.0)
        XCTAssertEqual(size.z, 10, accuracy: 0.5)
    }

    func testLinearExtrudeCentered() {
        let polygon = Polygon2D(points: [
            SIMD2<Float>(-5, -5),
            SIMD2<Float>(5, -5),
            SIMD2<Float>(5, 5),
            SIMD2<Float>(-5, 5),
        ])

        let params = ExtrudeParams(height: 20, center: true)
        let mesh = LinearExtrudeOperation.extrude(polygon: polygon, params: params)

        let bb = mesh.boundingBox
        // Centered means z from -10 to +10
        XCTAssertEqual(bb.min.z, -10, accuracy: 0.5)
        XCTAssertEqual(bb.max.z, 10, accuracy: 0.5)
    }

    func testLinearExtrudeEmptyPolygon() {
        let polygon = Polygon2D()
        let params = ExtrudeParams(height: 10)
        let mesh = LinearExtrudeOperation.extrude(polygon: polygon, params: params)
        XCTAssertTrue(mesh.isEmpty)
    }

    // MARK: - Kernel integration

    func testKernelEvaluatesExtrude() {
        let kernel = GeometryKernel()
        let profileOp = GeometryOp.primitive(
            .polygon,
            PrimitiveParams(points2D: [
                SIMD2<Float>(-5, -5),
                SIMD2<Float>(5, -5),
                SIMD2<Float>(5, 5),
                SIMD2<Float>(-5, 5),
            ])
        )
        let extrudeOp = GeometryOp.extrude(
            .linear,
            ExtrudeParams(height: 15),
            profileOp
        )

        let mesh = kernel.evaluate(extrudeOp)
        XCTAssertFalse(mesh.isEmpty)

        let bb = mesh.boundingBox
        let size = bb.max - bb.min
        XCTAssertEqual(size.z, 15, accuracy: 0.5)
    }
}
