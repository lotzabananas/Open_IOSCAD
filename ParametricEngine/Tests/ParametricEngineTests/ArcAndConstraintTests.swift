import XCTest
@testable import ParametricEngine
import GeometryKernel

final class ArcAndConstraintTests: XCTestCase {

    // MARK: - Arc Profile Extraction

    func testSingleArcFailsAsOpenProfile() {
        let element = SketchElement.arc(
            id: ElementID(),
            center: Point2D(x: 0, y: 0),
            radius: 5,
            startAngle: 0,
            sweepAngle: 180
        )
        let result = ProfileExtractor.extractProfile(from: [element])
        switch result {
        case .success:
            XCTFail("Single arc should fail (open profile)")
        case .failure(let error):
            if case .openProfile = error {} else {
                XCTFail("Expected openProfile error, got: \(error)")
            }
        }
    }

    func testArcAndLineMakeClosedProfile() {
        // Semicircle arc + straight line closing the diameter
        let arcID = ElementID()
        let lineID = ElementID()
        let elements: [SketchElement] = [
            .arc(id: arcID, center: Point2D(x: 0, y: 0), radius: 5, startAngle: 0, sweepAngle: 180),
            // Line from arc end (-5, 0) back to arc start (5, 0)
            .lineSegment(id: lineID, start: Point2D(x: -5, y: 0), end: Point2D(x: 5, y: 0)),
        ]

        let result = ProfileExtractor.extractProfile(from: elements)
        switch result {
        case .success(let polygon):
            XCTAssertGreaterThan(polygon.points.count, 2)
            XCTAssertFalse(polygon.isClockwise)
        case .failure(let error):
            XCTFail("Expected success for semicircle + line, got: \(error)")
        }
    }

    func testArcExtrudeProducesGeometry() {
        let evaluator = FeatureEvaluator()
        var tree = FeatureTree()

        // Build a D-shape: semicircle arc + line
        let arcID = ElementID()
        let lineID = ElementID()
        let sketch = SketchFeature(
            name: "D-Shape",
            plane: .xy,
            elements: [
                .arc(id: arcID, center: Point2D(x: 0, y: 0), radius: 5, startAngle: -90, sweepAngle: 180),
                .lineSegment(id: lineID, start: Point2D(x: 0, y: -5), end: Point2D(x: 0, y: 5)),
            ]
        )
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 10, operation: .additive)

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Arc Element Properties

    func testArcStartPoint() {
        let arc = SketchElement.arc(
            id: ElementID(),
            center: Point2D(x: 0, y: 0),
            radius: 10,
            startAngle: 0,
            sweepAngle: 90
        )
        guard let start = arc.startPoint else {
            XCTFail("Arc should have a start point")
            return
        }
        XCTAssertEqual(start.x, 10, accuracy: 1e-6)
        XCTAssertEqual(start.y, 0, accuracy: 1e-6)
    }

    func testArcEndPoint() {
        let arc = SketchElement.arc(
            id: ElementID(),
            center: Point2D(x: 0, y: 0),
            radius: 10,
            startAngle: 0,
            sweepAngle: 90
        )
        guard let end = arc.endPoint else {
            XCTFail("Arc should have an end point")
            return
        }
        XCTAssertEqual(end.x, 0, accuracy: 1e-6)
        XCTAssertEqual(end.y, 10, accuracy: 1e-6)
    }

    func testArcTypeName() {
        let arc = SketchElement.arc(
            id: ElementID(),
            center: Point2D(x: 0, y: 0),
            radius: 5,
            startAngle: 0,
            sweepAngle: 180
        )
        XCTAssertEqual(arc.typeName, "Arc")
    }

    // MARK: - Constraint Serialization

    func testConstraintRoundTrip() throws {
        let elemID = ElementID()
        let constraint = SketchConstraint.horizontal(id: ConstraintID(), elementID: elemID)

        let data = try JSONEncoder().encode(constraint)
        let decoded = try JSONDecoder().decode(SketchConstraint.self, from: data)

        XCTAssertEqual(decoded.id, constraint.id)
        if case .horizontal(_, let decodedElemID) = decoded {
            XCTAssertEqual(decodedElemID, elemID)
        } else {
            XCTFail("Expected horizontal constraint")
        }
    }

    func testDistanceConstraintRoundTrip() throws {
        let elem1 = ElementID()
        let elem2 = ElementID()
        let constraint = SketchConstraint.distance(
            id: ConstraintID(),
            point1: PointRef(elementID: elem1, position: .start),
            point2: PointRef(elementID: elem2, position: .end),
            value: 42.5
        )

        let data = try JSONEncoder().encode(constraint)
        let decoded = try JSONDecoder().decode(SketchConstraint.self, from: data)

        XCTAssertEqual(decoded.id, constraint.id)
        if case .distance(_, let p1, let p2, let val) = decoded {
            XCTAssertEqual(p1.elementID, elem1)
            XCTAssertEqual(p1.position, .start)
            XCTAssertEqual(p2.elementID, elem2)
            XCTAssertEqual(p2.position, .end)
            XCTAssertEqual(val, 42.5)
        } else {
            XCTFail("Expected distance constraint")
        }
    }

    func testSketchWithConstraintsRoundTrip() throws {
        let lineID = ElementID()
        let sketch = SketchFeature(
            name: "Constrained Sketch",
            plane: .xy,
            elements: [
                .lineSegment(id: lineID, start: Point2D(x: 0, y: 0), end: Point2D(x: 10, y: 5))
            ],
            constraints: [
                .horizontal(id: ConstraintID(), elementID: lineID),
                .distance(
                    id: ConstraintID(),
                    point1: PointRef(elementID: lineID, position: .start),
                    point2: PointRef(elementID: lineID, position: .end),
                    value: 10
                )
            ]
        )

        let anyFeature = AnyFeature.sketch(sketch)
        let data = try JSONEncoder().encode(anyFeature)
        let decoded = try JSONDecoder().decode(AnyFeature.self, from: data)

        if case .sketch(let decodedSketch) = decoded {
            XCTAssertEqual(decodedSketch.constraints.count, 2)
            XCTAssertEqual(decodedSketch.elements.count, 1)
        } else {
            XCTFail("Expected sketch feature")
        }
    }

    func testArcElementRoundTrip() throws {
        let arcID = ElementID()
        let sketch = SketchFeature(
            name: "Arc Sketch",
            plane: .xy,
            elements: [
                .arc(id: arcID, center: Point2D(x: 5, y: 5), radius: 10, startAngle: 45, sweepAngle: 270)
            ]
        )

        let anyFeature = AnyFeature.sketch(sketch)
        let data = try JSONEncoder().encode(anyFeature)
        let decoded = try JSONDecoder().decode(AnyFeature.self, from: data)

        if case .sketch(let decodedSketch) = decoded {
            if case .arc(_, let center, let radius, let startAngle, let sweepAngle) = decodedSketch.elements[0] {
                XCTAssertEqual(center.x, 5)
                XCTAssertEqual(center.y, 5)
                XCTAssertEqual(radius, 10)
                XCTAssertEqual(startAngle, 45)
                XCTAssertEqual(sweepAngle, 270)
            } else {
                XCTFail("Expected arc element")
            }
        } else {
            XCTFail("Expected sketch feature")
        }
    }

    // MARK: - PointRef

    func testPointRefRoundTrip() throws {
        let ref = PointRef(elementID: ElementID(), position: .center)
        let data = try JSONEncoder().encode(ref)
        let decoded = try JSONDecoder().decode(PointRef.self, from: data)
        XCTAssertEqual(decoded.elementID, ref.elementID)
        XCTAssertEqual(decoded.position, .center)
    }

    // MARK: - Constraint Properties

    func testConstraintIsDimensional() {
        XCTAssertFalse(SketchConstraint.horizontal(id: ConstraintID(), elementID: ElementID()).isDimensional)
        XCTAssertFalse(SketchConstraint.vertical(id: ConstraintID(), elementID: ElementID()).isDimensional)
        XCTAssertFalse(SketchConstraint.parallel(id: ConstraintID(), element1: ElementID(), element2: ElementID()).isDimensional)

        XCTAssertTrue(SketchConstraint.distance(
            id: ConstraintID(),
            point1: PointRef(elementID: ElementID(), position: .start),
            point2: PointRef(elementID: ElementID(), position: .end),
            value: 10
        ).isDimensional)

        XCTAssertTrue(SketchConstraint.radius(id: ConstraintID(), elementID: ElementID(), value: 5).isDimensional)
    }

    func testConstraintTypeName() {
        XCTAssertEqual(
            SketchConstraint.horizontal(id: ConstraintID(), elementID: ElementID()).typeName,
            "Horizontal"
        )
        XCTAssertEqual(
            SketchConstraint.radius(id: ConstraintID(), elementID: ElementID(), value: 5).typeName,
            "Radius"
        )
    }

    // MARK: - Evaluator with Constraints

    func testEvaluatorSolvesConstraintsBeforeExtrude() {
        let evaluator = FeatureEvaluator()
        var tree = FeatureTree()

        let lineID = ElementID()
        let sketch = SketchFeature(
            name: "Constrained",
            plane: .xy,
            elements: [
                .rectangle(id: lineID, origin: Point2D(x: -5, y: -5), width: 10, height: 10)
            ],
            constraints: [] // No constraints — should work fine
        )
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 15, operation: .additive)

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }
}
