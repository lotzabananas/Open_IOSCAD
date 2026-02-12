import Foundation

/// Ordered container for the feature history.
/// This is the single source of truth for the model at runtime.
public struct FeatureTree: Codable, Sendable {
    public private(set) var features: [AnyFeature]

    public init(features: [AnyFeature] = []) {
        self.features = features
    }

    // MARK: - Query

    public var count: Int { features.count }
    public var isEmpty: Bool { features.isEmpty }

    public func feature(at index: Int) -> AnyFeature? {
        guard index >= 0, index < features.count else { return nil }
        return features[index]
    }

    public func feature(byID id: FeatureID) -> AnyFeature? {
        features.first { $0.id == id }
    }

    public func index(ofID id: FeatureID) -> Int? {
        features.firstIndex { $0.id == id }
    }

    /// All features that are not suppressed, in order.
    public var activeFeatures: [AnyFeature] {
        features.filter { !$0.isSuppressed }
    }

    // MARK: - Mutation

    public mutating func append(_ feature: AnyFeature) {
        features.append(feature)
    }

    public mutating func insert(_ feature: AnyFeature, at index: Int) {
        let clamped = min(max(index, 0), features.count)
        features.insert(feature, at: clamped)
    }

    public mutating func remove(at index: Int) {
        guard index >= 0, index < features.count else { return }
        features.remove(at: index)
    }

    public mutating func removeByID(_ id: FeatureID) {
        features.removeAll { $0.id == id }
    }

    public mutating func move(from source: Int, to destination: Int) {
        guard source >= 0, source < features.count,
              destination >= 0, destination <= features.count,
              source != destination else { return }
        let feature = features.remove(at: source)
        let insertAt = destination > source ? destination - 1 : destination
        features.insert(feature, at: min(insertAt, features.count))
    }

    public mutating func toggleSuppressed(at index: Int) {
        guard index >= 0, index < features.count else { return }
        features[index].isSuppressed.toggle()
    }

    public mutating func rename(at index: Int, to newName: String) {
        guard index >= 0, index < features.count else { return }
        features[index].name = newName
    }

    public mutating func update(at index: Int, _ feature: AnyFeature) {
        guard index >= 0, index < features.count else { return }
        features[index] = feature
    }

    public mutating func updateByID(_ id: FeatureID, _ feature: AnyFeature) {
        guard let idx = index(ofID: id) else { return }
        features[idx] = feature
    }
}
