import XCTest
@testable import ParametricEngine

final class FeatureTreeTests: XCTestCase {

    func testEmptyTree() {
        let tree = FeatureTree()
        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
    }

    func testAppendAndCount() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        tree.append(.sketch(sketch))
        XCTAssertEqual(tree.count, 1)
        XCTAssertFalse(tree.isEmpty)
    }

    func testLookupByID() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        tree.append(.sketch(sketch))

        let found = tree.feature(byID: sketch.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "S1")
    }

    func testLookupByIndex() {
        var tree = FeatureTree()
        let s1 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let s2 = SketchFeature.circleOnXY(radius: 5, name: "S2")
        tree.append(.sketch(s1))
        tree.append(.sketch(s2))

        let first = tree.feature(at: 0)
        XCTAssertEqual(first?.name, "S1")
        let second = tree.feature(at: 1)
        XCTAssertEqual(second?.name, "S2")
        XCTAssertNil(tree.feature(at: 5))
    }

    func testRemoveAtIndex() {
        var tree = FeatureTree()
        let s1 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let s2 = SketchFeature.circleOnXY(radius: 5, name: "S2")
        tree.append(.sketch(s1))
        tree.append(.sketch(s2))

        tree.remove(at: 0)
        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree.feature(at: 0)?.name, "S2")
    }

    func testRemoveByID() {
        var tree = FeatureTree()
        let s1 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        tree.append(.sketch(s1))

        tree.removeByID(s1.id)
        XCTAssertTrue(tree.isEmpty)
    }

    func testMove() {
        var tree = FeatureTree()
        let s1 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let s2 = SketchFeature.circleOnXY(radius: 5, name: "S2")
        let s3 = SketchFeature.circleOnXY(radius: 3, name: "S3")
        tree.append(.sketch(s1))
        tree.append(.sketch(s2))
        tree.append(.sketch(s3))

        // Move S3 (index 2) to index 0
        tree.move(from: 2, to: 0)
        XCTAssertEqual(tree.feature(at: 0)?.name, "S3")
        XCTAssertEqual(tree.feature(at: 1)?.name, "S1")
        XCTAssertEqual(tree.feature(at: 2)?.name, "S2")
    }

    func testToggleSuppressed() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        tree.append(.sketch(sketch))

        XCTAssertFalse(tree.feature(at: 0)?.isSuppressed ?? true)
        tree.toggleSuppressed(at: 0)
        XCTAssertTrue(tree.feature(at: 0)?.isSuppressed ?? false)
        tree.toggleSuppressed(at: 0)
        XCTAssertFalse(tree.feature(at: 0)?.isSuppressed ?? true)
    }

    func testRename() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        tree.append(.sketch(sketch))

        tree.rename(at: 0, to: "My Box Sketch")
        XCTAssertEqual(tree.feature(at: 0)?.name, "My Box Sketch")
    }

    func testActiveFeatures() {
        var tree = FeatureTree()
        let s1 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let s2 = SketchFeature.circleOnXY(radius: 5, name: "S2")
        tree.append(.sketch(s1))
        tree.append(.sketch(s2))

        tree.toggleSuppressed(at: 0)
        XCTAssertEqual(tree.activeFeatures.count, 1)
        XCTAssertEqual(tree.activeFeatures[0].name, "S2")
    }

    func testIndexOfID() {
        var tree = FeatureTree()
        let s1 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        let s2 = SketchFeature.circleOnXY(radius: 5, name: "S2")
        tree.append(.sketch(s1))
        tree.append(.sketch(s2))

        XCTAssertEqual(tree.index(ofID: s1.id), 0)
        XCTAssertEqual(tree.index(ofID: s2.id), 1)
        XCTAssertNil(tree.index(ofID: FeatureID()))
    }
}
