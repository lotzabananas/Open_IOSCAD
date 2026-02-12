import Foundation

/// Extrudes a sketch profile into 3D geometry.
/// Can add material (boss/pad) or subtract it (cut/pocket).
public struct ExtrudeFeature: Feature, Sendable {
    public static let featureType: FeatureKind = .extrude

    public let id: FeatureID
    public var name: String
    public var isSuppressed: Bool
    public var sketchID: FeatureID
    public var depth: Double
    public var operation: Operation

    public enum Operation: String, Codable, Sendable {
        case additive    // Union with existing geometry (boss/pad)
        case subtractive // Subtract from existing geometry (cut/pocket)
    }

    public init(
        id: FeatureID = FeatureID(),
        name: String = "Extrude",
        isSuppressed: Bool = false,
        sketchID: FeatureID,
        depth: Double = 10.0,
        operation: Operation = .additive
    ) {
        self.id = id
        self.name = name
        self.isSuppressed = isSuppressed
        self.sketchID = sketchID
        self.depth = depth
        self.operation = operation
    }
}
