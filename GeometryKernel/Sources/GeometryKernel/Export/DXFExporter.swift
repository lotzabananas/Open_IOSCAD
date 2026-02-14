import Foundation
import simd

/// Exports a TriangleMesh as a 2D DXF drawing with orthographic projections.
/// Produces AutoCAD R12-compatible DXF with front, top, and right side views.
public enum DXFExporter {

    /// Projection direction for orthographic views.
    public enum ProjectionView: String, Sendable {
        case front  // XZ plane (looking along -Y)
        case top    // XY plane (looking along -Z)
        case right  // YZ plane (looking along -X)
    }

    /// Export a mesh as a multi-view DXF drawing.
    /// Produces three orthographic views arranged in standard third-angle projection layout.
    public static func export(_ mesh: TriangleMesh, scale: Float = 1.0) -> String {
        guard !mesh.isEmpty else { return emptyDXF() }

        let bb = mesh.boundingBox
        let size = bb.max - bb.min
        let margin: Float = max(size.x, size.y, size.z) * 0.3

        // Extract silhouette edges for each projection
        let frontEdges = projectEdges(mesh, view: .front, offsetX: 0, offsetY: 0, scale: scale)
        let topEdges = projectEdges(mesh, view: .top, offsetX: 0, offsetY: Float(size.z) * scale + margin, scale: scale)
        let rightEdges = projectEdges(mesh, view: .right, offsetX: Float(size.x) * scale + margin, offsetY: 0, scale: scale)

        var lines: [String] = []

        // DXF Header
        lines.append(contentsOf: dxfHeader())

        // Tables section (layer definitions)
        lines.append(contentsOf: dxfTables())

        // Entities section
        lines.append("0")
        lines.append("SECTION")
        lines.append("2")
        lines.append("ENTITIES")

        // Front view entities
        for edge in frontEdges {
            lines.append(contentsOf: dxfLine(edge, layer: "FRONT"))
        }

        // Top view entities
        for edge in topEdges {
            lines.append(contentsOf: dxfLine(edge, layer: "TOP"))
        }

        // Right view entities
        for edge in rightEdges {
            lines.append(contentsOf: dxfLine(edge, layer: "RIGHT"))
        }

        // View labels
        lines.append(contentsOf: dxfText("Front", x: 0, y: -margin * 0.5, layer: "LABELS"))
        lines.append(contentsOf: dxfText("Top", x: 0, y: Float(size.z) * scale + margin * 1.5, layer: "LABELS"))
        lines.append(contentsOf: dxfText("Right", x: Float(size.x) * scale + margin, y: -margin * 0.5, layer: "LABELS"))

        // Bounding dimension annotations
        lines.append(contentsOf: dimensionAnnotations(mesh, scale: scale, margin: margin))

        lines.append("0")
        lines.append("ENDSEC")

        // EOF
        lines.append("0")
        lines.append("EOF")

        return lines.joined(separator: "\n")
    }

    /// Export a single projection view as DXF.
    public static func exportSingleView(_ mesh: TriangleMesh, view: ProjectionView, scale: Float = 1.0) -> String {
        guard !mesh.isEmpty else { return emptyDXF() }

        let edges = projectEdges(mesh, view: view, offsetX: 0, offsetY: 0, scale: scale)

        var lines: [String] = []
        lines.append(contentsOf: dxfHeader())
        lines.append(contentsOf: dxfTables())

        lines.append("0")
        lines.append("SECTION")
        lines.append("2")
        lines.append("ENTITIES")

        for edge in edges {
            lines.append(contentsOf: dxfLine(edge, layer: "0"))
        }

        lines.append("0")
        lines.append("ENDSEC")
        lines.append("0")
        lines.append("EOF")

        return lines.joined(separator: "\n")
    }

    // MARK: - Edge Projection

    /// A 2D line segment resulting from projection.
    private struct Edge2D {
        let x1: Float, y1: Float
        let x2: Float, y2: Float
    }

    /// Project mesh edges onto a 2D plane and extract visible silhouette edges.
    private static func projectEdges(
        _ mesh: TriangleMesh,
        view: ProjectionView,
        offsetX: Float,
        offsetY: Float,
        scale: Float
    ) -> [Edge2D] {
        // Extract unique edges from triangles, keeping only silhouette/boundary edges
        var edgeTriCount: [EdgeKey: Int] = [:]
        var edgePairs: [EdgeKey: (UInt32, UInt32)] = [:]

        for tri in mesh.triangles {
            let edges: [(UInt32, UInt32)] = [
                (tri.0, tri.1), (tri.1, tri.2), (tri.0, tri.2)
            ]
            for (a, b) in edges {
                let key = EdgeKey(a: min(a, b), b: max(a, b))
                edgeTriCount[key, default: 0] += 1
                edgePairs[key] = (min(a, b), max(a, b))
            }
        }

        // Include silhouette edges: boundary edges (count == 1) and edges where
        // adjacent face normals differ significantly in the projection direction
        var result: [Edge2D] = []
        let viewDir = viewDirection(view)

        for (key, count) in edgeTriCount {
            guard let pair = edgePairs[key] else { continue }
            let v0 = mesh.vertices[Int(pair.0)]
            let v1 = mesh.vertices[Int(pair.1)]

            let isSilhouette = count == 1 || isEdgeSilhouette(mesh: mesh, edge: pair, viewDir: viewDir)
            guard isSilhouette else { continue }

            let p0 = project(v0, view: view, scale: scale)
            let p1 = project(v1, view: view, scale: scale)

            // Skip degenerate (zero-length) edges
            let dx = p1.x - p0.x
            let dy = p1.y - p0.y
            guard dx * dx + dy * dy > 1e-8 else { continue }

            result.append(Edge2D(
                x1: p0.x + offsetX, y1: p0.y + offsetY,
                x2: p1.x + offsetX, y2: p1.y + offsetY
            ))
        }

        return result
    }

    private static func viewDirection(_ view: ProjectionView) -> SIMD3<Float> {
        switch view {
        case .front: return SIMD3<Float>(0, -1, 0)
        case .top:   return SIMD3<Float>(0, 0, -1)
        case .right: return SIMD3<Float>(-1, 0, 0)
        }
    }

    private static func project(_ point: SIMD3<Float>, view: ProjectionView, scale: Float) -> SIMD2<Float> {
        switch view {
        case .front: return SIMD2<Float>(point.x * scale, point.z * scale)
        case .top:   return SIMD2<Float>(point.x * scale, point.y * scale)
        case .right: return SIMD2<Float>(point.y * scale, point.z * scale)
        }
    }

    /// Check if an edge is a silhouette edge (adjacent faces have normals pointing
    /// in opposite directions relative to the view).
    private static func isEdgeSilhouette(mesh: TriangleMesh, edge: (UInt32, UInt32), viewDir: SIMD3<Float>) -> Bool {
        // Find the two triangles sharing this edge
        var faceNormals: [SIMD3<Float>] = []

        for tri in mesh.triangles {
            let triVerts = [tri.0, tri.1, tri.2]
            if triVerts.contains(edge.0) && triVerts.contains(edge.1) {
                let v0 = mesh.vertices[Int(tri.0)]
                let v1 = mesh.vertices[Int(tri.1)]
                let v2 = mesh.vertices[Int(tri.2)]
                let normal = simd_normalize(simd_cross(v1 - v0, v2 - v0))
                faceNormals.append(normal)
                if faceNormals.count >= 2 { break }
            }
        }

        guard faceNormals.count == 2 else { return true }

        let dot0 = simd_dot(faceNormals[0], viewDir)
        let dot1 = simd_dot(faceNormals[1], viewDir)

        // Silhouette: one face toward viewer, one away
        return (dot0 * dot1) <= 0
    }

    // MARK: - Dimension Annotations

    private static func dimensionAnnotations(_ mesh: TriangleMesh, scale: Float, margin: Float) -> [String] {
        let bb = mesh.boundingBox
        let size = bb.max - bb.min
        var lines: [String] = []

        // Width dimension (X) below front view
        let widthLabel = String(format: "%.1f", size.x)
        lines.append(contentsOf: dxfText(
            widthLabel,
            x: Float(size.x) * scale * 0.5,
            y: -margin * 0.3,
            layer: "DIMENSIONS",
            height: margin * 0.12
        ))

        // Height dimension (Z) to the left of front view
        let heightLabel = String(format: "%.1f", size.z)
        lines.append(contentsOf: dxfText(
            heightLabel,
            x: -margin * 0.4,
            y: Float(size.z) * scale * 0.5,
            layer: "DIMENSIONS",
            height: margin * 0.12
        ))

        // Depth dimension (Y) below top view
        let depthLabel = String(format: "%.1f", size.y)
        lines.append(contentsOf: dxfText(
            depthLabel,
            x: Float(size.x) * scale * 0.5,
            y: Float(size.z) * scale + margin + Float(size.y) * scale * 0.5,
            layer: "DIMENSIONS",
            height: margin * 0.12
        ))

        return lines
    }

    // MARK: - DXF Generation Helpers

    private static func emptyDXF() -> String {
        var lines: [String] = []
        lines.append(contentsOf: dxfHeader())
        lines.append("0")
        lines.append("SECTION")
        lines.append("2")
        lines.append("ENTITIES")
        lines.append("0")
        lines.append("ENDSEC")
        lines.append("0")
        lines.append("EOF")
        return lines.joined(separator: "\n")
    }

    private static func dxfHeader() -> [String] {
        [
            "0", "SECTION",
            "2", "HEADER",
            "9", "$ACADVER",
            "1", "AC1009",
            "9", "$INSUNITS",
            "70", "4",
            "0", "ENDSEC"
        ]
    }

    private static func dxfTables() -> [String] {
        [
            "0", "SECTION",
            "2", "TABLES",
            "0", "TABLE",
            "2", "LAYER",
            "70", "5",
            // Layer 0
            "0", "LAYER",
            "2", "0",
            "70", "0",
            "62", "7",
            "6", "CONTINUOUS",
            // Front view layer
            "0", "LAYER",
            "2", "FRONT",
            "70", "0",
            "62", "1",
            "6", "CONTINUOUS",
            // Top view layer
            "0", "LAYER",
            "2", "TOP",
            "70", "0",
            "62", "3",
            "6", "CONTINUOUS",
            // Right view layer
            "0", "LAYER",
            "2", "RIGHT",
            "70", "0",
            "62", "5",
            "6", "CONTINUOUS",
            // Labels layer
            "0", "LAYER",
            "2", "LABELS",
            "70", "0",
            "62", "7",
            "6", "CONTINUOUS",
            // Dimensions layer
            "0", "LAYER",
            "2", "DIMENSIONS",
            "70", "0",
            "62", "2",
            "6", "CONTINUOUS",
            "0", "ENDTAB",
            "0", "ENDSEC"
        ]
    }

    private static func dxfLine(_ edge: Edge2D, layer: String) -> [String] {
        [
            "0", "LINE",
            "8", layer,
            "10", formatDXF(edge.x1),
            "20", formatDXF(edge.y1),
            "30", "0.0",
            "11", formatDXF(edge.x2),
            "21", formatDXF(edge.y2),
            "31", "0.0"
        ]
    }

    private static func dxfText(_ text: String, x: Float, y: Float, layer: String, height: Float = 2.0) -> [String] {
        [
            "0", "TEXT",
            "8", layer,
            "10", formatDXF(x),
            "20", formatDXF(y),
            "30", "0.0",
            "40", formatDXF(height),
            "1", text
        ]
    }

    private static func formatDXF(_ value: Float) -> String {
        String(format: "%.6f", value)
    }
}
