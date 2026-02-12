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

            // Extract features
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

    // MARK: - GUI Actions (write to script)

    func addPrimitive(_ type: String) {
        pushUndo()
        let scriptAddition: String
        switch type.lowercased() {
        case "cube":
            scriptAddition = "cube([10, 10, 10]);\n"
        case "cylinder":
            scriptAddition = "cylinder(h=10, r=5, $fn=32);\n"
        case "sphere":
            scriptAddition = "sphere(r=5, $fn=32);\n"
        default:
            scriptAddition = "\(type.lowercased())();\n"
        }
        scriptText += scriptAddition
        showAddMenu = false
    }

    func updateParameter(name: String, value: Value) {
        pushUndo()
        scriptText = customizerExtractor.updateParameter(in: scriptText, name: name, newValue: value)
    }

    // MARK: - Undo/Redo

    func pushUndo() {
        undoStack.append(scriptText)
        redoStack.removeAll()
        canUndo = true
        canRedo = false
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(scriptText)
        scriptText = previous
        canUndo = !undoStack.isEmpty
        canRedo = true
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(scriptText)
        scriptText = next
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
        var items: [FeatureItem] = []
        let lines = source.components(separatedBy: "\n")
        var featureIndex = 0

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for @feature annotation
            if let range = trimmed.range(of: "// @feature") {
                let nameStart = trimmed.index(range.upperBound, offsetBy: 1, limitedBy: trimmed.endIndex) ?? range.upperBound
                var name = String(trimmed[nameStart...]).trimmingCharacters(in: .whitespaces)
                // Remove quotes
                if name.hasPrefix("\"") && name.hasSuffix("\"") {
                    name = String(name.dropFirst().dropLast())
                }
                items.append(FeatureItem(name: name, lineNumber: i + 1, index: featureIndex))
                featureIndex += 1
                continue
            }

            // Auto-detect primitive calls
            let primitives = ["cube", "cylinder", "sphere", "polyhedron", "difference", "union", "intersection",
                            "translate", "rotate", "scale", "linear_extrude", "rotate_extrude"]
            for prim in primitives {
                if trimmed.hasPrefix("\(prim)(") || trimmed.hasPrefix("\(prim) (") {
                    items.append(FeatureItem(name: "\(prim)", lineNumber: i + 1, index: featureIndex))
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
    var id: Int { index }
}
