import Foundation

/// Generates OpenSCAD script text for GUI actions.
/// All GUI-originated model changes flow through here to produce valid .scad code
/// with @feature annotations that the feature tree can parse.
struct ScriptBridge {

    enum PrimitiveType: String, CaseIterable {
        case cube, cylinder, sphere
    }

    enum BooleanOp: String {
        case difference, union, intersection
    }

    // MARK: - Feature Name Generation

    /// Returns the next auto-incremented name for a primitive type.
    /// Scans existing script for feature annotations like `// @feature "Cube 1"`
    /// and returns the next available number.
    static func nextFeatureName(for type: String, in script: String) -> String {
        let base = type.prefix(1).uppercased() + type.dropFirst().lowercased()
        var maxNum = 0
        let pattern = "// @feature \"\(base) (\\d+)\""
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: script, range: NSRange(script.startIndex..., in: script))
            for match in matches {
                if let range = Range(match.range(at: 1), in: script),
                   let num = Int(script[range]) {
                    maxNum = max(maxNum, num)
                }
            }
        }
        return "\(base) \(maxNum + 1)"
    }

    // MARK: - Primitive Insertion

    /// Generates a script block for a primitive with @feature annotation.
    static func scriptBlock(for type: PrimitiveType, featureName: String) -> String {
        let code: String
        switch type {
        case .cube:
            code = "cube([10, 10, 10]);"
        case .cylinder:
            code = "cylinder(h=10, r=5, $fn=32);"
        case .sphere:
            code = "sphere(r=5, $fn=32);"
        }
        return "// @feature \"\(featureName)\"\n\(code)\n"
    }

    /// Inserts a primitive into the script after the specified feature index.
    /// If afterFeatureIndex is nil, appends to the end.
    /// Returns the new script text.
    static func insertPrimitive(
        _ type: PrimitiveType,
        in script: String,
        afterFeatureIndex: Int?
    ) -> String {
        let name = nextFeatureName(for: type.rawValue, in: script)
        let block = scriptBlock(for: type, featureName: name)
        return insertBlock(block, in: script, afterFeatureIndex: afterFeatureIndex)
    }

    // MARK: - Boolean Wrapping

    /// Wraps two feature blocks in a boolean operation.
    /// Takes the indices of two features in the script and wraps them.
    static func wrapInBoolean(
        _ op: BooleanOp,
        featureIndices: [Int],
        in script: String
    ) -> String {
        let blocks = featureBlocks(in: script)
        guard featureIndices.count >= 2 else { return script }

        // Collect the text of the blocks to wrap (in source order)
        let sortedIndices = featureIndices.sorted()
        var blockTexts: [String] = []
        for idx in sortedIndices {
            guard idx < blocks.count else { continue }
            let block = blocks[idx]
            blockTexts.append(block.text)
        }

        guard blockTexts.count >= 2 else { return script }

        // Build the boolean wrapper
        let opName: String
        switch op {
        case .difference: opName = "Difference"
        case .union: opName = "Union"
        case .intersection: opName = "Intersection"
        }

        let name = nextFeatureName(for: opName, in: script)
        let indentedBlocks = blockTexts.map { block in
            block.components(separatedBy: "\n")
                .map { line in line.isEmpty ? "" : "    \(line)" }
                .joined(separator: "\n")
        }.joined(separator: "\n")

        let boolBlock = "// @feature \"\(name)\"\n\(op.rawValue)() {\n\(indentedBlocks)\n}\n"

        // Remove original blocks (from last to first to preserve indices)
        var lines = script.components(separatedBy: "\n")
        for idx in sortedIndices.reversed() {
            guard idx < blocks.count else { continue }
            let block = blocks[idx]
            let startLine = block.startLine - 1 // 0-based
            let endLine = block.endLine - 1
            guard startLine >= 0, endLine < lines.count else { continue }
            lines.removeSubrange(startLine...endLine)
        }

        // Insert the boolean block where the first block was
        let insertLine = sortedIndices.first.flatMap { idx -> Int? in
            guard idx < blocks.count else { return nil }
            return blocks[idx].startLine - 1
        } ?? lines.count

        let boolLines = boolBlock.components(separatedBy: "\n")
        lines.insert(contentsOf: boolLines, at: min(insertLine, lines.count))

        return lines.joined(separator: "\n")
    }

    // MARK: - Feature Block Parsing

    struct FeatureBlock {
        let name: String
        let startLine: Int   // 1-based, inclusive
        let endLine: Int     // 1-based, inclusive
        let text: String     // the raw text of this block
        let isSuppressed: Bool
    }

    /// Parses the script to identify feature blocks.
    /// A feature block starts at a `// @feature` line and extends to the line before
    /// the next `// @feature` or end of file (trimming trailing blank lines).
    static func featureBlocks(in script: String) -> [FeatureBlock] {
        let lines = script.components(separatedBy: "\n")
        var blocks: [FeatureBlock] = []
        var featureStarts: [(line: Int, name: String, suppressed: Bool)] = []

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let info = parseFeatureAnnotation(trimmed) {
                featureStarts.append((line: i + 1, name: info.name, suppressed: info.suppressed))
            }
        }

        for (i, start) in featureStarts.enumerated() {
            let startLine = start.line
            let endLine: Int
            if i + 1 < featureStarts.count {
                // End before the next feature annotation, trimming trailing blank lines
                var end = featureStarts[i + 1].line - 2 // line before next @feature, 0-based
                while end >= startLine - 1 && lines[end].trimmingCharacters(in: .whitespaces).isEmpty {
                    end -= 1
                }
                endLine = end + 1 // back to 1-based
            } else {
                // Last block extends to end of file, trimming trailing blank lines
                var end = lines.count - 1
                while end >= startLine - 1 && lines[end].trimmingCharacters(in: .whitespaces).isEmpty {
                    end -= 1
                }
                endLine = end + 1
            }

            let blockLines = lines[(startLine - 1)...(endLine - 1)]
            let text = blockLines.joined(separator: "\n")

            blocks.append(FeatureBlock(
                name: start.name,
                startLine: startLine,
                endLine: endLine,
                text: text,
                isSuppressed: start.suppressed
            ))
        }

        return blocks
    }

    /// Parse a `// @feature "Name"` annotation, optionally with [suppressed] marker.
    private static func parseFeatureAnnotation(_ line: String) -> (name: String, suppressed: Bool)? {
        guard line.hasPrefix("// @feature") else { return nil }
        let rest = line.dropFirst("// @feature".count).trimmingCharacters(in: .whitespaces)

        let suppressed = rest.contains("[suppressed]")
        var name = rest
            .replacingOccurrences(of: "[suppressed]", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Remove surrounding quotes
        if name.hasPrefix("\"") && name.hasSuffix("\"") {
            name = String(name.dropFirst().dropLast())
        }

        return (name: name, suppressed: suppressed)
    }

    // MARK: - Block Insertion

    /// Inserts a text block after the specified feature index, or at end if nil.
    static func insertBlock(
        _ block: String,
        in script: String,
        afterFeatureIndex: Int?
    ) -> String {
        let blocks = featureBlocks(in: script)

        guard let afterIndex = afterFeatureIndex, afterIndex < blocks.count else {
            // Append to end
            let trimmed = script.hasSuffix("\n") ? script : script + "\n"
            return trimmed + block
        }

        let targetBlock = blocks[afterIndex]
        var lines = script.components(separatedBy: "\n")
        let insertAt = targetBlock.endLine // insert after end line (0-based = endLine)

        let blockLines = block.components(separatedBy: "\n")
        // Add a blank line separator
        var toInsert = [""] + blockLines
        // Remove trailing empty string if block already ends with \n
        if toInsert.last == "" && blockLines.last == "" {
            toInsert.removeLast()
        }

        lines.insert(contentsOf: toInsert, at: min(insertAt, lines.count))
        return lines.joined(separator: "\n")
    }

    // MARK: - Feature Operations

    /// Suppresses a feature by commenting out its code lines (not the @feature annotation).
    /// Adds [suppressed] marker to the annotation.
    static func suppressFeature(at index: Int, in script: String) -> String {
        let blocks = featureBlocks(in: script)
        guard index < blocks.count else { return script }
        let block = blocks[index]

        var lines = script.components(separatedBy: "\n")

        if block.isSuppressed {
            // Unsuppress: remove [suppressed] and uncomment code
            let annotationIdx = block.startLine - 1
            lines[annotationIdx] = lines[annotationIdx]
                .replacingOccurrences(of: " [suppressed]", with: "")
                .replacingOccurrences(of: "[suppressed]", with: "")

            for i in block.startLine...min(block.endLine - 1, lines.count - 1) {
                let line = lines[i]
                if line.hasPrefix("// ") {
                    lines[i] = String(line.dropFirst(3))
                } else if line.hasPrefix("//") {
                    lines[i] = String(line.dropFirst(2))
                }
            }
        } else {
            // Suppress: add [suppressed] and comment out code
            let annotationIdx = block.startLine - 1
            lines[annotationIdx] = lines[annotationIdx]
                .replacingOccurrences(of: "// @feature", with: "// @feature [suppressed]")

            for i in block.startLine...min(block.endLine - 1, lines.count - 1) {
                let line = lines[i]
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    lines[i] = "// \(line)"
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Deletes a feature block entirely from the script.
    static func deleteFeature(at index: Int, in script: String) -> String {
        let blocks = featureBlocks(in: script)
        guard index < blocks.count else { return script }
        let block = blocks[index]

        var lines = script.components(separatedBy: "\n")
        let startIdx = block.startLine - 1
        let endIdx = block.endLine - 1
        guard startIdx >= 0, endIdx < lines.count else { return script }

        lines.removeSubrange(startIdx...endIdx)

        // Remove any extra blank line that was left
        if startIdx < lines.count && startIdx > 0 &&
           lines[startIdx - 1].trimmingCharacters(in: .whitespaces).isEmpty &&
           lines[startIdx].trimmingCharacters(in: .whitespaces).isEmpty {
            lines.remove(at: startIdx)
        }

        return lines.joined(separator: "\n")
    }

    /// Renames a feature by updating its @feature annotation.
    static func renameFeature(at index: Int, to newName: String, in script: String) -> String {
        let blocks = featureBlocks(in: script)
        guard index < blocks.count else { return script }
        let block = blocks[index]

        var lines = script.components(separatedBy: "\n")
        let annotationIdx = block.startLine - 1
        guard annotationIdx < lines.count else { return script }

        let oldLine = lines[annotationIdx]
        let suppressed = block.isSuppressed ? " [suppressed]" : ""
        // Preserve indentation
        let indent = String(oldLine.prefix(while: { $0 == " " || $0 == "\t" }))
        lines[annotationIdx] = "\(indent)// @feature\(suppressed) \"\(newName)\""

        return lines.joined(separator: "\n")
    }

    /// Moves a feature block to a new position (by feature index).
    /// `toIndex` is the target position in the feature list after removal.
    static func moveFeature(from fromIndex: Int, to toIndex: Int, in script: String) -> String {
        guard fromIndex != toIndex else { return script }
        let blocks = featureBlocks(in: script)
        guard fromIndex < blocks.count else { return script }

        let block = blocks[fromIndex]
        let blockText = block.text

        // Step 1: Remove the source block
        var lines = script.components(separatedBy: "\n")
        let startIdx = block.startLine - 1
        let endIdx = block.endLine - 1
        guard startIdx >= 0, endIdx < lines.count else { return script }
        lines.removeSubrange(startIdx...endIdx)

        // Remove trailing blank line if one remains
        if startIdx < lines.count && lines[startIdx].trimmingCharacters(in: .whitespaces).isEmpty {
            lines.remove(at: startIdx)
        }

        let intermediateScript = lines.joined(separator: "\n")

        // Step 2: Re-parse blocks from the modified script and insert at new position
        let adjustedTo = toIndex > fromIndex ? toIndex - 1 : toIndex
        let newBlocks = featureBlocks(in: intermediateScript)

        var newLines = intermediateScript.components(separatedBy: "\n")
        let blockLines = blockText.components(separatedBy: "\n")

        if adjustedTo <= 0 || newBlocks.isEmpty {
            // Insert at beginning
            let insertLines = blockLines + [""]
            newLines.insert(contentsOf: insertLines, at: 0)
        } else if adjustedTo >= newBlocks.count {
            // Append to end
            if !newLines.last!.trimmingCharacters(in: .whitespaces).isEmpty {
                newLines.append("")
            }
            newLines.append(contentsOf: blockLines)
            newLines.append("")
        } else {
            // Insert before the block at adjustedTo
            let insertAt = newBlocks[adjustedTo].startLine - 1
            let insertLines = blockLines + [""]
            newLines.insert(contentsOf: insertLines, at: insertAt)
        }

        return newLines.joined(separator: "\n")
    }
}
