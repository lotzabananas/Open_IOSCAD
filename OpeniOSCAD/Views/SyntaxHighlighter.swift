import UIKit
import SCADEngine

/// Applies OpenSCAD syntax highlighting to an NSAttributedString.
struct SyntaxHighlighter {

    struct Theme {
        let keyword = UIColor.systemBlue
        let builtin = UIColor.systemTeal
        let number = UIColor.systemOrange
        let string = UIColor.systemGreen
        let comment = UIColor.systemGray
        let feature = UIColor.systemPurple
        let specialVar = UIColor.systemTeal
        let plain = UIColor.label
        let background = UIColor.systemBackground
        let font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    }

    static let theme = Theme()

    /// Highlights OpenSCAD source using the Lexer's token stream.
    static func highlight(_ source: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: source,
            attributes: [
                .foregroundColor: theme.plain,
                .font: theme.font
            ]
        )

        // Tokenize for highlighting (ignore errors — partially valid code should still highlight)
        let lexer = Lexer(source: source)
        guard let tokens = try? lexer.tokenize() else {
            // Fallback: just highlight comments and @feature annotations with regex
            highlightComments(in: result, source: source)
            return result
        }

        let nsSource = source as NSString

        for token in tokens {
            guard token.type != .eof else { continue }

            let color: UIColor?
            let bold: Bool

            switch token.type {
            case .keyword:
                color = theme.keyword
                bold = true
            case .builtinModule:
                color = theme.builtin
                bold = false
            case .numberLiteral:
                color = theme.number
                bold = false
            case .stringLiteral:
                color = theme.string
                bold = false
            case .lineComment:
                if token.value.contains("@feature") {
                    color = theme.feature
                } else {
                    color = theme.comment
                }
                bold = false
            case .blockComment:
                color = theme.comment
                bold = false
            case .specialVariable:
                color = theme.specialVar
                bold = false
            default:
                color = nil
                bold = false
            }

            guard let col = color else { continue }

            // Convert SourceLocation to NSRange
            if let range = rangeForToken(token, in: source) {
                let nsRange = NSRange(range, in: source)
                result.addAttribute(.foregroundColor, value: col, range: nsRange)
                if bold {
                    result.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold), range: nsRange)
                }
            }
        }

        return result
    }

    /// Find the string range for a token based on its source location and value.
    private static func rangeForToken(_ token: Token, in source: String) -> Range<String.Index>? {
        let lines = source.components(separatedBy: "\n")
        let line = token.location.line - 1
        let col = token.location.column - 1

        guard line >= 0, line < lines.count else { return nil }

        // Calculate the offset from the start of the string
        var offset = 0
        for i in 0..<line {
            offset += lines[i].count + 1 // +1 for \n
        }
        offset += col

        let startIndex = source.index(source.startIndex, offsetBy: offset, limitedBy: source.endIndex)
        guard let start = startIndex else { return nil }

        let tokenLen = token.value.count
        let endIndex = source.index(start, offsetBy: tokenLen, limitedBy: source.endIndex)
        guard let end = endIndex else { return nil }

        return start..<end
    }

    /// Fallback regex-based comment highlighting when lexer fails.
    private static func highlightComments(in result: NSMutableAttributedString, source: String) {
        let nsSource = source as NSString

        // Line comments
        if let regex = try? NSRegularExpression(pattern: "//.*$", options: .anchorsMatchLines) {
            for match in regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length)) {
                let matchStr = nsSource.substring(with: match.range)
                let color = matchStr.contains("@feature") ? theme.feature : theme.comment
                result.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }

        // Block comments
        if let regex = try? NSRegularExpression(pattern: "/\\*[\\s\\S]*?\\*/", options: []) {
            for match in regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length)) {
                result.addAttribute(.foregroundColor, value: theme.comment, range: match.range)
            }
        }
    }
}
