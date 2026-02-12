import Foundation

public struct CustomizerParam: Equatable, Sendable {
    public let name: String
    public let label: String
    public let group: String?
    public let defaultValue: Value
    public let constraint: ParamConstraint?
    public let lineNumber: Int

    public init(name: String, label: String, group: String? = nil, defaultValue: Value,
                constraint: ParamConstraint? = nil, lineNumber: Int) {
        self.name = name
        self.label = label
        self.group = group
        self.defaultValue = defaultValue
        self.constraint = constraint
        self.lineNumber = lineNumber
    }
}

public enum ParamConstraint: Equatable, Sendable {
    case range(min: Double, step: Double?, max: Double)
    case enumList([String])
}

public final class CustomizerExtractor {
    public init() {}

    public func extract(from source: String) -> [CustomizerParam] {
        let lines = source.components(separatedBy: "\n")
        var params: [CustomizerParam] = []
        var currentGroup: String? = nil

        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for group header: /* [GroupName] */
            if let group = parseGroupHeader(trimmed) {
                currentGroup = group
                continue
            }

            // Check for variable assignment with optional comment annotation
            if let param = parseAssignmentLine(trimmed, lineNumber: lineIndex + 1, group: currentGroup) {
                params.append(param)
            }
        }

        return params
    }

    /// Update script source with new parameter values
    public func updateParameter(in source: String, name: String, newValue: Value) -> String {
        let lines = source.components(separatedBy: "\n")
        var result = lines

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let eqIndex = trimmed.firstIndex(of: "=") else { continue }
            let varName = trimmed[trimmed.startIndex..<eqIndex].trimmingCharacters(in: .whitespaces)
            guard varName == name else { continue }

            // Find the value part (between = and ; or //)
            let afterEq = trimmed[trimmed.index(after: eqIndex)...]
            var valueEnd = afterEq.endIndex
            if let semiIndex = afterEq.firstIndex(of: ";") {
                valueEnd = semiIndex
            }

            // Preserve comment
            var comment = ""
            if let commentStart = line.range(of: "//") {
                comment = " " + String(line[commentStart.lowerBound...])
            }

            let indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
            let newValueStr: String
            switch newValue {
            case .number(let n):
                if n == n.rounded() && abs(n) < 1e15 {
                    newValueStr = "\(Int(n))"
                } else {
                    newValueStr = "\(n)"
                }
            case .string(let s):
                newValueStr = "\"\(s)\""
            case .boolean(let b):
                newValueStr = b ? "true" : "false"
            default:
                newValueStr = newValue.description
            }

            result[i] = "\(indent)\(name) = \(newValueStr);\(comment)"
            break
        }

        return result.joined(separator: "\n")
    }

    // MARK: - Private

    private func parseGroupHeader(_ line: String) -> String? {
        let pattern = #"^/\*\s*\[(.+?)\]\s*\*/$"#
        guard let match = line.range(of: pattern, options: .regularExpression) else { return nil }
        let content = line[match]
        // Extract group name between [ and ]
        if let start = content.firstIndex(of: "["),
           let end = content.firstIndex(of: "]") {
            return String(content[content.index(after: start)..<end])
        }
        return nil
    }

    private func parseAssignmentLine(_ line: String, lineNumber: Int, group: String?) -> CustomizerParam? {
        // Match: varname = value; // [annotation] label
        let pattern = #"^(\w+)\s*=\s*(.+?)\s*;\s*(//\s*(.*))?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        let varName = String(line[Range(match.range(at: 1), in: line)!])
        let valueStr = String(line[Range(match.range(at: 2), in: line)!]).trimmingCharacters(in: .whitespaces)

        var comment = ""
        if match.range(at: 4).location != NSNotFound {
            comment = String(line[Range(match.range(at: 4), in: line)!])
        }

        let defaultValue = parseValue(valueStr)
        let (constraint, label) = parseAnnotation(comment)

        return CustomizerParam(
            name: varName,
            label: label.isEmpty ? varName : label,
            group: group,
            defaultValue: defaultValue,
            constraint: constraint,
            lineNumber: lineNumber
        )
    }

    private func parseValue(_ str: String) -> Value {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        if trimmed == "true" { return .boolean(true) }
        if trimmed == "false" { return .boolean(false) }
        if trimmed == "undef" { return .undef }

        if let num = Double(trimmed) {
            return .number(num)
        }

        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            let inner = String(trimmed.dropFirst().dropLast())
            return .string(inner)
        }

        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            let inner = String(trimmed.dropFirst().dropLast())
            let elements = inner.components(separatedBy: ",").map { elem -> Value in
                parseValue(elem.trimmingCharacters(in: .whitespaces))
            }
            return .vector(elements)
        }

        return .string(trimmed)
    }

    private func parseAnnotation(_ comment: String) -> (ParamConstraint?, String) {
        let trimmed = comment.trimmingCharacters(in: .whitespaces)

        // [min:max] or [min:step:max] — range annotation
        let rangePattern = #"^\[(\-?[\d.]+)\s*:\s*(\-?[\d.]+)(?:\s*:\s*(\-?[\d.]+))?\]\s*(.*)"#
        if let regex = try? NSRegularExpression(pattern: rangePattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {

            let firstStr = String(trimmed[Range(match.range(at: 1), in: trimmed)!])
            let secondStr = String(trimmed[Range(match.range(at: 2), in: trimmed)!])

            var label = ""
            if match.range(at: 4).location != NSNotFound {
                label = String(trimmed[Range(match.range(at: 4), in: trimmed)!]).trimmingCharacters(in: .whitespaces)
            }

            if match.range(at: 3).location != NSNotFound {
                // [min:step:max]
                let thirdStr = String(trimmed[Range(match.range(at: 3), in: trimmed)!])
                if let min = Double(firstStr), let step = Double(secondStr), let max = Double(thirdStr) {
                    return (.range(min: min, step: step, max: max), label)
                }
            } else {
                // [min:max]
                if let min = Double(firstStr), let max = Double(secondStr) {
                    return (.range(min: min, step: nil, max: max), label)
                }
            }
        }

        // [opt1, opt2, opt3] — enum annotation
        let enumPattern = #"^\[([^\]]*[a-zA-Z][^\]]*)\]\s*(.*)"#
        if let regex = try? NSRegularExpression(pattern: enumPattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {

            let optionsStr = String(trimmed[Range(match.range(at: 1), in: trimmed)!])
            let options = optionsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            var label = ""
            if match.range(at: 2).location != NSNotFound {
                label = String(trimmed[Range(match.range(at: 2), in: trimmed)!]).trimmingCharacters(in: .whitespaces)
            }

            return (.enumList(options), label)
        }

        return (nil, trimmed)
    }
}
