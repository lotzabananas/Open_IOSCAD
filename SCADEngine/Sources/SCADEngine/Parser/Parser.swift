import Foundation

public struct Parser {
    private var tokens: [Token]
    private var current: Int = 0

    public init(tokens: [Token]) {
        // Filter out comment tokens — the parser does not need them
        // except for trailing comment capture which we handle specially.
        self.tokens = tokens
    }

    public mutating func parse() throws -> ASTNode {
        var statements: [ASTNode] = []
        while !isAtEnd() {
            skipComments()
            if isAtEnd() { break }
            if check(.semicolon) {
                advance()
                continue
            }
            let stmt = try parseStatement()
            statements.append(stmt)
        }
        return .program(statements)
    }

    // MARK: - Statement Parsing

    private mutating func parseStatement() throws -> ASTNode {
        skipComments()

        // Check for modifier characters
        if let modifier = checkModifier() {
            advance()
            return try parseModuleInstantiation(modifier: modifier)
        }

        if check(.keyword(.module)) {
            return try parseModuleDefinition()
        }
        if check(.keyword(.function)) {
            return try parseFunctionDefinition()
        }
        if check(.keyword(.if)) {
            return try parseIfStatement()
        }
        if check(.keyword(.for)) {
            return try parseForStatement()
        }
        if check(.keyword(.let)) {
            return try parseLetStatement()
        }
        if check(.keyword(.use)) {
            return try parseUseStatement()
        }
        if check(.keyword(.include)) {
            return try parseIncludeStatement()
        }

        // Check for assignment: identifier = expression ;
        if checkAssignment() {
            return try parseAssignment()
        }

        // Module instantiation or expression
        if checkIdentifierOrBuiltin() {
            return try parseModuleInstantiation(modifier: nil)
        }

        // Block
        if check(.leftBrace) {
            return try parseBlock()
        }

        // Expression statement
        let expr = try parseExpression()
        try consumeOptionalSemicolon()
        return .expression(expr)
    }

    private mutating func parseModuleDefinition() throws -> ASTNode {
        let loc = currentLocation()
        try consume(.keyword(.module))
        let name = try consumeIdentifierOrBuiltin()
        try consume(.leftParen)
        let params = try parseParameterList()
        try consume(.rightParen)
        let body = try parseStatementOrBlock()
        return .moduleDefinition(ModuleDefinition(name: name, parameters: params, body: body, location: loc))
    }

    private mutating func parseFunctionDefinition() throws -> ASTNode {
        let loc = currentLocation()
        try consume(.keyword(.function))
        let name = try consumeIdentifierOrBuiltin()
        try consume(.leftParen)
        let params = try parseParameterList()
        try consume(.rightParen)
        try consume(.assign)
        let body = try parseExpression()
        try consumeOptionalSemicolon()
        return .functionDefinition(FunctionDefinition(name: name, parameters: params, body: body, location: loc))
    }

    private mutating func parseIfStatement() throws -> ASTNode {
        let loc = currentLocation()
        try consume(.keyword(.if))
        try consume(.leftParen)
        let condition = try parseExpression()
        try consume(.rightParen)
        let thenBranch = try parseStatementOrBlock()
        var elseBranch: ASTNode?
        if check(.keyword(.else)) {
            advance()
            elseBranch = try parseStatementOrBlock()
        }
        return .ifStatement(IfStatement(condition: condition, thenBranch: thenBranch, elseBranch: elseBranch, location: loc))
    }

    private mutating func parseForStatement() throws -> ASTNode {
        let loc = currentLocation()
        try consume(.keyword(.for))
        try consume(.leftParen)
        let varName = try consumeIdentifierName()
        try consume(.assign)
        let iterable = try parseExpression()
        try consume(.rightParen)
        let body = try parseStatementOrBlock()
        return .forStatement(ForStatement(variable: varName, iterable: iterable, body: body, location: loc))
    }

    private mutating func parseLetStatement() throws -> ASTNode {
        let loc = currentLocation()
        try consume(.keyword(.let))
        try consume(.leftParen)
        var assignments: [(String, Expression)] = []
        if !check(.rightParen) {
            repeat {
                let name = try consumeIdentifierName()
                try consume(.assign)
                let value = try parseExpression()
                assignments.append((name, value))
            } while matchToken(.comma)
        }
        try consume(.rightParen)
        let body = try parseStatementOrBlock()
        return .letExpression(LetExpression(assignments: assignments, body: body, location: loc))
    }

    private mutating func parseUseStatement() throws -> ASTNode {
        try consume(.keyword(.use))
        try consume(.less)
        var path = ""
        while !check(.greater) && !isAtEnd() {
            path += peek().value
            advance()
        }
        try consume(.greater)
        return .useStatement(path)
    }

    private mutating func parseIncludeStatement() throws -> ASTNode {
        try consume(.keyword(.include))
        try consume(.less)
        var path = ""
        while !check(.greater) && !isAtEnd() {
            path += peek().value
            advance()
        }
        try consume(.greater)
        return .includeStatement(path)
    }

    private mutating func parseAssignment() throws -> ASTNode {
        let loc = currentLocation()
        let name = try consumeIdentifierName()
        try consume(.assign)
        let value = try parseExpression()
        // Capture trailing comment
        let comment = captureTrailingComment()
        try consumeOptionalSemicolon()
        return .assignment(Assignment(name: name, value: value, location: loc, trailingComment: comment))
    }

    private mutating func parseModuleInstantiation(modifier: ModifierChar?) throws -> ASTNode {
        let loc = currentLocation()
        let name = try consumeIdentifierOrBuiltin()
        try consume(.leftParen)
        let args = try parseArgumentList()
        try consume(.rightParen)

        var children: ASTNode?
        if check(.leftBrace) {
            children = try parseBlock()
        } else if check(.semicolon) {
            advance()
        } else if !isAtEnd() && !check(.rightBrace) {
            // Single child statement: translate([1,0,0]) cube(5);
            children = try parseStatement()
        }

        return .moduleInstantiation(ModuleInstantiation(
            name: name, arguments: args, children: children,
            modifier: modifier, location: loc
        ))
    }

    private mutating func parseBlock() throws -> ASTNode {
        try consume(.leftBrace)
        var statements: [ASTNode] = []
        while !check(.rightBrace) && !isAtEnd() {
            skipComments()
            if check(.rightBrace) || isAtEnd() { break }
            if check(.semicolon) {
                advance()
                continue
            }
            statements.append(try parseStatement())
        }
        try consume(.rightBrace)
        return .block(statements)
    }

    private mutating func parseStatementOrBlock() throws -> ASTNode {
        skipComments()
        if check(.leftBrace) {
            return try parseBlock()
        }
        return try parseStatement()
    }

    // MARK: - Expression Parsing (Pratt parser / precedence climbing)

    private mutating func parseExpression() throws -> Expression {
        return try parseTernary()
    }

    private mutating func parseTernary() throws -> Expression {
        var expr = try parseOr()
        if matchToken(.question) {
            let thenExpr = try parseExpression()
            try consume(.colon)
            let elseExpr = try parseExpression()
            expr = .ternary(expr, thenExpr, elseExpr)
        }
        return expr
    }

    private mutating func parseOr() throws -> Expression {
        var left = try parseAnd()
        while matchToken(.or) {
            let right = try parseAnd()
            left = .binaryOp(.or, left, right)
        }
        return left
    }

    private mutating func parseAnd() throws -> Expression {
        var left = try parseEquality()
        while matchToken(.and) {
            let right = try parseEquality()
            left = .binaryOp(.and, left, right)
        }
        return left
    }

    private mutating func parseEquality() throws -> Expression {
        var left = try parseComparison()
        while true {
            if matchToken(.equalEqual) {
                left = .binaryOp(.equal, left, try parseComparison())
            } else if matchToken(.notEqual) {
                left = .binaryOp(.notEqual, left, try parseComparison())
            } else {
                break
            }
        }
        return left
    }

    private mutating func parseComparison() throws -> Expression {
        var left = try parseAddition()
        while true {
            if matchToken(.less) {
                left = .binaryOp(.lessThan, left, try parseAddition())
            } else if matchToken(.greater) {
                left = .binaryOp(.greaterThan, left, try parseAddition())
            } else if matchToken(.lessEqual) {
                left = .binaryOp(.lessEqual, left, try parseAddition())
            } else if matchToken(.greaterEqual) {
                left = .binaryOp(.greaterEqual, left, try parseAddition())
            } else {
                break
            }
        }
        return left
    }

    private mutating func parseAddition() throws -> Expression {
        var left = try parseMultiplication()
        while true {
            if matchToken(.plus) {
                left = .binaryOp(.add, left, try parseMultiplication())
            } else if matchToken(.minus) {
                left = .binaryOp(.subtract, left, try parseMultiplication())
            } else {
                break
            }
        }
        return left
    }

    private mutating func parseMultiplication() throws -> Expression {
        var left = try parseUnary()
        while true {
            if matchToken(.star) {
                left = .binaryOp(.multiply, left, try parseUnary())
            } else if matchToken(.slash) {
                left = .binaryOp(.divide, left, try parseUnary())
            } else if matchToken(.percent) {
                left = .binaryOp(.modulo, left, try parseUnary())
            } else if matchToken(.caret) {
                left = .binaryOp(.power, left, try parseUnary())
            } else {
                break
            }
        }
        return left
    }

    private mutating func parseUnary() throws -> Expression {
        if matchToken(.minus) {
            return .unaryOp(.negate, try parseUnary())
        }
        if matchToken(.bang) {
            return .unaryOp(.not, try parseUnary())
        }
        if matchToken(.plus) {
            return .unaryOp(.plus, try parseUnary())
        }
        return try parsePostfix()
    }

    private mutating func parsePostfix() throws -> Expression {
        var expr = try parsePrimary()
        while true {
            if matchToken(.leftBracket) {
                let index = try parseExpression()
                try consume(.rightBracket)
                expr = .indexAccess(expr, index)
            } else if matchToken(.dot) {
                let member = try consumeIdentifierName()
                expr = .memberAccess(expr, member)
            } else {
                break
            }
        }
        return expr
    }

    private mutating func parsePrimary() throws -> Expression {
        skipComments()
        let tok = peek()

        switch tok.type {
        case .numberLiteral:
            advance()
            guard let value = Double(tok.value) else {
                throw ParseError.unexpectedToken(tok)
            }
            return .number(value)

        case .stringLiteral:
            advance()
            return .string(tok.value)

        case .keyword(.true):
            advance()
            return .boolean(true)

        case .keyword(.false):
            advance()
            return .boolean(false)

        case .keyword(.undef):
            advance()
            return .undef

        case .specialVariable:
            advance()
            return .specialVariable(tok.value)

        case .identifier:
            advance()
            if check(.leftParen) {
                // Function call
                advance()
                let args = try parseArgumentList()
                try consume(.rightParen)
                return .functionCall(tok.value, args)
            }
            return .identifier(tok.value)

        case .builtinModule:
            advance()
            if check(.leftParen) {
                advance()
                let args = try parseArgumentList()
                try consume(.rightParen)
                return .functionCall(tok.value, args)
            }
            return .identifier(tok.value)

        case .keyword(.let):
            advance()
            return try parseLetExpression()

        case .leftParen:
            advance()
            let expr = try parseExpression()
            try consume(.rightParen)
            return expr

        case .leftBracket:
            advance()
            return try parseListOrRange()

        case .keyword(.each):
            advance()
            let expr = try parseExpression()
            return .functionCall("each", [Argument(value: expr)])

        default:
            throw ParseError.unexpectedToken(tok)
        }
    }

    private mutating func parseLetExpression() throws -> Expression {
        try consume(.leftParen)
        var assignments: [(String, Expression)] = []
        if !check(.rightParen) {
            repeat {
                let name = try consumeIdentifierName()
                try consume(.assign)
                let value = try parseExpression()
                assignments.append((name, value))
            } while matchToken(.comma)
        }
        try consume(.rightParen)
        let body = try parseExpression()
        return .letInExpression(assignments, body)
    }

    private mutating func parseListOrRange() throws -> Expression {
        if check(.rightBracket) {
            advance()
            return .listLiteral([])
        }

        // Check for list comprehension: [for (...) ...]
        if check(.keyword(.for)) {
            return try parseListComprehension()
        }

        let first = try parseExpression()

        // Range: [start : end] or [start : step : end]
        if matchToken(.colon) {
            let second = try parseExpression()
            if matchToken(.colon) {
                let third = try parseExpression()
                try consume(.rightBracket)
                return .range(first, second, third)
            }
            try consume(.rightBracket)
            return .range(first, nil, second)
        }

        // List literal: [expr, expr, ...]
        var elements = [first]
        while matchToken(.comma) {
            if check(.rightBracket) { break }
            elements.append(try parseExpression())
        }
        try consume(.rightBracket)
        return .listLiteral(elements)
    }

    private mutating func parseListComprehension() throws -> Expression {
        try consume(.keyword(.for))
        try consume(.leftParen)
        let variable = try consumeIdentifierName()
        try consume(.assign)
        let iterable = try parseExpression()
        try consume(.rightParen)

        var condition: Expression?
        if check(.keyword(.if)) {
            advance()
            try consume(.leftParen)
            condition = try parseExpression()
            try consume(.rightParen)
        }

        let body = try parseExpression()
        try consume(.rightBracket)

        return .listComprehension(ListComprehension(
            variable: variable, iterable: iterable, body: body, condition: condition
        ))
    }

    // MARK: - Argument/Parameter Lists

    private mutating func parseArgumentList() throws -> [Argument] {
        var args: [Argument] = []
        skipComments()
        if check(.rightParen) { return args }

        repeat {
            skipComments()
            if check(.rightParen) { break }
            // Check for named argument: name = expr
            if case .identifier = peek().type, peekNext()?.type == .assign {
                let name = peek().value
                advance() // consume name
                advance() // consume =
                let value = try parseExpression()
                args.append(Argument(name: name, value: value))
            } else if case .specialVariable = peek().type, peekNext()?.type == .assign {
                let name = peek().value
                advance()
                advance()
                let value = try parseExpression()
                args.append(Argument(name: name, value: value))
            } else {
                let value = try parseExpression()
                args.append(Argument(value: value))
            }
        } while matchToken(.comma)

        return args
    }

    private mutating func parseParameterList() throws -> [Parameter] {
        var params: [Parameter] = []
        if check(.rightParen) { return params }

        repeat {
            if check(.rightParen) { break }
            let name = try consumeIdentifierName()
            var defaultValue: Expression?
            if matchToken(.assign) {
                defaultValue = try parseExpression()
            }
            params.append(Parameter(name: name, defaultValue: defaultValue))
        } while matchToken(.comma)

        return params
    }

    // MARK: - Token Helpers

    private mutating func skipComments() {
        while current < tokens.count {
            let t = tokens[current].type
            if t == .lineComment || t == .blockComment {
                current += 1
            } else {
                break
            }
        }
    }

    private func peek() -> Token {
        guard current < tokens.count else {
            return Token(type: .eof, value: "", location: SourceLocation(line: 0, column: 0))
        }
        return tokens[current]
    }

    private func peekNext() -> Token? {
        var i = current + 1
        while i < tokens.count {
            let t = tokens[i].type
            if t == .lineComment || t == .blockComment {
                i += 1
                continue
            }
            return tokens[i]
        }
        return nil
    }

    @discardableResult
    private mutating func advance() -> Token {
        let tok = peek()
        current += 1
        skipComments()
        return tok
    }

    private func check(_ type: TokenType) -> Bool {
        peek().type == type
    }

    private func isAtEnd() -> Bool {
        peek().type == .eof
    }

    private mutating func matchToken(_ type: TokenType) -> Bool {
        if check(type) {
            advance()
            return true
        }
        return false
    }

    @discardableResult
    private mutating func consume(_ type: TokenType) throws -> Token {
        if check(type) { return advance() }
        throw ParseError.expected(type, got: peek())
    }

    private mutating func consumeIdentifierName() throws -> String {
        let tok = peek()
        switch tok.type {
        case .identifier:
            advance()
            return tok.value
        case .specialVariable:
            advance()
            return tok.value
        default:
            throw ParseError.expectedIdentifier(got: tok)
        }
    }

    private mutating func consumeIdentifierOrBuiltin() throws -> String {
        let tok = peek()
        switch tok.type {
        case .identifier:
            advance()
            return tok.value
        case .builtinModule:
            advance()
            return tok.value
        default:
            throw ParseError.expectedIdentifier(got: tok)
        }
    }

    private func checkIdentifierOrBuiltin() -> Bool {
        switch peek().type {
        case .identifier: return true
        case .builtinModule: return true
        default: return false
        }
    }

    private func checkAssignment() -> Bool {
        guard case .identifier = peek().type else { return false }
        guard let next = peekNext() else { return false }
        return next.type == .assign
    }

    private func checkModifier() -> ModifierChar? {
        let tok = peek()
        switch tok.type {
        case .star:
            if let next = peekNext(), next.type.isIdentifierOrBuiltin { return .disable }
        case .bang:
            if let next = peekNext(), next.type.isIdentifierOrBuiltin { return .showOnly }
        case .modifier:
            if tok.value == "#", let next = peekNext(), next.type.isIdentifierOrBuiltin { return .highlight }
        case .percent:
            if let next = peekNext(), next.type.isIdentifierOrBuiltin { return .transparent }
        default:
            break
        }
        return nil
    }

    private mutating func consumeOptionalSemicolon() throws {
        if check(.semicolon) { advance() }
    }

    private func currentLocation() -> SourceLocation {
        peek().location
    }

    private func captureTrailingComment() -> String? {
        // Look for a comment token that follows on the same line
        guard current < tokens.count else { return nil }
        let tok = tokens[current]
        if tok.type == .lineComment {
            return tok.value
        }
        return nil
    }
}

// MARK: - Token Type Helpers

extension TokenType {
    var isIdentifierOrBuiltin: Bool {
        switch self {
        case .identifier, .builtinModule: return true
        default: return false
        }
    }
}

// MARK: - Parse Error

public enum ParseError: Error, CustomStringConvertible {
    case unexpectedToken(Token)
    case expected(TokenType, got: Token)
    case expectedIdentifier(got: Token)
    case unexpectedEOF

    public var description: String {
        switch self {
        case .unexpectedToken(let tok):
            return "Unexpected token '\(tok.type)' at line \(tok.location.line), column \(tok.location.column)"
        case .expected(let expected, let got):
            return "Expected '\(expected)' but got '\(got.type)' at line \(got.location.line), column \(got.location.column)"
        case .expectedIdentifier(let got):
            return "Expected identifier but got '\(got.type)' at line \(got.location.line), column \(got.location.column)"
        case .unexpectedEOF:
            return "Unexpected end of file"
        }
    }
}
