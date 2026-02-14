import Foundation

/// Stable identifier for constraints.
public typealias ConstraintID = UUID

/// References a specific point on a sketch element.
public struct PointRef: Codable, Sendable, Hashable {
    public let elementID: ElementID
    public let position: PointPosition

    public init(elementID: ElementID, position: PointPosition) {
        self.elementID = elementID
        self.position = position
    }

    public enum PointPosition: String, Codable, Sendable, Hashable {
        /// Line segment start or arc start.
        case start
        /// Line segment end or arc end.
        case end
        /// Circle center or arc center.
        case center
        /// Rectangle bottom-left origin.
        case origin
    }
}

/// A geometric or dimensional constraint between sketch elements.
public enum SketchConstraint: Identifiable, Codable, Sendable, Hashable {

    // ── Geometric constraints (no dimension value) ──

    /// Two points coincide.
    case coincident(id: ConstraintID, point1: PointRef, point2: PointRef)
    /// A line segment is horizontal (start.y == end.y).
    case horizontal(id: ConstraintID, elementID: ElementID)
    /// A line segment is vertical (start.x == end.x).
    case vertical(id: ConstraintID, elementID: ElementID)
    /// Two line segments are parallel.
    case parallel(id: ConstraintID, element1: ElementID, element2: ElementID)
    /// Two line segments are perpendicular.
    case perpendicular(id: ConstraintID, element1: ElementID, element2: ElementID)
    /// A line is tangent to a circle or arc.
    case tangent(id: ConstraintID, element1: ElementID, element2: ElementID)
    /// Two elements have equal size (equal length for lines, equal radius for circles/arcs).
    case equal(id: ConstraintID, element1: ElementID, element2: ElementID)
    /// Two circles/arcs share the same center.
    case concentric(id: ConstraintID, element1: ElementID, element2: ElementID)

    // ── Dimensional constraints (with a value) ──

    /// Distance between two points equals `value`.
    case distance(id: ConstraintID, point1: PointRef, point2: PointRef, value: Double)
    /// Circle or arc radius equals `value`.
    case radius(id: ConstraintID, elementID: ElementID, value: Double)
    /// Angle between two line segments equals `value` (degrees).
    case angle(id: ConstraintID, element1: ElementID, element2: ElementID, value: Double)
    /// A point is locked at fixed coordinates.
    case fixedPoint(id: ConstraintID, point: PointRef, x: Double, y: Double)

    public var id: ConstraintID {
        switch self {
        case .coincident(let id, _, _): return id
        case .horizontal(let id, _): return id
        case .vertical(let id, _): return id
        case .parallel(let id, _, _): return id
        case .perpendicular(let id, _, _): return id
        case .tangent(let id, _, _): return id
        case .equal(let id, _, _): return id
        case .concentric(let id, _, _): return id
        case .distance(let id, _, _, _): return id
        case .radius(let id, _, _): return id
        case .angle(let id, _, _, _): return id
        case .fixedPoint(let id, _, _, _): return id
        }
    }

    /// Whether this constraint carries a user-editable dimension value.
    public var isDimensional: Bool {
        switch self {
        case .distance, .radius, .angle, .fixedPoint:
            return true
        default:
            return false
        }
    }

    /// Human-readable type name for UI.
    public var typeName: String {
        switch self {
        case .coincident: return "Coincident"
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        case .parallel: return "Parallel"
        case .perpendicular: return "Perpendicular"
        case .tangent: return "Tangent"
        case .equal: return "Equal"
        case .concentric: return "Concentric"
        case .distance: return "Distance"
        case .radius: return "Radius"
        case .angle: return "Angle"
        case .fixedPoint: return "Fixed"
        }
    }
}
