import Foundation
import simd

public enum LinearExtrudeOperation {
    public static func extrude(polygon: Polygon2D, params: ExtrudeParams) -> TriangleMesh {
        guard polygon.points.count >= 3 else { return TriangleMesh() }

        var poly = polygon
        poly.ensureCounterClockwise()

        let height = params.height
        let twist = params.twist * .pi / 180.0
        let scaleEnd = params.scale
        let slices = max(params.slices, twist != 0 ? max(Int(abs(twist) / (Float.pi / 18)), 1) : 1)
        let zOffset: Float = params.center ? -height / 2 : 0

        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var triangles: [(UInt32, UInt32, UInt32)] = []

        let n = poly.points.count

        // Generate vertex rings at each slice
        var rings: [[SIMD3<Float>]] = []
        for s in 0...slices {
            let t = Float(s) / Float(slices)
            let z = zOffset + height * t
            let angle = twist * t
            let sx = 1.0 + (scaleEnd.x - 1.0) * t
            let sy = 1.0 + (scaleEnd.y - 1.0) * t
            let cosA = cos(angle)
            let sinA = sin(angle)

            var ring: [SIMD3<Float>] = []
            for pt in poly.points {
                let scaled = SIMD2<Float>(pt.x * sx, pt.y * sy)
                let rotated = SIMD2<Float>(
                    scaled.x * cosA - scaled.y * sinA,
                    scaled.x * sinA + scaled.y * cosA
                )
                ring.append(SIMD3<Float>(rotated.x, rotated.y, z))
            }
            rings.append(ring)
        }

        // Side faces
        for s in 0..<slices {
            let ringBottom = rings[s]
            let ringTop = rings[s + 1]
            let baseIdx = UInt32(vertices.count)

            for i in 0..<n {
                vertices.append(ringBottom[i])
                vertices.append(ringTop[i])
            }

            for i in 0..<n {
                let j = (i + 1) % n
                let bi = baseIdx + UInt32(i * 2)
                let ti = baseIdx + UInt32(i * 2 + 1)
                let bj = baseIdx + UInt32(j * 2)
                let tj = baseIdx + UInt32(j * 2 + 1)

                triangles.append((bi, bj, tj))
                triangles.append((bi, tj, ti))
            }
        }

        // Compute side normals
        for _ in 0..<vertices.count {
            normals.append(SIMD3<Float>(0, 0, 0))
        }
        for tri in triangles {
            let v0 = vertices[Int(tri.0)]
            let v1 = vertices[Int(tri.1)]
            let v2 = vertices[Int(tri.2)]
            let fn = simd_normalize(simd_cross(v1 - v0, v2 - v0))
            normals[Int(tri.0)] += fn
            normals[Int(tri.1)] += fn
            normals[Int(tri.2)] += fn
        }
        for i in normals.indices {
            let len = simd_length(normals[i])
            if len > 0 { normals[i] /= len }
        }

        // Bottom cap (z = zOffset)
        let bottomCapStart = UInt32(vertices.count)
        let bottomRing = rings[0]
        for pt in bottomRing {
            vertices.append(pt)
            normals.append(SIMD3<Float>(0, 0, -1))
        }
        for i in 1..<(n - 1) {
            triangles.append((bottomCapStart, bottomCapStart + UInt32(i + 1), bottomCapStart + UInt32(i)))
        }

        // Top cap (z = zOffset + height)
        let topCapStart = UInt32(vertices.count)
        let topRing = rings[slices]
        for pt in topRing {
            vertices.append(pt)
            normals.append(SIMD3<Float>(0, 0, 1))
        }
        for i in 1..<(n - 1) {
            triangles.append((topCapStart, topCapStart + UInt32(i), topCapStart + UInt32(i + 1)))
        }

        return TriangleMesh(vertices: vertices, normals: normals, triangles: triangles)
    }
}
