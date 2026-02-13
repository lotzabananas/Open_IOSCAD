import Foundation
import GeometryKernel

/// Extracts geometric properties from triangle mesh faces.
/// Used to compute sketch plane transforms for face-based sketching.
public enum FaceQuery {

    /// Information about a mesh face (triangle) needed for placing a sketch plane.
    public struct FacePlane: Sendable {
        /// Centroid of the face.
        public let position: SIMD3<Float>
        /// Outward-facing normal of the face.
        public let normal: SIMD3<Float>
        /// A tangent vector lying in the face plane (U axis for sketch).
        public let tangentU: SIMD3<Float>
        /// A second tangent vector (V axis for sketch), perpendicular to normal and tangentU.
        public let tangentV: SIMD3<Float>
    }

    /// Extract plane information for a face (triangle) at the given index.
    /// Returns nil if the index is out of range or the face is degenerate.
    public static func facePlane(of mesh: TriangleMesh, faceIndex: Int) -> FacePlane? {
        guard faceIndex >= 0, faceIndex < mesh.triangles.count else { return nil }

        let tri = mesh.triangles[faceIndex]
        let v0 = mesh.vertices[Int(tri.0)]
        let v1 = mesh.vertices[Int(tri.1)]
        let v2 = mesh.vertices[Int(tri.2)]

        let edge1 = v1 - v0
        let edge2 = v2 - v0

        let cross = simd_cross(edge1, edge2)
        let len = simd_length(cross)
        guard len > 1e-8 else { return nil } // Degenerate triangle

        let normal = cross / len
        let centroid = (v0 + v1 + v2) / 3

        // Build a tangent frame: tangentU along the first edge, tangentV = normal x tangentU
        let u = simd_normalize(edge1)
        let v = simd_cross(normal, u)

        return FacePlane(
            position: centroid,
            normal: normal,
            tangentU: u,
            tangentV: v
        )
    }

    /// Build a 4x4 transform matrix that maps the XY sketch plane to the face plane.
    /// Sketch X → tangentU, Sketch Y → tangentV, Sketch Z (extrude) → normal.
    /// Origin at face centroid.
    public static func faceTransform(of mesh: TriangleMesh, faceIndex: Int) -> simd_float4x4? {
        guard let plane = facePlane(of: mesh, faceIndex: faceIndex) else { return nil }

        // Column-major: columns are [tangentU, tangentV, normal, position]
        return simd_float4x4(
            SIMD4<Float>(plane.tangentU.x, plane.tangentU.y, plane.tangentU.z, 0),
            SIMD4<Float>(plane.tangentV.x, plane.tangentV.y, plane.tangentV.z, 0),
            SIMD4<Float>(plane.normal.x, plane.normal.y, plane.normal.z, 0),
            SIMD4<Float>(plane.position.x, plane.position.y, plane.position.z, 1)
        )
    }

    /// Find the average plane for a group of connected faces sharing a common normal direction.
    /// Useful for picking a flat face that spans multiple triangles.
    /// Returns a plane based on the seed face, averaging with neighbors within
    /// the given angular tolerance (in radians).
    public static func averageFacePlane(
        of mesh: TriangleMesh,
        seedFaceIndex: Int,
        angleTolerance: Float = 0.1 // ~5.7 degrees
    ) -> FacePlane? {
        guard let seedPlane = facePlane(of: mesh, faceIndex: seedFaceIndex) else { return nil }

        // Collect coplanar faces
        var totalPosition = seedPlane.position
        var count: Float = 1

        for i in 0..<mesh.triangles.count where i != seedFaceIndex {
            guard let otherPlane = facePlane(of: mesh, faceIndex: i) else { continue }
            let dot = simd_dot(seedPlane.normal, otherPlane.normal)
            if dot > cos(angleTolerance) {
                // Check coplanarity: the centroid should lie roughly on the same plane
                let diff = otherPlane.position - seedPlane.position
                let dist = abs(simd_dot(diff, seedPlane.normal))
                if dist < 0.5 { // Within 0.5mm of the seed plane
                    totalPosition += otherPlane.position
                    count += 1
                }
            }
        }

        let avgPosition = totalPosition / count

        return FacePlane(
            position: avgPosition,
            normal: seedPlane.normal,
            tangentU: seedPlane.tangentU,
            tangentV: seedPlane.tangentV
        )
    }
}
