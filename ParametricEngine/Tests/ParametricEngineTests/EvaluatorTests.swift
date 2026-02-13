import XCTest
@testable import ParametricEngine
import GeometryKernel

final class EvaluatorTests: XCTestCase {

    let evaluator = FeatureEvaluator()

    // MARK: - Basic evaluation

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

    // MARK: - Transform feature

    func testTranslateMovesGeometry() {
        var tree = FeatureTree()

        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let extrude = ExtrudeFeature(
            name: "E1", sketchID: sketch.id, depth: 10, operation: .additive
        )

        // Move the box 50 units in +Y
        let translate = TransformFeature(
            name: "Translate1",
            transformType: .translate,
            vector: SIMD3<Double>(0, 50, 0),
            targetID: extrude.id
        )

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.transform(translate))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)

        // The box center should be at approximately Y=50
        let center = result.mesh.center
        XCTAssertEqual(center.y, 50, accuracy: 1.0)
    }

    func testTranslatePreservesSize() {
        var tree = FeatureTree()

        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let extrude = ExtrudeFeature(
            name: "E1", sketchID: sketch.id, depth: 20, operation: .additive
        )

        let translate = TransformFeature(
            name: "Translate1",
            transformType: .translate,
            vector: SIMD3<Double>(100, 0, 0),
            targetID: extrude.id
        )

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.transform(translate))

        let result = evaluator.evaluate(tree)
        let bb = result.mesh.boundingBox
        let size = bb.max - bb.min

        // Size should still be 10x10x20 after translation
        XCTAssertEqual(size.x, 10, accuracy: 0.5)
        XCTAssertEqual(size.y, 10, accuracy: 0.5)
        XCTAssertEqual(size.z, 20, accuracy: 0.5)
    }

    func testScaleDoublesSize() {
        var tree = FeatureTree()

        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let extrude = ExtrudeFeature(
            name: "E1", sketchID: sketch.id, depth: 10, operation: .additive
        )

        // Scale 2x in all directions
        let scale = TransformFeature(
            name: "Scale1",
            transformType: .scale,
            vector: SIMD3<Double>(2, 2, 2),
            targetID: extrude.id
        )

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.transform(scale))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)

        let bb = result.mesh.boundingBox
        let size = bb.max - bb.min

        // 10x10x10 scaled 2x = 20x20x20
        XCTAssertEqual(size.x, 20, accuracy: 1.0)
        XCTAssertEqual(size.y, 20, accuracy: 1.0)
        XCTAssertEqual(size.z, 20, accuracy: 1.0)
    }

    func testTransformOnlyAffectsTarget() {
        var tree = FeatureTree()

        // Box 1: 10x10x10 at origin
        let s1 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let e1 = ExtrudeFeature(name: "E1", sketchID: s1.id, depth: 10, operation: .additive)

        // Box 2: 10x10x10 at origin (overlapping)
        let s2 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S2")
        let e2 = ExtrudeFeature(name: "E2", sketchID: s2.id, depth: 10, operation: .additive)

        // Move only Box 2 far away
        let translate = TransformFeature(
            name: "Move Box 2",
            transformType: .translate,
            vector: SIMD3<Double>(100, 0, 0),
            targetID: e2.id
        )

        tree.append(.sketch(s1))
        tree.append(.extrude(e1))
        tree.append(.sketch(s2))
        tree.append(.extrude(e2))
        tree.append(.transform(translate))

        let result = evaluator.evaluate(tree)
        XCTAssertTrue(result.errors.isEmpty)

        // Bounding box should span from ~-5 (box1) to ~105 (translated box2) in X
        let bb = result.mesh.boundingBox
        XCTAssertLessThan(bb.min.x, 0)
        XCTAssertGreaterThan(bb.max.x, 90)
    }

    func testTransformMissingTargetProducesError() {
        var tree = FeatureTree()

        let translate = TransformFeature(
            name: "Bad Transform",
            transformType: .translate,
            vector: SIMD3<Double>(10, 0, 0),
            targetID: FeatureID() // Non-existent target
        )

        tree.append(.transform(translate))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.errors.isEmpty)
    }

    func testRotateChangesOrientation() {
        var tree = FeatureTree()

        // Tall narrow box: 4x4x40 on XY
        let sketch = SketchFeature.rectangleOnXY(width: 4, depth: 4, name: "S1")
        let extrude = ExtrudeFeature(
            name: "E1", sketchID: sketch.id, depth: 40, operation: .additive
        )

        // Rotate 90 degrees around X axis (should tilt the tall Z dimension into Y)
        let rotate = TransformFeature(
            name: "Rotate1",
            transformType: .rotate,
            vector: .zero,
            angle: 90,
            axis: SIMD3<Double>(1, 0, 0),
            targetID: extrude.id
        )

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.transform(rotate))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)

        let bb = result.mesh.boundingBox
        let size = bb.max - bb.min

        // After 90deg rotation around X: Z extent should be ~4, Y extent should be ~40
        XCTAssertEqual(size.x, 4, accuracy: 1.0)
        XCTAssertEqual(size.y, 40, accuracy: 1.0)
        XCTAssertEqual(size.z, 4, accuracy: 1.0)
    }

    // MARK: - Boolean feature

    func testBooleanUnionCombinesTwoBodies() {
        var tree = FeatureTree()

        // Two non-overlapping boxes
        let s1 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let e1 = ExtrudeFeature(name: "E1", sketchID: s1.id, depth: 10, operation: .additive)

        let s2 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S2")
        let e2 = ExtrudeFeature(name: "E2", sketchID: s2.id, depth: 10, operation: .additive)

        // Separate them first
        let translate = TransformFeature(
            name: "Move E2",
            transformType: .translate,
            vector: SIMD3<Double>(50, 0, 0),
            targetID: e2.id
        )

        // Boolean union the two
        let boolUnion = BooleanFeature(
            name: "Union",
            booleanType: .union,
            targetIDs: [e1.id, e2.id]
        )

        tree.append(.sketch(s1))
        tree.append(.extrude(e1))
        tree.append(.sketch(s2))
        tree.append(.extrude(e2))
        tree.append(.transform(translate))
        tree.append(.boolean(boolUnion))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testBooleanDifferenceSubtracts() {
        var tree = FeatureTree()

        // Large box
        let s1 = SketchFeature.rectangleOnXY(width: 20, depth: 20, name: "S1")
        let e1 = ExtrudeFeature(name: "E1", sketchID: s1.id, depth: 20, operation: .additive)

        // Smaller overlapping box to subtract
        let s2 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S2")
        let e2 = ExtrudeFeature(name: "E2", sketchID: s2.id, depth: 30, operation: .additive)

        let boolDiff = BooleanFeature(
            name: "Difference",
            booleanType: .difference,
            targetIDs: [e1.id, e2.id]
        )

        tree.append(.sketch(s1))
        tree.append(.extrude(e1))
        tree.append(.sketch(s2))
        tree.append(.extrude(e2))
        tree.append(.boolean(boolDiff))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)

        // Result should have more triangles than either box alone
        XCTAssertGreaterThan(result.mesh.triangleCount, 12)
    }

    func testBooleanIntersectionKeepsOverlap() {
        var tree = FeatureTree()

        // Two overlapping boxes
        let s1 = SketchFeature.rectangleOnXY(width: 20, depth: 20, name: "S1")
        let e1 = ExtrudeFeature(name: "E1", sketchID: s1.id, depth: 20, operation: .additive)

        let s2 = SketchFeature.rectangleOnXY(width: 20, depth: 20, name: "S2")
        let e2 = ExtrudeFeature(name: "E2", sketchID: s2.id, depth: 20, operation: .additive)

        let boolIntersect = BooleanFeature(
            name: "Intersection",
            booleanType: .intersection,
            targetIDs: [e1.id, e2.id]
        )

        tree.append(.sketch(s1))
        tree.append(.extrude(e1))
        tree.append(.sketch(s2))
        tree.append(.extrude(e2))
        tree.append(.boolean(boolIntersect))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testBooleanWithTooFewTargetsProducesError() {
        var tree = FeatureTree()

        let s1 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let e1 = ExtrudeFeature(name: "E1", sketchID: s1.id, depth: 10, operation: .additive)

        // Boolean referencing only one target
        let boolUnion = BooleanFeature(
            name: "Bad Union",
            booleanType: .union,
            targetIDs: [e1.id]
        )

        tree.append(.sketch(s1))
        tree.append(.extrude(e1))
        tree.append(.boolean(boolUnion))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.errors.isEmpty)
    }

    func testBooleanWithMissingTargetsProducesError() {
        var tree = FeatureTree()

        // Boolean referencing non-existent features
        let boolUnion = BooleanFeature(
            name: "Ghost Union",
            booleanType: .union,
            targetIDs: [FeatureID(), FeatureID()]
        )

        tree.append(.boolean(boolUnion))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.errors.isEmpty)
    }

    // MARK: - Combined operations

    func testTransformThenBooleanWorksTogether() {
        var tree = FeatureTree()

        // Two boxes, move one, then union them
        let s1 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let e1 = ExtrudeFeature(name: "E1", sketchID: s1.id, depth: 10, operation: .additive)

        let s2 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S2")
        let e2 = ExtrudeFeature(name: "E2", sketchID: s2.id, depth: 10, operation: .additive)

        // Move box 2 so they don't overlap
        let translate = TransformFeature(
            name: "Move",
            transformType: .translate,
            vector: SIMD3<Double>(20, 0, 0),
            targetID: e2.id
        )

        let boolUnion = BooleanFeature(
            name: "Union",
            booleanType: .union,
            targetIDs: [e1.id, e2.id]
        )

        tree.append(.sketch(s1))
        tree.append(.extrude(e1))
        tree.append(.sketch(s2))
        tree.append(.extrude(e2))
        tree.append(.transform(translate))
        tree.append(.boolean(boolUnion))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)

        // Result should span from box1 at ~-5 to translated box2 at ~25
        let bb = result.mesh.boundingBox
        XCTAssertGreaterThan(bb.max.x - bb.min.x, 25)
    }

    func testTransformSubtractiveFeature() {
        var tree = FeatureTree()

        // Base box
        let s1 = SketchFeature.rectangleOnXY(width: 20, depth: 20, name: "S1")
        let e1 = ExtrudeFeature(name: "Box", sketchID: s1.id, depth: 20, operation: .additive)

        // Hole at origin
        let s2 = SketchFeature.circleOnXY(radius: 3, name: "S2")
        let e2 = ExtrudeFeature(name: "Hole", sketchID: s2.id, depth: 30, operation: .subtractive)

        // Move the hole off-center
        let translate = TransformFeature(
            name: "Move Hole",
            transformType: .translate,
            vector: SIMD3<Double>(5, 5, 0),
            targetID: e2.id
        )

        tree.append(.sketch(s1))
        tree.append(.extrude(e1))
        tree.append(.sketch(s2))
        tree.append(.extrude(e2))
        tree.append(.transform(translate))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)

        // Bounding box of the base box should be preserved (hole is inside)
        let bb = result.mesh.boundingBox
        let size = bb.max - bb.min
        XCTAssertEqual(size.x, 20, accuracy: 1.0)
        XCTAssertEqual(size.y, 20, accuracy: 1.0)
    }

    // MARK: - Sketch planes

    func testExtrudeOnXZPlane() {
        var tree = FeatureTree()

        let sketch = SketchFeature(
            name: "S1",
            plane: .xz,
            elements: [.rectangle(id: ElementID(), origin: Point2D(x: -5, y: -5), width: 10, height: 10)]
        )
        let extrude = ExtrudeFeature(
            name: "E1", sketchID: sketch.id, depth: 20, operation: .additive
        )
        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)

        // On XZ plane, extrusion goes along the rotated Z axis.
        // After -90deg X rotation, the Z-extrusion maps to -Y.
        let bb = result.mesh.boundingBox
        let size = bb.max - bb.min
        XCTAssertEqual(size.x, 10, accuracy: 1.0)
        XCTAssertGreaterThan(size.y + size.z, 15)
    }

    func testExtrudeOnOffsetXYPlane() {
        var tree = FeatureTree()

        let sketch = SketchFeature(
            name: "S1",
            plane: .offsetXY(distance: 30),
            elements: [.rectangle(id: ElementID(), origin: Point2D(x: -5, y: -5), width: 10, height: 10)]
        )
        let extrude = ExtrudeFeature(
            name: "E1", sketchID: sketch.id, depth: 10, operation: .additive
        )
        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)

        // The geometry should be offset in Z by 30
        let bb = result.mesh.boundingBox
        XCTAssertGreaterThanOrEqual(bb.min.z, 29.0)
    }
}
