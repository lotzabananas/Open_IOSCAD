import Foundation

/// Tokenizes OpenSCAD source code into a stream of `Token` values.
///
/// Usage:
/// ```swift
/// let lexer = Lexer(source: "cube([10,10,10]);")
/// let tokens = try lexer.tokenize()
/// ```
public struct Lexer: Sendable {

    // MARK: - Stored Properties

    private let source: String
    private let scalars: [Unicode.Scalar]

    // MARK: - Init

    public init(source: String) {
        self.source = source
        self.scalars = Array(source.unicodeScalars)
    }

    // MARK: - Public API

    /// Tokenize the entire source into an array of tokens, ending with `.eof`.
    public func tokenize() throws -> [Token] {
        var state = ScanState(scalars: scalars)
        var tokens: [Token] = []

        while !state.isAtEnd {
            state.skipWhitespace()
            if state.isAtEnd { break }

            let token = try state.scanToken()
            tokens.append(token)
        }

        tokens.append(Token(
            type: .eof,
            value: "",
            location: state.currentLocation
        ))
        return tokens
    }
}

// MARK: - Lookup Tables

/// Set of keyword raw values for O(1) lookup.
private let keywordSet: Set<String> = Set(Keyword.allCases.map(\.rawValue))

/// Set of builtin module raw values for O(1) lookup.
private let builtinModuleSet: Set<String> = Set(BuiltinModule.allCases.map(\.rawValue))

// MARK: - Scan State

/// Mutable scanning state used internally by the lexer.
/// Separated from the `Lexer` struct so `tokenize()` can be non-mutating.
///
/// Uses `Unicode.Scalar` rather than `Character` to avoid Swift's grapheme
/// clustering (which merges `\r\n` into a single `Character`).
private struct ScanState {
    let scalars: [Unicode.Scalar]
    var position: Int = 0
    var line: Int = 1
    var column: Int = 1

    var isAtEnd: Bool { position >= scalars.count }
    var currentLocation: SourceLocation { SourceLocation(line: line, column: column) }

    // MARK: - Scalar Access

    func peek() -> Unicode.Scalar? {
        guard position < scalars.count else { return nil }
        return scalars[position]
    }

    func peekNext() -> Unicode.Scalar? {
        let next = position + 1
        guard next < scalars.count else { return nil }
        return scalars[next]
    }

    @discardableResult
    mutating func advance() -> Unicode.Scalar {
        let s = scalars[position]
        position += 1
        if s == "\n" {
            line += 1
            column = 1
        } else if s == "\r" {
            // \r followed by \n: treat as one newline; the \n will be skipped
            if position < scalars.count && scalars[position] == "\n" {
                position += 1
            }
            line += 1
            column = 1
        } else {
            column += 1
        }
        return s
    }

    mutating func match(_ expected: Unicode.Scalar) -> Bool {
        guard !isAtEnd, scalars[position] == expected else { return false }
        advance()
        return true
    }

    // MARK: - Whitespace

    mutating func skipWhitespace() {
        while !isAtEnd {
            guard let s = peek() else { return }
            if s == " " || s == "\t" || s == "\r" || s == "\n" {
                advance()
            } else {
                return
            }
        }
    }

    // MARK: - Token Scanning

    mutating func scanToken() throws -> Token {
        let startLocation = currentLocation
        let s = peek()!

        // Comments: // and /* */
        if s == "/" {
            if peekNext() == "/" {
                return scanLineComment(startLocation: startLocation)
            } else if peekNext() == "*" {
                return try scanBlockComment(startLocation: startLocation)
            }
        }

        // String literals
        if s == "\"" {
            return try scanString(startLocation: startLocation)
        }

        // Number literals
        if s.isDigit || (s == "." && peekNext()?.isDigit == true) {
            return try scanNumber(startLocation: startLocation)
        }

        // Special variables ($fn, $fa, etc.) and any $-prefixed identifier
        if s == "$" {
            return scanSpecialVariable(startLocation: startLocation)
        }

        // Identifiers and keywords
        if s.isIdentifierStart {
            return scanIdentifierOrKeyword(startLocation: startLocation)
        }

        // Modifier character: # has no other operator meaning in OpenSCAD
        if s == "#" {
            advance()
            return Token(type: .modifier, value: "#", location: startLocation)
        }

        // Two-character operators first
        if let token = try scanTwoCharOperator(startLocation: startLocation) {
            return token
        }

        // Single-character operators and delimiters
        if let token = scanSingleCharToken(startLocation: startLocation) {
            return token
        }

        let ch = Character(advance())
        throw LexerError.unexpectedCharacter(ch, startLocation)
    }

    // MARK: - Line Comment

    mutating func scanLineComment(startLocation: SourceLocation) -> Token {
        // Consume the //
        advance() // /
        advance() // /
        var text = "//"
        while !isAtEnd, let s = peek(), s != "\n" && s != "\r" {
            text.append(Character(advance()))
        }
        return Token(type: .lineComment, value: text, location: startLocation)
    }

    // MARK: - Block Comment (supports nesting)

    mutating func scanBlockComment(startLocation: SourceLocation) throws -> Token {
        // Consume the /*
        advance() // /
        advance() // *
        var text = "/*"
        var depth = 1

        while !isAtEnd && depth > 0 {
            let s = peek()!
            if s == "/" && peekNext() == "*" {
                text.append(Character(advance())) // /
                text.append(Character(advance())) // *
                depth += 1
            } else if s == "*" && peekNext() == "/" {
                text.append(Character(advance())) // *
                text.append(Character(advance())) // /
                depth -= 1
            } else {
                let advanced = advance()
                if advanced == "\r" {
                    // \r or \r\n becomes a newline in the text
                    text.append("\n")
                } else {
                    text.append(Character(advanced))
                }
            }
        }

        if depth > 0 {
            throw LexerError.unterminatedBlockComment(startLocation)
        }

        return Token(type: .blockComment, value: text, location: startLocation)
    }

    // MARK: - String Literal

    mutating func scanString(startLocation: SourceLocation) throws -> Token {
        advance() // consume opening "
        var value = ""

        while !isAtEnd {
            let s = peek()!
            if s == "\"" {
                advance() // consume closing "
                return Token(type: .stringLiteral, value: value, location: startLocation)
            } else if s == "\\" {
                advance() // consume backslash
                guard !isAtEnd else {
                    throw LexerError.unterminatedString(startLocation)
                }
                let escaped = advance()
                switch escaped {
                case "n": value.append("\n")
                case "t": value.append("\t")
                case "\\": value.append("\\")
                case "\"": value.append("\"")
                case "r": value.append("\r")
                case "0": value.append("\0")
                default:
                    throw LexerError.invalidEscapeSequence(Character(escaped), currentLocation)
                }
            } else if s == "\n" || s == "\r" {
                // OpenSCAD does not allow unescaped newlines in strings
                throw LexerError.unterminatedString(startLocation)
            } else {
                value.append(Character(advance()))
            }
        }

        throw LexerError.unterminatedString(startLocation)
    }

    // MARK: - Number Literal

    mutating func scanNumber(startLocation: SourceLocation) throws -> Token {
        var text = ""

        // Integer part (may be empty if starts with '.')
        while !isAtEnd, let s = peek(), s.isDigit {
            text.append(Character(advance()))
        }

        // Fractional part
        if !isAtEnd, peek() == ".", peekNext()?.isDigit == true {
            text.append(Character(advance())) // .
            while !isAtEnd, let s = peek(), s.isDigit {
                text.append(Character(advance()))
            }
        } else if !isAtEnd, peek() == "." {
            // A trailing dot with no digits after it: only consume it if we have digits before
            // e.g., "10." is valid as 10.0, but we need to be careful about "10.method"
            // Only consume the dot if the next char is NOT an identifier start
            if !text.isEmpty {
                let afterDot = peekNext()
                if afterDot == nil || !(afterDot!.isIdentifierStart) {
                    text.append(Character(advance())) // .
                }
            }
        }

        // Exponent part (e or E, optionally followed by + or -, then digits)
        if !isAtEnd, let s = peek(), s == "e" || s == "E" {
            text.append(Character(advance())) // e/E
            if !isAtEnd, let sign = peek(), sign == "+" || sign == "-" {
                text.append(Character(advance()))
            }
            if isAtEnd || peek()?.isDigit != true {
                throw LexerError.invalidNumberLiteral(text, startLocation)
            }
            while !isAtEnd, let s = peek(), s.isDigit {
                text.append(Character(advance()))
            }
        }

        if text.isEmpty {
            throw LexerError.invalidNumberLiteral(".", startLocation)
        }

        return Token(type: .numberLiteral, value: text, location: startLocation)
    }

    // MARK: - Special Variable

    mutating func scanSpecialVariable(startLocation: SourceLocation) -> Token {
        advance() // consume $
        var name = "$"
        while !isAtEnd, let s = peek(), s.isIdentifierContinuation {
            name.append(Character(advance()))
        }
        return Token(type: .specialVariable, value: name, location: startLocation)
    }

    // MARK: - Identifier / Keyword / Builtin Module

    mutating func scanIdentifierOrKeyword(startLocation: SourceLocation) -> Token {
        var name = ""
        while !isAtEnd, let s = peek(), s.isIdentifierContinuation {
            name.append(Character(advance()))
        }

        // Check keywords first
        if let kw = Keyword(rawValue: name) {
            return Token(type: .keyword(kw), value: name, location: startLocation)
        }

        // Check builtin modules
        if builtinModuleSet.contains(name) {
            return Token(type: .builtinModule, value: name, location: startLocation)
        }

        return Token(type: .identifier, value: name, location: startLocation)
    }

    // MARK: - Two-Character Operators

    mutating func scanTwoCharOperator(startLocation: SourceLocation) throws -> Token? {
        guard let s = peek() else { return nil }

        switch s {
        case "<":
            advance()
            if match("=") {
                return Token(type: .lessEqual, value: "<=", location: startLocation)
            }
            return Token(type: .less, value: "<", location: startLocation)

        case ">":
            advance()
            if match("=") {
                return Token(type: .greaterEqual, value: ">=", location: startLocation)
            }
            return Token(type: .greater, value: ">", location: startLocation)

        case "=":
            advance()
            if match("=") {
                return Token(type: .equalEqual, value: "==", location: startLocation)
            }
            return Token(type: .assign, value: "=", location: startLocation)

        case "!":
            advance()
            if match("=") {
                return Token(type: .notEqual, value: "!=", location: startLocation)
            }
            return Token(type: .bang, value: "!", location: startLocation)

        case "&":
            if peekNext() == "&" {
                advance()
                advance()
                return Token(type: .and, value: "&&", location: startLocation)
            }
            return nil

        case "|":
            if peekNext() == "|" {
                advance()
                advance()
                return Token(type: .or, value: "||", location: startLocation)
            }
            return nil

        default:
            return nil
        }
    }

    // MARK: - Single-Character Tokens

    mutating func scanSingleCharToken(startLocation: SourceLocation) -> Token? {
        guard let s = peek() else { return nil }

        let type: TokenType
        switch s {
        case "+": type = .plus
        case "-": type = .minus
        case "*": type = .star
        case "/": type = .slash
        case "%": type = .percent
        case "^": type = .caret
        case "(": type = .leftParen
        case ")": type = .rightParen
        case "[": type = .leftBracket
        case "]": type = .rightBracket
        case "{": type = .leftBrace
        case "}": type = .rightBrace
        case ",": type = .comma
        case ";": type = .semicolon
        case ".": type = .dot
        case "?": type = .question
        case ":": type = .colon
        default: return nil
        }

        advance()
        return Token(type: type, value: String(s), location: startLocation)
    }
}

// MARK: - Unicode.Scalar Extensions

private extension Unicode.Scalar {
    var isDigit: Bool {
        self >= "0" && self <= "9"
    }

    var isIdentifierStart: Bool {
        (self >= "a" && self <= "z") ||
        (self >= "A" && self <= "Z") ||
        self == "_"
    }

    var isIdentifierContinuation: Bool {
        isIdentifierStart || isDigit
    }
}
