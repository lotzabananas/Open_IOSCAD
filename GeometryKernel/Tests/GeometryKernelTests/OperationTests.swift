import XCTest
@testable import GeometryKernel

final class OperationTests: XCTestCase {

    private func box(size: Float) -> TriangleMesh {
        let params = PrimitiveParams(size: SIMD3<Float>(size, size, size), center: true)
        return CubeGenerator.generate(params: params)
    }

    // MARK: - Fillet

    func testFilletOnBox() {
        let mesh = box(size: 20)
        let result = FilletOperation.apply(to: mesh, radius: 2.0)
        XCTAssertFalse(result.isEmpty)
        // Filleted mesh should have more triangles than original
        XCTAssertGreaterThanOrEqual(result.triangleCount, mesh.triangleCount)
    }

    func testFilletZeroRadius() {
        let mesh = box(size: 20)
        let result = FilletOperation.apply(to: mesh, radius: 0)
        XCTAssertEqual(result.triangleCount, mesh.triangleCount)
    }

    func testFilletOnEmptyMesh() {
        let result = FilletOperation.apply(to: TriangleMesh(), radius: 2.0)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Chamfer

    func testChamferOnBox() {
        let mesh = box(size: 20)
        let result = ChamferOperation.apply(to: mesh, distance: 1.0)
        XCTAssertFalse(result.isEmpty)
        XCTAssertGreaterThanOrEqual(result.triangleCount, mesh.triangleCount)
    }

    func testChamferZeroDistance() {
        let mesh = box(size: 20)
        let result = ChamferOperation.apply(to: mesh, distance: 0)
        XCTAssertEqual(result.triangleCount, mesh.triangleCount)
    }

    // MARK: - Shell

    func testShellCreatesInnerWalls() {
        let mesh = box(size: 20)
        let result = ShellOperation.apply(to: mesh, thickness: 2.0)
        XCTAssertFalse(result.isEmpty)
        // Shelled mesh has outer + inner faces
        XCTAssertGreaterThan(result.triangleCount, mesh.triangleCount)
    }

    func testShellWithOpenFace() {
        let mesh = box(size: 20)
        let result = ShellOperation.apply(to: mesh, thickness: 2.0, openFaceIndices: [0])
        XCTAssertFalse(result.isEmpty)
        XCTAssertGreaterThan(result.triangleCount, mesh.triangleCount)
    }

    func testShellZeroThickness() {
        let mesh = box(size: 20)
        let result = ShellOperation.apply(to: mesh, thickness: 0)
        XCTAssertEqual(result.triangleCount, mesh.triangleCount)
    }

    // MARK: - Linear Pattern

    func testLinearPatternCountThree() {
        let mesh = box(size: 10)
        let result = PatternOperation.linear(
            mesh: mesh,
            direction: SIMD3<Float>(1, 0, 0),
            count: 3,
            spacing: 20
        )
        XCTAssertFalse(result.isEmpty)
        // 3 copies merged
        XCTAssertEqual(result.triangleCount, mesh.triangleCount * 3)
    }

    func testLinearPatternCountOne() {
        let mesh = box(size: 10)
        let result = PatternOperation.linear(
            mesh: mesh,
            direction: SIMD3<Float>(1, 0, 0),
            count: 1,
            spacing: 20
        )
        XCTAssertEqual(result.triangleCount, mesh.triangleCount)
    }

    func testLinearPatternSpread() {
        let mesh = box(size: 10)
        let result = PatternOperation.linear(
            mesh: mesh,
            direction: SIMD3<Float>(1, 0, 0),
            count: 3,
            spacing: 30
        )
        let bb = result.boundingBox
        // Should span from -5 (first box) to 65 (third box at 60 + 5)
        XCTAssertGreaterThan(bb.max.x - bb.min.x, 60)
    }

    // MARK: - Circular Pattern

    func testCircularPatternFour() {
        let mesh = box(size: 10)
        let result = PatternOperation.circular(
            mesh: mesh,
            axis: SIMD3<Float>(0, 0, 1),
            count: 4,
            totalAngle: 360,
            equalSpacing: true
        )
        XCTAssertEqual(result.triangleCount, mesh.triangleCount * 4)
    }

    // MARK: - Mirror Pattern

    func testMirrorCreatesDouble() {
        let mesh = box(size: 10)
        let result = PatternOperation.mirror(mesh: mesh, planeNormal: SIMD3<Float>(1, 0, 0))
        XCTAssertEqual(result.triangleCount, mesh.triangleCount * 2)
    }

    func testMirrorOnEmptyMesh() {
        let result = PatternOperation.mirror(mesh: TriangleMesh(), planeNormal: SIMD3<Float>(1, 0, 0))
        XCTAssertTrue(result.isEmpty)
    }
}
