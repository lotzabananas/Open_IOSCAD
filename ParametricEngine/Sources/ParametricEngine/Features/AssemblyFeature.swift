import Foundation

/// Represents a multi-body assembly grouping.
/// An assembly groups features into independent "bodies" within a single model file.
/// Each body is evaluated independently and the results are merged for display.
///
/// Use cases:
/// - Multi-part assemblies (e.g., lid + base of an enclosure)
/// - Bodies that can be exported separately for 3D printing
/// - Logical grouping for bill-of-materials
public struct AssemblyFeature: Feature, Sendable {
    public static let featureType: FeatureKind = .assembly

    public let id: FeatureID
    public var name: String
    public var isSuppressed: Bool

    /// IDs of features that belong to this body/assembly group.
    /// Features not claimed by any assembly are considered the "default body."
    public var memberFeatureIDs: [FeatureID]

    /// Display color for this body (RGBA, 0–1 range).
    public var color: [Double]

    /// Optional transform to position this body relative to the assembly origin.
    public var positionX: Double
    public var positionY: Double
    public var positionZ: Double

    /// Optional rotation (Euler angles in degrees).
    public var rotationX: Double
    public var rotationY: Double
    public var rotationZ: Double

    public init(
        id: FeatureID = UUID(),
        name: String = "Assembly",
        isSuppressed: Bool = false,
        memberFeatureIDs: [FeatureID] = [],
        color: [Double] = [0.7, 0.7, 0.7, 1.0],
        positionX: Double = 0,
        positionY: Double = 0,
        positionZ: Double = 0,
        rotationX: Double = 0,
        rotationY: Double = 0,
        rotationZ: Double = 0
    ) {
        self.id = id
        self.name = name
        self.isSuppressed = isSuppressed
        self.memberFeatureIDs = memberFeatureIDs
        self.color = color
        self.positionX = positionX
        self.positionY = positionY
        self.positionZ = positionZ
        self.rotationX = rotationX
        self.rotationY = rotationY
        self.rotationZ = rotationZ
    }
}
