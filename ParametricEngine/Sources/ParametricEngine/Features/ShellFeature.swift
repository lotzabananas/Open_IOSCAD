import Foundation

/// Hollows a solid by removing material from one face, leaving walls of specified thickness.
public struct ShellFeature: Feature, Sendable {
    public static let featureType: FeatureKind = .shell

    public let id: FeatureID
    public var name: String
    public var isSuppressed: Bool
    /// Wall thickness
    public var thickness: Double
    /// Which faces to open (remove). If empty, creates a fully enclosed thin shell.
    public var openFaceIndices: [Int]
    /// The feature to shell
    public var targetID: FeatureID

    public init(
        id: FeatureID = FeatureID(),
        name: String = "Shell",
        isSuppressed: Bool = false,
        thickness: Double = 1.0,
        openFaceIndices: [Int] = [],
        targetID: FeatureID
    ) {
        self.id = id
        self.name = name
        self.isSuppressed = isSuppressed
        self.thickness = thickness
        self.openFaceIndices = openFaceIndices
        self.targetID = targetID
    }
}
