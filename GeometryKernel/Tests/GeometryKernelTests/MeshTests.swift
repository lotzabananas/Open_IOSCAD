import XCTest
@testable import GeometryKernel
import simd

final class MeshTests: XCTestCase {

    func testEmptyMesh() {
        let mesh = TriangleMesh()
        XCTAssertTrue(mesh.isEmpty)
        XCTAssertEqual(mesh.triangleCount, 0)
        XCTAssertEqual(mesh.vertexCount, 0)
    }

    func testMerge() {
        let params = PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true)
        var a = CubeGenerator.generate(params: params)
        let b = CubeGenerator.generate(params: params)

        let aTriCount = a.triangleCount
        let bTriCount = b.triangleCount

        a.merge(b)

        XCTAssertEqual(a.triangleCount, aTriCount + bTriCount)
        XCTAssertEqual(a.vertexCount, 16)
    }

    func testBoundingBox() {
        let mesh = TriangleMesh(
            vertices: [
                SIMD3<Float>(-1, -2, -3),
                SIMD3<Float>(4, 5, 6),
                SIMD3<Float>(0, 0, 0),
            ],
            normals: [
                SIMD3<Float>(0, 0, 1),
                SIMD3<Float>(0, 0, 1),
                SIMD3<Float>(0, 0, 1),
            ],
            triangles: [(0, 1, 2)]
        )

        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.x, -1, accuracy: 0.01)
        XCTAssertEqual(bb.min.y, -2, accuracy: 0.01)
        XCTAssertEqual(bb.min.z, -3, accuracy: 0.01)
        XCTAssertEqual(bb.max.x, 4, accuracy: 0.01)
        XCTAssertEqual(bb.max.y, 5, accuracy: 0.01)
        XCTAssertEqual(bb.max.z, 6, accuracy: 0.01)
    }

    func testCenter() {
        let mesh = TriangleMesh(
            vertices: [
                SIMD3<Float>(0, 0, 0),
                SIMD3<Float>(10, 10, 10),
                SIMD3<Float>(5, 5, 5),
            ],
            normals: [
                SIMD3<Float>(0, 0, 1),
                SIMD3<Float>(0, 0, 1),
                SIMD3<Float>(0, 0, 1),
            ],
            triangles: [(0, 1, 2)]
        )

        let center = mesh.center
        XCTAssertEqual(center.x, 5, accuracy: 0.01)
        XCTAssertEqual(center.y, 5, accuracy: 0.01)
        XCTAssertEqual(center.z, 5, accuracy: 0.01)
    }

    func testFlatShading() {
        let params = PrimitiveParams(size: SIMD3<Float>(10, 10, 10))
        let mesh = CubeGenerator.generate(params: params)
        let flat = mesh.flatShaded()

        // Flat shading duplicates vertices: 12 triangles * 3 verts = 36
        XCTAssertEqual(flat.vertexCount, 36)
        XCTAssertEqual(flat.triangleCount, 12)
    }

    func testFlipWinding() {
        var mesh = TriangleMesh(
            vertices: [
                SIMD3<Float>(0, 0, 0),
                SIMD3<Float>(1, 0, 0),
                SIMD3<Float>(0, 1, 0),
            ],
            normals: [
                SIMD3<Float>(0, 0, 1),
                SIMD3<Float>(0, 0, 1),
                SIMD3<Float>(0, 0, 1),
            ],
            triangles: [(0, 1, 2)]
        )

        mesh.flipWinding()

        // Triangle should be (0, 2, 1) after flip
        XCTAssertEqual(mesh.triangles[0].0, 0)
        XCTAssertEqual(mesh.triangles[0].1, 2)
        XCTAssertEqual(mesh.triangles[0].2, 1)

        // Normals should be negated
        XCTAssertEqual(mesh.normals[0].z, -1, accuracy: 0.01)
    }

    func testManifoldCheckOnCube() {
        let params = PrimitiveParams(size: SIMD3<Float>(10, 10, 10))
        let mesh = CubeGenerator.generate(params: params)
        XCTAssertTrue(mesh.isManifold)
    }

    func testRecomputeNormals() {
        let params = PrimitiveParams(size: SIMD3<Float>(10, 10, 10))
        var mesh = CubeGenerator.generate(params: params)

        // Zero out normals
        mesh.normals = Array(repeating: SIMD3<Float>(0, 0, 0), count: mesh.vertexCount)

        mesh.recomputeNormals()

        // Normals should all be non-zero after recomputation
        for n in mesh.normals {
            XCTAssertGreaterThan(simd_length(n), 0.5)
        }
    }
}
