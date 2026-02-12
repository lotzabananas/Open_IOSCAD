import Foundation
import simd

/// Generates arbitrary polyhedron meshes from PrimitiveParams.
///
/// Accepts a point cloud and a face list. Faces with more than 3 vertices
/// are triangulated using a simple fan from the first vertex.
public enum PolyhedronGenerator {

    /// Generate a polyhedron mesh.
    ///
    /// - Parameter params: Primitive parameters.
    ///   - `points`: An array whose first element is the list of 3-D
    ///     vertices (`SIMD3<Float>`).
    ///   - `faces`: An array of index lists. Each inner array contains
    ///     the vertex indices for one face, wound so that the outward
    ///     normal follows the right-hand rule.
    /// - Returns: A `TriangleMesh` with per-face normals assigned to
    ///   every vertex of each triangle (flat shading).
    public static func generate(params: PrimitiveParams) -> TriangleMesh {
        guard let pointSets = params.points, let firstSet = pointSets.first else {
            return TriangleMesh()
        }
        guard let faceList = params.faces else {
            return TriangleMesh()
        }

        let points = firstSet

        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var triangles: [(UInt32, UInt32, UInt32)] = []

        for face in faceList {
            guard face.count >= 3 else { continue }

            // Compute the face normal from the first three vertices.
            let p0 = points[face[0]]
            let p1 = points[face[1]]
            let p2 = points[face[2]]
            let faceNormal = simd_normalize(simd_cross(p1 - p0, p2 - p0))

            // Fan triangulation from vertex 0 of the face.
            for i in 1..<(face.count - 1) {
                let baseIdx = UInt32(vertices.count)

                vertices.append(points[face[0]])
                vertices.append(points[face[i]])
                vertices.append(points[face[i + 1]])

                normals.append(faceNormal)
                normals.append(faceNormal)
                normals.append(faceNormal)

                triangles.append((baseIdx, baseIdx + 1, baseIdx + 2))
            }
        }

        return TriangleMesh(
            vertices: vertices,
            normals: normals,
            triangles: triangles
        )
    }
}
