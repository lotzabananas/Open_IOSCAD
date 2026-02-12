import Foundation
import simd

/// Generates UV-sphere meshes from PrimitiveParams.
///
/// Produces a closed, manifold TriangleMesh using a standard latitude /
/// longitude tessellation. The poles are shared single vertices connected
/// to triangle fans, while the intermediate rings are joined by quads
/// (each split into 2 triangles).
public enum SphereGenerator {

    /// Generate a UV sphere mesh.
    ///
    /// - Parameter params: Primitive parameters.
    ///   - `radius`: Sphere radius. Defaults to 1.
    ///   - `fn` / `fa` / `fs`: Facet count controls.
    ///     Segments (longitude slices) = `resolvedSegments(forRadius:)`.
    ///     Rings (latitude bands) = segments / 2, clamped to a minimum of 2.
    /// - Returns: A manifold `TriangleMesh`.
    public static func generate(params: PrimitiveParams) -> TriangleMesh {
        let r = params.radius ?? 1.0
        let segments = params.resolvedSegments(forRadius: r)
        let rings = max(segments / 2, 2)

        var vertices: [SIMD3<Float>] = []
        var triangles: [(UInt32, UInt32, UInt32)] = []

        // --- Vertex layout ---
        // Index 0          : south pole (0, 0, -r)
        // 1 ..< 1 + (rings-1)*segments : intermediate ring vertices
        // last index       : north pole (0, 0,  r)

        // South pole
        let southPole = UInt32(vertices.count)
        vertices.append(SIMD3<Float>(0, 0, -r))

        // Intermediate rings (from just above the south pole to just below the north pole)
        for ring in 1..<rings {
            let phi = Float.pi * Float(ring) / Float(rings)  // 0 (north) .. pi (south), but we go bottom-up
            let z = -r * cos(phi)
            let ringR = r * sin(phi)
            for seg in 0..<segments {
                let theta = 2.0 * Float.pi * Float(seg) / Float(segments)
                let x = ringR * cos(theta)
                let y = ringR * sin(theta)
                vertices.append(SIMD3<Float>(x, y, z))
            }
        }

        // North pole
        let northPole = UInt32(vertices.count)
        vertices.append(SIMD3<Float>(0, 0, r))

        // --- Helper to get the vertex index of a given ring/segment ---
        // Ring 0 is the south pole, ring `rings` is the north pole.
        func idx(ring: Int, seg: Int) -> UInt32 {
            if ring == 0 { return southPole }
            if ring == rings { return northPole }
            return UInt32(1 + (ring - 1) * segments + (seg % segments))
        }

        // --- South pole fan ---
        for seg in 0..<segments {
            let next = (seg + 1) % segments
            triangles.append((southPole, idx(ring: 1, seg: next), idx(ring: 1, seg: seg)))
        }

        // --- Intermediate quads ---
        for ring in 1..<(rings - 1) {
            for seg in 0..<segments {
                let next = (seg + 1) % segments
                let bl = idx(ring: ring,     seg: seg)
                let br = idx(ring: ring,     seg: next)
                let tl = idx(ring: ring + 1, seg: seg)
                let tr = idx(ring: ring + 1, seg: next)
                triangles.append((bl, br, tr))
                triangles.append((bl, tr, tl))
            }
        }

        // --- North pole fan ---
        for seg in 0..<segments {
            let next = (seg + 1) % segments
            triangles.append((northPole, idx(ring: rings - 1, seg: seg), idx(ring: rings - 1, seg: next)))
        }

        var mesh = TriangleMesh(
            vertices: vertices,
            normals: [],
            triangles: triangles
        )
        mesh.recomputeNormals()
        return mesh
    }
}
