import Foundation

/// Revolves a sketch profile around an axis to create 3D geometry.
/// Uses the GeometryKernel's RotateExtrudeOperation under the hood.
public struct RevolveFeature: Feature, Sendable {
    public static let featureType: FeatureKind = .revolve

    public let id: FeatureID
    public var name: String
    public var isSuppressed: Bool
    public var sketchID: FeatureID
    public var angle: Double        // degrees, 0 < angle <= 360
    public var operation: Operation

    public enum Operation: String, Codable, Sendable {
        case additive    // Union with existing geometry
        case subtractive // Subtract from existing geometry
    }

    public init(
        id: FeatureID = FeatureID(),
        name: String = "Revolve",
        isSuppressed: Bool = false,
        sketchID: FeatureID,
        angle: Double = 360.0,
        operation: Operation = .additive
    ) {
        self.id = id
        self.name = name
        self.isSuppressed = isSuppressed
        self.sketchID = sketchID
        self.angle = angle
        self.operation = operation
    }
}
