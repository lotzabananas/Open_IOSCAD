import XCTest
@testable import SCADEngine
@testable import GeometryKernel

final class IntegrationTests: XCTestCase {
    private func parseAndEvaluate(_ source: String) throws -> TriangleMesh {
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        var parser = Parser(tokens: tokens)
        let ast = try parser.parse()
        let evaluator = Evaluator()
        let result = evaluator.evaluate(program: ast)
        XCTAssertTrue(result.errors.isEmpty, "Evaluation errors: \(result.errors)")
        let kernel = GeometryKernel()
        return kernel.evaluate(result.geometry)
    }

    func testSimpleCubeEndToEnd() throws {
        let mesh = try parseAndEvaluate("cube([10, 10, 10]);")
        XCTAssertEqual(mesh.triangleCount, 12)
        let bb = mesh.boundingBox
        XCTAssertEqual(bb.max.x, 10.0, accuracy: 0.01)
    }

    func testDifferenceEndToEnd() throws {
        let mesh = try parseAndEvaluate("""
        difference() {
            cube([20, 20, 20]);
            translate([5, 5, -1])
                cylinder(h=22, r=5, $fn=16);
        }
        """)
        XCTAssertGreaterThan(mesh.triangleCount, 0)
    }

    func testParametricBox() throws {
        let source = """
        width = 40;
        depth = 30;
        height = 25;
        wall = 2;
        difference() {
            cube([width, depth, height]);
            translate([wall, wall, wall])
                cube([width - 2*wall, depth - 2*wall, height]);
        }
        """
        let mesh = try parseAndEvaluate(source)
        XCTAssertGreaterThan(mesh.triangleCount, 0)
        let bb = mesh.boundingBox
        XCTAssertEqual(bb.max.x, 40.0, accuracy: 0.01)
    }

    func testForLoopWithTranslate() throws {
        let mesh = try parseAndEvaluate("""
        for (i = [0:3]) {
            translate([i*10, 0, 0])
                cube(5);
        }
        """)
        XCTAssertEqual(mesh.triangleCount, 12 * 4) // 4 cubes, 12 tris each
    }

    func testModuleWithParameters() throws {
        let mesh = try parseAndEvaluate("""
        module box(w, h, d) {
            cube([w, h, d]);
        }
        box(10, 20, 30);
        """)
        XCTAssertEqual(mesh.triangleCount, 12)
        let bb = mesh.boundingBox
        XCTAssertEqual(bb.max.y, 20.0, accuracy: 0.01)
    }

    func testUnionOfPrimitives() throws {
        let mesh = try parseAndEvaluate("""
        union() {
            cube(10);
            translate([15, 0, 0])
                sphere(r=5, $fn=16);
        }
        """)
        XCTAssertGreaterThan(mesh.triangleCount, 12)
    }

    func testConditionalGeometry() throws {
        let mesh = try parseAndEvaluate("""
        use_cube = true;
        if (use_cube) {
            cube(10);
        } else {
            sphere(5, $fn=16);
        }
        """)
        XCTAssertEqual(mesh.triangleCount, 12) // Should be cube
    }

    func testSTLExportFromScript() throws {
        let mesh = try parseAndEvaluate("cube([10, 10, 10]);")
        let stlData = STLExporter.exportBinary(mesh)
        XCTAssertEqual(stlData.count, 80 + 4 + 50 * 12) // header + count + 12 triangles
    }

    func testCacheHitsOnRepeatedEvaluation() throws {
        let source = """
        width = 40;
        cube([width, 20, 10]);
        sphere(r=5, $fn=16);
        """

        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        var parser = Parser(tokens: tokens)
        let ast = try parser.parse()
        let evaluator = Evaluator()

        let kernel = GeometryKernel()

        // First evaluation — all cache misses
        let result1 = evaluator.evaluate(program: ast)
        _ = kernel.evaluate(result1.geometry)
        let stats1 = kernel.cacheStats
        XCTAssertEqual(stats1.hits, 0)
        XCTAssertGreaterThan(stats1.misses, 0)

        // Change only the variable, re-evaluate
        let source2 = """
        width = 55;
        cube([width, 20, 10]);
        sphere(r=5, $fn=16);
        """
        let lexer2 = Lexer(source: source2)
        let tokens2 = try lexer2.tokenize()
        var parser2 = Parser(tokens: tokens2)
        let ast2 = try parser2.parse()
        let result2 = evaluator.evaluate(program: ast2)
        _ = kernel.evaluate(result2.geometry)
        let stats2 = kernel.cacheStats

        // The sphere subtree should be a cache hit since it didn't change
        XCTAssertGreaterThan(stats2.hits, 0, "Cache should hit for unchanged subtrees")
    }

    func testCustomizerVarsExtraction() throws {
        let source = """
        width = 40; // [10:100] Box width
        height = 25; // [10:50]
        cube([width, height, 10]);
        """
        let extractor = CustomizerExtractor()
        let params = extractor.extract(from: source)
        XCTAssertEqual(params.count, 2)
        XCTAssertEqual(params[0].name, "width")
    }
}
