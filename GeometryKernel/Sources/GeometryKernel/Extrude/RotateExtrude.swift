import Foundation
import simd

public enum RotateExtrudeOperation {
    public static func extrude(polygon: Polygon2D, params: ExtrudeParams) -> TriangleMesh {
        guard polygon.points.count >= 2 else { return TriangleMesh() }

        let angleRad = params.angle * .pi / 180.0
        let segments = params.fn > 0 ? params.fn : max(Int(params.angle / 10), 8)
        let fullRevolution = abs(params.angle - 360.0) < 0.001

        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var triangles: [(UInt32, UInt32, UInt32)] = []

        let profile = polygon.points
        let profileCount = profile.count

        // Generate rings by rotating the 2D profile around Y axis
        let ringCount = fullRevolution ? segments : segments + 1

        var rings: [[UInt32]] = []
        for s in 0..<ringCount {
            let t = Float(s) / Float(segments)
            let theta = angleRad * t
            let cosT = cos(theta)
            let sinT = sin(theta)

            var ring: [UInt32] = []
            for pt in profile {
                let x = pt.x * cosT
                let z = pt.x * sinT
                let y = pt.y
                let idx = UInt32(vertices.count)
                vertices.append(SIMD3<Float>(x, y, z))

                // Normal: rotate the 2D normal around Y
                let nx = cosT
                let nz = sinT
                normals.append(SIMD3<Float>(nx, 0, nz))
                ring.append(idx)
            }
            rings.append(ring)
        }

        // Connect rings with triangles
        for s in 0..<segments {
            let nextS = fullRevolution ? (s + 1) % segments : s + 1
            let ringA = rings[s]
            let ringB = rings[nextS]

            for i in 0..<(profileCount - 1) {
                let a0 = ringA[i]
                let a1 = ringA[i + 1]
                let b0 = ringB[i]
                let b1 = ringB[i + 1]

                triangles.append((a0, b0, b1))
                triangles.append((a0, b1, a1))
            }
        }

        // Cap faces for partial revolution
        if !fullRevolution {
            // Start cap
            let startCapBase = rings[0]
            if startCapBase.count >= 3 {
                for i in 1..<(startCapBase.count - 1) {
                    triangles.append((startCapBase[0], startCapBase[i + 1], startCapBase[i]))
                }
            }

            // End cap
            let endCapBase = rings[ringCount - 1]
            if endCapBase.count >= 3 {
                for i in 1..<(endCapBase.count - 1) {
                    triangles.append((endCapBase[0], endCapBase[i], endCapBase[i + 1]))
                }
            }
        }

        var mesh = TriangleMesh(vertices: vertices, normals: normals, triangles: triangles)
        mesh.recomputeNormals()
        return mesh
    }
}
