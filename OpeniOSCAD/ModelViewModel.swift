import SwiftUI
import Combine
import GeometryKernel
import ParametricEngine

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
    @Published var selectedFeatureID: FeatureID?
    @Published var showPropertyInspector: Bool = false

    // Sketch mode
    @Published var isInSketchMode: Bool = false
    @Published var sketchPlane: SketchPlane = .xy

    // Face/edge selection
    @Published var selectedFaceIndex: Int?
    @Published var selectedEdgeIndex: Int?

    // Undo/Redo
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false

    // Engine
    var featureTree = FeatureTree()
    private let evaluator = FeatureEvaluator()
    private let undoStack = UndoStack()

    // Counters for auto-naming
    private var sketchCounter = 0
    private var extrudeCounter = 0
    private var cutCounter = 0
    private var revolveCounter = 0
    private var filletCounter = 0
    private var chamferCounter = 0
    private var shellCounter = 0
    private var patternCounter = 0

    init() {
        pushUndoSnapshot()
    }

    // MARK: - Feature List for UI

    /// Features formatted for the tree view.
    var featureItems: [FeatureDisplayItem] {
        featureTree.features.enumerated().map { (index, feature) in
            FeatureDisplayItem(
                id: feature.id,
                name: feature.name,
                kind: feature.kind,
                index: index,
                isSuppressed: feature.isSuppressed,
                detail: featureDetail(feature)
            )
        }
    }

    private func featureDetail(_ feature: AnyFeature) -> String {
        switch feature {
        case .sketch(let s):
            return s.plane.displayName
        case .extrude(let e):
            let opLabel = e.operation == .additive ? "Add" : "Cut"
            return "\(opLabel) \(String(format: "%.1f", e.depth))mm"
        case .revolve(let r):
            let opLabel = r.operation == .additive ? "Add" : "Cut"
            return "\(opLabel) \(String(format: "%.0f", r.angle))\u{00B0}"
        case .boolean(let b):
            return b.booleanType.rawValue.capitalized
        case .transform(let t):
            return t.transformType.rawValue.capitalized
        case .fillet(let f):
            return "R\(String(format: "%.1f", f.radius))mm"
        case .chamfer(let c):
            return "\(String(format: "%.1f", c.distance))mm"
        case .shell(let s):
            return "\(String(format: "%.1f", s.thickness))mm wall"
        case .pattern(let p):
            switch p.patternType {
            case .linear: return "Linear \(p.count)x"
            case .circular: return "Circular \(p.count)x"
            case .mirror: return "Mirror"
            }
        }
    }

    // MARK: - Convenience Commands

    /// "Add Box" — creates a centered rectangle sketch + additive extrude.
    func addBox(width: Double = 20, depth: Double = 20, height: Double = 20) {
        sketchCounter += 1
        extrudeCounter += 1

        let sketch = SketchFeature.rectangleOnXY(
            width: width,
            depth: depth,
            name: "Sketch \(sketchCounter)"
        )
        let extrude = ExtrudeFeature(
            name: "Extrude \(extrudeCounter)",
            sketchID: sketch.id,
            depth: height,
            operation: .additive
        )

        featureTree.append(.sketch(sketch))
        featureTree.append(.extrude(extrude))

        showAddMenu = false
        pushUndoSnapshot()
        reevaluate()
    }

    /// "Add Cylinder" — creates a centered circle sketch + additive extrude.
    func addCylinder(radius: Double = 10, height: Double = 20) {
        sketchCounter += 1
        extrudeCounter += 1

        let sketch = SketchFeature.circleOnXY(
            radius: radius,
            name: "Sketch \(sketchCounter)"
        )
        let extrude = ExtrudeFeature(
            name: "Extrude \(extrudeCounter)",
            sketchID: sketch.id,
            depth: height,
            operation: .additive
        )

        featureTree.append(.sketch(sketch))
        featureTree.append(.extrude(extrude))

        showAddMenu = false
        pushUndoSnapshot()
        reevaluate()
    }

    /// "Add Sphere" — creates a semicircle sketch on XY + 360° revolve.
    func addSphere(radius: Double = 10) {
        sketchCounter += 1
        revolveCounter += 1

        // Create a semicircle profile: half-circle in +X half-plane
        // Points along an arc from (0, -r) to (0, r) through (r, 0)
        let segments = 24
        var points: [Point2D] = []
        for i in 0...segments {
            let angle = Double(i) / Double(segments) * Double.pi - Double.pi / 2
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            points.append(Point2D(x: x, y: y))
        }
        // Close along the Y axis
        points.append(Point2D(x: 0, y: -radius))

        // Build line segments forming the semicircle profile
        var elements: [SketchElement] = []
        for i in 0..<(points.count - 1) {
            elements.append(.lineSegment(
                id: ElementID(),
                start: points[i],
                end: points[i + 1]
            ))
        }

        let sketch = SketchFeature(
            name: "Sketch \(sketchCounter)",
            plane: .xy,
            elements: elements
        )
        let revolve = RevolveFeature(
            name: "Revolve \(revolveCounter)",
            sketchID: sketch.id,
            angle: 360.0,
            operation: .additive
        )

        featureTree.append(.sketch(sketch))
        featureTree.append(.revolve(revolve))

        showAddMenu = false
        pushUndoSnapshot()
        reevaluate()
    }

    /// "Add Torus" — creates an offset circle sketch + 360° revolve.
    func addTorus(majorRadius: Double = 15, minorRadius: Double = 5) {
        sketchCounter += 1
        revolveCounter += 1

        // Circle profile offset from Y axis by majorRadius
        let element = SketchElement.circle(
            id: ElementID(),
            center: Point2D(x: majorRadius, y: 0),
            radius: minorRadius
        )
        let sketch = SketchFeature(
            name: "Sketch \(sketchCounter)",
            plane: .xy,
            elements: [element]
        )
        let revolve = RevolveFeature(
            name: "Revolve \(revolveCounter)",
            sketchID: sketch.id,
            angle: 360.0,
            operation: .additive
        )

        featureTree.append(.sketch(sketch))
        featureTree.append(.revolve(revolve))

        showAddMenu = false
        pushUndoSnapshot()
        reevaluate()
    }

    /// "Add Hole" — creates a circle sketch + subtractive extrude on XY
    /// (or on selected face when face selection is available).
    func addHole(radius: Double = 5, depth: Double = 100) {
        sketchCounter += 1
        cutCounter += 1

        let plane: SketchPlane
        if let faceIdx = selectedFaceIndex, let featureID = selectedFeatureID {
            plane = .faceOf(featureID: featureID, faceIndex: faceIdx)
        } else {
            plane = .xy
        }

        let element = SketchElement.circle(
            id: ElementID(),
            center: Point2D(x: 0, y: 0),
            radius: radius
        )
        let sketch = SketchFeature(
            name: "Sketch \(sketchCounter)",
            plane: plane,
            elements: [element]
        )
        let cut = ExtrudeFeature(
            name: "Cut \(cutCounter)",
            sketchID: sketch.id,
            depth: depth,
            operation: .subtractive
        )

        featureTree.append(.sketch(sketch))
        featureTree.append(.extrude(cut))

        showAddMenu = false
        pushUndoSnapshot()
        reevaluate()
    }

    // MARK: - Phase 3 Operations

    /// Add a fillet to the last geometry-producing feature (or a selected one).
    func addFillet(radius: Double = 2.0, targetID: FeatureID? = nil) {
        guard let target = targetID ?? lastGeometryFeatureID() else { return }
        filletCounter += 1
        let fillet = FilletFeature(
            name: "Fillet \(filletCounter)",
            radius: radius,
            targetID: target
        )
        featureTree.append(.fillet(fillet))
        showAddMenu = false
        pushUndoSnapshot()
        reevaluate()
    }

    /// Add a chamfer to the last geometry-producing feature (or a selected one).
    func addChamfer(distance: Double = 1.0, targetID: FeatureID? = nil) {
        guard let target = targetID ?? lastGeometryFeatureID() else { return }
        chamferCounter += 1
        let chamfer = ChamferFeature(
            name: "Chamfer \(chamferCounter)",
            distance: distance,
            targetID: target
        )
        featureTree.append(.chamfer(chamfer))
        showAddMenu = false
        pushUndoSnapshot()
        reevaluate()
    }

    /// Shell the last geometry-producing feature (or a selected one).
    func addShell(thickness: Double = 1.0, targetID: FeatureID? = nil) {
        guard let target = targetID ?? lastGeometryFeatureID() else { return }
        shellCounter += 1
        let shell = ShellFeature(
            name: "Shell \(shellCounter)",
            thickness: thickness,
            targetID: target
        )
        featureTree.append(.shell(shell))
        showAddMenu = false
        pushUndoSnapshot()
        reevaluate()
    }

    /// Add a linear pattern.
    func addLinearPattern(count: Int = 3, spacing: Double = 20.0, direction: SIMD3<Double> = SIMD3<Double>(1, 0, 0), sourceID: FeatureID? = nil) {
        guard let source = sourceID ?? lastGeometryFeatureID() else { return }
        patternCounter += 1
        let pattern = PatternFeature(
            name: "Pattern \(patternCounter)",
            patternType: .linear,
            sourceID: source,
            direction: direction,
            count: count,
            spacing: spacing
        )
        featureTree.append(.pattern(pattern))
        showAddMenu = false
        pushUndoSnapshot()
        reevaluate()
    }

    /// Add a circular pattern.
    func addCircularPattern(count: Int = 4, totalAngle: Double = 360.0, axis: SIMD3<Double> = SIMD3<Double>(0, 0, 1), sourceID: FeatureID? = nil) {
        guard let source = sourceID ?? lastGeometryFeatureID() else { return }
        patternCounter += 1
        let pattern = PatternFeature(
            name: "Pattern \(patternCounter)",
            patternType: .circular,
            sourceID: source,
            count: count,
            axis: axis,
            totalAngle: totalAngle
        )
        featureTree.append(.pattern(pattern))
        showAddMenu = false
        pushUndoSnapshot()
        reevaluate()
    }

    /// Add a mirror pattern.
    func addMirrorPattern(planeNormal: SIMD3<Double> = SIMD3<Double>(1, 0, 0), sourceID: FeatureID? = nil) {
        guard let source = sourceID ?? lastGeometryFeatureID() else { return }
        patternCounter += 1
        let pattern = PatternFeature(
            name: "Pattern \(patternCounter)",
            patternType: .mirror,
            sourceID: source,
            direction: planeNormal
        )
        featureTree.append(.pattern(pattern))
        showAddMenu = false
        pushUndoSnapshot()
        reevaluate()
    }

    /// Finds the last geometry-producing feature ID (extrude, revolve, or boolean).
    private func lastGeometryFeatureID() -> FeatureID? {
        featureTree.features.last(where: {
            switch $0 {
            case .extrude, .revolve, .boolean: return true
            default: return false
            }
        })?.id
    }

    /// Add a sketch from sketch mode.
    func addSketchFromSketchMode(elements: [SketchElement], plane: SketchPlane) {
        sketchCounter += 1
        let sketch = SketchFeature(
            name: "Sketch \(sketchCounter)",
            plane: plane,
            elements: elements
        )
        featureTree.append(.sketch(sketch))
        pushUndoSnapshot()
        reevaluate()
    }

    /// Add extrude after completing sketch mode.
    func addExtrudeForSketch(sketchID: FeatureID, depth: Double, operation: ExtrudeFeature.Operation) {
        if operation == .additive {
            extrudeCounter += 1
            let extrude = ExtrudeFeature(
                name: "Extrude \(extrudeCounter)",
                sketchID: sketchID,
                depth: depth,
                operation: .additive
            )
            featureTree.append(.extrude(extrude))
        } else {
            cutCounter += 1
            let cut = ExtrudeFeature(
                name: "Cut \(cutCounter)",
                sketchID: sketchID,
                depth: depth,
                operation: .subtractive
            )
            featureTree.append(.extrude(cut))
        }
        pushUndoSnapshot()
        reevaluate()
    }

    // MARK: - Feature Operations

    func suppressFeature(at index: Int) {
        featureTree.toggleSuppressed(at: index)
        pushUndoSnapshot()
        reevaluate()
    }

    func deleteFeature(at index: Int) {
        guard let feature = featureTree.feature(at: index) else { return }

        // If deleting a sketch, also delete extrudes/revolves that reference it
        if case .sketch(let sketch) = feature {
            let dependents = featureTree.features.enumerated().compactMap { (i, f) -> Int? in
                switch f {
                case .extrude(let e) where e.sketchID == sketch.id: return i
                case .revolve(let r) where r.sketchID == sketch.id: return i
                default: return nil
                }
            }
            // Remove in reverse order to preserve indices
            for depIdx in dependents.reversed() {
                featureTree.remove(at: depIdx)
            }
        }

        // Recalculate the actual index after possible dependent removals
        if let currentIdx = featureTree.index(ofID: feature.id) {
            featureTree.remove(at: currentIdx)
        }

        if selectedFeatureID == feature.id {
            selectedFeatureID = nil
            showPropertyInspector = false
        }

        pushUndoSnapshot()
        reevaluate()
    }

    func deleteFeatureByID(_ id: FeatureID) {
        guard let idx = featureTree.index(ofID: id) else { return }
        deleteFeature(at: idx)
    }

    func renameFeature(at index: Int, to newName: String) {
        featureTree.rename(at: index, to: newName)
        pushUndoSnapshot()
    }

    func moveFeature(from source: Int, to destination: Int) {
        featureTree.move(from: source, to: destination)
        pushUndoSnapshot()
        reevaluate()
    }

    func selectFeature(at index: Int) {
        guard let feature = featureTree.feature(at: index) else { return }
        selectedFeatureID = feature.id
        showPropertyInspector = true
    }

    func deselectFeature() {
        selectedFeatureID = nil
        showPropertyInspector = false
    }

    // MARK: - Parameter Editing

    func updateFeature(_ feature: AnyFeature) {
        featureTree.updateByID(feature.id, feature)
        pushUndoSnapshot()
        reevaluate()
    }

    /// Get the selected feature for the property inspector.
    var selectedFeature: AnyFeature? {
        guard let id = selectedFeatureID else { return nil }
        return featureTree.feature(byID: id)
    }

    // MARK: - Undo/Redo

    func undo() {
        guard let tree = undoStack.undo() else { return }
        featureTree = tree
        updateUndoState()
        reevaluate()
    }

    func redo() {
        guard let tree = undoStack.redo() else { return }
        featureTree = tree
        updateUndoState()
        reevaluate()
    }

    private func pushUndoSnapshot() {
        undoStack.push(featureTree)
        updateUndoState()
    }

    private func updateUndoState() {
        canUndo = undoStack.canUndo
        canRedo = undoStack.canRedo
    }

    // MARK: - Evaluation

    private func reevaluate() {
        let result = evaluator.evaluate(featureTree)
        currentMesh = result.mesh

        if let firstError = result.errors.first {
            lastError = "\(firstError)"
        } else {
            lastError = nil
        }
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

    func exportSCAD() -> Data? {
        let scad = SCADExporter.export(featureTree)
        return scad.data(using: .utf8)
    }

    func exportCadQuery() -> Data? {
        let cq = CadQueryExporter.export(featureTree)
        return cq.data(using: .utf8)
    }

    // MARK: - STEP I/O

    func saveSTEP() throws -> Data {
        let stepContent = try STEPFileIO.write(tree: featureTree, mesh: currentMesh)
        guard let data = stepContent.data(using: .utf8) else {
            throw SerializationError.encodingFailed
        }
        return data
    }

    func loadSTEP(from data: Data) throws {
        guard let content = String(data: data, encoding: .utf8) else {
            throw SerializationError.decodingFailed("Invalid UTF-8 data")
        }

        if let tree = try HistoryComment.decode(from: content) {
            featureTree = tree
            // Reset counters based on loaded features
            resetCounters()
        } else {
            // External STEP file — no history. Start fresh with empty tree.
            featureTree = FeatureTree()
        }

        undoStack.reset()
        pushUndoSnapshot()
        reevaluate()
    }

    private func resetCounters() {
        sketchCounter = featureTree.features.filter { $0.kind == .sketch }.count
        extrudeCounter = featureTree.features.filter {
            if case .extrude(let e) = $0, e.operation == .additive { return true }
            return false
        }.count
        cutCounter = featureTree.features.filter {
            if case .extrude(let e) = $0, e.operation == .subtractive { return true }
            return false
        }.count
        revolveCounter = featureTree.features.filter { $0.kind == .revolve }.count
        filletCounter = featureTree.features.filter { $0.kind == .fillet }.count
        chamferCounter = featureTree.features.filter { $0.kind == .chamfer }.count
        shellCounter = featureTree.features.filter { $0.kind == .shell }.count
        patternCounter = featureTree.features.filter { $0.kind == .pattern }.count
    }

    // MARK: - Face/Edge Selection

    func selectFace(at index: Int?) {
        selectedFaceIndex = index
        selectedEdgeIndex = nil
    }

    func selectEdge(at index: Int?) {
        selectedEdgeIndex = index
        selectedFaceIndex = nil
    }

    func clearGeometrySelection() {
        selectedFaceIndex = nil
        selectedEdgeIndex = nil
    }
}

/// Display item for the feature tree UI — lightweight value type.
struct FeatureDisplayItem: Identifiable {
    let id: FeatureID
    let name: String
    let kind: FeatureKind
    let index: Int
    let isSuppressed: Bool
    let detail: String
}
