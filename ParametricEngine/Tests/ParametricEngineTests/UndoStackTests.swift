import XCTest
@testable import ParametricEngine

final class UndoStackTests: XCTestCase {

    func testInitialState() {
        let stack = UndoStack()
        XCTAssertFalse(stack.canUndo)
        XCTAssertFalse(stack.canRedo)
    }

    func testPushAndUndo() {
        let stack = UndoStack()

        var tree1 = FeatureTree()
        tree1.append(.sketch(SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")))
        stack.push(tree1)

        var tree2 = tree1
        tree2.append(.sketch(SketchFeature.circleOnXY(radius: 5, name: "S2")))
        stack.push(tree2)

        XCTAssertTrue(stack.canUndo)
        XCTAssertFalse(stack.canRedo)

        let undone = stack.undo()
        XCTAssertNotNil(undone)
        XCTAssertEqual(undone?.count, 1)
        XCTAssertTrue(stack.canRedo)
    }

    func testRedo() {
        let stack = UndoStack()

        let tree1 = FeatureTree()
        stack.push(tree1)

        var tree2 = FeatureTree()
        tree2.append(.sketch(SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")))
        stack.push(tree2)

        _ = stack.undo()
        XCTAssertTrue(stack.canRedo)

        let redone = stack.redo()
        XCTAssertNotNil(redone)
        XCTAssertEqual(redone?.count, 1)
    }

    func testPushClearsRedoStack() {
        let stack = UndoStack()

        let tree1 = FeatureTree()
        stack.push(tree1)

        var tree2 = FeatureTree()
        tree2.append(.sketch(SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")))
        stack.push(tree2)

        _ = stack.undo()
        XCTAssertTrue(stack.canRedo)

        // New push should clear redo
        var tree3 = FeatureTree()
        tree3.append(.sketch(SketchFeature.circleOnXY(radius: 3, name: "S3")))
        stack.push(tree3)

        XCTAssertFalse(stack.canRedo)
    }

    func testMultipleUndos() {
        let stack = UndoStack()

        for i in 0..<5 {
            var tree = FeatureTree()
            for j in 0...i {
                tree.append(.sketch(SketchFeature.rectangleOnXY(width: Double(j + 1), depth: 10, name: "S\(j)")))
            }
            stack.push(tree)
        }

        // Undo 4 times
        for expected in (1...4).reversed() {
            let undone = stack.undo()
            XCTAssertEqual(undone?.count, expected, "Expected \(expected) features after undo")
        }

        // Can't undo anymore
        XCTAssertFalse(stack.canUndo)
        XCTAssertNil(stack.undo())
    }

    func testReset() {
        let stack = UndoStack()
        stack.push(FeatureTree())
        stack.push(FeatureTree())

        stack.reset()
        XCTAssertFalse(stack.canUndo)
        XCTAssertFalse(stack.canRedo)
        XCTAssertEqual(stack.snapshotCount, 0)
    }

    func testMaxSnapshots() {
        let stack = UndoStack(maxSnapshots: 5)

        for i in 0..<10 {
            var tree = FeatureTree()
            tree.append(.sketch(SketchFeature.rectangleOnXY(width: Double(i), depth: 10, name: "S\(i)")))
            stack.push(tree)
        }

        XCTAssertEqual(stack.snapshotCount, 5)
    }
}
