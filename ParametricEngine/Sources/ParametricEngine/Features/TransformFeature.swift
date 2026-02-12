import Foundation

/// Applies a spatial transform (translate, rotate, scale, mirror) to geometry
/// produced by a target feature.
public struct TransformFeature: Feature, Sendable {
    public static let featureType: FeatureKind = .transform

    public let id: FeatureID
    public var name: String
    public var isSuppressed: Bool
    public var transformType: TransformKind
    public var vectorX: Double
    public var vectorY: Double
    public var vectorZ: Double
    public var angle: Double
    public var axisX: Double
    public var axisY: Double
    public var axisZ: Double
    public var targetID: FeatureID

    public enum TransformKind: String, Codable, Sendable {
        case translate
        case rotate
        case scale
        case mirror
    }

    public var vector: SIMD3<Double> {
        get { SIMD3<Double>(vectorX, vectorY, vectorZ) }
        set { vectorX = newValue.x; vectorY = newValue.y; vectorZ = newValue.z }
    }

    public var axis: SIMD3<Double> {
        get { SIMD3<Double>(axisX, axisY, axisZ) }
        set { axisX = newValue.x; axisY = newValue.y; axisZ = newValue.z }
    }

    public init(
        id: FeatureID = FeatureID(),
        name: String = "Transform",
        isSuppressed: Bool = false,
        transformType: TransformKind = .translate,
        vector: SIMD3<Double> = .zero,
        angle: Double = 0,
        axis: SIMD3<Double> = SIMD3<Double>(0, 0, 1),
        targetID: FeatureID
    ) {
        self.id = id
        self.name = name
        self.isSuppressed = isSuppressed
        self.transformType = transformType
        self.vectorX = vector.x
        self.vectorY = vector.y
        self.vectorZ = vector.z
        self.angle = angle
        self.axisX = axis.x
        self.axisY = axis.y
        self.axisZ = axis.z
        self.targetID = targetID
    }
}

