import Foundation

/// Defines where a sketch lives in 3D space.
public enum SketchPlane: Codable, Sendable, Hashable {
    /// Global XY plane (Z=0), default for first sketch.
    case xy
    /// Global XZ plane (Y=0).
    case xz
    /// Global YZ plane (X=0).
    case yz
    /// Parallel to XY at a given Z offset.
    case offsetXY(distance: Double)
    /// On an existing face of another feature.
    case faceOf(featureID: FeatureID, faceIndex: Int)

    /// Human-readable description for UI display.
    public var displayName: String {
        switch self {
        case .xy: return "XY Plane"
        case .xz: return "XZ Plane"
        case .yz: return "YZ Plane"
        case .offsetXY(let d): return "XY + \(String(format: "%.1f", d))mm"
        case .faceOf(_, let idx): return "Face \(idx)"
        }
    }
}
