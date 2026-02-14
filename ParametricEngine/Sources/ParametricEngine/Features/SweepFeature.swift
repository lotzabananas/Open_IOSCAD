import Foundation

/// Sweeps a sketch profile along a path defined by another sketch.
public struct SweepFeature: Feature, Sendable {
    public static let featureType: FeatureKind = .sweep

    public let id: FeatureID
    public var name: String
    public var isSuppressed: Bool
    /// The sketch containing the cross-section profile
    public var profileSketchID: FeatureID
    /// The sketch containing the sweep path
    public var pathSketchID: FeatureID
    /// Twist angle in degrees over the sweep length
    public var twist: Double
    /// Scale factor at the end of the sweep (1.0 = no scale change)
    public var scaleEnd: Double
    /// Operation type (additive or subtractive)
    public var operation: ExtrudeFeature.Operation

    public init(
        id: FeatureID = FeatureID(),
        name: String = "Sweep",
        isSuppressed: Bool = false,
        profileSketchID: FeatureID,
        pathSketchID: FeatureID,
        twist: Double = 0,
        scaleEnd: Double = 1.0,
        operation: ExtrudeFeature.Operation = .additive
    ) {
        self.id = id
        self.name = name
        self.isSuppressed = isSuppressed
        self.profileSketchID = profileSketchID
        self.pathSketchID = pathSketchID
        self.twist = twist
        self.scaleEnd = scaleEnd
        self.operation = operation
    }
}
