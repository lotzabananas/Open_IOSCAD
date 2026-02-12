import SwiftUI
import Combine
import SCADEngine
import GeometryKernel
import Renderer

@MainActor
final class ModelViewModel: ObservableObject {
    // Script state
    @Published var scriptText: String = "" {
        didSet {
            if scriptText != oldValue {
                scheduleRebuild()
                scheduleUndoSnapshot()
            }
        }
    }

    // Geometry state
    @Published var currentMesh: TriangleMesh = TriangleMesh()

    // UI state
    @Published var showScriptEditor: Bool = false
    @Published var showCustomizer: Bool = false
    @Published var showFeatureTree: Bool = true
    @Published var showAddMenu: Bool = false
    @Published var showExportSheet: Bool = false
    @Published var showExportSuccess: Bool = false
    @Published var lastError: String?
    @Published var selectedFeatureIndex: Int? = nil
    @Published var features: [FeatureItem] = []
    @Published var customizerParams: [CustomizerParam] = []

    // Undo/Redo
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    private var undoStack: [String] = []
    private var redoStack: [String] = []
    private let maxUndoStates = 100
    private var isApplyingUndoRedo = false
    private var undoDebounceTask: Task<Void, Never>?
    private var pendingUndoSnapshot: String?
    private let systemUndoManager = UndoManager()

    // Engine
    private let evaluator = Evaluator()
    private let kernel = GeometryKernel()
    private let customizerExtractor = CustomizerExtractor()

    private var rebuildTask: Task<Void, Never>?

    init() {}

    // MARK: - Script Rebuild Pipeline

    func rebuildFromScript() {
        rebuildTask?.cancel()
        rebuildTask = Task { [weak self] in
            guard let self = self else { return }
            await self.performRebuild()
        }
    }

    private func scheduleRebuild() {
        rebuildTask?.cancel()
        rebuildTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            guard !Task.isCancelled else { return }
            guard let self = self else { return }
            await self.performRebuild()
        }
    }

    private func performRebuild() async {
        let source = scriptText
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            currentMesh = TriangleMesh()
            features = []
            customizerParams = []
            lastError = nil
            return
        }

        do {
            // Lex
            let lexer = Lexer(source: source)
            let tokens = try lexer.tokenize()

            // Parse
            var parser = Parser(tokens: tokens)
            let ast = try parser.parse()

            // Extract customizer params
            customizerParams = customizerExtractor.extract(from: source)

            // Extract features (from @feature annotations + auto-detected primitives)
            features = extractFeatures(from: source)

            // Evaluate
            let result = evaluator.evaluate(program: ast)

            if !result.errors.isEmpty {
                lastError = result.errors.map(\.description).joined(separator: "\n")
            } else {
                lastError = nil
            }

            // Build mesh
            let mesh = kernel.evaluate(result.geometry)
            currentMesh = mesh

        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - GUI Actions (ScriptBridge — write to script)

    func addPrimitive(_ type: String) {
        guard let primType = ScriptBridge.PrimitiveType(rawValue: type.lowercased()) else {
            // Fallback for unknown types
            pushUndoImmediate()
            scriptText += "\(type.lowercased())();\n"
            showAddMenu = false
            return
        }

        pushUndoImmediate()
        scriptText = ScriptBridge.insertPrimitive(
            primType,
            in: scriptText,
            afterFeatureIndex: selectedFeatureIndex
        )
        showAddMenu = false
    }

    func addBooleanOp(_ op: String) {
        pushUndoImmediate()

        let name = ScriptBridge.nextFeatureName(for: op.capitalized, in: scriptText)
        let block = "// @feature \"\(name)\"\n\(op)() {\n    \n}\n"

        scriptText = ScriptBridge.insertBlock(
            block,
            in: scriptText,
            afterFeatureIndex: selectedFeatureIndex
        )
    }

    func updateParameter(name: String, value: Value) {
        pushUndoImmediate()
        scriptText = customizerExtractor.updateParameter(in: scriptText, name: name, newValue: value)
    }

    // MARK: - Feature Tree Operations

    func suppressFeature(at index: Int) {
        pushUndoImmediate()
        scriptText = ScriptBridge.suppressFeature(at: index, in: scriptText)
    }

    func deleteFeature(at index: Int) {
        pushUndoImmediate()
        if selectedFeatureIndex == index {
            selectedFeatureIndex = nil
        }
        scriptText = ScriptBridge.deleteFeature(at: index, in: scriptText)
    }

    func renameFeature(at index: Int, to newName: String) {
        pushUndoImmediate()
        scriptText = ScriptBridge.renameFeature(at: index, to: newName, in: scriptText)
    }

    func moveFeature(from source: Int, to destination: Int) {
        pushUndoImmediate()
        scriptText = ScriptBridge.moveFeature(from: source, to: destination, in: scriptText)
    }

    // MARK: - Undo/Redo

    /// Push an immediate undo snapshot (for discrete GUI actions).
    func pushUndoImmediate() {
        guard !isApplyingUndoRedo else { return }
        undoDebounceTask?.cancel()
        pendingUndoSnapshot = nil

        undoStack.append(scriptText)
        if undoStack.count > maxUndoStates {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        canUndo = true
        canRedo = false
    }

    /// Schedule a debounced undo snapshot (for typing in editor).
    private func scheduleUndoSnapshot() {
        guard !isApplyingUndoRedo else { return }

        if pendingUndoSnapshot == nil {
            pendingUndoSnapshot = scriptText
        }

        undoDebounceTask?.cancel()
        undoDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s debounce for typing
            guard !Task.isCancelled else { return }
            guard let self = self else { return }
            self.flushUndoSnapshot()
        }
    }

    private func flushUndoSnapshot() {
        guard let snapshot = pendingUndoSnapshot else { return }
        // Only push if different from the last undo state
        if undoStack.last != snapshot {
            undoStack.append(snapshot)
            if undoStack.count > maxUndoStates {
                undoStack.removeFirst()
            }
        }
        pendingUndoSnapshot = nil
        redoStack.removeAll()
        canUndo = !undoStack.isEmpty
        canRedo = false
    }

    func undo() {
        // Flush any pending typing snapshot first
        undoDebounceTask?.cancel()
        if let pending = pendingUndoSnapshot, undoStack.last != pending {
            undoStack.append(pending)
            pendingUndoSnapshot = nil
        }

        guard let previous = undoStack.popLast() else { return }
        isApplyingUndoRedo = true
        redoStack.append(scriptText)
        scriptText = previous
        isApplyingUndoRedo = false
        canUndo = !undoStack.isEmpty
        canRedo = true
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        isApplyingUndoRedo = true
        undoStack.append(scriptText)
        scriptText = next
        isApplyingUndoRedo = false
        canUndo = true
        canRedo = !redoStack.isEmpty
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

    // MARK: - Features

    private func extractFeatures(from source: String) -> [FeatureItem] {
        // Prefer @feature annotations from ScriptBridge
        let annotatedBlocks = ScriptBridge.featureBlocks(in: source)
        if !annotatedBlocks.isEmpty {
            return annotatedBlocks.enumerated().map { (i, block) in
                FeatureItem(
                    name: block.name,
                    lineNumber: block.startLine,
                    index: i,
                    endLine: block.endLine,
                    isSuppressed: block.isSuppressed
                )
            }
        }

        // Fallback: auto-detect top-level primitive calls
        var items: [FeatureItem] = []
        let lines = source.components(separatedBy: "\n")
        var featureIndex = 0

        let primitives = ["cube", "cylinder", "sphere", "polyhedron", "difference", "union", "intersection",
                        "translate", "rotate", "scale", "linear_extrude", "rotate_extrude"]

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for prim in primitives {
                if trimmed.hasPrefix("\(prim)(") || trimmed.hasPrefix("\(prim) (") {
                    items.append(FeatureItem(
                        name: prim,
                        lineNumber: i + 1,
                        index: featureIndex,
                        endLine: i + 1,
                        isSuppressed: false
                    ))
                    featureIndex += 1
                    break
                }
            }
        }

        return items
    }
}

struct FeatureItem: Identifiable {
    let name: String
    let lineNumber: Int
    let index: Int
    let endLine: Int
    let isSuppressed: Bool
    var id: Int { index }
}
