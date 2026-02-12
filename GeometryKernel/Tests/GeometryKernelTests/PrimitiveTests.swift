import XCTest
import simd
@testable import GeometryKernel

final class PrimitiveTests: XCTestCase {

    // MARK: - Cube

    func testCubeDefault() {
        let params = PrimitiveParams()
        let mesh = CubeGenerator.generate(params: params)

        XCTAssertEqual(mesh.triangleCount, 12, "A cube must have exactly 12 triangles")
        XCTAssertEqual(mesh.vertexCount, 8, "A cube must have exactly 8 vertices")
        XCTAssertTrue(mesh.isManifold, "Default cube must be manifold")

        let bb = mesh.boundingBox
        assertApproxEqual(bb.min, SIMD3<Float>(0, 0, 0), "Min corner should be at origin")
        assertApproxEqual(bb.max, SIMD3<Float>(1, 1, 1), "Max corner should be at (1,1,1)")
    }

    func testCubeCentered() {
        let params = PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true)
        let mesh = CubeGenerator.generate(params: params)

        XCTAssertEqual(mesh.triangleCount, 12)
        XCTAssertEqual(mesh.vertexCount, 8)
        XCTAssertTrue(mesh.isManifold)

        let bb = mesh.boundingBox
        assertApproxEqual(bb.min, SIMD3<Float>(-5, -5, -5), "Centered cube min should be (-5,-5,-5)")
        assertApproxEqual(bb.max, SIMD3<Float>( 5,  5,  5), "Centered cube max should be (5,5,5)")
    }

    // MARK: - Cylinder

    func testCylinderHexagonalPrism() {
        let params = PrimitiveParams(height: 2.0, fn: 6)
        let mesh = CylinderGenerator.generate(params: params)

        // A hexagonal prism: 6 side quads (12 tris) + 6 bottom + 6 top = 24 triangles
        XCTAssertEqual(mesh.triangleCount, 24,
                       "Hexagonal cylinder ($fn=6) should have 24 triangles")
        XCTAssertTrue(mesh.isManifold,
                      "Hexagonal cylinder must be manifold")

        // Bounding box check: radius 1 means x/y in [-1, 1], z in [0, 2]
        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.z, 0, accuracy: 1e-5)
        XCTAssertEqual(bb.max.z, 2, accuracy: 1e-5)
    }

    func testCylinderCone() {
        let params = PrimitiveParams(
            radius1: 2.0, radius2: 0.5, height: 5.0, center: true, fn: 12
        )
        let mesh = CylinderGenerator.generate(params: params)

        XCTAssertTrue(mesh.isManifold, "Cone must be manifold")

        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.z, -2.5, accuracy: 1e-5, "Centered cone bottom at -h/2")
        XCTAssertEqual(bb.max.z,  2.5, accuracy: 1e-5, "Centered cone top at h/2")

        // The bottom ring has radius 2, so max x/y extent should be ~2.
        XCTAssertEqual(bb.max.x, 2.0, accuracy: 1e-4)
    }

    // MARK: - Sphere

    func testSphere() {
        let params = PrimitiveParams(radius: 3.0, fn: 16)
        let mesh = SphereGenerator.generate(params: params)

        XCTAssertTrue(mesh.isManifold, "Sphere must be manifold")

        // Topology check: for a UV sphere with S segments and R rings:
        //   vertices = 2 (poles) + (R-1)*S
        //   triangles = 2*S (pole fans) + 2*S*(R-2) (quads)
        //             = 2*S*(R-1)
        let segments = 16
        let rings = max(segments / 2, 2)  // 8
        let expectedVerts = 2 + (rings - 1) * segments
        let expectedTris = 2 * segments * (rings - 1)

        XCTAssertEqual(mesh.vertexCount, expectedVerts,
                       "Sphere vertex count should match UV sphere formula")
        XCTAssertEqual(mesh.triangleCount, expectedTris,
                       "Sphere triangle count should match UV sphere formula")

        // Bounding box should be roughly [-3, -3, -3] to [3, 3, 3]
        let bb = mesh.boundingBox
        XCTAssertEqual(bb.min.z, -3.0, accuracy: 1e-5)
        XCTAssertEqual(bb.max.z,  3.0, accuracy: 1e-5)
    }

    // MARK: - Polyhedron

    func testPolyhedronTetrahedron() {
        // A regular-ish tetrahedron with 4 triangular faces.
        let pts: [SIMD3<Float>] = [
            SIMD3<Float>( 1,  1,  1),
            SIMD3<Float>( 1, -1, -1),
            SIMD3<Float>(-1,  1, -1),
            SIMD3<Float>(-1, -1,  1),
        ]
        let faces: [[Int]] = [
            [0, 1, 2],
            [0, 3, 1],
            [0, 2, 3],
            [1, 3, 2],
        ]

        let params = PrimitiveParams(points: [pts], faces: faces)
        let mesh = PolyhedronGenerator.generate(params: params)

        // 4 triangular faces => 4 triangles
        XCTAssertEqual(mesh.triangleCount, 4,
                       "Tetrahedron should have exactly 4 triangles")

        // Each triangle is duplicated (flat shading) so 4 * 3 = 12 vertices.
        XCTAssertEqual(mesh.vertexCount, 12,
                       "Flat-shaded tetrahedron should have 12 vertices (3 per tri)")

        // Normals should be present and unit length.
        XCTAssertEqual(mesh.normals.count, mesh.vertexCount)
        for n in mesh.normals {
            XCTAssertEqual(simd_length(n), 1.0, accuracy: 1e-5,
                           "All normals must be unit length")
        }
    }

    func testPolyhedronQuadFaces() {
        // A simple quad face should be fan-triangulated into 2 triangles.
        let pts: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(1, 1, 0),
            SIMD3<Float>(0, 1, 0),
        ]
        let faces: [[Int]] = [
            [0, 1, 2, 3],  // quad
        ]

        let params = PrimitiveParams(points: [pts], faces: faces)
        let mesh = PolyhedronGenerator.generate(params: params)

        XCTAssertEqual(mesh.triangleCount, 2,
                       "A single quad face should produce 2 triangles")
    }

    // MARK: - Helpers

    private func assertApproxEqual(
        _ a: SIMD3<Float>,
        _ b: SIMD3<Float>,
        _ message: String = "",
        accuracy: Float = 1e-5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(a.x, b.x, accuracy: accuracy, message, file: file, line: line)
        XCTAssertEqual(a.y, b.y, accuracy: accuracy, message, file: file, line: line)
        XCTAssertEqual(a.z, b.z, accuracy: accuracy, message, file: file, line: line)
    }
}
