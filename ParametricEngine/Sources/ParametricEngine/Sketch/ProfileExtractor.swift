import Foundation
import GeometryKernel

/// Converts SketchElements into Polygon2D for extrusion by GeometryKernel.
public enum ProfileExtractor {

    /// Number of segments to approximate a circle.
    private static let circleSegments = 32

    /// Extract a Polygon2D from an array of sketch elements.
    /// For Phase 1, handles single-element profiles: rectangle, circle,
    /// and closed line-segment chains.
    public static func extractProfile(from elements: [SketchElement]) -> Result<Polygon2D, ProfileError> {
        guard !elements.isEmpty else {
            return .failure(.emptySketch)
        }

        // Single element cases
        if elements.count == 1 {
            return extractSingleElement(elements[0])
        }

        // Multiple elements: try to form a closed line-segment chain
        let lineSegments = elements.compactMap { element -> (Point2D, Point2D)? in
            if case .lineSegment(_, let start, let end) = element {
                return (start, end)
            }
            return nil
        }

        if lineSegments.count == elements.count && lineSegments.count >= 3 {
            return extractClosedLineChain(lineSegments)
        }

        // Multiple non-line elements: extract first element as profile
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

    // MARK: - Closed Line Chain

    private static func extractClosedLineChain(_ segments: [(Point2D, Point2D)]) -> Result<Polygon2D, ProfileError> {
        // Build an ordered point list from connected segments.
        var remaining = segments
        var orderedPoints: [Point2D] = []

        guard let first = remaining.first else {
            return .failure(.emptySketch)
        }
        orderedPoints.append(first.0)
        orderedPoints.append(first.1)
        remaining.removeFirst()

        let tolerance = 1e-4

        while !remaining.isEmpty {
            let currentEnd = orderedPoints.last!
            var found = false

            for (i, seg) in remaining.enumerated() {
                if distance(currentEnd, seg.0) < tolerance {
                    orderedPoints.append(seg.1)
                    remaining.remove(at: i)
                    found = true
                    break
                } else if distance(currentEnd, seg.1) < tolerance {
                    orderedPoints.append(seg.0)
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
            orderedPoints.removeLast() // Remove duplicate closing point
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
