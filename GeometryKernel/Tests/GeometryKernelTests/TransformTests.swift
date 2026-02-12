import XCTest
import simd
@testable import GeometryKernel

final class TransformTests: XCTestCase {
    func testTranslate() {
        let params = PrimitiveParams(size: SIMD3<Float>(1, 1, 1))
        var mesh = CubeGenerator.generate(params: params)
        let matrix = TransformOperations.translationMatrix(SIMD3<Float>(5, 0, 0))
        mesh.apply(transform: matrix)
        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.x, 5.0, accuracy: 0.001)
        XCTAssertEqual(bb.max.x, 6.0, accuracy: 0.001)
        XCTAssertEqual(bb.min.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(bb.max.y, 1.0, accuracy: 0.001)
    }

    func testRotateZ90() {
        let params = PrimitiveParams(size: SIMD3<Float>(1, 2, 3))
        var mesh = CubeGenerator.generate(params: params)
        let matrix = TransformOperations.eulerRotationMatrix(SIMD3<Float>(0, 0, 90))
        mesh.apply(transform: matrix)
        let bb = mesh.boundingBox
        // After 90 deg Z rotation: X extent should be ~2, Y extent should be ~1
        XCTAssertEqual(bb.max.x - bb.min.x, 2.0, accuracy: 0.01)
        XCTAssertEqual(bb.max.y - bb.min.y, 1.0, accuracy: 0.01)
        XCTAssertEqual(bb.max.z - bb.min.z, 3.0, accuracy: 0.01)
    }

    func testScaleNegativeFlips() {
        let params = TransformParams(vector: SIMD3<Float>(1, 1, -1))
        XCTAssertTrue(TransformOperations.requiresWindingFlip(type: .scale, params: params))
    }

    func testScalePositiveNoFlip() {
        let params = TransformParams(vector: SIMD3<Float>(2, 2, 2))
        XCTAssertFalse(TransformOperations.requiresWindingFlip(type: .scale, params: params))
    }

    func testMirrorRequiresFlip() {
        let params = TransformParams(vector: SIMD3<Float>(1, 0, 0))
        XCTAssertTrue(TransformOperations.requiresWindingFlip(type: .mirror, params: params))
    }

    func testTransformComposition() {
        let translate = TransformOperations.translationMatrix(SIMD3<Float>(10, 0, 0))
        let rotate = TransformOperations.eulerRotationMatrix(SIMD3<Float>(0, 0, 90))
        // OpenSCAD applies right-to-left: rotate first, then translate
        let composed = translate * rotate
        let point = SIMD4<Float>(1, 0, 0, 1)
        let result = composed * point
        // rotate(90) on (1,0,0) -> (0,1,0), then translate(10,0,0) -> (10,1,0)
        XCTAssertEqual(result.x, 10.0, accuracy: 0.01)
        XCTAssertEqual(result.y, 1.0, accuracy: 0.01)
    }
}
