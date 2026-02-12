import XCTest
import simd
@testable import GeometryKernel

final class CSGTests: XCTestCase {
    func testUnionNonOverlapping() {
        let cubeA = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(1, 1, 1)))
        var paramsB = PrimitiveParams(size: SIMD3<Float>(1, 1, 1))
        var cubeB = CubeGenerator.generate(params: paramsB)
        cubeB.apply(transform: TransformOperations.translationMatrix(SIMD3<Float>(5, 0, 0)))

        let result = CSGOperations.perform(.union, on: [cubeA, cubeB])
        // Non-overlapping union should have all triangles from both
        XCTAssertEqual(result.triangleCount, cubeA.triangleCount + cubeB.triangleCount)
    }

    func testUnionOverlapping() {
        let cubeA = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(2, 2, 2)))
        var cubeB = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(2, 2, 2)))
        cubeB.apply(transform: TransformOperations.translationMatrix(SIMD3<Float>(1, 0, 0)))

        let result = CSGOperations.perform(.union, on: [cubeA, cubeB])
        XCTAssertGreaterThan(result.triangleCount, 0)
        XCTAssertFalse(result.isEmpty)
    }

    func testDifferenceProducesGeometry() {
        let cubeA = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(10, 10, 10)))
        let cylParams = PrimitiveParams(radius: 3, height: 20, center: true, fn: 16)
        let cylinder = CylinderGenerator.generate(params: cylParams)

        let result = CSGOperations.perform(.difference, on: [cubeA, cylinder])
        XCTAssertGreaterThan(result.triangleCount, 0)
    }

    func testDifferenceNoOverlap() {
        let cubeA = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(1, 1, 1)))
        var cubeB = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(1, 1, 1)))
        cubeB.apply(transform: TransformOperations.translationMatrix(SIMD3<Float>(10, 10, 10)))

        let result = CSGOperations.perform(.difference, on: [cubeA, cubeB])
        XCTAssertEqual(result.triangleCount, cubeA.triangleCount)
    }

    func testIntersectionOverlapping() {
        let cubeA = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(2, 2, 2)))
        var cubeB = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(2, 2, 2)))
        cubeB.apply(transform: TransformOperations.translationMatrix(SIMD3<Float>(1, 0, 0)))

        let result = CSGOperations.perform(.intersection, on: [cubeA, cubeB])
        XCTAssertGreaterThan(result.triangleCount, 0)
    }

    func testIntersectionNoOverlap() {
        let cubeA = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(1, 1, 1)))
        var cubeB = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(1, 1, 1)))
        cubeB.apply(transform: TransformOperations.translationMatrix(SIMD3<Float>(10, 10, 10)))

        let result = CSGOperations.perform(.intersection, on: [cubeA, cubeB])
        XCTAssertTrue(result.isEmpty)
    }

    func testUnionEmpty() {
        let result = CSGOperations.perform(.union, on: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testUnionSingle() {
        let cube = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(1, 1, 1)))
        let result = CSGOperations.perform(.union, on: [cube])
        XCTAssertEqual(result.triangleCount, cube.triangleCount)
    }
}
