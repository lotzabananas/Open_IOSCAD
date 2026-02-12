import XCTest
@testable import ParametricEngine

final class HistoryCommentTests: XCTestCase {

    func testEncodeProducesMarkerComment() throws {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        tree.append(.sketch(sketch))

        let comment = try HistoryComment.encode(tree: tree)
        XCTAssertTrue(comment.hasPrefix("/* @openioscad"))
        XCTAssertTrue(comment.hasSuffix("*/"))
    }

    func testEncodeDecodeRoundTrip() throws {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 20, depth: 15, name: "My Sketch")
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 25, operation: .additive)
        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        let comment = try HistoryComment.encode(tree: tree)

        // Simulate a STEP file with the comment embedded
        let stepContent = """
        ISO-10303-21;
        HEADER;
        ENDSEC;
        DATA;
        \(comment)
        #1=CARTESIAN_POINT('',(0.,0.,0.));
        ENDSEC;
        END-ISO-10303-21;
        """

        let decoded = try HistoryComment.decode(from: stepContent)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 2)
        XCTAssertEqual(decoded?.features[0].name, "My Sketch")
        XCTAssertEqual(decoded?.features[1].name, "E1")
    }

    func testDecodeReturnsNilForMissingMarker() throws {
        let stepContent = """
        ISO-10303-21;
        HEADER;
        ENDSEC;
        DATA;
        #1=CARTESIAN_POINT('',(0.,0.,0.));
        ENDSEC;
        END-ISO-10303-21;
        """

        let result = try HistoryComment.decode(from: stepContent)
        XCTAssertNil(result)
    }

    func testVersionFieldPreserved() throws {
        var tree = FeatureTree()
        tree.append(.sketch(SketchFeature.rectangleOnXY(width: 5, depth: 5, name: "S")))

        let comment = try HistoryComment.encode(tree: tree)
        XCTAssertTrue(comment.contains("\"version\":1"))
    }
}
