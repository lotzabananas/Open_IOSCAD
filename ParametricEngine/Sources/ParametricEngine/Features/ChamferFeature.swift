import Foundation

/// Applies a chamfer (angled cut) to edges of the model.
public struct ChamferFeature: Feature, Sendable {
    public static let featureType: FeatureKind = .chamfer

    public let id: FeatureID
    public var name: String
    public var isSuppressed: Bool
    /// The distance of the chamfer from the edge
    public var distance: Double
    /// Which edges to chamfer. Empty means all edges of the target feature.
    public var edgeIndices: [Int]
    /// The feature whose edges are chamfered
    public var targetID: FeatureID

    public init(
        id: FeatureID = FeatureID(),
        name: String = "Chamfer",
        isSuppressed: Bool = false,
        distance: Double = 1.0,
        edgeIndices: [Int] = [],
        targetID: FeatureID
    ) {
        self.id = id
        self.name = name
        self.isSuppressed = isSuppressed
        self.distance = distance
        self.edgeIndices = edgeIndices
        self.targetID = targetID
    }
}
