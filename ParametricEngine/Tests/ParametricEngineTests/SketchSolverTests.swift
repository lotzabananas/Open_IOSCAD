import XCTest
@testable import ParametricEngine

final class SketchSolverTests: XCTestCase {

    // MARK: - No constraints

    func testNoConstraintsReturnsOriginalElements() {
        let elements: [SketchElement] = [
            .lineSegment(id: ElementID(), start: Point2D(x: 0, y: 0), end: Point2D(x: 10, y: 5))
        ]
        let result = SketchSolver.solve(elements: elements, constraints: [])

        XCTAssertTrue(result.converged)
        XCTAssertEqual(result.residual, 0)
        XCTAssertEqual(result.degreesOfFreedom, 4) // line: 4 params
        XCTAssertEqual(result.elements.count, 1)
    }

    // MARK: - Horizontal constraint

    func testHorizontalConstraintMakesLineHorizontal() {
        let lineID = ElementID()
        let elements: [SketchElement] = [
            .lineSegment(id: lineID, start: Point2D(x: 0, y: 0), end: Point2D(x: 10, y: 5))
        ]
        let constraints: [SketchConstraint] = [
            .horizontal(id: ConstraintID(), elementID: lineID)
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertTrue(result.converged)

        if case .lineSegment(_, let start, let end) = result.elements[0] {
            XCTAssertEqual(start.y, end.y, accuracy: 1e-6)
        } else {
            XCTFail("Expected line segment")
        }
    }

    // MARK: - Vertical constraint

    func testVerticalConstraintMakesLineVertical() {
        let lineID = ElementID()
        let elements: [SketchElement] = [
            .lineSegment(id: lineID, start: Point2D(x: 0, y: 0), end: Point2D(x: 5, y: 10))
        ]
        let constraints: [SketchConstraint] = [
            .vertical(id: ConstraintID(), elementID: lineID)
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertTrue(result.converged)

        if case .lineSegment(_, let start, let end) = result.elements[0] {
            XCTAssertEqual(start.x, end.x, accuracy: 1e-6)
        } else {
            XCTFail("Expected line segment")
        }
    }

    // MARK: - Fixed point constraint

    func testFixedPointLocksPosition() {
        let lineID = ElementID()
        let elements: [SketchElement] = [
            .lineSegment(id: lineID, start: Point2D(x: 1, y: 2), end: Point2D(x: 10, y: 5))
        ]
        let constraints: [SketchConstraint] = [
            .fixedPoint(
                id: ConstraintID(),
                point: PointRef(elementID: lineID, position: .start),
                x: 0, y: 0
            )
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertTrue(result.converged)

        if case .lineSegment(_, let start, _) = result.elements[0] {
            XCTAssertEqual(start.x, 0, accuracy: 1e-6)
            XCTAssertEqual(start.y, 0, accuracy: 1e-6)
        } else {
            XCTFail("Expected line segment")
        }
    }

    // MARK: - Coincident constraint

    func testCoincidentMakesTwoPointsMeet() {
        let line1ID = ElementID()
        let line2ID = ElementID()
        let elements: [SketchElement] = [
            .lineSegment(id: line1ID, start: Point2D(x: 0, y: 0), end: Point2D(x: 10, y: 0)),
            .lineSegment(id: line2ID, start: Point2D(x: 12, y: 3), end: Point2D(x: 20, y: 5)),
        ]
        let constraints: [SketchConstraint] = [
            .coincident(
                id: ConstraintID(),
                point1: PointRef(elementID: line1ID, position: .end),
                point2: PointRef(elementID: line2ID, position: .start)
            )
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertTrue(result.converged)

        if case .lineSegment(_, _, let end1) = result.elements[0],
           case .lineSegment(_, let start2, _) = result.elements[1] {
            XCTAssertEqual(end1.x, start2.x, accuracy: 1e-4)
            XCTAssertEqual(end1.y, start2.y, accuracy: 1e-4)
        } else {
            XCTFail("Expected two line segments")
        }
    }

    // MARK: - Distance constraint

    func testDistanceConstraintSetsLength() {
        let lineID = ElementID()
        let elements: [SketchElement] = [
            .lineSegment(id: lineID, start: Point2D(x: 0, y: 0), end: Point2D(x: 7, y: 0))
        ]
        let constraints: [SketchConstraint] = [
            .distance(
                id: ConstraintID(),
                point1: PointRef(elementID: lineID, position: .start),
                point2: PointRef(elementID: lineID, position: .end),
                value: 10
            ),
            .fixedPoint(
                id: ConstraintID(),
                point: PointRef(elementID: lineID, position: .start),
                x: 0, y: 0
            ),
            .horizontal(id: ConstraintID(), elementID: lineID)
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertTrue(result.converged)

        if case .lineSegment(_, let start, let end) = result.elements[0] {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let dist = (dx * dx + dy * dy).squareRoot()
            XCTAssertEqual(dist, 10, accuracy: 1e-4)
        } else {
            XCTFail("Expected line segment")
        }
    }

    // MARK: - Radius constraint

    func testRadiusConstraintSetsCircleRadius() {
        let circleID = ElementID()
        let elements: [SketchElement] = [
            .circle(id: circleID, center: Point2D(x: 0, y: 0), radius: 7)
        ]
        let constraints: [SketchConstraint] = [
            .radius(id: ConstraintID(), elementID: circleID, value: 15)
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertTrue(result.converged)

        if case .circle(_, _, let radius) = result.elements[0] {
            XCTAssertEqual(radius, 15, accuracy: 1e-4)
        } else {
            XCTFail("Expected circle")
        }
    }

    func testRadiusConstraintSetsArcRadius() {
        let arcID = ElementID()
        let elements: [SketchElement] = [
            .arc(id: arcID, center: Point2D(x: 0, y: 0), radius: 5, startAngle: 0, sweepAngle: 90)
        ]
        let constraints: [SketchConstraint] = [
            .radius(id: ConstraintID(), elementID: arcID, value: 12)
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertTrue(result.converged)

        if case .arc(_, _, let radius, _, _) = result.elements[0] {
            XCTAssertEqual(radius, 12, accuracy: 1e-4)
        } else {
            XCTFail("Expected arc")
        }
    }

    // MARK: - Parallel constraint

    func testParallelConstraintMakesLinesParallel() {
        let l1 = ElementID()
        let l2 = ElementID()
        let elements: [SketchElement] = [
            .lineSegment(id: l1, start: Point2D(x: 0, y: 0), end: Point2D(x: 10, y: 0)),
            .lineSegment(id: l2, start: Point2D(x: 0, y: 5), end: Point2D(x: 10, y: 8)),
        ]
        let constraints: [SketchConstraint] = [
            .parallel(id: ConstraintID(), element1: l1, element2: l2)
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertTrue(result.converged)

        if case .lineSegment(_, let s1, let e1) = result.elements[0],
           case .lineSegment(_, let s2, let e2) = result.elements[1] {
            let dx1 = e1.x - s1.x, dy1 = e1.y - s1.y
            let dx2 = e2.x - s2.x, dy2 = e2.y - s2.y
            let cross = dx1 * dy2 - dy1 * dx2
            XCTAssertEqual(cross, 0, accuracy: 1e-4)
        } else {
            XCTFail("Expected two line segments")
        }
    }

    // MARK: - Perpendicular constraint

    func testPerpendicularConstraintMakesLinesPerpendicular() {
        let l1 = ElementID()
        let l2 = ElementID()
        let elements: [SketchElement] = [
            .lineSegment(id: l1, start: Point2D(x: 0, y: 0), end: Point2D(x: 10, y: 0)),
            .lineSegment(id: l2, start: Point2D(x: 5, y: 0), end: Point2D(x: 5, y: 8)),
        ]
        let constraints: [SketchConstraint] = [
            .perpendicular(id: ConstraintID(), element1: l1, element2: l2)
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertTrue(result.converged)

        if case .lineSegment(_, let s1, let e1) = result.elements[0],
           case .lineSegment(_, let s2, let e2) = result.elements[1] {
            let dx1 = e1.x - s1.x, dy1 = e1.y - s1.y
            let dx2 = e2.x - s2.x, dy2 = e2.y - s2.y
            let dot = dx1 * dx2 + dy1 * dy2
            XCTAssertEqual(dot, 0, accuracy: 1e-4)
        } else {
            XCTFail("Expected two line segments")
        }
    }

    // MARK: - Equal constraint

    func testEqualConstraintMakesLinesEqualLength() {
        let l1 = ElementID()
        let l2 = ElementID()
        let elements: [SketchElement] = [
            .lineSegment(id: l1, start: Point2D(x: 0, y: 0), end: Point2D(x: 10, y: 0)),
            .lineSegment(id: l2, start: Point2D(x: 0, y: 5), end: Point2D(x: 7, y: 5)),
        ]
        let constraints: [SketchConstraint] = [
            .equal(id: ConstraintID(), element1: l1, element2: l2)
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertTrue(result.converged)

        func length(_ el: SketchElement) -> Double {
            if case .lineSegment(_, let s, let e) = el {
                let dx = e.x - s.x, dy = e.y - s.y
                return (dx * dx + dy * dy).squareRoot()
            }
            return 0
        }

        XCTAssertEqual(length(result.elements[0]), length(result.elements[1]), accuracy: 1e-4)
    }

    // MARK: - Concentric constraint

    func testConcentricConstraintSharesCenter() {
        let c1 = ElementID()
        let c2 = ElementID()
        let elements: [SketchElement] = [
            .circle(id: c1, center: Point2D(x: 0, y: 0), radius: 5),
            .circle(id: c2, center: Point2D(x: 3, y: 4), radius: 10),
        ]
        let constraints: [SketchConstraint] = [
            .concentric(id: ConstraintID(), element1: c1, element2: c2)
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertTrue(result.converged)

        if case .circle(_, let center1, _) = result.elements[0],
           case .circle(_, let center2, _) = result.elements[1] {
            XCTAssertEqual(center1.x, center2.x, accuracy: 1e-4)
            XCTAssertEqual(center1.y, center2.y, accuracy: 1e-4)
        } else {
            XCTFail("Expected two circles")
        }
    }

    // MARK: - Multiple constraints

    func testFullyConstrainedRightTriangle() {
        let l1 = ElementID()
        let l2 = ElementID()
        let l3 = ElementID()
        let elements: [SketchElement] = [
            .lineSegment(id: l1, start: Point2D(x: 0, y: 0), end: Point2D(x: 10, y: 0)),
            .lineSegment(id: l2, start: Point2D(x: 10, y: 0), end: Point2D(x: 10, y: 7)),
            .lineSegment(id: l3, start: Point2D(x: 10, y: 7), end: Point2D(x: 0, y: 0)),
        ]
        let constraints: [SketchConstraint] = [
            // Fix the origin
            .fixedPoint(id: ConstraintID(), point: PointRef(elementID: l1, position: .start), x: 0, y: 0),
            // Bottom edge is horizontal
            .horizontal(id: ConstraintID(), elementID: l1),
            // Right edge is vertical
            .vertical(id: ConstraintID(), elementID: l2),
            // Connect edges
            .coincident(id: ConstraintID(),
                        point1: PointRef(elementID: l1, position: .end),
                        point2: PointRef(elementID: l2, position: .start)),
            .coincident(id: ConstraintID(),
                        point1: PointRef(elementID: l2, position: .end),
                        point2: PointRef(elementID: l3, position: .start)),
            .coincident(id: ConstraintID(),
                        point1: PointRef(elementID: l3, position: .end),
                        point2: PointRef(elementID: l1, position: .start)),
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertTrue(result.converged)
        XCTAssertLessThan(result.residual, 1e-6)
    }

    // MARK: - DOF calculation

    func testDOFCalculation() {
        // A single line with 4 params and 1 constraint (horizontal) = 3 DOF
        let lineID = ElementID()
        let elements: [SketchElement] = [
            .lineSegment(id: lineID, start: Point2D(x: 0, y: 0), end: Point2D(x: 10, y: 5))
        ]
        let constraints: [SketchConstraint] = [
            .horizontal(id: ConstraintID(), elementID: lineID)
        ]

        let result = SketchSolver.solve(elements: elements, constraints: constraints)
        XCTAssertEqual(result.degreesOfFreedom, 3) // 4 params - 1 constraint = 3 DOF
    }

    // MARK: - Parameterization

    func testParamCountForAllElementTypes() {
        XCTAssertEqual(SketchSolver.paramCount(for:
            .rectangle(id: ElementID(), origin: Point2D(x: 0, y: 0), width: 1, height: 1)), 4)
        XCTAssertEqual(SketchSolver.paramCount(for:
            .circle(id: ElementID(), center: Point2D(x: 0, y: 0), radius: 1)), 3)
        XCTAssertEqual(SketchSolver.paramCount(for:
            .lineSegment(id: ElementID(), start: Point2D(x: 0, y: 0), end: Point2D(x: 1, y: 1))), 4)
        XCTAssertEqual(SketchSolver.paramCount(for:
            .arc(id: ElementID(), center: Point2D(x: 0, y: 0), radius: 1, startAngle: 0, sweepAngle: 90)), 5)
    }
}
