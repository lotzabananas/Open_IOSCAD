import XCTest
@testable import ParametricEngine
import GeometryKernel

final class ProfileExtractorTests: XCTestCase {

    func testRectangleToPolygon() {
        let element = SketchElement.rectangle(
            id: ElementID(),
            origin: Point2D(x: 0, y: 0),
            width: 10,
            height: 5
        )
        let result = ProfileExtractor.extractProfile(from: [element])

        switch result {
        case .success(let polygon):
            XCTAssertEqual(polygon.points.count, 4)
            // Check that the polygon is counter-clockwise
            XCTAssertFalse(polygon.isClockwise)
        case .failure(let error):
            XCTFail("Expected success, got error: \(error)")
        }
    }

    func testCenteredRectangleToPolygon() {
        let element = SketchElement.rectangle(
            id: ElementID(),
            origin: Point2D(x: -5, y: -2.5),
            width: 10,
            height: 5
        )
        let result = ProfileExtractor.extractProfile(from: [element])

        switch result {
        case .success(let polygon):
            XCTAssertEqual(polygon.points.count, 4)
            // Verify bounds encompass the expected area
            let minX = polygon.points.map(\.x).min()!
            let maxX = polygon.points.map(\.x).max()!
            XCTAssertEqual(minX, -5, accuracy: 0.01)
            XCTAssertEqual(maxX, 5, accuracy: 0.01)
        case .failure(let error):
            XCTFail("Expected success, got error: \(error)")
        }
    }

    func testCircleToPolygon() {
        let element = SketchElement.circle(
            id: ElementID(),
            center: Point2D(x: 0, y: 0),
            radius: 5
        )
        let result = ProfileExtractor.extractProfile(from: [element])

        switch result {
        case .success(let polygon):
            XCTAssertEqual(polygon.points.count, 32) // Default 32 segments
            XCTAssertFalse(polygon.isClockwise)

            // Check that all points are approximately at radius 5
            for point in polygon.points {
                let dist = sqrt(point.x * point.x + point.y * point.y)
                XCTAssertEqual(dist, 5.0, accuracy: 0.1)
            }
        case .failure(let error):
            XCTFail("Expected success, got error: \(error)")
        }
    }

    func testEmptySketchFails() {
        let result = ProfileExtractor.extractProfile(from: [])
        switch result {
        case .success:
            XCTFail("Expected failure for empty sketch")
        case .failure(let error):
            if case .emptySketch = error {} else {
                XCTFail("Expected emptySketch error, got: \(error)")
            }
        }
    }

    func testSingleLineSegmentFails() {
        let element = SketchElement.lineSegment(
            id: ElementID(),
            start: Point2D(x: 0, y: 0),
            end: Point2D(x: 10, y: 0)
        )
        let result = ProfileExtractor.extractProfile(from: [element])
        switch result {
        case .success:
            XCTFail("Expected failure for single line segment")
        case .failure(let error):
            if case .openProfile = error {} else {
                XCTFail("Expected openProfile error, got: \(error)")
            }
        }
    }

    func testClosedTriangleFromLineSegments() {
        let elements: [SketchElement] = [
            .lineSegment(id: ElementID(), start: Point2D(x: 0, y: 0), end: Point2D(x: 10, y: 0)),
            .lineSegment(id: ElementID(), start: Point2D(x: 10, y: 0), end: Point2D(x: 5, y: 10)),
            .lineSegment(id: ElementID(), start: Point2D(x: 5, y: 10), end: Point2D(x: 0, y: 0)),
        ]
        let result = ProfileExtractor.extractProfile(from: elements)

        switch result {
        case .success(let polygon):
            XCTAssertEqual(polygon.points.count, 3)
            XCTAssertFalse(polygon.isClockwise)
        case .failure(let error):
            XCTFail("Expected success for closed triangle, got: \(error)")
        }
    }

    func testInvalidRectangleDimensions() {
        let element = SketchElement.rectangle(
            id: ElementID(),
            origin: Point2D(x: 0, y: 0),
            width: -5,
            height: 10
        )
        let result = ProfileExtractor.extractProfile(from: [element])
        switch result {
        case .success:
            XCTFail("Expected failure for negative width")
        case .failure(let error):
            if case .invalidDimensions = error {} else {
                XCTFail("Expected invalidDimensions error, got: \(error)")
            }
        }
    }

    func testInvalidCircleRadius() {
        let element = SketchElement.circle(
            id: ElementID(),
            center: Point2D(x: 0, y: 0),
            radius: 0
        )
        let result = ProfileExtractor.extractProfile(from: [element])
        switch result {
        case .success:
            XCTFail("Expected failure for zero radius")
        case .failure(let error):
            if case .invalidDimensions = error {} else {
                XCTFail("Expected invalidDimensions error, got: \(error)")
            }
        }
    }
}
