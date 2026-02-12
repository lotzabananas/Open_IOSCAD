import Foundation

// MARK: - AST Node Types

public indirect enum ASTNode: Equatable, Sendable {
    case program([ASTNode])
    case moduleDefinition(ModuleDefinition)
    case functionDefinition(FunctionDefinition)
    case moduleInstantiation(ModuleInstantiation)
    case assignment(Assignment)
    case ifStatement(IfStatement)
    case forStatement(ForStatement)
    case letExpression(LetExpression)
    case useStatement(String)
    case includeStatement(String)
    case expression(Expression)
    case block([ASTNode])
    case empty
}

public struct ModuleDefinition: Equatable, Sendable {
    public let name: String
    public let parameters: [Parameter]
    public let body: ASTNode
    public let location: SourceLocation

    public init(name: String, parameters: [Parameter], body: ASTNode, location: SourceLocation) {
        self.name = name
        self.parameters = parameters
        self.body = body
        self.location = location
    }
}

public struct FunctionDefinition: Equatable, Sendable {
    public let name: String
    public let parameters: [Parameter]
    public let body: Expression
    public let location: SourceLocation

    public init(name: String, parameters: [Parameter], body: Expression, location: SourceLocation) {
        self.name = name
        self.parameters = parameters
        self.body = body
        self.location = location
    }
}

public struct ModuleInstantiation: Equatable, Sendable {
    public let name: String
    public let arguments: [Argument]
    public let children: ASTNode?
    public let modifier: ModifierChar?
    public let location: SourceLocation

    public init(name: String, arguments: [Argument], children: ASTNode?, modifier: ModifierChar? = nil, location: SourceLocation) {
        self.name = name
        self.arguments = arguments
        self.children = children
        self.modifier = modifier
        self.location = location
    }
}

public struct Assignment: Equatable, Sendable {
    public let name: String
    public let value: Expression
    public let location: SourceLocation
    public let trailingComment: String?

    public init(name: String, value: Expression, location: SourceLocation, trailingComment: String? = nil) {
        self.name = name
        self.value = value
        self.location = location
        self.trailingComment = trailingComment
    }
}

public struct IfStatement: Equatable, Sendable {
    public let condition: Expression
    public let thenBranch: ASTNode
    public let elseBranch: ASTNode?
    public let location: SourceLocation

    public init(condition: Expression, thenBranch: ASTNode, elseBranch: ASTNode? = nil, location: SourceLocation) {
        self.condition = condition
        self.thenBranch = thenBranch
        self.elseBranch = elseBranch
        self.location = location
    }
}

public struct ForStatement: Equatable, Sendable {
    public let variable: String
    public let iterable: Expression
    public let body: ASTNode
    public let location: SourceLocation

    public init(variable: String, iterable: Expression, body: ASTNode, location: SourceLocation) {
        self.variable = variable
        self.iterable = iterable
        self.body = body
        self.location = location
    }
}

public struct LetExpression: Equatable, Sendable {
    public let assignments: [(String, Expression)]
    public let body: ASTNode
    public let location: SourceLocation

    public init(assignments: [(String, Expression)], body: ASTNode, location: SourceLocation) {
        self.assignments = assignments
        self.body = body
        self.location = location
    }

    public static func == (lhs: LetExpression, rhs: LetExpression) -> Bool {
        guard lhs.assignments.count == rhs.assignments.count else { return false }
        for (l, r) in zip(lhs.assignments, rhs.assignments) {
            guard l.0 == r.0 && l.1 == r.1 else { return false }
        }
        return lhs.body == rhs.body && lhs.location == rhs.location
    }
}

public struct Parameter: Equatable, Sendable {
    public let name: String
    public let defaultValue: Expression?

    public init(name: String, defaultValue: Expression? = nil) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

public struct Argument: Equatable, Sendable {
    public let name: String?
    public let value: Expression

    public init(name: String? = nil, value: Expression) {
        self.name = name
        self.value = value
    }
}

public enum ModifierChar: String, Sendable {
    case disable = "*"
    case showOnly = "!"
    case highlight = "#"
    case transparent = "%"
}

// MARK: - Expressions

public indirect enum Expression: Sendable {
    case number(Double)
    case string(String)
    case boolean(Bool)
    case undef
    case identifier(String)
    case specialVariable(String) // $fn, $fa, etc.
    case unaryOp(UnaryOperator, Expression)
    case binaryOp(BinaryOperator, Expression, Expression)
    case ternary(Expression, Expression, Expression)
    case functionCall(String, [Argument])
    case listLiteral([Expression])
    case range(Expression, Expression?, Expression) // start, step?, end
    case indexAccess(Expression, Expression)
    case memberAccess(Expression, String)
    case listComprehension(ListComprehension)
    case letInExpression([(String, Expression)], Expression)
}

extension Expression: Equatable {
    public static func == (lhs: Expression, rhs: Expression) -> Bool {
        switch (lhs, rhs) {
        case (.number(let a), .number(let b)):
            return a == b
        case (.string(let a), .string(let b)):
            return a == b
        case (.boolean(let a), .boolean(let b)):
            return a == b
        case (.undef, .undef):
            return true
        case (.identifier(let a), .identifier(let b)):
            return a == b
        case (.specialVariable(let a), .specialVariable(let b)):
            return a == b
        case (.unaryOp(let opA, let exprA), .unaryOp(let opB, let exprB)):
            return opA == opB && exprA == exprB
        case (.binaryOp(let opA, let lA, let rA), .binaryOp(let opB, let lB, let rB)):
            return opA == opB && lA == lB && rA == rB
        case (.ternary(let cA, let tA, let fA), .ternary(let cB, let tB, let fB)):
            return cA == cB && tA == tB && fA == fB
        case (.functionCall(let nA, let argsA), .functionCall(let nB, let argsB)):
            return nA == nB && argsA == argsB
        case (.listLiteral(let a), .listLiteral(let b)):
            return a == b
        case (.range(let sA, let stA, let eA), .range(let sB, let stB, let eB)):
            return sA == sB && stA == stB && eA == eB
        case (.indexAccess(let aA, let iA), .indexAccess(let aB, let iB)):
            return aA == aB && iA == iB
        case (.memberAccess(let eA, let mA), .memberAccess(let eB, let mB)):
            return eA == eB && mA == mB
        case (.listComprehension(let a), .listComprehension(let b)):
            return a == b
        case (.letInExpression(let asA, let bA), .letInExpression(let asB, let bB)):
            guard asA.count == asB.count else { return false }
            for (a, b) in zip(asA, asB) {
                guard a.0 == b.0 && a.1 == b.1 else { return false }
            }
            return bA == bB
        default:
            return false
        }
    }
}

public struct ListComprehension: Equatable, Sendable {
    public let variable: String
    public let iterable: Expression
    public let body: Expression
    public let condition: Expression?

    public init(variable: String, iterable: Expression, body: Expression, condition: Expression? = nil) {
        self.variable = variable
        self.iterable = iterable
        self.body = body
        self.condition = condition
    }
}

public enum UnaryOperator: String, Sendable {
    case negate = "-"
    case not = "!"
    case plus = "+"
}

public enum BinaryOperator: String, Sendable {
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"
    case modulo = "%"
    case power = "^"
    case lessThan = "<"
    case greaterThan = ">"
    case lessEqual = "<="
    case greaterEqual = ">="
    case equal = "=="
    case notEqual = "!="
    case and = "&&"
    case or = "||"
}
