import Foundation

/// Stable identifier for features, survives reorder/undo/serialization.
public typealias FeatureID = UUID

/// Stable identifier for sketch elements.
public typealias ElementID = UUID

/// Protocol that all parametric features conform to.
/// Features are the atomic units of the modeling history.
public protocol Feature: Identifiable, Codable, Sendable {
    var id: FeatureID { get }
    var name: String { get set }
    var isSuppressed: Bool { get set }

    /// Discriminator for polymorphic Codable decoding.
    static var featureType: FeatureKind { get }
}

/// Discriminator enum for polymorphic feature decoding.
public enum FeatureKind: String, Codable, Sendable, CaseIterable {
    case sketch
    case extrude
    case revolve
    case boolean
    case transform
    case fillet
    case chamfer
    case shell
    case pattern
    case sweep
    case loft
}

/// Type-erased wrapper for Feature, enabling heterogeneous collections
/// that remain Codable and Sendable.
public enum AnyFeature: Codable, Sendable, Identifiable {
    case sketch(SketchFeature)
    case extrude(ExtrudeFeature)
    case revolve(RevolveFeature)
    case boolean(BooleanFeature)
    case transform(TransformFeature)
    case fillet(FilletFeature)
    case chamfer(ChamferFeature)
    case shell(ShellFeature)
    case pattern(PatternFeature)
    case sweep(SweepFeature)
    case loft(LoftFeature)

    public var id: FeatureID {
        switch self {
        case .sketch(let f): return f.id
        case .extrude(let f): return f.id
        case .revolve(let f): return f.id
        case .boolean(let f): return f.id
        case .transform(let f): return f.id
        case .fillet(let f): return f.id
        case .chamfer(let f): return f.id
        case .shell(let f): return f.id
        case .pattern(let f): return f.id
        case .sweep(let f): return f.id
        case .loft(let f): return f.id
        }
    }

    public var name: String {
        get {
            switch self {
            case .sketch(let f): return f.name
            case .extrude(let f): return f.name
            case .revolve(let f): return f.name
            case .boolean(let f): return f.name
            case .transform(let f): return f.name
            case .fillet(let f): return f.name
            case .chamfer(let f): return f.name
            case .shell(let f): return f.name
            case .pattern(let f): return f.name
            case .sweep(let f): return f.name
            case .loft(let f): return f.name
            }
        }
        set {
            switch self {
            case .sketch(var f): f.name = newValue; self = .sketch(f)
            case .extrude(var f): f.name = newValue; self = .extrude(f)
            case .revolve(var f): f.name = newValue; self = .revolve(f)
            case .boolean(var f): f.name = newValue; self = .boolean(f)
            case .transform(var f): f.name = newValue; self = .transform(f)
            case .fillet(var f): f.name = newValue; self = .fillet(f)
            case .chamfer(var f): f.name = newValue; self = .chamfer(f)
            case .shell(var f): f.name = newValue; self = .shell(f)
            case .pattern(var f): f.name = newValue; self = .pattern(f)
            case .sweep(var f): f.name = newValue; self = .sweep(f)
            case .loft(var f): f.name = newValue; self = .loft(f)
            }
        }
    }

    public var isSuppressed: Bool {
        get {
            switch self {
            case .sketch(let f): return f.isSuppressed
            case .extrude(let f): return f.isSuppressed
            case .revolve(let f): return f.isSuppressed
            case .boolean(let f): return f.isSuppressed
            case .transform(let f): return f.isSuppressed
            case .fillet(let f): return f.isSuppressed
            case .chamfer(let f): return f.isSuppressed
            case .shell(let f): return f.isSuppressed
            case .pattern(let f): return f.isSuppressed
            case .sweep(let f): return f.isSuppressed
            case .loft(let f): return f.isSuppressed
            }
        }
        set {
            switch self {
            case .sketch(var f): f.isSuppressed = newValue; self = .sketch(f)
            case .extrude(var f): f.isSuppressed = newValue; self = .extrude(f)
            case .revolve(var f): f.isSuppressed = newValue; self = .revolve(f)
            case .boolean(var f): f.isSuppressed = newValue; self = .boolean(f)
            case .transform(var f): f.isSuppressed = newValue; self = .transform(f)
            case .fillet(var f): f.isSuppressed = newValue; self = .fillet(f)
            case .chamfer(var f): f.isSuppressed = newValue; self = .chamfer(f)
            case .shell(var f): f.isSuppressed = newValue; self = .shell(f)
            case .pattern(var f): f.isSuppressed = newValue; self = .pattern(f)
            case .sweep(var f): f.isSuppressed = newValue; self = .sweep(f)
            case .loft(var f): f.isSuppressed = newValue; self = .loft(f)
            }
        }
    }

    public var kind: FeatureKind {
        switch self {
        case .sketch: return .sketch
        case .extrude: return .extrude
        case .revolve: return .revolve
        case .boolean: return .boolean
        case .transform: return .transform
        case .fillet: return .fillet
        case .chamfer: return .chamfer
        case .shell: return .shell
        case .pattern: return .pattern
        case .sweep: return .sweep
        case .loft: return .loft
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(FeatureKind.self, forKey: .type)
        switch kind {
        case .sketch:
            self = .sketch(try SketchFeature(from: decoder))
        case .extrude:
            self = .extrude(try ExtrudeFeature(from: decoder))
        case .revolve:
            self = .revolve(try RevolveFeature(from: decoder))
        case .boolean:
            self = .boolean(try BooleanFeature(from: decoder))
        case .transform:
            self = .transform(try TransformFeature(from: decoder))
        case .fillet:
            self = .fillet(try FilletFeature(from: decoder))
        case .chamfer:
            self = .chamfer(try ChamferFeature(from: decoder))
        case .shell:
            self = .shell(try ShellFeature(from: decoder))
        case .pattern:
            self = .pattern(try PatternFeature(from: decoder))
        case .sweep:
            self = .sweep(try SweepFeature(from: decoder))
        case .loft:
            self = .loft(try LoftFeature(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sketch(let f):
            try container.encode(FeatureKind.sketch, forKey: .type)
            try f.encode(to: encoder)
        case .extrude(let f):
            try container.encode(FeatureKind.extrude, forKey: .type)
            try f.encode(to: encoder)
        case .revolve(let f):
            try container.encode(FeatureKind.revolve, forKey: .type)
            try f.encode(to: encoder)
        case .boolean(let f):
            try container.encode(FeatureKind.boolean, forKey: .type)
            try f.encode(to: encoder)
        case .transform(let f):
            try container.encode(FeatureKind.transform, forKey: .type)
            try f.encode(to: encoder)
        case .fillet(let f):
            try container.encode(FeatureKind.fillet, forKey: .type)
            try f.encode(to: encoder)
        case .chamfer(let f):
            try container.encode(FeatureKind.chamfer, forKey: .type)
            try f.encode(to: encoder)
        case .shell(let f):
            try container.encode(FeatureKind.shell, forKey: .type)
            try f.encode(to: encoder)
        case .pattern(let f):
            try container.encode(FeatureKind.pattern, forKey: .type)
            try f.encode(to: encoder)
        case .sweep(let f):
            try container.encode(FeatureKind.sweep, forKey: .type)
            try f.encode(to: encoder)
        case .loft(let f):
            try container.encode(FeatureKind.loft, forKey: .type)
            try f.encode(to: encoder)
        }
    }
}
