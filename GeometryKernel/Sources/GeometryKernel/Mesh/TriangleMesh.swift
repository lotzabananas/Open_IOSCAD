import Foundation
import simd

/// Core triangle mesh data structure used throughout OpeniOSCAD.
/// All geometry operations produce and consume this type.
public struct TriangleMesh: Equatable, Sendable {
    public var vertices: [SIMD3<Float>]
    public var normals: [SIMD3<Float>]
    public var triangles: [(UInt32, UInt32, UInt32)]

    public init(
        vertices: [SIMD3<Float>] = [],
        normals: [SIMD3<Float>] = [],
        triangles: [(UInt32, UInt32, UInt32)] = []
    ) {
        self.vertices = vertices
        self.normals = normals
        self.triangles = triangles
    }

    public var triangleCount: Int { triangles.count }
    public var vertexCount: Int { vertices.count }
    public var isEmpty: Bool { triangles.isEmpty }

    public var boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard !vertices.isEmpty else {
            return (SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, 0))
        }
        var minV = vertices[0]
        var maxV = vertices[0]
        for v in vertices {
            minV = simd_min(minV, v)
            maxV = simd_max(maxV, v)
        }
        return (minV, maxV)
    }

    public var center: SIMD3<Float> {
        let bb = boundingBox
        return (bb.min + bb.max) * 0.5
    }

    /// Check if the mesh is manifold (every edge shared by exactly 2 triangles)
    public var isManifold: Bool {
        var edgeCounts: [EdgeKey: Int] = [:]
        for tri in triangles {
            let edges: [(UInt32, UInt32)] = [
                (min(tri.0, tri.1), max(tri.0, tri.1)),
                (min(tri.1, tri.2), max(tri.1, tri.2)),
                (min(tri.0, tri.2), max(tri.0, tri.2)),
            ]
            for edge in edges {
                let key = EdgeKey(a: edge.0, b: edge.1)
                edgeCounts[key, default: 0] += 1
            }
        }
        return edgeCounts.values.allSatisfy { $0 == 2 }
    }

    /// Recompute per-vertex normals from face normals (smooth shading)
    public mutating func recomputeNormals() {
        normals = Array(repeating: SIMD3<Float>(0, 0, 0), count: vertices.count)
        for tri in triangles {
            let v0 = vertices[Int(tri.0)]
            let v1 = vertices[Int(tri.1)]
            let v2 = vertices[Int(tri.2)]
            let faceNormal = simd_normalize(simd_cross(v1 - v0, v2 - v0))
            normals[Int(tri.0)] += faceNormal
            normals[Int(tri.1)] += faceNormal
            normals[Int(tri.2)] += faceNormal
        }
        for i in normals.indices {
            let len = simd_length(normals[i])
            if len > 0 {
                normals[i] = normals[i] / len
            }
        }
    }

    /// Compute flat (per-face) normals by duplicating vertices
    public func flatShaded() -> TriangleMesh {
        var newVertices: [SIMD3<Float>] = []
        var newNormals: [SIMD3<Float>] = []
        var newTriangles: [(UInt32, UInt32, UInt32)] = []

        for tri in triangles {
            let v0 = vertices[Int(tri.0)]
            let v1 = vertices[Int(tri.1)]
            let v2 = vertices[Int(tri.2)]
            let normal = simd_normalize(simd_cross(v1 - v0, v2 - v0))
            let idx = UInt32(newVertices.count)
            newVertices.append(contentsOf: [v0, v1, v2])
            newNormals.append(contentsOf: [normal, normal, normal])
            newTriangles.append((idx, idx + 1, idx + 2))
        }

        return TriangleMesh(vertices: newVertices, normals: newNormals, triangles: newTriangles)
    }

    /// Merge another mesh into this one
    public mutating func merge(_ other: TriangleMesh) {
        let offset = UInt32(vertices.count)
        vertices.append(contentsOf: other.vertices)
        normals.append(contentsOf: other.normals)
        for tri in other.triangles {
            triangles.append((tri.0 + offset, tri.1 + offset, tri.2 + offset))
        }
    }

    /// Apply a 4x4 transform matrix to all vertices and normals
    public mutating func apply(transform: simd_float4x4) {
        let normalMatrix = transform.upperLeft3x3.inverse.transpose
        for i in vertices.indices {
            let v4 = transform * SIMD4<Float>(vertices[i], 1.0)
            vertices[i] = SIMD3<Float>(v4.x, v4.y, v4.z)
        }
        for i in normals.indices {
            normals[i] = simd_normalize(normalMatrix * normals[i])
        }
    }

    public static func == (lhs: TriangleMesh, rhs: TriangleMesh) -> Bool {
        lhs.vertices == rhs.vertices &&
        lhs.normals == rhs.normals &&
        lhs.triangles.count == rhs.triangles.count &&
        zip(lhs.triangles, rhs.triangles).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 && $0.2 == $1.2 }
    }
}

struct EdgeKey: Hashable {
    let a: UInt32
    let b: UInt32
}

extension simd_float4x4 {
    public var upperLeft3x3: simd_float3x3 {
        simd_float3x3(
            SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z),
            SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z),
            SIMD3<Float>(columns.2.x, columns.2.y, columns.2.z)
        )
    }
}
