import Foundation
import simd

/// Reads a STEP file and extracts basic geometry as a TriangleMesh.
/// Phase 1 focuses on reading CARTESIAN_POINT entities to build a point cloud
/// and advanced faces to reconstruct triangulated geometry.
/// External STEP files (without @openioscad history) are imported as solid bodies.
public enum STEPReader {

    /// Parse a STEP file string and return extracted geometry.
    /// Returns an empty mesh if parsing fails gracefully.
    public static func read(_ content: String) -> TriangleMesh {
        let lines = content.components(separatedBy: "\n")

        // Parse CARTESIAN_POINT entities
        var points: [Int: SIMD3<Float>] = [:]
        var vertexPoints: [Int: Int] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // CARTESIAN_POINT
            if let (id, point) = parseCartesianPoint(trimmed) {
                points[id] = point
            }

            // VERTEX_POINT — references a CARTESIAN_POINT
            if let (id, pointRef) = parseVertexPoint(trimmed) {
                vertexPoints[id] = pointRef
            }
        }

        // If no geometry entities found, return empty mesh
        if points.isEmpty {
            return TriangleMesh()
        }

        // Build a simple point cloud mesh as a fallback
        // For proper STEP import, we'd need full BREP reconstruction
        // which is a Phase 4 concern
        let allPoints = Array(points.values)
        if allPoints.count >= 3 {
            return buildConvexHullApproximation(from: allPoints)
        }

        return TriangleMesh()
    }

    // MARK: - Parsing Helpers

    private static func parseCartesianPoint(_ line: String) -> (Int, SIMD3<Float>)? {
        // Pattern: #123=CARTESIAN_POINT('',(...));
        guard line.contains("CARTESIAN_POINT") else { return nil }

        guard let idEnd = line.firstIndex(of: "=") else { return nil }
        let idStr = String(line[line.index(after: line.startIndex)..<idEnd])
        guard let id = Int(idStr) else { return nil }

        guard let parenStart = line.firstIndex(of: "("),
              let innerStart = line[line.index(after: parenStart)...].firstIndex(of: "("),
              let innerEnd = line[line.index(after: innerStart)...].firstIndex(of: ")") else {
            return nil
        }

        let coordStr = String(line[line.index(after: innerStart)..<innerEnd])
        let parts = coordStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 3,
              let x = Float(parts[0]),
              let y = Float(parts[1]),
              let z = Float(parts[2]) else {
            return nil
        }

        return (id, SIMD3<Float>(x, y, z))
    }

    private static func parseVertexPoint(_ line: String) -> (Int, Int)? {
        // Pattern: #123=VERTEX_POINT('',#456);
        guard line.contains("VERTEX_POINT") else { return nil }

        guard let idEnd = line.firstIndex(of: "=") else { return nil }
        let idStr = String(line[line.index(after: line.startIndex)..<idEnd])
        guard let id = Int(idStr) else { return nil }

        guard let hashIdx = line[line.index(after: idEnd)...].lastIndex(of: "#") else { return nil }
        let refStr = line[line.index(after: hashIdx)...]
            .trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
        guard let ref = Int(refStr) else { return nil }

        return (id, ref)
    }

    /// Build a rough triangulated surface from a point cloud.
    /// This is a placeholder — real STEP BREP import comes in Phase 4.
    private static func buildConvexHullApproximation(from points: [SIMD3<Float>]) -> TriangleMesh {
        // For imported STEP files without our history comment,
        // we create a simple bounding representation.
        // Full BREP→mesh conversion is a Phase 4 feature.
        guard points.count >= 4 else { return TriangleMesh() }

        // Find bounding box and create a box mesh
        var minP = points[0]
        var maxP = points[0]
        for p in points {
            minP = simd_min(minP, p)
            maxP = simd_max(maxP, p)
        }

        let size = maxP - minP
        guard size.x > 0, size.y > 0, size.z > 0 else { return TriangleMesh() }

        let params = PrimitiveParams(size: size)
        var mesh = CubeGenerator.generate(params: params)

        // Translate to correct position
        let offset = minP
        let transform = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(offset.x, offset.y, offset.z, 1)
        )
        mesh.apply(transform: transform)

        return mesh
    }
}
