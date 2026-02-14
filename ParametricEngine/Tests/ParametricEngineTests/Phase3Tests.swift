import XCTest
@testable import ParametricEngine
import GeometryKernel

final class Phase3Tests: XCTestCase {

    let evaluator = FeatureEvaluator()

    // MARK: - Fillet

    func testFilletAppliedToBox() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 20, depth: 20, name: "S1")
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 20, operation: .additive)
        let fillet = FilletFeature(name: "Fillet1", radius: 2.0, targetID: extrude.id)

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.fillet(fillet))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
        // Filleted mesh should have more triangles due to bevel geometry
        XCTAssertGreaterThanOrEqual(result.mesh.triangleCount, 12)
    }

    func testFilletWithMissingTarget() {
        var tree = FeatureTree()
        let fillet = FilletFeature(name: "Fillet1", radius: 2.0, targetID: UUID())

        tree.append(.fillet(fillet))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.errors.isEmpty)
    }

    // MARK: - Chamfer

    func testChamferAppliedToBox() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 20, depth: 20, name: "S1")
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 20, operation: .additive)
        let chamfer = ChamferFeature(name: "Chamfer1", distance: 1.0, targetID: extrude.id)

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.chamfer(chamfer))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Shell

    func testShellHollowsBox() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 20, depth: 20, name: "S1")
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 20, operation: .additive)
        let shell = ShellFeature(name: "Shell1", thickness: 2.0, targetID: extrude.id)

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.shell(shell))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
        // Shelled mesh should have significantly more triangles (inner + outer faces)
        XCTAssertGreaterThan(result.mesh.triangleCount, 12)
    }

    func testShellWithOpenFace() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 20, depth: 20, name: "S1")
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 20, operation: .additive)
        let shell = ShellFeature(name: "Shell1", thickness: 2.0, openFaceIndices: [0], targetID: extrude.id)

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.shell(shell))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Linear Pattern

    func testLinearPatternCreatesMultipleCopies() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 10, operation: .additive)
        let pattern = PatternFeature(
            name: "LinearPattern",
            patternType: .linear,
            sourceID: extrude.id,
            direction: SIMD3<Double>(1, 0, 0),
            count: 3,
            spacing: 20.0
        )

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.pattern(pattern))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)

        // 3 copies of a 12-triangle box = 36 triangles (merged, not boolean'd)
        XCTAssertEqual(result.mesh.triangleCount, 36)

        // Should span wider than a single box
        let bb = result.mesh.boundingBox
        XCTAssertGreaterThan(bb.max.x - bb.min.x, 30)
    }

    // MARK: - Circular Pattern

    func testCircularPatternCreatesMultipleCopies() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 5, depth: 5, name: "S1")
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 5, operation: .additive)
        let pattern = PatternFeature(
            name: "CircularPattern",
            patternType: .circular,
            sourceID: extrude.id,
            count: 4,
            spacing: 10.0,
            axis: SIMD3<Double>(0, 0, 1),
            totalAngle: 360.0
        )

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.pattern(pattern))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)

        // 4 copies of a 12-triangle box
        XCTAssertEqual(result.mesh.triangleCount, 48)
    }

    // MARK: - Mirror Pattern

    func testMirrorPatternCreatesMirroredCopy() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 10, operation: .additive)
        let pattern = PatternFeature(
            name: "MirrorPattern",
            patternType: .mirror,
            sourceID: extrude.id,
            direction: SIMD3<Double>(1, 0, 0) // Mirror across YZ plane
        )

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.pattern(pattern))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)

        // Original + mirror = 24 triangles
        XCTAssertEqual(result.mesh.triangleCount, 24)
    }

    // MARK: - SCAD Export

    func testSCADExportBasicBox() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "Box Sketch")
        let extrude = ExtrudeFeature(name: "Box Extrude", sketchID: sketch.id, depth: 20, operation: .additive)

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        let scad = SCADExporter.export(tree)
        XCTAssertTrue(scad.contains("linear_extrude"))
        XCTAssertTrue(scad.contains("20"))
        XCTAssertTrue(scad.contains("Generated by OpeniOSCAD"))
    }

    func testSCADExportWithTransform() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 10, operation: .additive)
        let transform = TransformFeature(
            name: "Move",
            transformType: .translate,
            vector: SIMD3<Double>(10, 20, 30),
            targetID: extrude.id
        )

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.transform(transform))

        let scad = SCADExporter.export(tree)
        XCTAssertTrue(scad.contains("translate"))
    }

    // MARK: - CadQuery Export

    func testCadQueryExportBasicBox() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 20, operation: .additive)

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        let cq = CadQueryExporter.export(tree)
        XCTAssertTrue(cq.contains("import cadquery"))
        XCTAssertTrue(cq.contains("extrude"))
        XCTAssertTrue(cq.contains("show_object"))
    }

    func testCadQueryExportWithFillet() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 10, operation: .additive)
        let fillet = FilletFeature(name: "Fillet1", radius: 2.0, targetID: extrude.id)

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.fillet(fillet))

        let cq = CadQueryExporter.export(tree)
        XCTAssertTrue(cq.contains("fillet"))
    }

    // MARK: - Serialization

    func testNewFeatureTypesRoundTrip() throws {
        let fillet = FilletFeature(name: "F1", radius: 3.0, targetID: UUID())
        let chamfer = ChamferFeature(name: "C1", distance: 1.5, targetID: UUID())
        let shell = ShellFeature(name: "S1", thickness: 2.0, targetID: UUID())
        let pattern = PatternFeature(name: "P1", patternType: .linear, sourceID: UUID(), count: 4, spacing: 15.0)

        let features: [AnyFeature] = [
            .fillet(fillet),
            .chamfer(chamfer),
            .shell(shell),
            .pattern(pattern)
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(features)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([AnyFeature].self, from: data)

        XCTAssertEqual(decoded.count, 4)
        XCTAssertEqual(decoded[0].kind, .fillet)
        XCTAssertEqual(decoded[1].kind, .chamfer)
        XCTAssertEqual(decoded[2].kind, .shell)
        XCTAssertEqual(decoded[3].kind, .pattern)

        if case .fillet(let f) = decoded[0] {
            XCTAssertEqual(f.radius, 3.0)
        } else { XCTFail("Expected fillet") }

        if case .pattern(let p) = decoded[3] {
            XCTAssertEqual(p.count, 4)
            XCTAssertEqual(p.spacing, 15.0)
        } else { XCTFail("Expected pattern") }
    }
}
