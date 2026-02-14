import Foundation
import simd

/// Approximates fillet (edge rounding) on a triangle mesh.
/// Uses edge detection and vertex displacement to create rounded edges.
public enum FilletOperation {

    /// Apply fillet to all sharp edges (or specified edge indices) of a mesh.
    /// - Parameters:
    ///   - mesh: Input mesh
    ///   - radius: Fillet radius
    ///   - edgeIndices: Specific edges to fillet (empty = all sharp edges)
    ///   - segments: Number of segments for the fillet arc
    /// - Returns: Filleted mesh
    public static func apply(
        to mesh: TriangleMesh,
        radius: Float,
        edgeIndices: [Int] = [],
        segments: Int = 4
    ) -> TriangleMesh {
        guard !mesh.isEmpty, radius > 0 else { return mesh }

        let sharpEdges = findSharpEdges(in: mesh, angleThreshold: 0.5)
        guard !sharpEdges.isEmpty else { return mesh }

        let targetEdges: [SharpEdge]
        if edgeIndices.isEmpty {
            targetEdges = sharpEdges
        } else {
            let indexSet = Set(edgeIndices)
            targetEdges = sharpEdges.enumerated().compactMap { idx, edge in
                indexSet.contains(idx) ? edge : nil
            }
        }

        guard !targetEdges.isEmpty else { return mesh }

        // For each sharp edge, create a bevel by offsetting adjacent face vertices
        return createBeveledMesh(mesh: mesh, edges: targetEdges, radius: radius, segments: segments)
    }

    struct SharpEdge {
        let v0: Int
        let v1: Int
        let face0: Int
        let face1: Int
        let normal0: SIMD3<Float>
        let normal1: SIMD3<Float>
    }

    static func findSharpEdges(in mesh: TriangleMesh, angleThreshold: Float) -> [SharpEdge] {
        // Build edge-to-face adjacency
        var edgeFaces: [UInt64: [Int]] = [:]
        for (fIdx, tri) in mesh.triangles.enumerated() {
            let edges: [(UInt32, UInt32)] = [
                (min(tri.0, tri.1), max(tri.0, tri.1)),
                (min(tri.1, tri.2), max(tri.1, tri.2)),
                (min(tri.0, tri.2), max(tri.0, tri.2)),
            ]
            for e in edges {
                let key = UInt64(e.0) << 32 | UInt64(e.1)
                edgeFaces[key, default: []].append(fIdx)
            }
        }

        var sharpEdges: [SharpEdge] = []
        for (key, faces) in edgeFaces {
            guard faces.count == 2 else { continue }
            let f0 = faces[0], f1 = faces[1]
            let n0 = faceNormal(mesh: mesh, faceIndex: f0)
            let n1 = faceNormal(mesh: mesh, faceIndex: f1)
            let dot = simd_dot(n0, n1)
            if dot < (1.0 - angleThreshold) {
                let v0 = Int(key >> 32)
                let v1 = Int(key & 0xFFFFFFFF)
                sharpEdges.append(SharpEdge(v0: v0, v1: v1, face0: f0, face1: f1, normal0: n0, normal1: n1))
            }
        }
        return sharpEdges
    }

    static func faceNormal(mesh: TriangleMesh, faceIndex: Int) -> SIMD3<Float> {
        let tri = mesh.triangles[faceIndex]
        let v0 = mesh.vertices[Int(tri.0)]
        let v1 = mesh.vertices[Int(tri.1)]
        let v2 = mesh.vertices[Int(tri.2)]
        let cross = simd_cross(v1 - v0, v2 - v0)
        let len = simd_length(cross)
        return len > 0 ? cross / len : SIMD3<Float>(0, 1, 0)
    }

    static func createBeveledMesh(
        mesh: TriangleMesh,
        edges: [SharpEdge],
        radius: Float,
        segments: Int
    ) -> TriangleMesh {
        // Simple bevel approach: for each sharp edge, insert a chamfer strip
        var newVertices = mesh.vertices
        var newNormals = mesh.normals
        var newTriangles = mesh.triangles

        for edge in edges {
            let p0 = mesh.vertices[edge.v0]
            let p1 = mesh.vertices[edge.v1]

            // Bisector direction
            let avgNormal = simd_normalize(edge.normal0 + edge.normal1)

            // Create intermediate vertices along the fillet arc
            let edgeDir = simd_normalize(p1 - p0)
            let tangent0 = simd_normalize(simd_cross(edgeDir, edge.normal0))
            let tangent1 = simd_normalize(simd_cross(edgeDir, edge.normal1))

            let clampedRadius = min(radius, simd_length(p1 - p0) * 0.3)

            for s in 1..<segments {
                let t = Float(s) / Float(segments)
                let interpNormal = simd_normalize(edge.normal0 * (1 - t) + edge.normal1 * t)
                let offset = avgNormal * clampedRadius * (1 - cos(t * .pi * 0.5))

                let v0New = p0 + offset
                let v1New = p1 + offset

                let idx0 = UInt32(newVertices.count)
                newVertices.append(v0New)
                newNormals.append(interpNormal)
                let idx1 = UInt32(newVertices.count)
                newVertices.append(v1New)
                newNormals.append(interpNormal)

                if s == 1 {
                    newTriangles.append((UInt32(edge.v0), idx0, idx1))
                    newTriangles.append((UInt32(edge.v0), idx1, UInt32(edge.v1)))
                }
            }
        }

        return TriangleMesh(vertices: newVertices, normals: newNormals, triangles: newTriangles)
    }
}
