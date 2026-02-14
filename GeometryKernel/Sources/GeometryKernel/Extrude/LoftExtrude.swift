import Foundation
import simd

/// Lofts between two or more 2D profiles at different heights to create a smooth solid.
/// Profiles must have the same number of points for 1:1 correspondence.
public enum LoftExtrudeOperation {

    /// Loft between profiles at specified heights.
    /// - Parameters:
    ///   - profiles: Array of 2D profiles (must all have same point count)
    ///   - heights: Z-height for each profile (must match profiles count)
    ///   - slicesPerSpan: Number of interpolation slices between each profile pair
    /// - Returns: The lofted triangle mesh
    public static func loft(
        profiles: [Polygon2D],
        heights: [Float],
        slicesPerSpan: Int = 4
    ) -> TriangleMesh {
        guard profiles.count >= 2,
              profiles.count == heights.count else { return TriangleMesh() }

        // Normalize all profiles to CCW
        var normalizedProfiles = profiles.map { profile -> Polygon2D in
            var p = profile
            p.ensureCounterClockwise()
            return p
        }

        // All profiles must have the same point count for 1:1 lofting
        let pointCount = normalizedProfiles[0].points.count
        guard pointCount >= 3 else { return TriangleMesh() }
        for p in normalizedProfiles {
            guard p.points.count == pointCount else { return TriangleMesh() }
        }

        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var triangles: [(UInt32, UInt32, UInt32)] = []

        // Build interpolated rings between each pair of profiles
        var rings: [[SIMD3<Float>]] = []

        for spanIdx in 0..<(normalizedProfiles.count - 1) {
            let profileA = normalizedProfiles[spanIdx]
            let profileB = normalizedProfiles[spanIdx + 1]
            let zA = heights[spanIdx]
            let zB = heights[spanIdx + 1]

            let slices = max(slicesPerSpan, 1)
            let startSlice = spanIdx == 0 ? 0 : 1 // Avoid duplicate rings at junctions

            for s in startSlice...slices {
                let t = Float(s) / Float(slices)
                let z = zA + (zB - zA) * t

                var ring: [SIMD3<Float>] = []
                for i in 0..<pointCount {
                    let ptA = profileA.points[i]
                    let ptB = profileB.points[i]
                    // Smooth interpolation using hermite-like cubic
                    let smoothT = t * t * (3 - 2 * t)
                    let x = ptA.x + (ptB.x - ptA.x) * smoothT
                    let y = ptA.y + (ptB.y - ptA.y) * smoothT
                    ring.append(SIMD3<Float>(x, y, z))
                }
                rings.append(ring)
            }
        }

        let n = pointCount
        let ringCount = rings.count

        // Side faces
        for s in 0..<(ringCount - 1) {
            let ringA = rings[s]
            let ringB = rings[s + 1]
            let baseIdx = UInt32(vertices.count)

            for i in 0..<n {
                vertices.append(ringA[i])
                vertices.append(ringB[i])
            }

            for i in 0..<n {
                let j = (i + 1) % n
                let ai = baseIdx + UInt32(i * 2)
                let bi = baseIdx + UInt32(i * 2 + 1)
                let aj = baseIdx + UInt32(j * 2)
                let bj = baseIdx + UInt32(j * 2 + 1)

                triangles.append((ai, aj, bj))
                triangles.append((ai, bj, bi))
            }
        }

        // Bottom cap
        let bottomCapBase = UInt32(vertices.count)
        for pt in rings[0] {
            vertices.append(pt)
        }
        for i in 1..<(n - 1) {
            triangles.append((bottomCapBase, bottomCapBase + UInt32(i + 1), bottomCapBase + UInt32(i)))
        }

        // Top cap
        let topCapBase = UInt32(vertices.count)
        for pt in rings[ringCount - 1] {
            vertices.append(pt)
        }
        for i in 1..<(n - 1) {
            triangles.append((topCapBase, topCapBase + UInt32(i), topCapBase + UInt32(i + 1)))
        }

        // Compute normals
        normals = Array(repeating: SIMD3<Float>(0, 0, 0), count: vertices.count)
        for tri in triangles {
            let v0 = vertices[Int(tri.0)]
            let v1 = vertices[Int(tri.1)]
            let v2 = vertices[Int(tri.2)]
            let fn = simd_normalize(simd_cross(v1 - v0, v2 - v0))
            if simd_length(fn) > 0 {
                normals[Int(tri.0)] += fn
                normals[Int(tri.1)] += fn
                normals[Int(tri.2)] += fn
            }
        }
        for i in normals.indices {
            let len = simd_length(normals[i])
            if len > 0 { normals[i] /= len }
        }

        return TriangleMesh(vertices: vertices, normals: normals, triangles: triangles)
    }
}
