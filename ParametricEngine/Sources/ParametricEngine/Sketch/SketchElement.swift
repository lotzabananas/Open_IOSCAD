import Foundation

/// A 2D point in sketch-local coordinates.
public struct Point2D: Codable, Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A 2D geometric element in a sketch's local coordinate system.
public enum SketchElement: Identifiable, Codable, Sendable, Hashable {
    case rectangle(id: ElementID, origin: Point2D, width: Double, height: Double)
    case circle(id: ElementID, center: Point2D, radius: Double)
    case lineSegment(id: ElementID, start: Point2D, end: Point2D)
    /// Circular arc defined by center, radius, start angle, and sweep angle (degrees).
    /// startAngle: 0 = +X, counter-clockwise positive.
    /// sweepAngle: positive = counter-clockwise.
    case arc(id: ElementID, center: Point2D, radius: Double, startAngle: Double, sweepAngle: Double)

    public var id: ElementID {
        switch self {
        case .rectangle(let id, _, _, _): return id
        case .circle(let id, _, _): return id
        case .lineSegment(let id, _, _): return id
        case .arc(let id, _, _, _, _): return id
        }
    }

    /// Human-readable type name for UI.
    public var typeName: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .lineSegment: return "Line"
        case .arc: return "Arc"
        }
    }

    /// Start point of the element (for chaining and constraint references).
    public var startPoint: Point2D? {
        switch self {
        case .lineSegment(_, let start, _):
            return start
        case .arc(_, let center, let radius, let startAngle, _):
            let rad = startAngle * .pi / 180
            return Point2D(x: center.x + radius * cos(rad), y: center.y + radius * sin(rad))
        default:
            return nil
        }
    }

    /// End point of the element (for chaining and constraint references).
    public var endPoint: Point2D? {
        switch self {
        case .lineSegment(_, _, let end):
            return end
        case .arc(_, let center, let radius, let startAngle, let sweepAngle):
            let rad = (startAngle + sweepAngle) * .pi / 180
            return Point2D(x: center.x + radius * cos(rad), y: center.y + radius * sin(rad))
        default:
            return nil
        }
    }
}
