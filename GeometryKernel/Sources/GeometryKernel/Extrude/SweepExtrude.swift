import Foundation
import simd

/// Sweeps a 2D profile along a 3D path to create a solid.
/// The profile is oriented perpendicular to the path at each station.
public enum SweepExtrudeOperation {

    /// Sweep a polygon profile along a 3D path.
    /// - Parameters:
    ///   - polygon: The cross-section profile
    ///   - path: Ordered list of 3D points defining the sweep path
    ///   - twistPerStation: Twist angle (radians) applied incrementally per path station
    ///   - scaleEnd: Scale factor at the end of the path (uniform)
    /// - Returns: The swept triangle mesh
    public static func sweep(
        polygon: Polygon2D,
        path: [SIMD3<Float>],
        twist: Float = 0,
        scaleEnd: Float = 1.0
    ) -> TriangleMesh {
        guard polygon.points.count >= 3, path.count >= 2 else { return TriangleMesh() }

        var poly = polygon
        poly.ensureCounterClockwise()

        let n = poly.points.count
        let stationCount = path.count

        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var triangles: [(UInt32, UInt32, UInt32)] = []

        // Build a coordinate frame at each path station using Frenet-like frames
        var frames: [(origin: SIMD3<Float>, tangent: SIMD3<Float>, normal: SIMD3<Float>, binormal: SIMD3<Float>)] = []

        for i in 0..<stationCount {
            let origin = path[i]

            // Tangent: direction along path
            let tangent: SIMD3<Float>
            if i == 0 {
                tangent = simd_normalize(path[1] - path[0])
            } else if i == stationCount - 1 {
                tangent = simd_normalize(path[i] - path[i - 1])
            } else {
                tangent = simd_normalize(path[i + 1] - path[i - 1])
            }

            // Find a normal perpendicular to tangent
            let up: SIMD3<Float>
            if abs(tangent.y) < 0.9 {
                up = SIMD3<Float>(0, 1, 0)
            } else {
                up = SIMD3<Float>(1, 0, 0)
            }
            let normal = simd_normalize(simd_cross(tangent, up))
            let binormal = simd_normalize(simd_cross(tangent, normal))

            frames.append((origin, tangent, normal, binormal))
        }

        // Generate vertex rings at each station
        var rings: [[SIMD3<Float>]] = []
        for i in 0..<stationCount {
            let frame = frames[i]
            let t = Float(i) / Float(max(stationCount - 1, 1))
            let scale = 1.0 + (scaleEnd - 1.0) * t
            let twistAngle = twist * t
            let cosA = cos(twistAngle)
            let sinA = sin(twistAngle)

            var ring: [SIMD3<Float>] = []
            for pt in poly.points {
                // Apply twist
                let rotatedX = pt.x * cosA - pt.y * sinA
                let rotatedY = pt.x * sinA + pt.y * cosA
                // Apply scale
                let scaledX = rotatedX * scale
                let scaledY = rotatedY * scale
                // Map to 3D using frame
                let worldPos = frame.origin
                    + frame.normal * scaledX
                    + frame.binormal * scaledY
                ring.append(worldPos)
            }
            rings.append(ring)
        }

        // Side faces connecting consecutive rings
        for s in 0..<(stationCount - 1) {
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

        // Start cap
        let startCapBase = UInt32(vertices.count)
        for pt in rings[0] {
            vertices.append(pt)
        }
        for i in 1..<(n - 1) {
            triangles.append((startCapBase, startCapBase + UInt32(i + 1), startCapBase + UInt32(i)))
        }

        // End cap
        let endCapBase = UInt32(vertices.count)
        for pt in rings[stationCount - 1] {
            vertices.append(pt)
        }
        for i in 1..<(n - 1) {
            triangles.append((endCapBase, endCapBase + UInt32(i), endCapBase + UInt32(i + 1)))
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
