import Foundation
import simd

/// Applies chamfer (angled cut) to edges of a triangle mesh.
public enum ChamferOperation {

    /// Apply chamfer to sharp edges of a mesh.
    /// - Parameters:
    ///   - mesh: Input mesh
    ///   - distance: Chamfer distance from edge
    ///   - edgeIndices: Specific edges to chamfer (empty = all sharp edges)
    /// - Returns: Chamfered mesh
    public static func apply(
        to mesh: TriangleMesh,
        distance: Float,
        edgeIndices: [Int] = []
    ) -> TriangleMesh {
        guard !mesh.isEmpty, distance > 0 else { return mesh }

        let sharpEdges = FilletOperation.findSharpEdges(in: mesh, angleThreshold: 0.5)
        guard !sharpEdges.isEmpty else { return mesh }

        let targetEdges: [FilletOperation.SharpEdge]
        if edgeIndices.isEmpty {
            targetEdges = sharpEdges
        } else {
            let indexSet = Set(edgeIndices)
            targetEdges = sharpEdges.enumerated().compactMap { idx, edge in
                indexSet.contains(idx) ? edge : nil
            }
        }

        guard !targetEdges.isEmpty else { return mesh }

        // For chamfer, we create a flat bevel strip at each sharp edge
        var newVertices = mesh.vertices
        var newNormals = mesh.normals
        var newTriangles = mesh.triangles

        for edge in targetEdges {
            let p0 = mesh.vertices[edge.v0]
            let p1 = mesh.vertices[edge.v1]

            // Offset vertices along each face normal
            let clampedDist = min(distance, simd_length(p1 - p0) * 0.3)
            let offset0 = edge.normal0 * clampedDist
            let offset1 = edge.normal1 * clampedDist

            let chamferNormal = simd_normalize(edge.normal0 + edge.normal1)

            // Create 4 new vertices for the chamfer strip
            let c00 = p0 + offset0
            let c01 = p0 + offset1
            let c10 = p1 + offset0
            let c11 = p1 + offset1

            let base = UInt32(newVertices.count)
            newVertices.append(contentsOf: [c00, c01, c10, c11])
            newNormals.append(contentsOf: [chamferNormal, chamferNormal, chamferNormal, chamferNormal])

            newTriangles.append((base, base + 1, base + 3))
            newTriangles.append((base, base + 3, base + 2))
        }

        return TriangleMesh(vertices: newVertices, normals: newNormals, triangles: newTriangles)
    }
}
