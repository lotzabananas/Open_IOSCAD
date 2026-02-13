import XCTest
@testable import GeometryKernel

final class PrimitiveTests: XCTestCase {

    // MARK: - Cube

    func testCubeDefaultSize() {
        let params = PrimitiveParams(size: SIMD3<Float>(1, 1, 1))
        let mesh = CubeGenerator.generate(params: params)

        XCTAssertFalse(mesh.isEmpty)
        // A cube has 6 faces, each split into 2 triangles = 12 triangles
        XCTAssertEqual(mesh.triangleCount, 12)
        XCTAssertEqual(mesh.vertexCount, 8)
    }

    func testCubeBoundingBox() {
        let params = PrimitiveParams(size: SIMD3<Float>(10, 20, 30), center: true)
        let mesh = CubeGenerator.generate(params: params)

        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.x, -5, accuracy: 0.01)
        XCTAssertEqual(bb.max.x, 5, accuracy: 0.01)
        XCTAssertEqual(bb.min.y, -10, accuracy: 0.01)
        XCTAssertEqual(bb.max.y, 10, accuracy: 0.01)
        XCTAssertEqual(bb.min.z, -15, accuracy: 0.01)
        XCTAssertEqual(bb.max.z, 15, accuracy: 0.01)
    }

    func testCubeNotCentered() {
        let params = PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: false)
        let mesh = CubeGenerator.generate(params: params)

        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.x, 0, accuracy: 0.01)
        XCTAssertEqual(bb.min.y, 0, accuracy: 0.01)
        XCTAssertEqual(bb.min.z, 0, accuracy: 0.01)
        XCTAssertEqual(bb.max.x, 10, accuracy: 0.01)
        XCTAssertEqual(bb.max.y, 10, accuracy: 0.01)
        XCTAssertEqual(bb.max.z, 10, accuracy: 0.01)
    }

    // MARK: - Cylinder

    func testCylinderProducesGeometry() {
        let params = PrimitiveParams(radius: 5, height: 10)
        let mesh = CylinderGenerator.generate(params: params)

        XCTAssertFalse(mesh.isEmpty)
        XCTAssertGreaterThan(mesh.triangleCount, 10)
    }

    func testCylinderBoundingBoxRadius() {
        let params = PrimitiveParams(radius: 5, height: 20, center: true)
        let mesh = CylinderGenerator.generate(params: params)

        let bb = mesh.boundingBox
        // Radius 5 means X and Y extents should be about 10 (diameter)
        let xExtent = bb.max.x - bb.min.x
        let yExtent = bb.max.y - bb.min.y
        XCTAssertEqual(xExtent, 10, accuracy: 0.5)
        XCTAssertEqual(yExtent, 10, accuracy: 0.5)
        // Height 20, centered
        XCTAssertEqual(bb.min.z, -10, accuracy: 0.01)
        XCTAssertEqual(bb.max.z, 10, accuracy: 0.01)
    }

    func testConeHasDifferentRadii() {
        let params = PrimitiveParams(radius1: 10, radius2: 5, height: 20)
        let mesh = CylinderGenerator.generate(params: params)

        XCTAssertFalse(mesh.isEmpty)
        let bb = mesh.boundingBox
        // Bottom radius 10 means extent at least 20 in diameter
        let xExtent = bb.max.x - bb.min.x
        XCTAssertEqual(xExtent, 20, accuracy: 1.0)
    }

    // MARK: - Sphere

    func testSphereProducesGeometry() {
        let params = PrimitiveParams(radius: 5)
        let mesh = SphereGenerator.generate(params: params)

        XCTAssertFalse(mesh.isEmpty)
        XCTAssertGreaterThan(mesh.triangleCount, 20)
    }

    func testSphereBoundingBox() {
        let params = PrimitiveParams(radius: 10)
        let mesh = SphereGenerator.generate(params: params)

        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.x, -10, accuracy: 1.0)
        XCTAssertEqual(bb.max.x, 10, accuracy: 1.0)
        XCTAssertEqual(bb.min.y, -10, accuracy: 1.0)
        XCTAssertEqual(bb.max.y, 10, accuracy: 1.0)
        XCTAssertEqual(bb.min.z, -10, accuracy: 0.5)
        XCTAssertEqual(bb.max.z, 10, accuracy: 0.5)
    }

    // MARK: - Polyhedron

    func testPolyhedronWithValidFaces() {
        // Simple tetrahedron
        let points: [[SIMD3<Float>]] = [[
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(0.5, 1, 0),
            SIMD3<Float>(0.5, 0.5, 1),
        ]]
        let faces: [[Int]] = [
            [0, 1, 2],
            [0, 1, 3],
            [1, 2, 3],
            [0, 2, 3],
        ]

        let params = PrimitiveParams(points: points, faces: faces)
        let mesh = PolyhedronGenerator.generate(params: params)

        XCTAssertFalse(mesh.isEmpty)
        XCTAssertEqual(mesh.triangleCount, 4)
    }

    func testPolyhedronSkipsInvalidFaceIndices() {
        let points: [[SIMD3<Float>]] = [[
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(0, 1, 0),
        ]]
        // One valid face, one with out-of-bounds indices
        let faces: [[Int]] = [
            [0, 1, 2],
            [0, 1, 99], // Out of bounds — should be skipped
        ]

        let params = PrimitiveParams(points: points, faces: faces)
        let mesh = PolyhedronGenerator.generate(params: params)

        // Only the valid face should produce triangles
        XCTAssertEqual(mesh.triangleCount, 1)
    }

    func testPolyhedronWithNoPoints() {
        let params = PrimitiveParams()
        let mesh = PolyhedronGenerator.generate(params: params)
        XCTAssertTrue(mesh.isEmpty)
    }
}
