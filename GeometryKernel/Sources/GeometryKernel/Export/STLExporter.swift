import Foundation
import simd

public enum STLExporter {
    /// Export a TriangleMesh to binary STL format
    public static func exportBinary(_ mesh: TriangleMesh) -> Data {
        var data = Data()

        // 80-byte header
        var header = "OpeniOSCAD Export".data(using: .ascii)!
        header.append(Data(count: 80 - header.count))
        data.append(header)

        // Triangle count (uint32, little-endian)
        var triangleCount = UInt32(mesh.triangles.count)
        data.append(Data(bytes: &triangleCount, count: 4))

        // Per triangle: normal (3 floats) + 3 vertices (9 floats) + attribute (2 bytes)
        for tri in mesh.triangles {
            let v0 = mesh.vertices[Int(tri.0)]
            let v1 = mesh.vertices[Int(tri.1)]
            let v2 = mesh.vertices[Int(tri.2)]

            // Compute face normal
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            var normal = simd_cross(edge1, edge2)
            let len = simd_length(normal)
            if len > 0 { normal /= len }

            // Normal
            appendFloat(&data, normal.x)
            appendFloat(&data, normal.y)
            appendFloat(&data, normal.z)

            // Vertex 1
            appendFloat(&data, v0.x)
            appendFloat(&data, v0.y)
            appendFloat(&data, v0.z)

            // Vertex 2
            appendFloat(&data, v1.x)
            appendFloat(&data, v1.y)
            appendFloat(&data, v1.z)

            // Vertex 3
            appendFloat(&data, v2.x)
            appendFloat(&data, v2.y)
            appendFloat(&data, v2.z)

            // Attribute byte count
            var attr: UInt16 = 0
            data.append(Data(bytes: &attr, count: 2))
        }

        return data
    }

    /// Export a TriangleMesh to ASCII STL format
    public static func exportASCII(_ mesh: TriangleMesh, name: String = "OpeniOSCAD") -> String {
        var lines: [String] = []
        lines.append("solid \(name)")

        for tri in mesh.triangles {
            let v0 = mesh.vertices[Int(tri.0)]
            let v1 = mesh.vertices[Int(tri.1)]
            let v2 = mesh.vertices[Int(tri.2)]

            let edge1 = v1 - v0
            let edge2 = v2 - v0
            var normal = simd_cross(edge1, edge2)
            let len = simd_length(normal)
            if len > 0 { normal /= len }

            lines.append("  facet normal \(normal.x) \(normal.y) \(normal.z)")
            lines.append("    outer loop")
            lines.append("      vertex \(v0.x) \(v0.y) \(v0.z)")
            lines.append("      vertex \(v1.x) \(v1.y) \(v1.z)")
            lines.append("      vertex \(v2.x) \(v2.y) \(v2.z)")
            lines.append("    endloop")
            lines.append("  endfacet")
        }

        lines.append("endsolid \(name)")
        return lines.joined(separator: "\n")
    }

    private static func appendFloat(_ data: inout Data, _ value: Float) {
        var v = value
        data.append(Data(bytes: &v, count: 4))
    }
}
