import Foundation
import simd

/// Generates cylinder and cone meshes from PrimitiveParams.
///
/// Produces a closed, manifold TriangleMesh with top cap, bottom cap,
/// and side quads (each split into 2 triangles). When `radius1 != radius2`
/// the result is a truncated cone (or a full cone when one radius is 0).
public enum CylinderGenerator {

    /// Generate a cylinder or cone mesh.
    ///
    /// - Parameter params: Primitive parameters.
    ///   - `radius` / `radius1` / `radius2`: Bottom and top radii.
    ///     If only `radius` is set both caps share it. Defaults to 1.
    ///   - `height`: Length along the Z axis. Defaults to 1.
    ///   - `center`: When false the bottom sits at z = 0; when true the
    ///     cylinder is centered vertically on the origin.
    ///   - `fn` / `fa` / `fs`: Facet count controls (passed through
    ///     `resolvedSegments(forRadius:)`).
    /// - Returns: A manifold `TriangleMesh`.
    public static func generate(params: PrimitiveParams) -> TriangleMesh {
        let r1 = params.radius1 ?? params.radius ?? 1.0  // bottom radius
        let r2 = params.radius2 ?? params.radius ?? 1.0  // top radius
        let h  = params.height ?? 1.0
        let maxR = max(r1, r2, Float.leastNonzeroMagnitude)
        let n  = params.resolvedSegments(forRadius: maxR)

        let zBottom: Float
        let zTop: Float
        if params.center {
            zBottom = -h / 2
            zTop    =  h / 2
        } else {
            zBottom = 0
            zTop    = h
        }

        var vertices: [SIMD3<Float>] = []
        var triangles: [(UInt32, UInt32, UInt32)] = []

        // --- Bottom ring (indices 0 ..< n) ---
        for i in 0..<n {
            let angle = Float(i) / Float(n) * 2.0 * .pi
            let x = r1 * cos(angle)
            let y = r1 * sin(angle)
            vertices.append(SIMD3<Float>(x, y, zBottom))
        }

        // --- Top ring (indices n ..< 2*n) ---
        for i in 0..<n {
            let angle = Float(i) / Float(n) * 2.0 * .pi
            let x = r2 * cos(angle)
            let y = r2 * sin(angle)
            vertices.append(SIMD3<Float>(x, y, zTop))
        }

        // --- Center of bottom cap (index 2*n) ---
        let bottomCenter = UInt32(vertices.count)
        vertices.append(SIMD3<Float>(0, 0, zBottom))

        // --- Center of top cap (index 2*n + 1) ---
        let topCenter = UInt32(vertices.count)
        vertices.append(SIMD3<Float>(0, 0, zTop))

        // --- Side faces ---
        for i in 0..<n {
            let bl = UInt32(i)
            let br = UInt32((i + 1) % n)
            let tl = UInt32(i + n)
            let tr = UInt32((i + 1) % n + n)

            // Two triangles per quad, wound so normals face outward.
            triangles.append((bl, br, tr))
            triangles.append((bl, tr, tl))
        }

        // --- Bottom cap (normal pointing -Z) ---
        // Winding must be clockwise when viewed from -Z (i.e., looking up
        // from below) so the outward normal faces downward.
        for i in 0..<n {
            let cur  = UInt32(i)
            let next = UInt32((i + 1) % n)
            triangles.append((bottomCenter, next, cur))
        }

        // --- Top cap (normal pointing +Z) ---
        for i in 0..<n {
            let cur  = UInt32(i + n)
            let next = UInt32((i + 1) % n + n)
            triangles.append((topCenter, cur, next))
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
