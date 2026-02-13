import XCTest
@testable import GeometryKernel
import simd

final class TransformTests: XCTestCase {

    // MARK: - Translation

    func testTranslationMatrix() {
        let m = TransformOperations.translationMatrix(SIMD3<Float>(10, 20, 30))
        let origin = m * SIMD4<Float>(0, 0, 0, 1)
        XCTAssertEqual(origin.x, 10, accuracy: 0.01)
        XCTAssertEqual(origin.y, 20, accuracy: 0.01)
        XCTAssertEqual(origin.z, 30, accuracy: 0.01)
    }

    func testTranslateMesh() {
        let params = PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true)
        var mesh = CubeGenerator.generate(params: params)

        let matrix = TransformOperations.translationMatrix(SIMD3<Float>(100, 0, 0))
        mesh.apply(transform: matrix)

        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.x, 95, accuracy: 0.5)
        XCTAssertEqual(bb.max.x, 105, accuracy: 0.5)
    }

    // MARK: - Scale

    func testScaleMatrix() {
        let m = TransformOperations.scaleMatrix(SIMD3<Float>(2, 3, 4))
        let p = m * SIMD4<Float>(1, 1, 1, 1)
        XCTAssertEqual(p.x, 2, accuracy: 0.01)
        XCTAssertEqual(p.y, 3, accuracy: 0.01)
        XCTAssertEqual(p.z, 4, accuracy: 0.01)
    }

    func testScaleMesh() {
        let params = PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true)
        var mesh = CubeGenerator.generate(params: params)

        let matrix = TransformOperations.scaleMatrix(SIMD3<Float>(2, 2, 2))
        mesh.apply(transform: matrix)

        let bb = mesh.boundingBox
        let size = bb.max - bb.min
        XCTAssertEqual(size.x, 20, accuracy: 0.5)
        XCTAssertEqual(size.y, 20, accuracy: 0.5)
        XCTAssertEqual(size.z, 20, accuracy: 0.5)
    }

    // MARK: - Rotation

    func testRotation90AroundZ() {
        let m = TransformOperations.rotationMatrix(angle: 90, axis: SIMD3<Float>(0, 0, 1))
        let p = m * SIMD4<Float>(1, 0, 0, 1)
        // 90deg around Z: (1,0,0) → (0,1,0)
        XCTAssertEqual(p.x, 0, accuracy: 0.01)
        XCTAssertEqual(p.y, 1, accuracy: 0.01)
        XCTAssertEqual(p.z, 0, accuracy: 0.01)
    }

    func testRotation90AroundX() {
        let m = TransformOperations.rotationMatrix(angle: 90, axis: SIMD3<Float>(1, 0, 0))
        let p = m * SIMD4<Float>(0, 1, 0, 1)
        // 90deg around X: (0,1,0) → (0,0,1)
        XCTAssertEqual(p.x, 0, accuracy: 0.01)
        XCTAssertEqual(p.y, 0, accuracy: 0.01)
        XCTAssertEqual(p.z, 1, accuracy: 0.01)
    }

    func testEulerRotation() {
        let m = TransformOperations.eulerRotationMatrix(SIMD3<Float>(0, 0, 90))
        let p = m * SIMD4<Float>(1, 0, 0, 1)
        XCTAssertEqual(p.x, 0, accuracy: 0.01)
        XCTAssertEqual(p.y, 1, accuracy: 0.01)
    }

    // MARK: - Mirror

    func testMirrorAcrossYZ() {
        // Mirror across YZ plane (normal = X axis)
        let m = TransformOperations.mirrorMatrix(normal: SIMD3<Float>(1, 0, 0))
        let p = m * SIMD4<Float>(5, 3, 7, 1)
        XCTAssertEqual(p.x, -5, accuracy: 0.01)
        XCTAssertEqual(p.y, 3, accuracy: 0.01)
        XCTAssertEqual(p.z, 7, accuracy: 0.01)
    }

    func testMirrorAcrossXZ() {
        let m = TransformOperations.mirrorMatrix(normal: SIMD3<Float>(0, 1, 0))
        let p = m * SIMD4<Float>(5, 3, 7, 1)
        XCTAssertEqual(p.x, 5, accuracy: 0.01)
        XCTAssertEqual(p.y, -3, accuracy: 0.01)
        XCTAssertEqual(p.z, 7, accuracy: 0.01)
    }

    // MARK: - Winding flip detection

    func testTranslateDoesNotFlipWinding() {
        let params = TransformParams(vector: SIMD3<Float>(1, 2, 3))
        XCTAssertFalse(TransformOperations.requiresWindingFlip(type: .translate, params: params))
    }

    func testRotateDoesNotFlipWinding() {
        let params = TransformParams(vector: SIMD3<Float>(0, 0, 90))
        XCTAssertFalse(TransformOperations.requiresWindingFlip(type: .rotate, params: params))
    }

    func testUniformScaleDoesNotFlipWinding() {
        let params = TransformParams(vector: SIMD3<Float>(2, 2, 2))
        XCTAssertFalse(TransformOperations.requiresWindingFlip(type: .scale, params: params))
    }

    func testNegativeScaleFlipsWinding() {
        let params = TransformParams(vector: SIMD3<Float>(-1, 1, 1))
        XCTAssertTrue(TransformOperations.requiresWindingFlip(type: .scale, params: params))
    }

    func testMirrorAlwaysFlipsWinding() {
        let params = TransformParams(vector: SIMD3<Float>(1, 0, 0))
        XCTAssertTrue(TransformOperations.requiresWindingFlip(type: .mirror, params: params))
    }

    // MARK: - GeometryKernel integration

    func testKernelEvaluatesTransform() {
        let kernel = GeometryKernel()
        let cubeOp = GeometryOp.primitive(.cube, PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true))
        let translateOp = GeometryOp.transform(
            .translate,
            TransformParams(vector: SIMD3<Float>(50, 0, 0)),
            cubeOp
        )

        let mesh = kernel.evaluate(translateOp)
        XCTAssertFalse(mesh.isEmpty)

        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.x, 45, accuracy: 0.5)
        XCTAssertEqual(bb.max.x, 55, accuracy: 0.5)
    }
}
