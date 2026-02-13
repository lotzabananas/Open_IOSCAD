import XCTest
@testable import GeometryKernel

final class CSGTests: XCTestCase {

    /// Helper: generate a centered cube mesh of given size.
    private func box(size: Float) -> TriangleMesh {
        let params = PrimitiveParams(size: SIMD3<Float>(size, size, size), center: true)
        return CubeGenerator.generate(params: params)
    }

    /// Helper: generate a cube at a specific position.
    private func box(size: Float, at offset: SIMD3<Float>) -> TriangleMesh {
        var mesh = box(size: size)
        let matrix = TransformOperations.translationMatrix(offset)
        mesh.apply(transform: matrix)
        return mesh
    }

    // MARK: - Union

    func testUnionOfEmptyMeshes() {
        let result = CSGOperations.perform(.union, on: [TriangleMesh(), TriangleMesh()])
        XCTAssertTrue(result.isEmpty)
    }

    func testUnionOfOneEmptyOneReal() {
        let a = box(size: 10)
        let result = CSGOperations.perform(.union, on: [a, TriangleMesh()])
        XCTAssertFalse(result.isEmpty)
    }

    func testUnionOfNonOverlappingBoxes() {
        let a = box(size: 10, at: SIMD3<Float>(-20, 0, 0))
        let b = box(size: 10, at: SIMD3<Float>(20, 0, 0))

        let result = CSGOperations.perform(.union, on: [a, b])
        XCTAssertFalse(result.isEmpty)

        // Should span from -25 to +25 in X
        let bb = result.boundingBox
        XCTAssertLessThan(bb.min.x, -10)
        XCTAssertGreaterThan(bb.max.x, 10)
    }

    func testUnionOfOverlappingBoxes() {
        let a = box(size: 10)
        let b = box(size: 10, at: SIMD3<Float>(5, 0, 0))

        let result = CSGOperations.perform(.union, on: [a, b])
        XCTAssertFalse(result.isEmpty)

        // Union should span from -5 to +10 in X
        let bb = result.boundingBox
        XCTAssertEqual(bb.min.x, -5, accuracy: 0.5)
        XCTAssertEqual(bb.max.x, 10, accuracy: 0.5)
    }

    // MARK: - Difference

    func testDifferenceFromEmpty() {
        let result = CSGOperations.perform(.difference, on: [TriangleMesh(), box(size: 10)])
        XCTAssertTrue(result.isEmpty)
    }

    func testDifferenceWithNonOverlapping() {
        // When meshes don't overlap, difference returns the first mesh unchanged
        let a = box(size: 10)
        let b = box(size: 10, at: SIMD3<Float>(100, 0, 0))

        let result = CSGOperations.perform(.difference, on: [a, b])
        XCTAssertFalse(result.isEmpty)

        let bb = result.boundingBox
        let size = bb.max - bb.min
        XCTAssertEqual(size.x, 10, accuracy: 0.5)
    }

    func testDifferenceWithOverlap() {
        let a = box(size: 20)
        let b = box(size: 10)

        let result = CSGOperations.perform(.difference, on: [a, b])
        XCTAssertFalse(result.isEmpty)
        // Result should have more triangles than the original box
        XCTAssertGreaterThan(result.triangleCount, 12)
    }

    // MARK: - Intersection

    func testIntersectionOfNonOverlapping() {
        let a = box(size: 10, at: SIMD3<Float>(-50, 0, 0))
        let b = box(size: 10, at: SIMD3<Float>(50, 0, 0))

        let result = CSGOperations.perform(.intersection, on: [a, b])
        XCTAssertTrue(result.isEmpty)
    }

    func testIntersectionOfOverlapping() {
        let a = box(size: 20)
        let b = box(size: 10)

        let result = CSGOperations.perform(.intersection, on: [a, b])
        XCTAssertFalse(result.isEmpty)

        // Intersection of 20x20x20 and 10x10x10 (both centered) = 10x10x10
        let bb = result.boundingBox
        let size = bb.max - bb.min
        XCTAssertEqual(size.x, 10, accuracy: 1.0)
        XCTAssertEqual(size.y, 10, accuracy: 1.0)
        XCTAssertEqual(size.z, 10, accuracy: 1.0)
    }

    // MARK: - Single mesh

    func testOperationOnSingleMesh() {
        let a = box(size: 10)
        let result = CSGOperations.perform(.union, on: [a])
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result.triangleCount, a.triangleCount)
    }

    func testOperationOnEmptyArray() {
        let result = CSGOperations.perform(.union, on: [])
        XCTAssertTrue(result.isEmpty)
    }
}
