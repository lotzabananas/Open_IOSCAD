import Foundation
import simd

/// Generates axis-aligned box meshes from PrimitiveParams.
///
/// Produces a closed, manifold TriangleMesh with 8 unique vertices,
/// 12 triangles (2 per face), and outward-facing normals.
public enum CubeGenerator {

    /// Generate a box mesh.
    ///
    /// - Parameter params: Primitive parameters.
    ///   - `size` (SIMD3): x, y, z dimensions. Defaults to [1, 1, 1].
    ///   - `center`: When false the minimum corner sits at the origin;
    ///     when true the box is centered on the origin.
    /// - Returns: A manifold `TriangleMesh` with 8 vertices and 12 triangles.
    public static func generate(params: PrimitiveParams) -> TriangleMesh {
        let size = params.size ?? SIMD3<Float>(1, 1, 1)
        let sx = size.x
        let sy = size.y
        let sz = size.z

        // Compute the offset so that either the corner or the center is at the origin.
        let offset: SIMD3<Float>
        if params.center {
            offset = SIMD3<Float>(-sx / 2, -sy / 2, -sz / 2)
        } else {
            offset = SIMD3<Float>(0, 0, 0)
        }

        // 8 unique vertices of an axis-aligned box.
        //
        //     6--------7
        //    /|       /|
        //   4--------5 |
        //   | 2------|-3
        //   |/       |/
        //   0--------1
        //
        let v0 = SIMD3<Float>(0,  0,  0 ) + offset
        let v1 = SIMD3<Float>(sx, 0,  0 ) + offset
        let v2 = SIMD3<Float>(0,  sy, 0 ) + offset
        let v3 = SIMD3<Float>(sx, sy, 0 ) + offset
        let v4 = SIMD3<Float>(0,  0,  sz) + offset
        let v5 = SIMD3<Float>(sx, 0,  sz) + offset
        let v6 = SIMD3<Float>(0,  sy, sz) + offset
        let v7 = SIMD3<Float>(sx, sy, sz) + offset

        let vertices: [SIMD3<Float>] = [v0, v1, v2, v3, v4, v5, v6, v7]

        // 12 triangles – 2 per face, wound counter-clockwise when viewed
        // from outside (outward-facing normals via right-hand rule).
        let triangles: [(UInt32, UInt32, UInt32)] = [
            // Front face  (z = sz) – normal +Z
            (4, 5, 7), (4, 7, 6),
            // Back face   (z = 0)  – normal -Z
            (1, 0, 2), (1, 2, 3),
            // Right face  (x = sx) – normal +X
            (1, 3, 7), (1, 7, 5),
            // Left face   (x = 0)  – normal -X
            (0, 4, 6), (0, 6, 2),
            // Top face    (y = sy) – normal +Y
            (2, 6, 7), (2, 7, 3),
            // Bottom face (y = 0)  – normal -Y
            (0, 1, 5), (0, 5, 4),
        ]

        // Per-vertex normals via smooth shading (each vertex touches 3 faces
        // at 90-degree angles so the averaged normal points toward the corner).
        // We use recomputeNormals for consistency with the rest of the engine,
        // but for a box the normals from flat shading are more useful in
        // rendering; callers can call flatShaded() if they need that.
        var mesh = TriangleMesh(
            vertices: vertices,
            normals: [],
            triangles: triangles
        )
        mesh.recomputeNormals()
        return mesh
    }
}
