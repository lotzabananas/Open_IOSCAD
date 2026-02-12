import SwiftUI
import Combine
import GeometryKernel
import Renderer

@MainActor
final class ModelViewModel: ObservableObject {
    // Geometry state
    @Published var currentMesh: TriangleMesh = TriangleMesh()

    // UI state
    @Published var showFeatureTree: Bool = true
    @Published var showAddMenu: Bool = false
    @Published var showExportSheet: Bool = false
    @Published var showExportSuccess: Bool = false
    @Published var lastError: String?
    @Published var selectedFeatureIndex: Int?
    @Published var features: [FeatureItem] = []

    // Undo/Redo
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false

    // Engine
    private let kernel = GeometryKernel()

    init() {}

    // MARK: - Feature Operations (stubs — ParametricEngine will implement)

    func addPrimitive(_ type: String) {
        let name = nextFeatureName(for: type)
        let feature = FeatureItem(
            name: name,
            type: type.lowercased(),
            index: features.count,
            isSuppressed: false
        )
        features.append(feature)
        showAddMenu = false
        // TODO: ParametricEngine evaluates feature → GeometryKernel → mesh
    }

    func addBooleanOp(_ op: String) {
        let name = nextFeatureName(for: op.capitalized)
        let feature = FeatureItem(
            name: name,
            type: op.lowercased(),
            index: features.count,
            isSuppressed: false
        )
        features.append(feature)
        // TODO: ParametricEngine evaluates feature → GeometryKernel → mesh
    }

    func suppressFeature(at index: Int) {
        guard index < features.count else { return }
        features[index] = FeatureItem(
            name: features[index].name,
            type: features[index].type,
            index: features[index].index,
            isSuppressed: !features[index].isSuppressed
        )
        reindex()
        // TODO: ParametricEngine re-evaluates from modified point
    }

    func deleteFeature(at index: Int) {
        guard index < features.count else { return }
        if selectedFeatureIndex == index {
            selectedFeatureIndex = nil
        }
        features.remove(at: index)
        reindex()
        // TODO: ParametricEngine re-evaluates from modified point
    }

    func renameFeature(at index: Int, to newName: String) {
        guard index < features.count else { return }
        features[index] = FeatureItem(
            name: newName,
            type: features[index].type,
            index: features[index].index,
            isSuppressed: features[index].isSuppressed
        )
    }

    func moveFeature(from source: Int, to destination: Int) {
        guard source != destination,
              source < features.count,
              destination <= features.count else { return }
        let feature = features.remove(at: source)
        let insertAt = destination > source ? destination - 1 : destination
        features.insert(feature, at: min(insertAt, features.count))
        reindex()
        // TODO: ParametricEngine re-evaluates from modified point
    }

    // MARK: - Undo/Redo (stubs — will operate on Feature list snapshots)

    func undo() {
        // TODO: Restore previous feature list snapshot
    }

    func redo() {
        // TODO: Restore next feature list snapshot
    }

    // MARK: - Export

    func exportSTL() -> Data? {
        guard !currentMesh.isEmpty else { return nil }
        return STLExporter.exportBinary(currentMesh)
    }

    func export3MF() -> Data? {
        guard !currentMesh.isEmpty else { return nil }
        return ThreeMFExporter.export(currentMesh)
    }

    // MARK: - Private

    private func nextFeatureName(for type: String) -> String {
        let base = type.prefix(1).uppercased() + type.dropFirst().lowercased()
        let existing = features.filter { $0.name.hasPrefix(base) }.count
        return "\(base) \(existing + 1)"
    }

    private func reindex() {
        features = features.enumerated().map { (i, f) in
            FeatureItem(name: f.name, type: f.type, index: i, isSuppressed: f.isSuppressed)
        }
    }
}

struct FeatureItem: Identifiable {
    let name: String
    let type: String
    let index: Int
    let isSuppressed: Bool
    var id: Int { index }
}
