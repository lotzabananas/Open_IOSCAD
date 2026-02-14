import Foundation

/// Applies a fillet (rounded edge) to edges of the model.
/// In mesh-based CSG, fillets are approximated by replacing sharp edges
/// with chamfer-like bevels or by inserting rounded geometry.
public struct FilletFeature: Feature, Sendable {
    public static let featureType: FeatureKind = .fillet

    public let id: FeatureID
    public var name: String
    public var isSuppressed: Bool
    /// The radius of the fillet
    public var radius: Double
    /// Which edges to fillet. Empty means all edges of the target feature.
    public var edgeIndices: [Int]
    /// The feature whose edges are filleted
    public var targetID: FeatureID

    public init(
        id: FeatureID = FeatureID(),
        name: String = "Fillet",
        isSuppressed: Bool = false,
        radius: Double = 2.0,
        edgeIndices: [Int] = [],
        targetID: FeatureID
    ) {
        self.id = id
        self.name = name
        self.isSuppressed = isSuppressed
        self.radius = radius
        self.edgeIndices = edgeIndices
        self.targetID = targetID
    }
}
