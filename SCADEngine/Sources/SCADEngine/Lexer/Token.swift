import Foundation

// MARK: - Source Location

/// A position in source code, used for error reporting and editor integration.
public struct SourceLocation: Equatable, Sendable, CustomStringConvertible {
    /// 1-based line number.
    public let line: Int
    /// 1-based column number.
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    public var description: String {
        "\(line):\(column)"
    }
}

// MARK: - Token

/// A single token produced by the OpenSCAD lexer.
public struct Token: Equatable, Sendable, CustomStringConvertible {
    public let type: TokenType
    public let value: String
    public let location: SourceLocation

    public init(type: TokenType, value: String, location: SourceLocation) {
        self.type = type
        self.value = value
        self.location = location
    }

    public var description: String {
        "\(type)(\(value.debugDescription)) at \(location)"
    }
}

// MARK: - Token Type

/// All possible token types produced by the OpenSCAD lexer.
public enum TokenType: Equatable, Sendable, CustomStringConvertible {

    // MARK: Literals

    /// An integer or floating-point number literal (including scientific notation).
    case numberLiteral
    /// A double-quoted string literal (escape sequences already decoded in value).
    case stringLiteral

    // MARK: Identifiers & Keywords

    /// A user-defined identifier (variable name, custom module/function name).
    case identifier
    /// A language keyword (module, function, if, else, for, let, each, include, use, true, false, undef).
    case keyword(Keyword)
    /// A recognized built-in module name (cube, sphere, translate, etc.).
    case builtinModule

    // MARK: Operators

    case plus              // +
    case minus             // -
    case star              // *
    case slash             // /
    case percent           // %
    case caret             // ^
    case less              // <
    case greater           // >
    case lessEqual         // <=
    case greaterEqual      // >=
    case equalEqual        // ==
    case notEqual          // !=
    case and               // &&
    case or                // ||
    case bang              // !
    case question          // ?
    case colon             // :

    // MARK: Delimiters

    case leftParen         // (
    case rightParen        // )
    case leftBracket       // [
    case rightBracket      // ]
    case leftBrace         // {
    case rightBrace        // }
    case comma             // ,
    case semicolon         // ;
    case dot               // .
    case assign            // =

    // MARK: Comments

    /// A line comment (// ...). The value contains the full comment text including //.
    case lineComment
    /// A block comment (/* ... */). The value contains the full comment text including delimiters.
    case blockComment

    // MARK: Special Variables

    /// An OpenSCAD special variable ($fn, $fa, $fs, $t, $children, or any $-prefixed name).
    case specialVariable

    // MARK: Modifier Characters

    /// A modifier prefix on a module instantiation (*, !, #, %).
    case modifier

    // MARK: End of File

    case eof

    public var description: String {
        switch self {
        case .numberLiteral: return "number"
        case .stringLiteral: return "string"
        case .identifier: return "identifier"
        case .keyword(let kw): return "keyword(\(kw.rawValue))"
        case .builtinModule: return "builtin"
        case .plus: return "+"
        case .minus: return "-"
        case .star: return "*"
        case .slash: return "/"
        case .percent: return "%"
        case .caret: return "^"
        case .less: return "<"
        case .greater: return ">"
        case .lessEqual: return "<="
        case .greaterEqual: return ">="
        case .equalEqual: return "=="
        case .notEqual: return "!="
        case .and: return "&&"
        case .or: return "||"
        case .bang: return "!"
        case .question: return "?"
        case .colon: return ":"
        case .leftParen: return "("
        case .rightParen: return ")"
        case .leftBracket: return "["
        case .rightBracket: return "]"
        case .leftBrace: return "{"
        case .rightBrace: return "}"
        case .comma: return ","
        case .semicolon: return ";"
        case .dot: return "."
        case .assign: return "="
        case .lineComment: return "lineComment"
        case .blockComment: return "blockComment"
        case .specialVariable: return "specialVariable"
        case .modifier: return "modifier"
        case .eof: return "eof"
        }
    }
}

// MARK: - Keyword

/// OpenSCAD language keywords.
public enum Keyword: String, Equatable, Sendable, CaseIterable {
    case module
    case function
    case `if`
    case `else`
    case `for`
    case `let`
    case each
    case include
    case use
    case `true`
    case `false`
    case undef
}

// MARK: - Builtin Module Names

/// Recognized OpenSCAD built-in module and function names.
/// These are lexed as `.builtinModule` tokens rather than plain identifiers.
public enum BuiltinModule: String, Equatable, Sendable, CaseIterable {
    case cube
    case cylinder
    case sphere
    case polyhedron
    case union
    case difference
    case intersection
    case translate
    case rotate
    case scale
    case mirror
    case linear_extrude
    case rotate_extrude
    case color
    case `import`
    case projection
    case hull
    case minkowski
    case echo
    case assert
    case children
}

// MARK: - Lexer Error

/// Errors that can occur during lexing.
public enum LexerError: Error, Equatable, Sendable, CustomStringConvertible {
    case unexpectedCharacter(Character, SourceLocation)
    case unterminatedString(SourceLocation)
    case unterminatedBlockComment(SourceLocation)
    case invalidEscapeSequence(Character, SourceLocation)
    case invalidNumberLiteral(String, SourceLocation)

    public var description: String {
        switch self {
        case .unexpectedCharacter(let ch, let loc):
            return "Unexpected character '\(ch)' at \(loc)"
        case .unterminatedString(let loc):
            return "Unterminated string literal starting at \(loc)"
        case .unterminatedBlockComment(let loc):
            return "Unterminated block comment starting at \(loc)"
        case .invalidEscapeSequence(let ch, let loc):
            return "Invalid escape sequence '\\(\(ch))' at \(loc)"
        case .invalidNumberLiteral(let text, let loc):
            return "Invalid number literal '\(text)' at \(loc)"
        }
    }
}
