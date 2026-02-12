import XCTest
@testable import SCADEngine

final class CustomizerTests: XCTestCase {
    let extractor = CustomizerExtractor()

    func testSimpleSlider() {
        let source = "width = 40; // [10:100] Bracket width\n"
        let params = extractor.extract(from: source)
        XCTAssertEqual(params.count, 1)
        XCTAssertEqual(params[0].name, "width")
        XCTAssertEqual(params[0].label, "Bracket width")
        XCTAssertEqual(params[0].defaultValue, .number(40))
        XCTAssertEqual(params[0].constraint, .range(min: 10, step: nil, max: 100))
    }

    func testStepSlider() {
        let source = "height = 25; // [10:2:50] Height\n"
        let params = extractor.extract(from: source)
        XCTAssertEqual(params.count, 1)
        XCTAssertEqual(params[0].constraint, .range(min: 10, step: 2, max: 50))
    }

    func testEnumDropdown() {
        let source = "style = \"round\"; // [round, square, hex] Style\n"
        let params = extractor.extract(from: source)
        XCTAssertEqual(params.count, 1)
        XCTAssertEqual(params[0].constraint, .enumList(["round", "square", "hex"]))
        XCTAssertEqual(params[0].defaultValue, .string("round"))
    }

    func testBoolCheckbox() {
        let source = "show_holes = true; //\n"
        let params = extractor.extract(from: source)
        XCTAssertEqual(params.count, 1)
        XCTAssertEqual(params[0].defaultValue, .boolean(true))
    }

    func testNoAnnotation() {
        let source = "name = \"Part\"; //\n"
        let params = extractor.extract(from: source)
        XCTAssertEqual(params.count, 1)
        XCTAssertEqual(params[0].defaultValue, .string("Part"))
    }

    func testGroupHeader() {
        let source = """
        /* [Dimensions] */
        wall = 3; // [1:10]
        height = 20; // [5:50]
        /* [Options] */
        rounded = true; //
        """
        let params = extractor.extract(from: source)
        XCTAssertEqual(params.count, 3)
        XCTAssertEqual(params[0].group, "Dimensions")
        XCTAssertEqual(params[1].group, "Dimensions")
        XCTAssertEqual(params[2].group, "Options")
    }

    func testMultipleParams() {
        let source = """
        width = 40; // [10:100] Bracket width
        height = 25; // [10:2:50] Height
        style = "round"; // [round, square, hex] Style
        count = 4; // [1:1:10]
        """
        let params = extractor.extract(from: source)
        XCTAssertEqual(params.count, 4)
        XCTAssertEqual(params[0].name, "width")
        XCTAssertEqual(params[1].name, "height")
        XCTAssertEqual(params[2].name, "style")
        XCTAssertEqual(params[3].name, "count")
    }

    func testLineNumbers() {
        let source = """
        width = 40; // [10:100]
        // comment
        height = 25; // [5:50]
        """
        let params = extractor.extract(from: source)
        XCTAssertEqual(params[0].lineNumber, 1)
        XCTAssertEqual(params[1].lineNumber, 3)
    }

    func testUpdateParameter() {
        let source = "width = 40; // [10:100] Bracket width\nheight = 25; // [10:50]\n"
        let updated = extractor.updateParameter(in: source, name: "width", newValue: .number(60))
        XCTAssertTrue(updated.contains("width = 60;"))
        XCTAssertTrue(updated.contains("// [10:100] Bracket width"))
        XCTAssertTrue(updated.contains("height = 25;"))
    }

    func testSourceOrder() {
        let source = """
        z = 1; // [0:10]
        a = 2; // [0:10]
        m = 3; // [0:10]
        """
        let params = extractor.extract(from: source)
        XCTAssertEqual(params[0].name, "z")
        XCTAssertEqual(params[1].name, "a")
        XCTAssertEqual(params[2].name, "m")
    }
}
