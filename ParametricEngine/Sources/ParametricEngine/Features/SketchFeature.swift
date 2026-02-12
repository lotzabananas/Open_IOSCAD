import Foundation

/// A 2D sketch on a plane or face.
/// Contains positioned geometric elements and (Phase 1: empty) constraints.
public struct SketchFeature: Feature, Sendable {
    public static let featureType: FeatureKind = .sketch

    public let id: FeatureID
    public var name: String
    public var isSuppressed: Bool
    public var plane: SketchPlane
    public var elements: [SketchElement]
    public var constraints: [SketchConstraint]

    public init(
        id: FeatureID = FeatureID(),
        name: String = "Sketch",
        isSuppressed: Bool = false,
        plane: SketchPlane = .xy,
        elements: [SketchElement] = [],
        constraints: [SketchConstraint] = []
    ) {
        self.id = id
        self.name = name
        self.isSuppressed = isSuppressed
        self.plane = plane
        self.elements = elements
        self.constraints = constraints
    }

    /// Create a rectangle sketch on XY centered at origin for convenience commands.
    public static func rectangleOnXY(
        width: Double,
        depth: Double,
        name: String = "Sketch"
    ) -> SketchFeature {
        let origin = Point2D(x: -width / 2, y: -depth / 2)
        let element = SketchElement.rectangle(
            id: ElementID(),
            origin: origin,
            width: width,
            height: depth
        )
        return SketchFeature(
            name: name,
            plane: .xy,
            elements: [element]
        )
    }

    /// Create a circle sketch on XY centered at origin for convenience commands.
    public static func circleOnXY(
        radius: Double,
        name: String = "Sketch"
    ) -> SketchFeature {
        let element = SketchElement.circle(
            id: ElementID(),
            center: Point2D(x: 0, y: 0),
            radius: radius
        )
        return SketchFeature(
            name: name,
            plane: .xy,
            elements: [element]
        )
    }
}
