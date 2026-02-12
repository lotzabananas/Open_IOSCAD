import XCTest
@testable import SCADEngine
@testable import GeometryKernel

final class EvaluatorTests: XCTestCase {
    private func evaluate(_ source: String) throws -> Evaluator.EvalResult {
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        var parser = Parser(tokens: tokens)
        let ast = try parser.parse()
        let evaluator = Evaluator()
        return evaluator.evaluate(program: ast)
    }

    func testSimpleCube() throws {
        let result = try evaluate("cube([10, 10, 10]);")
        if case .primitive(.cube, let params) = result.geometry {
            XCTAssertEqual(params.size, SIMD3<Float>(10, 10, 10))
        } else {
            XCTFail("Expected cube primitive")
        }
    }

    func testCenteredCube() throws {
        let result = try evaluate("cube([10, 10, 10], center=true);")
        if case .primitive(.cube, let params) = result.geometry {
            XCTAssertTrue(params.center)
        } else {
            XCTFail("Expected cube primitive")
        }
    }

    func testCylinder() throws {
        let result = try evaluate("cylinder(h=20, r=5, $fn=32);")
        if case .primitive(.cylinder, let params) = result.geometry {
            XCTAssertEqual(params.height, 20)
            XCTAssertEqual(params.radius, 5)
        } else {
            XCTFail("Expected cylinder")
        }
    }

    func testTranslate() throws {
        let result = try evaluate("translate([5, 0, 0]) cube(1);")
        if case .transform(.translate, let params, _) = result.geometry {
            XCTAssertEqual(params.vector.x, 5)
        } else {
            XCTFail("Expected transform")
        }
    }

    func testDifference() throws {
        let result = try evaluate("""
        difference() {
            cube(10);
            cylinder(r=3, h=20);
        }
        """)
        if case .boolean(.difference, let children) = result.geometry {
            XCTAssertEqual(children.count, 2)
        } else {
            XCTFail("Expected difference")
        }
    }

    func testVariableAssignment() throws {
        let result = try evaluate("""
        w = 20;
        cube([w, w, 10]);
        """)
        if case .primitive(.cube, let params) = result.geometry {
            XCTAssertEqual(params.size?.x, 20)
        } else {
            XCTFail("Expected cube with variable")
        }
    }

    func testLastAssignmentWins() throws {
        let result = try evaluate("""
        x = 10;
        x = 20;
        cube(x);
        """)
        if case .primitive(.cube, let params) = result.geometry {
            // Last assignment wins
            XCTAssertEqual(params.size?.x, 20)
        } else {
            XCTFail("Expected cube")
        }
    }

    func testMathFunctions() throws {
        let evaluator = Evaluator()
        let lexer = Lexer(source: "x = sin(90);")
        let tokens = try lexer.tokenize()
        var parser = Parser(tokens: tokens)
        let ast = try parser.parse()
        let _ = evaluator.evaluate(program: ast)
        // sin(90) should = 1.0 (degrees)
    }

    func testForLoop() throws {
        let result = try evaluate("""
        for (i = [0:2]) {
            translate([i*10, 0, 0]) cube(5);
        }
        """)
        if case .group(let ops) = result.geometry {
            XCTAssertEqual(ops.count, 3) // i=0,1,2
        } else {
            XCTFail("Expected group of 3 ops")
        }
    }

    func testModuleCall() throws {
        let result = try evaluate("""
        module mybox(s) {
            cube(s);
        }
        mybox(10);
        """)
        if case .primitive(.cube, let params) = result.geometry {
            XCTAssertEqual(params.size?.x, 10)
        } else {
            XCTFail("Expected cube from module call")
        }
    }

    func testIfStatement() throws {
        let result = try evaluate("""
        x = 10;
        if (x > 5) {
            cube(x);
        } else {
            sphere(x);
        }
        """)
        if case .primitive(.cube, _) = result.geometry {
            // OK - x=10 > 5 so should take cube branch
        } else {
            XCTFail("Expected cube (if branch)")
        }
    }

    func testNoErrors() throws {
        let result = try evaluate("cube(10);")
        XCTAssertTrue(result.errors.isEmpty)
    }
}
