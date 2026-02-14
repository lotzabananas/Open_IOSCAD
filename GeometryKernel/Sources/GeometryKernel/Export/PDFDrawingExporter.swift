import Foundation
import simd
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if canImport(CoreGraphics)
import CoreGraphics
import CoreText
#endif

/// Exports a TriangleMesh as a 2D technical drawing PDF.
/// Produces three orthographic views in standard third-angle projection
/// with dimension annotations and a title block.
public enum PDFDrawingExporter {

    /// Paper size for the drawing.
    public enum PaperSize: Sendable {
        case a4Landscape
        case a4Portrait
        case letterLandscape
        case letterPortrait

        var width: CGFloat {
            switch self {
            case .a4Landscape: return 841.89  // 297mm in points
            case .a4Portrait: return 595.28   // 210mm in points
            case .letterLandscape: return 792
            case .letterPortrait: return 612
            }
        }

        var height: CGFloat {
            switch self {
            case .a4Landscape: return 595.28
            case .a4Portrait: return 841.89
            case .letterLandscape: return 612
            case .letterPortrait: return 792
            }
        }
    }

    /// Export a mesh as a multi-view technical drawing PDF.
    public static func export(
        _ mesh: TriangleMesh,
        paperSize: PaperSize = .a4Landscape,
        title: String = "OpeniOSCAD Drawing",
        modelName: String = "Part"
    ) -> Data? {
        guard !mesh.isEmpty else { return nil }

        let pageWidth = paperSize.width
        let pageHeight = paperSize.height
        let margin: CGFloat = 40
        let titleBlockHeight: CGFloat = 50

        let drawableWidth = pageWidth - 2 * margin
        let drawableHeight = pageHeight - 2 * margin - titleBlockHeight

        // Compute model bounds and scale
        let bb = mesh.boundingBox
        let size = SIMD3<Float>(bb.max.x - bb.min.x, bb.max.y - bb.min.y, bb.max.z - bb.min.z)

        // Layout: front (bottom-left), top (top-left), right (bottom-right)
        // Each view gets roughly half the drawable area
        let viewWidth = drawableWidth * 0.45
        let viewHeight = drawableHeight * 0.45
        let _ = drawableWidth * 0.05 // gap between views

        // Scale to fit the largest dimension in each view
        let frontScale = fitScale(width: CGFloat(size.x), height: CGFloat(size.z), viewW: viewWidth, viewH: viewHeight)
        let topScale = fitScale(width: CGFloat(size.x), height: CGFloat(size.y), viewW: viewWidth, viewH: viewHeight)
        let rightScale = fitScale(width: CGFloat(size.y), height: CGFloat(size.z), viewW: viewWidth, viewH: viewHeight)
        let scale = min(frontScale, topScale, rightScale)

        // Create PDF data
        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        context.beginPage(mediaBox: &mediaBox)

        // Background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(mediaBox)

        // Drawing border
        context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(1.0)
        context.stroke(CGRect(
            x: margin - 5, y: margin + titleBlockHeight - 5,
            width: drawableWidth + 10, height: drawableHeight + 10
        ))

        // --- Front View (bottom-left) ---
        let frontOriginX = margin + viewWidth * 0.1
        let frontOriginY = margin + titleBlockHeight + viewHeight * 0.1

        drawViewLabel(context, "FRONT", x: frontOriginX, y: frontOriginY - 15)
        drawProjectedEdges(
            context, mesh: mesh, view: .front,
            originX: frontOriginX, originY: frontOriginY,
            scale: CGFloat(scale), bb: bb
        )
        drawBoundingDimensions(
            context, label: String(format: "%.1f", size.x),
            x: frontOriginX, y: frontOriginY - 8,
            width: CGFloat(size.x) * CGFloat(scale)
        )

        // --- Top View (top-left) ---
        let topOriginX = margin + viewWidth * 0.1
        let topOriginY = margin + titleBlockHeight + drawableHeight * 0.55

        drawViewLabel(context, "TOP", x: topOriginX, y: topOriginY - 15)
        drawProjectedEdges(
            context, mesh: mesh, view: .top,
            originX: topOriginX, originY: topOriginY,
            scale: CGFloat(scale), bb: bb
        )

        // --- Right View (bottom-right) ---
        let rightOriginX = margin + drawableWidth * 0.55
        let rightOriginY = margin + titleBlockHeight + viewHeight * 0.1

        drawViewLabel(context, "RIGHT", x: rightOriginX, y: rightOriginY - 15)
        drawProjectedEdges(
            context, mesh: mesh, view: .right,
            originX: rightOriginX, originY: rightOriginY,
            scale: CGFloat(scale), bb: bb
        )

        // --- Title Block ---
        drawTitleBlock(context, title: title, modelName: modelName,
                      x: margin, y: margin,
                      width: drawableWidth, height: titleBlockHeight)

        context.endPage()
        context.closePDF()

        return pdfData as Data
    }

    // MARK: - Projection

    private enum ViewDirection {
        case front, top, right
    }

    private static func project(_ point: SIMD3<Float>, view: ViewDirection) -> CGPoint {
        switch view {
        case .front: return CGPoint(x: CGFloat(point.x), y: CGFloat(point.z))
        case .top:   return CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
        case .right: return CGPoint(x: CGFloat(point.y), y: CGFloat(point.z))
        }
    }

    private static func viewDir(_ view: ViewDirection) -> SIMD3<Float> {
        switch view {
        case .front: return SIMD3<Float>(0, -1, 0)
        case .top:   return SIMD3<Float>(0, 0, -1)
        case .right: return SIMD3<Float>(-1, 0, 0)
        }
    }

    // MARK: - Drawing Helpers

    private static func drawProjectedEdges(
        _ ctx: CGContext,
        mesh: TriangleMesh,
        view: ViewDirection,
        originX: CGFloat,
        originY: CGFloat,
        scale: CGFloat,
        bb: (min: SIMD3<Float>, max: SIMD3<Float>)
    ) {
        let dir = viewDir(view)

        // Build edge adjacency
        var edgeTriCount: [EdgeKey: Int] = [:]
        var edgePairs: [EdgeKey: (UInt32, UInt32)] = [:]

        for tri in mesh.triangles {
            let pairs: [(UInt32, UInt32)] = [
                (tri.0, tri.1), (tri.1, tri.2), (tri.0, tri.2)
            ]
            for (a, b) in pairs {
                let key = EdgeKey(a: min(a, b), b: max(a, b))
                edgeTriCount[key, default: 0] += 1
                edgePairs[key] = (min(a, b), max(a, b))
            }
        }

        ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.setLineWidth(0.5)

        for (key, count) in edgeTriCount {
            guard let pair = edgePairs[key] else { continue }

            let isSilhouette = count == 1 || isSilhouetteEdge(mesh: mesh, edge: pair, viewDir: dir)
            guard isSilhouette else { continue }

            let v0 = mesh.vertices[Int(pair.0)]
            let v1 = mesh.vertices[Int(pair.1)]

            // Project to 2D, centered on bounding box
            let p0 = project(v0 - bb.min, view: view)
            let p1 = project(v1 - bb.min, view: view)

            let x0 = originX + p0.x * scale
            let y0 = originY + p0.y * scale
            let x1 = originX + p1.x * scale
            let y1 = originY + p1.y * scale

            // Skip degenerate
            let dx = x1 - x0
            let dy = y1 - y0
            guard dx * dx + dy * dy > 0.01 else { continue }

            ctx.move(to: CGPoint(x: x0, y: y0))
            ctx.addLine(to: CGPoint(x: x1, y: y1))
        }

        ctx.strokePath()
    }

    private static func isSilhouetteEdge(
        mesh: TriangleMesh,
        edge: (UInt32, UInt32),
        viewDir: SIMD3<Float>
    ) -> Bool {
        var normals: [SIMD3<Float>] = []

        for tri in mesh.triangles {
            let verts = [tri.0, tri.1, tri.2]
            if verts.contains(edge.0) && verts.contains(edge.1) {
                let v0 = mesh.vertices[Int(tri.0)]
                let v1 = mesh.vertices[Int(tri.1)]
                let v2 = mesh.vertices[Int(tri.2)]
                let n = simd_normalize(simd_cross(v1 - v0, v2 - v0))
                normals.append(n)
                if normals.count >= 2 { break }
            }
        }

        guard normals.count == 2 else { return true }
        return (simd_dot(normals[0], viewDir) * simd_dot(normals[1], viewDir)) <= 0
    }

    // MARK: - Text & Labels

    private static func drawViewLabel(_ ctx: CGContext, _ text: String, x: CGFloat, y: CGFloat) {
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 10, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)

        ctx.saveGState()
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    private static func drawBoundingDimensions(
        _ ctx: CGContext,
        label: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) {
        // Dimension line with arrows
        ctx.setStrokeColor(CGColor(red: 0.2, green: 0.2, blue: 0.8, alpha: 1))
        ctx.setLineWidth(0.3)

        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + width, y: y))
        ctx.strokePath()

        // Label
        let font = CTFontCreateWithName("Helvetica" as CFString, 7, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0.2, green: 0.2, blue: 0.8, alpha: 1)
        ]
        let attrString = NSAttributedString(string: label, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)

        ctx.saveGState()
        ctx.textPosition = CGPoint(x: x + width * 0.4, y: y + 2)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    private static func drawTitleBlock(
        _ ctx: CGContext,
        title: String,
        modelName: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) {
        // Border
        ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.setLineWidth(1.0)
        ctx.stroke(CGRect(x: x, y: y, width: width, height: height))

        // Title text
        let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 14, nil)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]
        let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
        let titleLine = CTLineCreateWithAttributedString(titleStr)

        ctx.saveGState()
        ctx.textPosition = CGPoint(x: x + 10, y: y + height - 20)
        CTLineDraw(titleLine, ctx)
        ctx.restoreGState()

        // Model name + date
        let infoFont = CTFontCreateWithName("Helvetica" as CFString, 9, nil)
        let infoAttrs: [NSAttributedString.Key: Any] = [
            .font: infoFont,
            .foregroundColor: CGColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateString = dateFormatter.string(from: Date())
        let infoStr = NSAttributedString(string: "Model: \(modelName)  |  Date: \(dateString)  |  Generated by OpeniOSCAD", attributes: infoAttrs)
        let infoLine = CTLineCreateWithAttributedString(infoStr)

        ctx.saveGState()
        ctx.textPosition = CGPoint(x: x + 10, y: y + 8)
        CTLineDraw(infoLine, ctx)
        ctx.restoreGState()
    }

    // MARK: - Utility

    private static func fitScale(width: CGFloat, height: CGFloat, viewW: CGFloat, viewH: CGFloat) -> Float {
        guard width > 0 && height > 0 else { return 1.0 }
        let scaleX = viewW / width
        let scaleY = viewH / height
        return Float(min(scaleX, scaleY))
    }
}
