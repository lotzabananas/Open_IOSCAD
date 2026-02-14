import Foundation

/// Repeats a feature in a pattern (linear, circular, or mirror).
public struct PatternFeature: Feature, Sendable {
    public static let featureType: FeatureKind = .pattern

    public let id: FeatureID
    public var name: String
    public var isSuppressed: Bool
    /// The type of pattern
    public var patternType: PatternKind
    /// The feature to repeat
    public var sourceID: FeatureID

    // Linear pattern parameters
    /// Direction vector for linear pattern
    public var directionX: Double
    public var directionY: Double
    public var directionZ: Double
    /// Number of copies (including original)
    public var count: Int
    /// Spacing between copies
    public var spacing: Double

    // Circular pattern parameters
    /// Axis of rotation for circular pattern
    public var axisX: Double
    public var axisY: Double
    public var axisZ: Double
    /// Total angle span for circular pattern (degrees)
    public var totalAngle: Double
    /// Whether to space evenly across totalAngle
    public var equalSpacing: Bool

    // Mirror pattern parameters (uses directionX/Y/Z as mirror plane normal)

    public enum PatternKind: String, Codable, Sendable {
        case linear
        case circular
        case mirror
    }

    public var direction: SIMD3<Double> {
        get { SIMD3<Double>(directionX, directionY, directionZ) }
        set { directionX = newValue.x; directionY = newValue.y; directionZ = newValue.z }
    }

    public var axis: SIMD3<Double> {
        get { SIMD3<Double>(axisX, axisY, axisZ) }
        set { axisX = newValue.x; axisY = newValue.y; axisZ = newValue.z }
    }

    public init(
        id: FeatureID = FeatureID(),
        name: String = "Pattern",
        isSuppressed: Bool = false,
        patternType: PatternKind = .linear,
        sourceID: FeatureID,
        direction: SIMD3<Double> = SIMD3<Double>(1, 0, 0),
        count: Int = 3,
        spacing: Double = 10.0,
        axis: SIMD3<Double> = SIMD3<Double>(0, 0, 1),
        totalAngle: Double = 360.0,
        equalSpacing: Bool = true
    ) {
        self.id = id
        self.name = name
        self.isSuppressed = isSuppressed
        self.patternType = patternType
        self.sourceID = sourceID
        self.directionX = direction.x
        self.directionY = direction.y
        self.directionZ = direction.z
        self.count = count
        self.spacing = spacing
        self.axisX = axis.x
        self.axisY = axis.y
        self.axisZ = axis.z
        self.totalAngle = totalAngle
        self.equalSpacing = equalSpacing
    }
}
