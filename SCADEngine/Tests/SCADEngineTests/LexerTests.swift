import XCTest
@testable import SCADEngine

final class LexerTests: XCTestCase {

    // MARK: - Helpers

    private func tokenize(_ source: String) throws -> [Token] {
        let lexer = Lexer(source: source)
        return try lexer.tokenize()
    }

    /// Returns tokens excluding the trailing EOF.
    private func tokenizeNoEOF(_ source: String) throws -> [Token] {
        let tokens = try tokenize(source)
        return tokens.filter { $0.type != .eof }
    }

    // MARK: - Empty Source

    func testEmptySource() throws {
        let tokens = try tokenize("")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .eof)
    }

    func testWhitespaceOnly() throws {
        let tokens = try tokenize("   \n\t\r\n   ")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .eof)
    }

    // MARK: - Keywords

    func testAllKeywords() throws {
        let keywords = ["module", "function", "if", "else", "for", "let",
                        "each", "include", "use", "true", "false", "undef"]
        for kw in keywords {
            let tokens = try tokenizeNoEOF(kw)
            XCTAssertEqual(tokens.count, 1, "Expected exactly one token for keyword '\(kw)'")
            guard case .keyword(let parsed) = tokens[0].type else {
                XCTFail("Expected keyword token for '\(kw)', got \(tokens[0].type)")
                continue
            }
            XCTAssertEqual(parsed.rawValue, kw)
            XCTAssertEqual(tokens[0].value, kw)
        }
    }

    func testKeywordLocations() throws {
        let tokens = try tokenizeNoEOF("if else")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].location, SourceLocation(line: 1, column: 1))
        XCTAssertEqual(tokens[1].location, SourceLocation(line: 1, column: 4))
    }

    // MARK: - Builtin Modules

    func testBuiltinModules() throws {
        let builtins = ["cube", "cylinder", "sphere", "polyhedron", "union",
                        "difference", "intersection", "translate", "rotate",
                        "scale", "mirror", "linear_extrude", "rotate_extrude",
                        "color", "import", "projection", "hull", "minkowski",
                        "echo", "assert", "children"]
        for name in builtins {
            let tokens = try tokenizeNoEOF(name)
            XCTAssertEqual(tokens.count, 1, "Expected exactly one token for builtin '\(name)'")
            XCTAssertEqual(tokens[0].type, .builtinModule, "Expected builtinModule for '\(name)'")
            XCTAssertEqual(tokens[0].value, name)
        }
    }

    // MARK: - Identifiers

    func testSimpleIdentifier() throws {
        let tokens = try tokenizeNoEOF("myVar")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .identifier)
        XCTAssertEqual(tokens[0].value, "myVar")
    }

    func testIdentifierWithUnderscore() throws {
        let tokens = try tokenizeNoEOF("_private_var")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .identifier)
        XCTAssertEqual(tokens[0].value, "_private_var")
    }

    func testIdentifierWithDigits() throws {
        let tokens = try tokenizeNoEOF("var123")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .identifier)
        XCTAssertEqual(tokens[0].value, "var123")
    }

    func testIdentifierNotConfusedWithKeywordPrefix() throws {
        // "iffy" should be an identifier, not keyword "if" + identifier "fy"
        let tokens = try tokenizeNoEOF("iffy")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .identifier)
        XCTAssertEqual(tokens[0].value, "iffy")
    }

    // MARK: - Number Literals

    func testIntegerLiteral() throws {
        let tokens = try tokenizeNoEOF("42")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .numberLiteral)
        XCTAssertEqual(tokens[0].value, "42")
    }

    func testZero() throws {
        let tokens = try tokenizeNoEOF("0")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .numberLiteral)
        XCTAssertEqual(tokens[0].value, "0")
    }

    func testFloatLiteral() throws {
        let tokens = try tokenizeNoEOF("3.14")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .numberLiteral)
        XCTAssertEqual(tokens[0].value, "3.14")
    }

    func testLeadingDotFloat() throws {
        let tokens = try tokenizeNoEOF(".5")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .numberLiteral)
        XCTAssertEqual(tokens[0].value, ".5")
    }

    func testScientificNotationPositiveExponent() throws {
        let tokens = try tokenizeNoEOF("1e3")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .numberLiteral)
        XCTAssertEqual(tokens[0].value, "1e3")
    }

    func testScientificNotationNegativeExponent() throws {
        let tokens = try tokenizeNoEOF("1e-3")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .numberLiteral)
        XCTAssertEqual(tokens[0].value, "1e-3")
    }

    func testScientificNotationWithPlus() throws {
        let tokens = try tokenizeNoEOF("2.5E+10")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .numberLiteral)
        XCTAssertEqual(tokens[0].value, "2.5E+10")
    }

    func testScientificNotationCapitalE() throws {
        let tokens = try tokenizeNoEOF("6.022E23")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .numberLiteral)
        XCTAssertEqual(tokens[0].value, "6.022E23")
    }

    func testTrailingDotNumber() throws {
        // "10." should parse as a number "10." when not followed by an identifier
        let tokens = try tokenizeNoEOF("10.;")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].type, .numberLiteral)
        XCTAssertEqual(tokens[0].value, "10.")
        XCTAssertEqual(tokens[1].type, .semicolon)
    }

    // MARK: - String Literals

    func testSimpleString() throws {
        let tokens = try tokenizeNoEOF("\"hello\"")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .stringLiteral)
        XCTAssertEqual(tokens[0].value, "hello")
    }

    func testEmptyString() throws {
        let tokens = try tokenizeNoEOF("\"\"")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .stringLiteral)
        XCTAssertEqual(tokens[0].value, "")
    }

    func testStringWithEscapes() throws {
        let tokens = try tokenizeNoEOF("\"hello\\nworld\"")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .stringLiteral)
        XCTAssertEqual(tokens[0].value, "hello\nworld")
    }

    func testStringWithTab() throws {
        let tokens = try tokenizeNoEOF("\"col1\\tcol2\"")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].value, "col1\tcol2")
    }

    func testStringWithEscapedBackslash() throws {
        let tokens = try tokenizeNoEOF("\"path\\\\file\"")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].value, "path\\file")
    }

    func testStringWithEscapedQuote() throws {
        let tokens = try tokenizeNoEOF("\"she said \\\"hi\\\"\"")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].value, "she said \"hi\"")
    }

    func testUnterminatedString() throws {
        XCTAssertThrowsError(try tokenize("\"no closing")) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError, got \(error)")
                return
            }
            if case .unterminatedString = lexerError {
                // expected
            } else {
                XCTFail("Expected unterminatedString, got \(lexerError)")
            }
        }
    }

    func testStringWithNewlineThrows() throws {
        XCTAssertThrowsError(try tokenize("\"line1\nline2\"")) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError")
                return
            }
            if case .unterminatedString = lexerError {
                // expected
            } else {
                XCTFail("Expected unterminatedString, got \(lexerError)")
            }
        }
    }

    // MARK: - Operators

    func testSingleCharOperators() throws {
        let source = "+ - * / % ^ ? :"
        let tokens = try tokenizeNoEOF(source)
        let expected: [TokenType] = [.plus, .minus, .star, .slash, .percent,
                                     .caret, .question, .colon]
        XCTAssertEqual(tokens.count, expected.count)
        for (token, expectedType) in zip(tokens, expected) {
            XCTAssertEqual(token.type, expectedType, "Expected \(expectedType), got \(token.type)")
        }
    }

    func testComparisonOperators() throws {
        let source = "< > <= >= == !="
        let tokens = try tokenizeNoEOF(source)
        let expected: [TokenType] = [.less, .greater, .lessEqual, .greaterEqual,
                                     .equalEqual, .notEqual]
        XCTAssertEqual(tokens.count, expected.count)
        for (token, expectedType) in zip(tokens, expected) {
            XCTAssertEqual(token.type, expectedType)
        }
    }

    func testLogicalOperators() throws {
        let source = "&& || !"
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens.count, 3)
        XCTAssertEqual(tokens[0].type, .and)
        XCTAssertEqual(tokens[1].type, .or)
        XCTAssertEqual(tokens[2].type, .bang)
    }

    func testBangNotEqual() throws {
        // "!=" should be a single notEqual token, not bang + assign
        let tokens = try tokenizeNoEOF("!=")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .notEqual)
    }

    func testAssignVsEqualEqual() throws {
        let tokens = try tokenizeNoEOF("= ==")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].type, .assign)
        XCTAssertEqual(tokens[1].type, .equalEqual)
    }

    // MARK: - Delimiters

    func testAllDelimiters() throws {
        let source = "( ) [ ] { } , ; . ="
        let tokens = try tokenizeNoEOF(source)
        let expected: [TokenType] = [.leftParen, .rightParen, .leftBracket, .rightBracket,
                                     .leftBrace, .rightBrace, .comma, .semicolon, .dot, .assign]
        XCTAssertEqual(tokens.count, expected.count)
        for (token, expectedType) in zip(tokens, expected) {
            XCTAssertEqual(token.type, expectedType)
        }
    }

    // MARK: - Comments

    func testLineComment() throws {
        let tokens = try tokenizeNoEOF("// this is a comment")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .lineComment)
        XCTAssertEqual(tokens[0].value, "// this is a comment")
    }

    func testLineCommentPreservesFeatureAnnotation() throws {
        let tokens = try tokenizeNoEOF("// @feature \"Base Plate\"")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .lineComment)
        XCTAssert(tokens[0].value.contains("@feature"))
        XCTAssert(tokens[0].value.contains("Base Plate"))
    }

    func testLineCommentDoesNotConsumeNewline() throws {
        let tokens = try tokenizeNoEOF("// comment\n42")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].type, .lineComment)
        XCTAssertEqual(tokens[1].type, .numberLiteral)
        XCTAssertEqual(tokens[1].value, "42")
        XCTAssertEqual(tokens[1].location.line, 2)
    }

    func testBlockComment() throws {
        let tokens = try tokenizeNoEOF("/* block */")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .blockComment)
        XCTAssertEqual(tokens[0].value, "/* block */")
    }

    func testBlockCommentMultiline() throws {
        let source = "/* line1\nline2\nline3 */"
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .blockComment)
        XCTAssert(tokens[0].value.contains("line1"))
        XCTAssert(tokens[0].value.contains("line3"))
    }

    func testNestedBlockComments() throws {
        let source = "/* outer /* inner */ still outer */"
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .blockComment)
        XCTAssertEqual(tokens[0].value, "/* outer /* inner */ still outer */")
    }

    func testDeeplyNestedBlockComments() throws {
        let source = "/* a /* b /* c */ b */ a */"
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .blockComment)
    }

    func testUnterminatedBlockComment() throws {
        XCTAssertThrowsError(try tokenize("/* never closed")) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError")
                return
            }
            if case .unterminatedBlockComment = lexerError {
                // expected
            } else {
                XCTFail("Expected unterminatedBlockComment, got \(lexerError)")
            }
        }
    }

    func testUnterminatedNestedBlockComment() throws {
        XCTAssertThrowsError(try tokenize("/* outer /* inner */")) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError")
                return
            }
            if case .unterminatedBlockComment = lexerError {
                // expected
            } else {
                XCTFail("Expected unterminatedBlockComment, got \(lexerError)")
            }
        }
    }

    // MARK: - Special Variables

    func testSpecialVariables() throws {
        let vars = ["$fn", "$fa", "$fs", "$t", "$children"]
        for v in vars {
            let tokens = try tokenizeNoEOF(v)
            XCTAssertEqual(tokens.count, 1, "Expected 1 token for '\(v)'")
            XCTAssertEqual(tokens[0].type, .specialVariable, "Expected specialVariable for '\(v)'")
            XCTAssertEqual(tokens[0].value, v)
        }
    }

    func testCustomSpecialVariable() throws {
        // OpenSCAD allows any $-prefixed variable
        let tokens = try tokenizeNoEOF("$preview")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .specialVariable)
        XCTAssertEqual(tokens[0].value, "$preview")
    }

    // MARK: - Modifier Characters

    func testHashModifier() throws {
        let tokens = try tokenizeNoEOF("#cube(10);")
        XCTAssertEqual(tokens[0].type, .modifier)
        XCTAssertEqual(tokens[0].value, "#")
        XCTAssertEqual(tokens[1].type, .builtinModule)
        XCTAssertEqual(tokens[1].value, "cube")
    }

    // MARK: - Source Locations

    func testSourceLocationsOnFirstLine() throws {
        let tokens = try tokenizeNoEOF("a + b")
        XCTAssertEqual(tokens[0].location, SourceLocation(line: 1, column: 1))
        XCTAssertEqual(tokens[1].location, SourceLocation(line: 1, column: 3))
        XCTAssertEqual(tokens[2].location, SourceLocation(line: 1, column: 5))
    }

    func testSourceLocationsMultipleLines() throws {
        let source = "a\nb\nc"
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens.count, 3)
        XCTAssertEqual(tokens[0].location, SourceLocation(line: 1, column: 1))
        XCTAssertEqual(tokens[1].location, SourceLocation(line: 2, column: 1))
        XCTAssertEqual(tokens[2].location, SourceLocation(line: 3, column: 1))
    }

    func testSourceLocationAfterBlockComment() throws {
        let source = "/* comment\nspanning lines */\nx"
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].type, .blockComment)
        XCTAssertEqual(tokens[1].type, .identifier)
        XCTAssertEqual(tokens[1].location.line, 3)
        XCTAssertEqual(tokens[1].location.column, 1)
    }

    // MARK: - Complete Small Programs

    func testCubeStatement() throws {
        let source = "cube([10, 10, 10]);"
        let tokens = try tokenizeNoEOF(source)
        let types = tokens.map(\.type)
        XCTAssertEqual(types, [
            .builtinModule, .leftParen, .leftBracket,
            .numberLiteral, .comma, .numberLiteral, .comma, .numberLiteral,
            .rightBracket, .rightParen, .semicolon
        ])
    }

    func testTranslateWithChild() throws {
        let source = "translate([5, 0, 0]) cube(10);"
        let tokens = try tokenizeNoEOF(source)
        let types = tokens.map(\.type)
        XCTAssertEqual(types, [
            .builtinModule, .leftParen, .leftBracket,
            .numberLiteral, .comma, .numberLiteral, .comma, .numberLiteral,
            .rightBracket, .rightParen,
            .builtinModule, .leftParen, .numberLiteral, .rightParen, .semicolon
        ])
    }

    func testDifferenceBlock() throws {
        let source = """
        difference() {
            cube(10);
            cylinder(r=3, h=20);
        }
        """
        let tokens = try tokenizeNoEOF(source)

        // Verify key token types are present
        XCTAssertEqual(tokens[0].type, .builtinModule)
        XCTAssertEqual(tokens[0].value, "difference")
        XCTAssert(tokens.contains { $0.type == .leftBrace })
        XCTAssert(tokens.contains { $0.type == .rightBrace })
        XCTAssert(tokens.contains { $0.value == "cube" })
        XCTAssert(tokens.contains { $0.value == "cylinder" })
    }

    func testModuleDefinition() throws {
        let source = """
        module bracket(width=40, height=25) {
            cube([width, height, 3]);
        }
        """
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens[0].type, .keyword(.module))
        XCTAssertEqual(tokens[1].type, .identifier)
        XCTAssertEqual(tokens[1].value, "bracket")
        XCTAssertEqual(tokens[2].type, .leftParen)
    }

    func testFunctionDefinition() throws {
        let source = "function add(a, b) = a + b;"
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens[0].type, .keyword(.function))
        XCTAssertEqual(tokens[1].type, .identifier)
        XCTAssertEqual(tokens[1].value, "add")
    }

    func testForLoop() throws {
        let source = "for (i = [0:5]) translate([i*10, 0, 0]) cube(5);"
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens[0].type, .keyword(.for))
    }

    func testIfElse() throws {
        let source = "if (x > 0) cube(x); else cube(1);"
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens[0].type, .keyword(.if))
        XCTAssert(tokens.contains { $0.type == .keyword(.else) })
    }

    func testLetExpression() throws {
        let source = "let (r = 5) cylinder(r=r, h=10);"
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens[0].type, .keyword(.let))
    }

    func testCustomizerAnnotation() throws {
        let source = """
        width = 40; // [10:100] Bracket width
        """
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens[0].type, .identifier)
        XCTAssertEqual(tokens[0].value, "width")
        XCTAssertEqual(tokens[1].type, .assign)
        XCTAssertEqual(tokens[2].type, .numberLiteral)
        XCTAssertEqual(tokens[3].type, .semicolon)
        XCTAssertEqual(tokens[4].type, .lineComment)
        XCTAssert(tokens[4].value.contains("[10:100]"))
        XCTAssert(tokens[4].value.contains("Bracket width"))
    }

    func testFeatureAnnotationInProgram() throws {
        let source = """
        // @feature "Base Plate"
        difference() {
            cube([40, 25, 3]);
            // @feature "Mounting Hole"
            translate([20, 12.5, -1])
                cylinder(h=5, d=5);
        }
        """
        let tokens = try tokenizeNoEOF(source)

        let featureComments = tokens.filter {
            $0.type == .lineComment && $0.value.contains("@feature")
        }
        XCTAssertEqual(featureComments.count, 2)
        XCTAssert(featureComments[0].value.contains("Base Plate"))
        XCTAssert(featureComments[1].value.contains("Mounting Hole"))
    }

    func testCompleteParametricModel() throws {
        let source = """
        width = 40;
        height = 25;
        thickness = 3;
        hole_diameter = 5;

        $fn = 32;

        difference() {
            cube([width, height, thickness]);
            translate([width/2, height/2, -1])
                cylinder(h=thickness+2, d=hole_diameter);
        }
        """
        let tokens = try tokenize(source)
        // Just verify it tokenizes without error and ends with EOF
        XCTAssertEqual(tokens.last?.type, .eof)
        // Should have a good number of tokens
        XCTAssertGreaterThan(tokens.count, 30)
    }

    // MARK: - Edge Cases

    func testNegativeNumberVsSubtraction() throws {
        // "5-3" should be: number, minus, number (not number, negative-number)
        let tokens = try tokenizeNoEOF("5-3")
        XCTAssertEqual(tokens.count, 3)
        XCTAssertEqual(tokens[0].type, .numberLiteral)
        XCTAssertEqual(tokens[0].value, "5")
        XCTAssertEqual(tokens[1].type, .minus)
        XCTAssertEqual(tokens[2].type, .numberLiteral)
        XCTAssertEqual(tokens[2].value, "3")
    }

    func testMinusBeforeNumber() throws {
        // "-3" should be minus, number (parser handles unary minus)
        let tokens = try tokenizeNoEOF("-3")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].type, .minus)
        XCTAssertEqual(tokens[1].type, .numberLiteral)
    }

    func testScientificNotationVsIdentifier() throws {
        // "1e3" is a number, "e3" is an identifier
        let tokensNum = try tokenizeNoEOF("1e3")
        XCTAssertEqual(tokensNum.count, 1)
        XCTAssertEqual(tokensNum[0].type, .numberLiteral)

        let tokensId = try tokenizeNoEOF("e3")
        XCTAssertEqual(tokensId.count, 1)
        XCTAssertEqual(tokensId[0].type, .identifier)
    }

    func testDotAsDotOperator() throws {
        // When dot is not followed by a digit, it should be a dot token
        let tokens = try tokenizeNoEOF("a.b")
        XCTAssertEqual(tokens.count, 3)
        XCTAssertEqual(tokens[0].type, .identifier)
        XCTAssertEqual(tokens[1].type, .dot)
        XCTAssertEqual(tokens[2].type, .identifier)
    }

    func testSlashNotComment() throws {
        // A lone "/" should be a slash operator
        let tokens = try tokenizeNoEOF("a / b")
        XCTAssertEqual(tokens.count, 3)
        XCTAssertEqual(tokens[0].type, .identifier)
        XCTAssertEqual(tokens[1].type, .slash)
        XCTAssertEqual(tokens[2].type, .identifier)
    }

    func testStarAsOperator() throws {
        let tokens = try tokenizeNoEOF("a * b")
        XCTAssertEqual(tokens.count, 3)
        XCTAssertEqual(tokens[1].type, .star)
    }

    func testPercentAsOperator() throws {
        let tokens = try tokenizeNoEOF("a % b")
        XCTAssertEqual(tokens.count, 3)
        XCTAssertEqual(tokens[1].type, .percent)
    }

    func testConsecutiveOperators() throws {
        let tokens = try tokenizeNoEOF("!true")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].type, .bang)
        XCTAssertEqual(tokens[1].type, .keyword(.true))
    }

    func testTernaryExpression() throws {
        let tokens = try tokenizeNoEOF("x > 0 ? x : 0")
        let types = tokens.map(\.type)
        XCTAssertEqual(types, [
            .identifier, .greater, .numberLiteral,
            .question, .identifier, .colon, .numberLiteral
        ])
    }

    func testRangeExpression() throws {
        // [0:10] used in for loops
        let tokens = try tokenizeNoEOF("[0:10]")
        let types = tokens.map(\.type)
        XCTAssertEqual(types, [
            .leftBracket, .numberLiteral, .colon, .numberLiteral, .rightBracket
        ])
    }

    func testRangeWithStep() throws {
        // [0:2:10]
        let tokens = try tokenizeNoEOF("[0:2:10]")
        let types = tokens.map(\.type)
        XCTAssertEqual(types, [
            .leftBracket, .numberLiteral, .colon, .numberLiteral,
            .colon, .numberLiteral, .rightBracket
        ])
    }

    func testUseStatement() throws {
        let tokens = try tokenizeNoEOF("use <library.scad>")
        XCTAssertEqual(tokens[0].type, .keyword(.use))
        XCTAssertEqual(tokens[1].type, .less)
        // The rest will be identifier, dot, identifier, greater
    }

    func testIncludeStatement() throws {
        let tokens = try tokenizeNoEOF("include <utils.scad>")
        XCTAssertEqual(tokens[0].type, .keyword(.include))
    }

    func testSpecialVariableAssignment() throws {
        let tokens = try tokenizeNoEOF("$fn = 32;")
        XCTAssertEqual(tokens[0].type, .specialVariable)
        XCTAssertEqual(tokens[0].value, "$fn")
        XCTAssertEqual(tokens[1].type, .assign)
        XCTAssertEqual(tokens[2].type, .numberLiteral)
        XCTAssertEqual(tokens[3].type, .semicolon)
    }

    func testNamedParameters() throws {
        let source = "cylinder(h=10, r=5, center=true);"
        let tokens = try tokenizeNoEOF(source)
        // Verify the = tokens are assign, not equalEqual
        let assigns = tokens.filter { $0.type == .assign }
        XCTAssertEqual(assigns.count, 3)
    }

    func testUnexpectedCharacter() throws {
        XCTAssertThrowsError(try tokenize("@")) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError")
                return
            }
            if case .unexpectedCharacter(let ch, _) = lexerError {
                XCTAssertEqual(ch, "@")
            } else {
                XCTFail("Expected unexpectedCharacter, got \(lexerError)")
            }
        }
    }

    func testInvalidEscapeSequence() throws {
        XCTAssertThrowsError(try tokenize("\"bad\\x\"")) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError")
                return
            }
            if case .invalidEscapeSequence(let ch, _) = lexerError {
                XCTAssertEqual(ch, "x")
            } else {
                XCTFail("Expected invalidEscapeSequence, got \(lexerError)")
            }
        }
    }

    func testInvalidScientificNotation() throws {
        // "1e" with no exponent digits should fail
        XCTAssertThrowsError(try tokenize("1e;")) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError")
                return
            }
            if case .invalidNumberLiteral = lexerError {
                // expected
            } else {
                XCTFail("Expected invalidNumberLiteral, got \(lexerError)")
            }
        }
    }

    func testMultipleStatementsOnOneLine() throws {
        let source = "a=1;b=2;c=3;"
        let tokens = try tokenizeNoEOF(source)
        // a = 1 ; b = 2 ; c = 3 ; = 12 tokens
        XCTAssertEqual(tokens.count, 12)
        // All on line 1
        for token in tokens {
            XCTAssertEqual(token.location.line, 1)
        }
    }

    func testCommentBetweenTokens() throws {
        let source = "a /* middle */ + b"
        let tokens = try tokenizeNoEOF(source)
        XCTAssertEqual(tokens.count, 4)
        XCTAssertEqual(tokens[0].type, .identifier)
        XCTAssertEqual(tokens[1].type, .blockComment)
        XCTAssertEqual(tokens[2].type, .plus)
        XCTAssertEqual(tokens[3].type, .identifier)
    }

    func testVectorLiteral() throws {
        let source = "[1, 2.5, 3e1]"
        let tokens = try tokenizeNoEOF(source)
        let types = tokens.map(\.type)
        XCTAssertEqual(types, [
            .leftBracket, .numberLiteral, .comma, .numberLiteral,
            .comma, .numberLiteral, .rightBracket
        ])
        XCTAssertEqual(tokens[1].value, "1")
        XCTAssertEqual(tokens[3].value, "2.5")
        XCTAssertEqual(tokens[5].value, "3e1")
    }

    func testBooleanLiterals() throws {
        let tokens = try tokenizeNoEOF("true false")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].type, .keyword(.true))
        XCTAssertEqual(tokens[1].type, .keyword(.false))
    }

    func testUndef() throws {
        let tokens = try tokenizeNoEOF("undef")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .keyword(.undef))
    }

    func testEachKeyword() throws {
        let tokens = try tokenizeNoEOF("each")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .keyword(.each))
    }

    // MARK: - Token Description

    func testTokenDescription() throws {
        let token = Token(type: .numberLiteral, value: "42",
                         location: SourceLocation(line: 1, column: 1))
        let desc = token.description
        XCTAssert(desc.contains("number"))
        XCTAssert(desc.contains("42"))
    }

    func testSourceLocationDescription() throws {
        let loc = SourceLocation(line: 5, column: 12)
        XCTAssertEqual(loc.description, "5:12")
    }

    // MARK: - Stress / Realistic Programs

    func testRealisticOpenSCADFile() throws {
        let source = """
        // Parametric Phone Stand
        // Author: OpenSCAD Community

        /* [Dimensions] */
        width = 60;       // [30:100] Base width
        depth = 80;       // [50:120] Base depth
        height = 5;       // [3:10] Base thickness
        angle = 70;       // [45:85] Viewing angle

        /* [Phone] */
        phone_width = 75; // [60:90]
        phone_thickness = 10;

        $fn = 32;

        module base() {
            cube([width, depth, height]);
        }

        module support() {
            translate([0, depth * 0.3, 0])
                rotate([90 - angle, 0, 0])
                    cube([width, height, depth * 0.6]);
        }

        module phone_slot() {
            translate([(width - phone_width) / 2, depth * 0.25, height])
                cube([phone_width, phone_thickness, 2]);
        }

        // @feature "Base"
        base();

        // @feature "Support"
        support();

        // @feature "Phone Slot"
        difference() {
            union() {
                base();
                support();
            }
            phone_slot();
        }
        """
        let tokens = try tokenize(source)
        XCTAssertEqual(tokens.last?.type, .eof)

        // Verify no errors — the source should tokenize cleanly
        let nonEOF = tokens.filter { $0.type != .eof }
        XCTAssertGreaterThan(nonEOF.count, 100, "Expected many tokens from a realistic file")

        // Verify specific expected elements
        let keywords = tokens.filter { if case .keyword = $0.type { return true }; return false }
        XCTAssert(keywords.contains { $0.value == "module" })

        let specials = tokens.filter { $0.type == .specialVariable }
        XCTAssert(specials.contains { $0.value == "$fn" })

        let builtins = tokens.filter { $0.type == .builtinModule }
        XCTAssert(builtins.contains { $0.value == "cube" })
        XCTAssert(builtins.contains { $0.value == "translate" })
        XCTAssert(builtins.contains { $0.value == "rotate" })
        XCTAssert(builtins.contains { $0.value == "difference" })
        XCTAssert(builtins.contains { $0.value == "union" })

        let featureComments = tokens.filter {
            $0.type == .lineComment && $0.value.contains("@feature")
        }
        XCTAssertEqual(featureComments.count, 3)
    }
}
