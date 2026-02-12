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

    public var id: ElementID {
        switch self {
        case .rectangle(let id, _, _, _): return id
        case .circle(let id, _, _): return id
        case .lineSegment(let id, _, _): return id
        }
    }

    /// Human-readable type name for UI.
    public var typeName: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .lineSegment: return "Line"
        }
    }
}

/// Placeholder for future constraint solver (Phase 2).
public enum SketchConstraint: Codable, Sendable, Hashable {
    // Phase 1: empty. Constraints arrive in Phase 2.
}
