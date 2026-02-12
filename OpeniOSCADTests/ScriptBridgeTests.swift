import XCTest
@testable import OpeniOSCAD

final class ScriptBridgeTests: XCTestCase {

    // MARK: - Feature Name Generation

    func testNextFeatureNameEmpty() {
        let name = ScriptBridge.nextFeatureName(for: "cube", in: "")
        XCTAssertEqual(name, "Cube 1")
    }

    func testNextFeatureNameIncrementsExisting() {
        let script = """
        // @feature "Cube 1"
        cube([10, 10, 10]);
        // @feature "Cube 2"
        cube([20, 20, 20]);
        """
        let name = ScriptBridge.nextFeatureName(for: "cube", in: script)
        XCTAssertEqual(name, "Cube 3")
    }

    func testNextFeatureNameDifferentTypes() {
        let script = """
        // @feature "Cube 1"
        cube([10, 10, 10]);
        """
        let cubeName = ScriptBridge.nextFeatureName(for: "cube", in: script)
        let cylName = ScriptBridge.nextFeatureName(for: "cylinder", in: script)
        XCTAssertEqual(cubeName, "Cube 2")
        XCTAssertEqual(cylName, "Cylinder 1")
    }

    // MARK: - Primitive Insertion

    func testInsertPrimitiveToEmpty() {
        let result = ScriptBridge.insertPrimitive(.cube, in: "", afterFeatureIndex: nil)
        XCTAssertTrue(result.contains("// @feature \"Cube 1\""))
        XCTAssertTrue(result.contains("cube([10, 10, 10]);"))
    }

    func testInsertPrimitiveAppends() {
        let script = "// @feature \"Cube 1\"\ncube([10, 10, 10]);\n"
        let result = ScriptBridge.insertPrimitive(.cylinder, in: script, afterFeatureIndex: nil)
        XCTAssertTrue(result.contains("// @feature \"Cylinder 1\""))
        XCTAssertTrue(result.contains("cylinder(h=10, r=5, $fn=32);"))
        XCTAssertTrue(result.contains("cube([10, 10, 10]);"))
    }

    func testInsertAfterFeature() {
        let script = """
        // @feature "Cube 1"
        cube([10, 10, 10]);

        // @feature "Sphere 1"
        sphere(r=5, $fn=32);
        """
        let result = ScriptBridge.insertPrimitive(.cylinder, in: script, afterFeatureIndex: 0)
        let lines = result.components(separatedBy: "\n")

        let cubeAnnotation = lines.firstIndex(where: { $0.contains("@feature \"Cube 1\"") })!
        let cylAnnotation = lines.firstIndex(where: { $0.contains("@feature \"Cylinder 1\"") })!
        let sphereAnnotation = lines.firstIndex(where: { $0.contains("@feature \"Sphere 1\"") })!

        XCTAssertLessThan(cubeAnnotation, cylAnnotation)
        XCTAssertLessThan(cylAnnotation, sphereAnnotation)
    }

    // MARK: - Script Block Generation

    func testCubeBlockGeneration() {
        let block = ScriptBridge.scriptBlock(for: .cube, featureName: "Cube 1")
        XCTAssertEqual(block, "// @feature \"Cube 1\"\ncube([10, 10, 10]);\n")
    }

    func testCylinderBlockGeneration() {
        let block = ScriptBridge.scriptBlock(for: .cylinder, featureName: "Cylinder 1")
        XCTAssertEqual(block, "// @feature \"Cylinder 1\"\ncylinder(h=10, r=5, $fn=32);\n")
    }

    func testSphereBlockGeneration() {
        let block = ScriptBridge.scriptBlock(for: .sphere, featureName: "Sphere 1")
        XCTAssertEqual(block, "// @feature \"Sphere 1\"\nsphere(r=5, $fn=32);\n")
    }

    // MARK: - Feature Block Parsing

    func testParseFeatureBlocks() {
        let script = """
        // @feature "Cube 1"
        cube([10, 10, 10]);

        // @feature "Cylinder 1"
        cylinder(h=10, r=5, $fn=32);
        """
        let blocks = ScriptBridge.featureBlocks(in: script)
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].name, "Cube 1")
        XCTAssertEqual(blocks[1].name, "Cylinder 1")
        XCTAssertFalse(blocks[0].isSuppressed)
    }

    func testParseSuppressedFeatureBlock() {
        let script = """
        // @feature [suppressed] "Cube 1"
        // cube([10, 10, 10]);
        """
        let blocks = ScriptBridge.featureBlocks(in: script)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].name, "Cube 1")
        XCTAssertTrue(blocks[0].isSuppressed)
    }

    // MARK: - Suppress

    func testSuppressFeature() {
        let script = """
        // @feature "Cube 1"
        cube([10, 10, 10]);
        """
        let result = ScriptBridge.suppressFeature(at: 0, in: script)
        XCTAssertTrue(result.contains("[suppressed]"))
        XCTAssertTrue(result.contains("// cube([10, 10, 10]);"))
    }

    func testUnsuppressFeature() {
        let script = """
        // @feature [suppressed] "Cube 1"
        // cube([10, 10, 10]);
        """
        let result = ScriptBridge.suppressFeature(at: 0, in: script)
        XCTAssertFalse(result.contains("[suppressed]"))
        XCTAssertTrue(result.contains("cube([10, 10, 10]);"))
        // Make sure comment prefix was removed
        let lines = result.components(separatedBy: "\n")
        let codeLine = lines.first(where: { $0.contains("cube(") })!
        XCTAssertFalse(codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("//"))
    }

    // MARK: - Delete

    func testDeleteFeature() {
        let script = """
        // @feature "Cube 1"
        cube([10, 10, 10]);

        // @feature "Cylinder 1"
        cylinder(h=10, r=5, $fn=32);
        """
        let result = ScriptBridge.deleteFeature(at: 0, in: script)
        XCTAssertFalse(result.contains("Cube 1"))
        XCTAssertTrue(result.contains("Cylinder 1"))
    }

    func testDeleteLastFeature() {
        let script = """
        // @feature "Cube 1"
        cube([10, 10, 10]);
        """
        let result = ScriptBridge.deleteFeature(at: 0, in: script)
        XCTAssertFalse(result.contains("cube"))
    }

    // MARK: - Rename

    func testRenameFeature() {
        let script = """
        // @feature "Cube 1"
        cube([10, 10, 10]);
        """
        let result = ScriptBridge.renameFeature(at: 0, to: "Base Plate", in: script)
        XCTAssertTrue(result.contains("// @feature \"Base Plate\""))
        XCTAssertFalse(result.contains("Cube 1"))
    }

    // MARK: - Move

    func testMoveFeatureForward() {
        let script = """
        // @feature "Cube 1"
        cube([10, 10, 10]);

        // @feature "Cylinder 1"
        cylinder(h=10, r=5, $fn=32);

        // @feature "Sphere 1"
        sphere(r=5, $fn=32);
        """
        let result = ScriptBridge.moveFeature(from: 0, to: 2, in: script)
        let blocks = ScriptBridge.featureBlocks(in: result)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].name, "Cylinder 1")
        XCTAssertEqual(blocks[1].name, "Cube 1")
        XCTAssertEqual(blocks[2].name, "Sphere 1")
    }

    func testMoveFeatureBackward() {
        let script = """
        // @feature "Cube 1"
        cube([10, 10, 10]);

        // @feature "Cylinder 1"
        cylinder(h=10, r=5, $fn=32);

        // @feature "Sphere 1"
        sphere(r=5, $fn=32);
        """
        let result = ScriptBridge.moveFeature(from: 2, to: 0, in: script)
        let blocks = ScriptBridge.featureBlocks(in: result)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].name, "Sphere 1")
        XCTAssertEqual(blocks[1].name, "Cube 1")
        XCTAssertEqual(blocks[2].name, "Cylinder 1")
    }

    // MARK: - Round-Trip Validation

    func testGeneratedScriptIsValidOpenSCAD() {
        var script = ""
        script = ScriptBridge.insertPrimitive(.cube, in: script, afterFeatureIndex: nil)
        script = ScriptBridge.insertPrimitive(.cylinder, in: script, afterFeatureIndex: nil)
        script = ScriptBridge.insertPrimitive(.sphere, in: script, afterFeatureIndex: nil)

        XCTAssertTrue(script.contains("// @feature \"Cube 1\""))
        XCTAssertTrue(script.contains("// @feature \"Cylinder 1\""))
        XCTAssertTrue(script.contains("// @feature \"Sphere 1\""))

        let blocks = ScriptBridge.featureBlocks(in: script)
        XCTAssertEqual(blocks.count, 3)
    }

    func testFullWorkflow() {
        // Add cube
        var script = ScriptBridge.insertPrimitive(.cube, in: "", afterFeatureIndex: nil)

        // Add cylinder
        script = ScriptBridge.insertPrimitive(.cylinder, in: script, afterFeatureIndex: nil)

        // Suppress the cube
        script = ScriptBridge.suppressFeature(at: 0, in: script)
        var blocks = ScriptBridge.featureBlocks(in: script)
        XCTAssertTrue(blocks[0].isSuppressed)
        XCTAssertFalse(blocks[1].isSuppressed)

        // Unsuppress
        script = ScriptBridge.suppressFeature(at: 0, in: script)
        blocks = ScriptBridge.featureBlocks(in: script)
        XCTAssertFalse(blocks[0].isSuppressed)

        // Rename
        script = ScriptBridge.renameFeature(at: 0, to: "My Cube", in: script)
        blocks = ScriptBridge.featureBlocks(in: script)
        XCTAssertEqual(blocks[0].name, "My Cube")

        // Delete
        script = ScriptBridge.deleteFeature(at: 0, in: script)
        blocks = ScriptBridge.featureBlocks(in: script)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].name, "Cylinder 1")
    }
}
