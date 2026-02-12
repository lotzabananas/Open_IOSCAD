import XCTest
@testable import ParametricEngine
import GeometryKernel

final class EvaluatorTests: XCTestCase {

    let evaluator = FeatureEvaluator()

    func testEmptyTreeProducesEmptyMesh() {
        let tree = FeatureTree()
        let result = evaluator.evaluate(tree)
        XCTAssertTrue(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testSketchOnlyDoesNotProduceMesh() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        tree.append(.sketch(sketch))

        let result = evaluator.evaluate(tree)
        // A sketch alone doesn't produce 3D geometry
        XCTAssertTrue(result.mesh.isEmpty)
    }

    func testRectangleExtrudeProducesGeometry() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let extrude = ExtrudeFeature(
            name: "E1",
            sketchID: sketch.id,
            depth: 20,
            operation: .additive
        )
        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertGreaterThan(result.mesh.triangleCount, 0)
        XCTAssertGreaterThan(result.mesh.vertexCount, 0)

        // Verify bounding box approximately matches 10x10x20
        let bb = result.mesh.boundingBox
        let size = bb.max - bb.min
        XCTAssertEqual(size.x, 10, accuracy: 0.5)
        XCTAssertEqual(size.y, 10, accuracy: 0.5)
        XCTAssertEqual(size.z, 20, accuracy: 0.5)
    }

    func testCircleExtrudeProducesGeometry() {
        var tree = FeatureTree()
        let sketch = SketchFeature.circleOnXY(radius: 5, name: "S1")
        let extrude = ExtrudeFeature(
            name: "E1",
            sketchID: sketch.id,
            depth: 15,
            operation: .additive
        )
        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)

        // Bounding box: approximately 10x10x15 (diameter 10, height 15)
        let bb = result.mesh.boundingBox
        let size = bb.max - bb.min
        XCTAssertEqual(size.x, 10, accuracy: 1.0)
        XCTAssertEqual(size.y, 10, accuracy: 1.0)
        XCTAssertEqual(size.z, 15, accuracy: 0.5)
    }

    func testSubtractiveExtrudeProducesCut() {
        var tree = FeatureTree()

        // Base box: 20x20x20
        let boxSketch = SketchFeature.rectangleOnXY(width: 20, depth: 20, name: "S1")
        let boxExtrude = ExtrudeFeature(
            name: "E1", sketchID: boxSketch.id, depth: 20, operation: .additive
        )

        // Hole: circle r=3, cut through
        let holeSketch = SketchFeature.circleOnXY(radius: 3, name: "S2")
        let holeCut = ExtrudeFeature(
            name: "Cut1", sketchID: holeSketch.id, depth: 30, operation: .subtractive
        )

        tree.append(.sketch(boxSketch))
        tree.append(.extrude(boxExtrude))
        tree.append(.sketch(holeSketch))
        tree.append(.extrude(holeCut))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        // The mesh should have more triangles than a plain box due to the cut
        XCTAssertGreaterThan(result.mesh.triangleCount, 12)
    }

    func testSuppressedFeatureSkipped() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let extrude = ExtrudeFeature(
            name: "E1", sketchID: sketch.id, depth: 20, operation: .additive
        )
        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        // Suppress the sketch
        tree.toggleSuppressed(at: 0)

        let result = evaluator.evaluate(tree)
        // Extrude can't find the suppressed sketch's profile
        // Should produce empty mesh (sketch suppressed = no profile to extrude)
        XCTAssertTrue(result.mesh.isEmpty || !result.errors.isEmpty)
    }

    func testMissingSketchReferenceProducesError() {
        var tree = FeatureTree()
        let extrude = ExtrudeFeature(
            name: "E1",
            sketchID: FeatureID(), // Non-existent sketch
            depth: 20,
            operation: .additive
        )
        tree.append(.extrude(extrude))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.errors.isEmpty)
    }

    func testMultipleAdditiveExtrudes() {
        var tree = FeatureTree()

        let s1 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let e1 = ExtrudeFeature(name: "E1", sketchID: s1.id, depth: 10, operation: .additive)

        let s2 = SketchFeature.circleOnXY(radius: 3, name: "S2")
        let e2 = ExtrudeFeature(name: "E2", sketchID: s2.id, depth: 20, operation: .additive)

        tree.append(.sketch(s1))
        tree.append(.extrude(e1))
        tree.append(.sketch(s2))
        tree.append(.extrude(e2))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }
}
