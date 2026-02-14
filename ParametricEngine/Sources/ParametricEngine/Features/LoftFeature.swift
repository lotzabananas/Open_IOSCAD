import Foundation

/// Creates a solid by blending between two or more sketch profiles at different heights.
public struct LoftFeature: Feature, Sendable {
    public static let featureType: FeatureKind = .loft

    public let id: FeatureID
    public var name: String
    public var isSuppressed: Bool
    /// Ordered list of sketch IDs defining the loft profiles (bottom to top)
    public var profileSketchIDs: [FeatureID]
    /// Heights corresponding to each profile sketch
    public var heights: [Double]
    /// Number of interpolation slices between each profile pair
    public var slicesPerSpan: Int
    /// Operation type
    public var operation: ExtrudeFeature.Operation

    public init(
        id: FeatureID = FeatureID(),
        name: String = "Loft",
        isSuppressed: Bool = false,
        profileSketchIDs: [FeatureID] = [],
        heights: [Double] = [],
        slicesPerSpan: Int = 4,
        operation: ExtrudeFeature.Operation = .additive
    ) {
        self.id = id
        self.name = name
        self.isSuppressed = isSuppressed
        self.profileSketchIDs = profileSketchIDs
        self.heights = heights
        self.slicesPerSpan = slicesPerSpan
        self.operation = operation
    }
}
