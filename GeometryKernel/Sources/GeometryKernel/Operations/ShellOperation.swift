import Foundation
import simd

/// Creates a thin-walled shell from a solid by offsetting faces inward.
public enum ShellOperation {

    /// Shell a solid mesh — create walls of the given thickness.
    /// - Parameters:
    ///   - mesh: Input solid mesh
    ///   - thickness: Wall thickness
    ///   - openFaceIndices: Face indices to remove (open), creating an opening
    /// - Returns: Shelled mesh
    public static func apply(
        to mesh: TriangleMesh,
        thickness: Float,
        openFaceIndices: [Int] = []
    ) -> TriangleMesh {
        guard !mesh.isEmpty, thickness > 0 else { return mesh }

        // Create inner shell by offsetting all vertices inward along their normals
        var innerMesh = mesh

        // Compute per-vertex normals for offset direction
        var vertexNormals = Array(repeating: SIMD3<Float>(0, 0, 0), count: mesh.vertices.count)
        for tri in mesh.triangles {
            let v0 = mesh.vertices[Int(tri.0)]
            let v1 = mesh.vertices[Int(tri.1)]
            let v2 = mesh.vertices[Int(tri.2)]
            let faceNormal = simd_normalize(simd_cross(v1 - v0, v2 - v0))
            vertexNormals[Int(tri.0)] += faceNormal
            vertexNormals[Int(tri.1)] += faceNormal
            vertexNormals[Int(tri.2)] += faceNormal
        }

        // Offset inner vertices inward
        for i in innerMesh.vertices.indices {
            let n = simd_normalize(vertexNormals[i])
            innerMesh.vertices[i] -= n * thickness
        }

        // Flip inner mesh winding (normals point inward)
        innerMesh.flipWinding()

        let openSet = Set(openFaceIndices)

        // Start with outer mesh (minus open faces)
        var resultVertices: [SIMD3<Float>] = []
        var resultNormals: [SIMD3<Float>] = []
        var resultTriangles: [(UInt32, UInt32, UInt32)] = []

        // Add outer faces (skip open faces)
        for (fIdx, tri) in mesh.triangles.enumerated() {
            if openSet.contains(fIdx) { continue }
            let base = UInt32(resultVertices.count)
            resultVertices.append(mesh.vertices[Int(tri.0)])
            resultVertices.append(mesh.vertices[Int(tri.1)])
            resultVertices.append(mesh.vertices[Int(tri.2)])
            let n = FilletOperation.faceNormal(mesh: mesh, faceIndex: fIdx)
            resultNormals.append(contentsOf: [n, n, n])
            resultTriangles.append((base, base + 1, base + 2))
        }

        // Add inner faces (skip faces corresponding to open outer faces)
        for (fIdx, tri) in innerMesh.triangles.enumerated() {
            if openSet.contains(fIdx) { continue }
            let base = UInt32(resultVertices.count)
            resultVertices.append(innerMesh.vertices[Int(tri.0)])
            resultVertices.append(innerMesh.vertices[Int(tri.1)])
            resultVertices.append(innerMesh.vertices[Int(tri.2)])
            let n = FilletOperation.faceNormal(mesh: innerMesh, faceIndex: fIdx)
            resultNormals.append(contentsOf: [n, n, n])
            resultTriangles.append((base, base + 1, base + 2))
        }

        // For open faces, add connecting walls between outer and inner edges
        // (This creates the rim where the shell is open)
        for fIdx in openSet {
            guard fIdx < mesh.triangles.count else { continue }
            let outerTri = mesh.triangles[fIdx]
            let innerTri = innerMesh.triangles[fIdx]

            // Create quad strips connecting outer edge to inner edge
            let outerVerts = [
                mesh.vertices[Int(outerTri.0)],
                mesh.vertices[Int(outerTri.1)],
                mesh.vertices[Int(outerTri.2)]
            ]
            let innerVerts = [
                innerMesh.vertices[Int(innerTri.0)],
                innerMesh.vertices[Int(innerTri.1)],
                innerMesh.vertices[Int(innerTri.2)]
            ]

            for i in 0..<3 {
                let j = (i + 1) % 3
                let base = UInt32(resultVertices.count)
                let wallNormal = simd_normalize(simd_cross(
                    outerVerts[j] - outerVerts[i],
                    innerVerts[i] - outerVerts[i]
                ))
                resultVertices.append(contentsOf: [outerVerts[i], outerVerts[j], innerVerts[j], innerVerts[i]])
                resultNormals.append(contentsOf: [wallNormal, wallNormal, wallNormal, wallNormal])
                resultTriangles.append((base, base + 1, base + 2))
                resultTriangles.append((base, base + 2, base + 3))
            }
        }

        return TriangleMesh(vertices: resultVertices, normals: resultNormals, triangles: resultTriangles)
    }
}
