import XCTest
@testable import SCADEngine

final class ParserTests: XCTestCase {
    private func parse(_ source: String) throws -> ASTNode {
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        var parser = Parser(tokens: tokens)
        return try parser.parse()
    }

    func testSimpleAssignment() throws {
        let ast = try parse("x = 5;")
        if case .program(let stmts) = ast {
            XCTAssertEqual(stmts.count, 1)
            if case .assignment(let a) = stmts[0] {
                XCTAssertEqual(a.name, "x")
                XCTAssertEqual(a.value, .number(5))
            } else {
                XCTFail("Expected assignment")
            }
        }
    }

    func testCubeInstantiation() throws {
        let ast = try parse("cube([10, 10, 10]);")
        if case .program(let stmts) = ast {
            XCTAssertEqual(stmts.count, 1)
            if case .moduleInstantiation(let inst) = stmts[0] {
                XCTAssertEqual(inst.name, "cube")
                XCTAssertEqual(inst.arguments.count, 1)
            } else {
                XCTFail("Expected module instantiation")
            }
        }
    }

    func testTranslateWithChild() throws {
        let ast = try parse("translate([1,0,0]) cube(5);")
        if case .program(let stmts) = ast {
            if case .moduleInstantiation(let inst) = stmts[0] {
                XCTAssertEqual(inst.name, "translate")
                XCTAssertNotNil(inst.children)
            } else {
                XCTFail("Expected module instantiation")
            }
        }
    }

    func testDifferenceWithChildren() throws {
        let ast = try parse("""
        difference() {
            cube(10);
            cylinder(r=3, h=20);
        }
        """)
        if case .program(let stmts) = ast {
            if case .moduleInstantiation(let inst) = stmts[0] {
                XCTAssertEqual(inst.name, "difference")
                if case .block(let children) = inst.children {
                    XCTAssertEqual(children.count, 2)
                }
            }
        }
    }

    func testNamedArguments() throws {
        let ast = try parse("cylinder(h=10, r=5);")
        if case .program(let stmts) = ast {
            if case .moduleInstantiation(let inst) = stmts[0] {
                XCTAssertEqual(inst.arguments.count, 2)
                XCTAssertEqual(inst.arguments[0].name, "h")
                XCTAssertEqual(inst.arguments[1].name, "r")
            }
        }
    }

    func testModuleDefinition() throws {
        let ast = try parse("""
        module box(size, wall=2) {
            cube(size);
        }
        """)
        if case .program(let stmts) = ast {
            if case .moduleDefinition(let def) = stmts[0] {
                XCTAssertEqual(def.name, "box")
                XCTAssertEqual(def.parameters.count, 2)
                XCTAssertEqual(def.parameters[0].name, "size")
                XCTAssertNil(def.parameters[0].defaultValue)
                XCTAssertEqual(def.parameters[1].name, "wall")
                XCTAssertEqual(def.parameters[1].defaultValue, .number(2))
            }
        }
    }

    func testFunctionDefinition() throws {
        let ast = try parse("function double(x) = x * 2;")
        if case .program(let stmts) = ast {
            if case .functionDefinition(let def) = stmts[0] {
                XCTAssertEqual(def.name, "double")
            }
        }
    }

    func testForLoop() throws {
        let ast = try parse("""
        for (i = [0:4]) {
            translate([i*10, 0, 0]) cube(5);
        }
        """)
        if case .program(let stmts) = ast {
            if case .forStatement(let stmt) = stmts[0] {
                XCTAssertEqual(stmt.variable, "i")
            }
        }
    }

    func testIfElse() throws {
        let ast = try parse("""
        if (x > 5) {
            cube(10);
        } else {
            sphere(5);
        }
        """)
        if case .program(let stmts) = ast {
            if case .ifStatement(let stmt) = stmts[0] {
                XCTAssertNotNil(stmt.elseBranch)
            }
        }
    }

    func testRangeExpression() throws {
        let ast = try parse("x = [0:2:10];")
        if case .program(let stmts) = ast {
            if case .assignment(let a) = stmts[0] {
                if case .range(_, let step, _) = a.value {
                    XCTAssertNotNil(step)
                } else {
                    XCTFail("Expected range")
                }
            }
        }
    }

    func testTernaryExpression() throws {
        let ast = try parse("x = a > 0 ? a : -a;")
        if case .program(let stmts) = ast {
            if case .assignment(let a) = stmts[0] {
                if case .ternary = a.value {
                    // OK
                } else {
                    XCTFail("Expected ternary")
                }
            }
        }
    }

    func testListLiteral() throws {
        let ast = try parse("x = [1, 2, 3];")
        if case .program(let stmts) = ast {
            if case .assignment(let a) = stmts[0] {
                if case .listLiteral(let elems) = a.value {
                    XCTAssertEqual(elems.count, 3)
                }
            }
        }
    }

    func testSpecialVariable() throws {
        let ast = try parse("cylinder(r=5, h=10, $fn=32);")
        if case .program(let stmts) = ast {
            if case .moduleInstantiation(let inst) = stmts[0] {
                XCTAssertTrue(inst.arguments.contains(where: { $0.name == "$fn" }))
            }
        }
    }
}
