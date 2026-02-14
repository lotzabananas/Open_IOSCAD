import Foundation
import simd

/// CSG operations on triangle meshes.
/// Uses a BSP-tree approach for boolean operations.
/// Falls back to additive merge for union when meshes don't overlap.
public enum CSGOperations {
    public static func perform(_ type: BooleanType, on meshes: [TriangleMesh]) -> TriangleMesh {
        guard !meshes.isEmpty else { return TriangleMesh() }
        guard meshes.count > 1 else { return meshes[0] }

        var result = meshes[0]
        for i in 1..<meshes.count {
            result = performBinary(type, a: result, b: meshes[i])
        }
        return result
    }

    private static func performBinary(_ type: BooleanType, a: TriangleMesh, b: TriangleMesh) -> TriangleMesh {
        guard !a.isEmpty && !b.isEmpty else {
            switch type {
            case .union: return a.isEmpty ? b : a
            case .difference: return a
            case .intersection: return TriangleMesh()
            }
        }

        let bbA = a.boundingBox
        let bbB = b.boundingBox
        let overlap = boxesOverlap(bbA, bbB)

        if !overlap {
            switch type {
            case .union:
                var merged = a
                merged.merge(b)
                return merged
            case .difference:
                return a
            case .intersection:
                return TriangleMesh()
            }
        }

        return bspBoolean(type, a: a, b: b)
    }

    private static func boxesOverlap(
        _ a: (min: SIMD3<Float>, max: SIMD3<Float>),
        _ b: (min: SIMD3<Float>, max: SIMD3<Float>)
    ) -> Bool {
        a.min.x <= b.max.x && a.max.x >= b.min.x &&
        a.min.y <= b.max.y && a.max.y >= b.min.y &&
        a.min.z <= b.max.z && a.max.z >= b.min.z
    }

    // MARK: - BSP Boolean

    private static func bspBoolean(_ type: BooleanType, a: TriangleMesh, b: TriangleMesh) -> TriangleMesh {
        let polysA = meshToPolygons(a)
        let polysB = meshToPolygons(b)

        var bspA = BSPNode(polygons: polysA)
        var bspB = BSPNode(polygons: polysB)

        switch type {
        case .union:
            bspA.clipTo(&bspB)
            bspB.clipTo(&bspA)
            bspB.invert()
            bspB.clipTo(&bspA)
            bspB.invert()
            let allPolys = bspA.allPolygons() + bspB.allPolygons()
            return polygonsToMesh(allPolys)

        case .difference:
            bspA.invert()
            bspA.clipTo(&bspB)
            bspB.clipTo(&bspA)
            bspB.invert()
            bspB.clipTo(&bspA)
            bspB.invert()
            let allPolys = bspA.allPolygons() + bspB.allPolygons()
            var result = polygonsToMesh(allPolys)
            result.flipWinding()
            return result

        case .intersection:
            // Intersection: keep A's faces inside B, keep B's faces inside A.
            // Use fresh BSP trees so clipping one doesn't affect the other's structure.
            var bspAForClipB = BSPNode(polygons: polysA)
            bspA.clipToInverse(&bspB)
            let bspB2 = BSPNode(polygons: polysB)
            bspB2.clipToInverse(&bspAForClipB)
            let allPolys = bspA.allPolygons() + bspB2.allPolygons()
            return polygonsToMesh(allPolys)
        }
    }
}

// MARK: - BSP Tree

struct BSPPolygon {
    var vertices: [SIMD3<Float>]
    var normal: SIMD3<Float>

    var plane: BSPPlane {
        BSPPlane(normal: normal, w: simd_dot(normal, vertices[0]))
    }
}

struct BSPPlane {
    var normal: SIMD3<Float>
    var w: Float

    static let epsilon: Float = 1e-5

    enum Classification: Int {
        case coplanar = 0
        case front = 1
        case back = 2
        case spanning = 3
    }

    func classify(_ polygon: BSPPolygon) -> Classification {
        var numFront = 0
        var numBack = 0
        for v in polygon.vertices {
            let t = simd_dot(normal, v) - w
            if t < -BSPPlane.epsilon {
                numBack += 1
            } else if t > BSPPlane.epsilon {
                numFront += 1
            }
        }
        if numFront > 0 && numBack > 0 { return .spanning }
        if numFront > 0 { return .front }
        if numBack > 0 { return .back }
        return .coplanar
    }

    func split(_ polygon: BSPPolygon) -> (front: [BSPPolygon], back: [BSPPolygon]) {
        let classification = classify(polygon)

        switch classification {
        case .coplanar:
            if simd_dot(normal, polygon.normal) > 0 {
                return ([polygon], [])
            } else {
                return ([], [polygon])
            }
        case .front:
            return ([polygon], [])
        case .back:
            return ([], [polygon])
        case .spanning:
            return splitPolygon(polygon)
        }
    }

    private func splitPolygon(_ polygon: BSPPolygon) -> (front: [BSPPolygon], back: [BSPPolygon]) {
        var frontVerts: [SIMD3<Float>] = []
        var backVerts: [SIMD3<Float>] = []

        let count = polygon.vertices.count
        for i in 0..<count {
            let j = (i + 1) % count
            let vi = polygon.vertices[i]
            let vj = polygon.vertices[j]
            let ti = simd_dot(normal, vi) - w
            let tj = simd_dot(normal, vj) - w

            if ti >= -BSPPlane.epsilon {
                frontVerts.append(vi)
            }
            if ti <= BSPPlane.epsilon {
                backVerts.append(vi)
            }

            if (ti > BSPPlane.epsilon && tj < -BSPPlane.epsilon) ||
               (ti < -BSPPlane.epsilon && tj > BSPPlane.epsilon) {
                let t = (w - simd_dot(normal, vi)) / simd_dot(normal, vj - vi)
                let intersection = vi + (vj - vi) * t
                frontVerts.append(intersection)
                backVerts.append(intersection)
            }
        }

        var front: [BSPPolygon] = []
        var back: [BSPPolygon] = []

        if frontVerts.count >= 3 {
            front.append(BSPPolygon(vertices: frontVerts, normal: polygon.normal))
        }
        if backVerts.count >= 3 {
            back.append(BSPPolygon(vertices: backVerts, normal: polygon.normal))
        }

        return (front, back)
    }
}

class BSPNode {
    var plane: BSPPlane?
    var front: BSPNode?
    var back: BSPNode?
    var polygons: [BSPPolygon]

    init(polygons: [BSPPolygon] = []) {
        self.polygons = []
        if !polygons.isEmpty {
            build(polygons)
        }
    }

    func build(_ polys: [BSPPolygon], depth: Int = 0) {
        guard !polys.isEmpty else { return }

        // Depth limit to prevent stack overflow
        if depth > 100 {
            polygons.append(contentsOf: polys)
            return
        }

        if plane == nil {
            plane = polys[0].plane
        }

        var frontPolys: [BSPPolygon] = []
        var backPolys: [BSPPolygon] = []

        for poly in polys {
            let (f, b) = plane!.split(poly)
            if f.isEmpty && b.isEmpty {
                polygons.append(poly)
            } else {
                frontPolys.append(contentsOf: f.filter { $0.vertices.count >= 3 })
                backPolys.append(contentsOf: b.filter { $0.vertices.count >= 3 })
            }
        }

        if !frontPolys.isEmpty {
            if front == nil { front = BSPNode() }
            front!.build(frontPolys, depth: depth + 1)
        }
        if !backPolys.isEmpty {
            if back == nil { back = BSPNode() }
            back!.build(backPolys, depth: depth + 1)
        }
    }

    func allPolygons() -> [BSPPolygon] {
        var result = polygons
        if let f = front { result += f.allPolygons() }
        if let b = back { result += b.allPolygons() }
        return result
    }

    func invert() {
        for i in polygons.indices {
            polygons[i].vertices.reverse()
            polygons[i].normal = -polygons[i].normal
        }
        if var p = plane {
            p.normal = -p.normal
            p.w = -p.w
            plane = p
        }
        front?.invert()
        back?.invert()
        let tmp = front
        front = back
        back = tmp
    }

    func clipPolygons(_ polys: [BSPPolygon]) -> [BSPPolygon] {
        guard let plane = plane else { return polys }

        var frontPolys: [BSPPolygon] = []
        var backPolys: [BSPPolygon] = []

        for poly in polys {
            let (f, b) = plane.split(poly)
            frontPolys += f
            backPolys += b
        }

        frontPolys = front?.clipPolygons(frontPolys) ?? frontPolys
        backPolys = back?.clipPolygons(backPolys) ?? []

        return frontPolys + backPolys
    }

    /// Inverse of clipPolygons: keeps polygons INSIDE the BSP tree, removes those outside.
    func clipPolygonsInverse(_ polys: [BSPPolygon]) -> [BSPPolygon] {
        guard let plane = plane else { return [] }

        var frontPolys: [BSPPolygon] = []
        var backPolys: [BSPPolygon] = []

        for poly in polys {
            let (f, b) = plane.split(poly)
            frontPolys += f
            backPolys += b
        }

        frontPolys = front?.clipPolygonsInverse(frontPolys) ?? []
        backPolys = back?.clipPolygonsInverse(backPolys) ?? backPolys

        return frontPolys + backPolys
    }

    func clipTo(_ other: inout BSPNode) {
        polygons = other.clipPolygons(polygons)
        front?.clipTo(&other)
        back?.clipTo(&other)
    }

    func clipToInverse(_ other: inout BSPNode) {
        polygons = other.clipPolygonsInverse(polygons)
        front?.clipToInverse(&other)
        back?.clipToInverse(&other)
    }
}

// MARK: - Mesh ↔ Polygon conversion

extension CSGOperations {
    static func meshToPolygons(_ mesh: TriangleMesh) -> [BSPPolygon] {
        var polys: [BSPPolygon] = []
        for tri in mesh.triangles {
            let v0 = mesh.vertices[Int(tri.0)]
            let v1 = mesh.vertices[Int(tri.1)]
            let v2 = mesh.vertices[Int(tri.2)]
            let normal = simd_normalize(simd_cross(v1 - v0, v2 - v0))
            if simd_length(normal) > 0 {
                polys.append(BSPPolygon(vertices: [v0, v1, v2], normal: normal))
            }
        }
        return polys
    }

    static func polygonsToMesh(_ polygons: [BSPPolygon]) -> TriangleMesh {
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var triangles: [(UInt32, UInt32, UInt32)] = []

        for poly in polygons {
            guard poly.vertices.count >= 3 else { continue }
            let baseIdx = UInt32(vertices.count)
            vertices.append(contentsOf: poly.vertices)
            for _ in poly.vertices {
                normals.append(poly.normal)
            }
            for i in 1..<(poly.vertices.count - 1) {
                triangles.append((baseIdx, baseIdx + UInt32(i), baseIdx + UInt32(i + 1)))
            }
        }

        return TriangleMesh(vertices: vertices, normals: normals, triangles: triangles)
    }
}
