import XCTest
@testable import ParametricEngine
import GeometryKernel
import simd

final class FaceQueryTests: XCTestCase {

    /// Helper: create a simple box mesh for testing.
    private func makeBoxMesh() -> TriangleMesh {
        let kernel = GeometryKernel()
        let op = GeometryOp.primitive(.cube, PrimitiveParams(
            size: SIMD3<Float>(10, 10, 10),
            center: true
        ))
        return kernel.evaluate(op)
    }

    // MARK: - FaceQuery

    func testFacePlaneReturnsValidData() {
        let mesh = makeBoxMesh()
        guard !mesh.triangles.isEmpty else {
            XCTFail("Box mesh should have triangles")
            return
        }

        guard let plane = FaceQuery.facePlane(of: mesh, faceIndex: 0) else {
            XCTFail("Should get plane for valid face index")
            return
        }

        // Normal should be unit length
        let normalLen = simd_length(plane.normal)
        XCTAssertEqual(normalLen, 1.0, accuracy: 0.01)

        // TangentU and tangentV should be unit length
        XCTAssertEqual(simd_length(plane.tangentU), 1.0, accuracy: 0.01)
        XCTAssertEqual(simd_length(plane.tangentV), 1.0, accuracy: 0.01)

        // Normal, tangentU, tangentV should be mutually perpendicular
        XCTAssertEqual(abs(simd_dot(plane.normal, plane.tangentU)), 0, accuracy: 0.01)
        XCTAssertEqual(abs(simd_dot(plane.normal, plane.tangentV)), 0, accuracy: 0.01)
        XCTAssertEqual(abs(simd_dot(plane.tangentU, plane.tangentV)), 0, accuracy: 0.01)
    }

    func testFacePlaneOutOfRangeReturnsNil() {
        let mesh = makeBoxMesh()
        XCTAssertNil(FaceQuery.facePlane(of: mesh, faceIndex: -1))
        XCTAssertNil(FaceQuery.facePlane(of: mesh, faceIndex: mesh.triangles.count))
    }

    func testFaceTransformReturnsValidMatrix() {
        let mesh = makeBoxMesh()
        guard !mesh.triangles.isEmpty else { return }

        guard let transform = FaceQuery.faceTransform(of: mesh, faceIndex: 0) else {
            XCTFail("Should get transform for valid face")
            return
        }

        // The transform should be a valid orthonormal basis + translation
        // Column 0, 1, 2 should be unit vectors
        let col0 = SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)
        let col1 = SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z)
        let col2 = SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        XCTAssertEqual(simd_length(col0), 1.0, accuracy: 0.01)
        XCTAssertEqual(simd_length(col1), 1.0, accuracy: 0.01)
        XCTAssertEqual(simd_length(col2), 1.0, accuracy: 0.01)
    }

    func testEmptyMeshFacePlane() {
        let mesh = TriangleMesh()
        XCTAssertNil(FaceQuery.facePlane(of: mesh, faceIndex: 0))
    }

    // MARK: - TopologicalNaming

    func testFaceRefCreation() {
        let mesh = makeBoxMesh()
        guard !mesh.triangles.isEmpty else { return }

        let featureID = FeatureID()
        guard let ref = TopologicalNaming.faceRef(from: mesh, faceIndex: 0, featureID: featureID) else {
            XCTFail("Should create face ref for valid face")
            return
        }

        XCTAssertEqual(ref.featureID, featureID)
        // Normal should have reasonable magnitude
        let normalLen = simd_length(ref.normal.simd)
        XCTAssertEqual(normalLen, 1.0, accuracy: 0.01)
    }

    func testFaceRefResolvesToSameFace() {
        let mesh = makeBoxMesh()
        guard !mesh.triangles.isEmpty else { return }

        let featureID = FeatureID()
        guard let ref = TopologicalNaming.faceRef(from: mesh, faceIndex: 0, featureID: featureID) else {
            XCTFail("Should create face ref")
            return
        }

        // Resolve back: should find the same or a nearby face
        let resolved = TopologicalNaming.resolve(faceRef: ref, in: mesh)
        XCTAssertNotNil(resolved)
    }

    func testFaceRefResolvesAfterIdentityTransform() {
        // Simulates re-evaluation: same mesh
        let mesh = makeBoxMesh()
        guard !mesh.triangles.isEmpty else { return }

        let featureID = FeatureID()
        guard let ref = TopologicalNaming.faceRef(from: mesh, faceIndex: 0, featureID: featureID) else {
            return
        }

        // Same mesh = should resolve
        let resolved = TopologicalNaming.resolve(faceRef: ref, in: mesh)
        XCTAssertNotNil(resolved)
    }

    func testCodableSIMD3RoundTrip() throws {
        let original = CodableSIMD3(SIMD3<Float>(1.5, 2.5, 3.5))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableSIMD3.self, from: data)

        XCTAssertEqual(decoded.x, 1.5)
        XCTAssertEqual(decoded.y, 2.5)
        XCTAssertEqual(decoded.z, 3.5)
        XCTAssertEqual(decoded.simd.x, 1.5)
    }

    func testFaceRefCodableRoundTrip() throws {
        let ref = TopologicalNaming.FaceRef(
            normal: SIMD3<Float>(0, 0, 1),
            centroid: SIMD3<Float>(5, 5, 10),
            featureID: FeatureID()
        )

        let data = try JSONEncoder().encode(ref)
        let decoded = try JSONDecoder().decode(TopologicalNaming.FaceRef.self, from: data)

        XCTAssertEqual(decoded.normal.z, 1.0)
        XCTAssertEqual(decoded.centroid.x, 5.0)
        XCTAssertEqual(decoded.featureID, ref.featureID)
    }
}
