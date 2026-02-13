import Foundation
import GeometryKernel

/// Converts SketchElements into Polygon2D for extrusion by GeometryKernel.
public enum ProfileExtractor {

    /// Number of segments to approximate a circle.
    private static let circleSegments = 32

    /// Number of segments per 90 degrees for arc tessellation.
    private static let arcSegmentsPer90 = 8

    /// Extract a Polygon2D from an array of sketch elements.
    /// Handles single-element profiles, closed chains of lines and arcs,
    /// and falls back to the first element for mixed cases.
    public static func extractProfile(from elements: [SketchElement]) -> Result<Polygon2D, ProfileError> {
        guard !elements.isEmpty else {
            return .failure(.emptySketch)
        }

        // Single element cases
        if elements.count == 1 {
            return extractSingleElement(elements[0])
        }

        // Multiple elements: try to form a closed chain of lines and arcs
        let chainable = elements.allSatisfy { element in
            switch element {
            case .lineSegment, .arc: return true
            default: return false
            }
        }

        if chainable && elements.count >= 2 {
            return extractClosedChain(elements)
        }

        // Multiple non-chainable elements: extract first element as profile
        return extractSingleElement(elements[0])
    }

    // MARK: - Single Element

    private static func extractSingleElement(_ element: SketchElement) -> Result<Polygon2D, ProfileError> {
        switch element {
        case .rectangle(_, let origin, let width, let height):
            return extractRectangle(origin: origin, width: width, height: height)
        case .circle(_, let center, let radius):
            return extractCircle(center: center, radius: radius)
        case .lineSegment:
            return .failure(.openProfile)
        case .arc:
            return .failure(.openProfile) // A single arc is not a closed profile
        }
    }

    // MARK: - Rectangle

    private static func extractRectangle(origin: Point2D, width: Double, height: Double) -> Result<Polygon2D, ProfileError> {
        guard width > 0, height > 0 else {
            return .failure(.invalidDimensions("Rectangle width and height must be positive"))
        }

        let points: [SIMD2<Float>] = [
            SIMD2(Float(origin.x), Float(origin.y)),
            SIMD2(Float(origin.x + width), Float(origin.y)),
            SIMD2(Float(origin.x + width), Float(origin.y + height)),
            SIMD2(Float(origin.x), Float(origin.y + height)),
        ]

        var polygon = Polygon2D(points: points)
        polygon.ensureCounterClockwise()
        return .success(polygon)
    }

    // MARK: - Circle

    private static func extractCircle(center: Point2D, radius: Double) -> Result<Polygon2D, ProfileError> {
        guard radius > 0 else {
            return .failure(.invalidDimensions("Circle radius must be positive"))
        }

        var points: [SIMD2<Float>] = []
        for i in 0..<circleSegments {
            let angle = Double(i) / Double(circleSegments) * 2.0 * .pi
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            points.append(SIMD2(Float(x), Float(y)))
        }

        var polygon = Polygon2D(points: points)
        polygon.ensureCounterClockwise()
        return .success(polygon)
    }

    // MARK: - Closed Chain (lines + arcs)

    /// Build an ordered point list from a closed chain of line segments and arcs.
    private static func extractClosedChain(_ elements: [SketchElement]) -> Result<Polygon2D, ProfileError> {
        // Build (start, end, tessellatedPoints) for each element
        struct ChainSegment {
            let start: Point2D
            let end: Point2D
            /// Interior points (excluding start, including end).
            let points: [Point2D]
        }

        var remaining: [ChainSegment] = elements.compactMap { element in
            switch element {
            case .lineSegment(_, let s, let e):
                return ChainSegment(start: s, end: e, points: [e])
            case .arc(_, let center, let radius, let startAngle, let sweepAngle):
                guard radius > 0, abs(sweepAngle) > 0 else { return nil }
                let segments = max(2, Int(abs(sweepAngle) / 90.0 * Double(arcSegmentsPer90)))
                var pts: [Point2D] = []
                for i in 1...segments {
                    let frac = Double(i) / Double(segments)
                    let angle = (startAngle + sweepAngle * frac) * .pi / 180
                    pts.append(Point2D(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
                }
                let startRad = startAngle * .pi / 180
                let s = Point2D(x: center.x + radius * cos(startRad), y: center.y + radius * sin(startRad))
                let e = pts.last ?? s
                return ChainSegment(start: s, end: e, points: pts)
            default:
                return nil
            }
        }

        guard !remaining.isEmpty else { return .failure(.emptySketch) }

        // Chain segments together
        var orderedPoints: [Point2D] = []
        let first = remaining.removeFirst()
        orderedPoints.append(first.start)
        orderedPoints.append(contentsOf: first.points)

        let tolerance = 1e-4

        while !remaining.isEmpty {
            let currentEnd = orderedPoints.last!
            var found = false

            for (i, seg) in remaining.enumerated() {
                if distance(currentEnd, seg.start) < tolerance {
                    orderedPoints.append(contentsOf: seg.points)
                    remaining.remove(at: i)
                    found = true
                    break
                } else if distance(currentEnd, seg.end) < tolerance {
                    // Reverse: add points from end to start
                    // seg.points excludes start, includes end.
                    // Reversed: [end, ..., second_point]. First element (end) == currentEnd, drop it.
                    let reversed = Array(seg.points.reversed())
                    orderedPoints.append(contentsOf: reversed.dropFirst())
                    orderedPoints.append(seg.start)
                    remaining.remove(at: i)
                    found = true
                    break
                }
            }

            if !found {
                return .failure(.openProfile)
            }
        }

        // Check closure
        guard orderedPoints.count >= 3 else {
            return .failure(.openProfile)
        }

        let first2D = orderedPoints.first!
        let last2D = orderedPoints.last!
        if distance(first2D, last2D) < tolerance {
            orderedPoints.removeLast()
        }

        guard orderedPoints.count >= 3 else {
            return .failure(.openProfile)
        }

        let points = orderedPoints.map { SIMD2<Float>(Float($0.x), Float($0.y)) }
        var polygon = Polygon2D(points: points)
        polygon.ensureCounterClockwise()
        return .success(polygon)
    }

    private static func distance(_ a: Point2D, _ b: Point2D) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// Errors that can occur during profile extraction.
public enum ProfileError: Error, Sendable {
    case emptySketch
    case openProfile
    case invalidDimensions(String)
}
