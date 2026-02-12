import Foundation

/// Combines separate bodies using boolean operations.
public struct BooleanFeature: Feature, Sendable {
    public static let featureType: FeatureKind = .boolean

    public let id: FeatureID
    public var name: String
    public var isSuppressed: Bool
    public var booleanType: BooleanOp
    public var targetIDs: [FeatureID]

    public enum BooleanOp: String, Codable, Sendable {
        case union
        case intersection
        case difference
    }

    public init(
        id: FeatureID = FeatureID(),
        name: String = "Boolean",
        isSuppressed: Bool = false,
        booleanType: BooleanOp = .union,
        targetIDs: [FeatureID] = []
    ) {
        self.id = id
        self.name = name
        self.isSuppressed = isSuppressed
        self.booleanType = booleanType
        self.targetIDs = targetIDs
    }
}
