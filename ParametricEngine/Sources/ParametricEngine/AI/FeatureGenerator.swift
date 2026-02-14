import Foundation

/// AI-driven feature generation from natural language descriptions.
/// Converts structured text prompts into Feature objects that can be added to a FeatureTree.
///
/// This module provides:
/// 1. A protocol for pluggable AI backends (local or cloud LLM)
/// 2. A template-based generator for common patterns (no LLM required)
/// 3. A structured prompt format for AI → Feature conversion
public enum FeatureGenerator {

    /// Result of AI feature generation.
    public struct GenerationResult: Sendable {
        public let features: [AnyFeature]
        public let description: String
        public let confidence: Double

        public init(features: [AnyFeature], description: String, confidence: Double) {
            self.features = features
            self.description = description
            self.confidence = confidence
        }
    }

    /// Error during generation.
    public enum GenerationError: Error, Sendable {
        case unrecognizedPrompt(String)
        case invalidParameters(String)
        case noFeaturesGenerated
    }

    // MARK: - Template-Based Generation

    /// Generate features from a natural language description using built-in templates.
    /// This works without any AI backend — it matches common patterns.
    public static func generate(from prompt: String) throws -> GenerationResult {
        let lower = prompt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Try each pattern matcher in order
        if let result = tryBox(lower) { return result }
        if let result = tryCylinder(lower) { return result }
        if let result = trySphere(lower) { return result }
        if let result = tryHole(lower) { return result }
        if let result = tryFillet(lower) { return result }
        if let result = tryChamfer(lower) { return result }
        if let result = tryShell(lower) { return result }
        if let result = tryPattern(lower) { return result }
        if let result = tryPlate(lower) { return result }
        if let result = tryBracket(lower) { return result }
        if let result = tryEnclosure(lower) { return result }

        throw GenerationError.unrecognizedPrompt(prompt)
    }

    // MARK: - Pattern Matchers

    private static func tryBox(_ prompt: String) -> GenerationResult? {
        guard prompt.contains("box") || prompt.contains("cube") || prompt.contains("block") else { return nil }
        let dims = extractDimensions(from: prompt) ?? (20, 20, 20)

        let sketch = SketchFeature.rectangleOnXY(width: dims.0, depth: dims.1, name: "AI Sketch")
        let extrude = ExtrudeFeature(
            name: "AI Extrude",
            sketchID: sketch.id,
            depth: dims.2,
            operation: .additive
        )

        return GenerationResult(
            features: [.sketch(sketch), .extrude(extrude)],
            description: "Box \(dims.0) x \(dims.1) x \(dims.2)mm",
            confidence: 0.9
        )
    }

    private static func tryCylinder(_ prompt: String) -> GenerationResult? {
        guard prompt.contains("cylinder") || prompt.contains("rod") || prompt.contains("pipe") else { return nil }
        let radius = extractNumber(after: ["radius", "r"], in: prompt) ?? 10.0
        let height = extractNumber(after: ["height", "h", "tall", "long"], in: prompt) ?? 20.0

        let sketch = SketchFeature.circleOnXY(radius: radius, name: "AI Sketch")
        let extrude = ExtrudeFeature(
            name: "AI Extrude",
            sketchID: sketch.id,
            depth: height,
            operation: .additive
        )

        return GenerationResult(
            features: [.sketch(sketch), .extrude(extrude)],
            description: "Cylinder R\(radius) x H\(height)mm",
            confidence: 0.85
        )
    }

    private static func trySphere(_ prompt: String) -> GenerationResult? {
        guard prompt.contains("sphere") || prompt.contains("ball") else { return nil }
        let radius = extractNumber(after: ["radius", "r", "diameter", "d"], in: prompt) ?? 10.0
        let actualRadius = prompt.contains("diameter") || prompt.contains(" d ") ? radius / 2 : radius

        // Sphere via semicircle revolve
        let segments = 24
        var elements: [SketchElement] = []
        var lastPoint = Point2D(x: 0, y: -actualRadius)

        for i in 1...segments {
            let angle = Double(i) / Double(segments) * .pi - .pi / 2
            let x = actualRadius * cos(angle)
            let y = actualRadius * sin(angle)
            let nextPoint = Point2D(x: x, y: y)
            elements.append(.lineSegment(id: ElementID(), start: lastPoint, end: nextPoint))
            lastPoint = nextPoint
        }
        elements.append(.lineSegment(id: ElementID(), start: lastPoint, end: Point2D(x: 0, y: -actualRadius)))

        let sketch = SketchFeature(name: "AI Sketch", plane: .xy, elements: elements)
        let revolve = RevolveFeature(name: "AI Revolve", sketchID: sketch.id, angle: 360, operation: .additive)

        return GenerationResult(
            features: [.sketch(sketch), .revolve(revolve)],
            description: "Sphere R\(actualRadius)mm",
            confidence: 0.85
        )
    }

    private static func tryHole(_ prompt: String) -> GenerationResult? {
        guard prompt.contains("hole") || prompt.contains("drill") || prompt.contains("bore") else { return nil }
        let radius = extractNumber(after: ["radius", "r", "diameter", "d"], in: prompt) ?? 5.0
        let actualRadius = prompt.contains("diameter") || prompt.contains(" d ") ? radius / 2 : radius
        let depth = extractNumber(after: ["depth", "deep", "through"], in: prompt) ?? 100.0

        let sketch = SketchFeature.circleOnXY(radius: actualRadius, name: "AI Hole Sketch")
        let cut = ExtrudeFeature(
            name: "AI Cut",
            sketchID: sketch.id,
            depth: depth,
            operation: .subtractive
        )

        return GenerationResult(
            features: [.sketch(sketch), .extrude(cut)],
            description: "Hole R\(actualRadius) x D\(depth)mm",
            confidence: 0.8
        )
    }

    private static func tryFillet(_ prompt: String) -> GenerationResult? {
        guard prompt.contains("fillet") || prompt.contains("round") else { return nil }
        let radius = extractNumber(after: ["radius", "r"], in: prompt) ?? 2.0

        // Fillet targets the most recent geometry feature — actual target resolved at add time
        return GenerationResult(
            features: [],
            description: "Fillet R\(radius)mm (apply to selected feature)",
            confidence: 0.7
        )
    }

    private static func tryChamfer(_ prompt: String) -> GenerationResult? {
        guard prompt.contains("chamfer") || prompt.contains("bevel") else { return nil }
        let distance = extractNumber(after: ["distance", "d", "size"], in: prompt) ?? 1.0

        return GenerationResult(
            features: [],
            description: "Chamfer \(distance)mm (apply to selected feature)",
            confidence: 0.7
        )
    }

    private static func tryShell(_ prompt: String) -> GenerationResult? {
        guard prompt.contains("shell") || prompt.contains("hollow") || prompt.contains("thin wall") else { return nil }
        let thickness = extractNumber(after: ["thickness", "wall", "t"], in: prompt) ?? 1.0

        return GenerationResult(
            features: [],
            description: "Shell \(thickness)mm wall (apply to selected feature)",
            confidence: 0.7
        )
    }

    private static func tryPattern(_ prompt: String) -> GenerationResult? {
        guard prompt.contains("pattern") || prompt.contains("array") || prompt.contains("repeat") else { return nil }
        let count = extractNumber(after: ["count", "copies", "times", "x"], in: prompt) ?? 3
        let spacing = extractNumber(after: ["spacing", "distance", "apart", "gap"], in: prompt) ?? 20.0

        return GenerationResult(
            features: [],
            description: "Linear pattern \(Int(count))x, spacing \(spacing)mm",
            confidence: 0.6
        )
    }

    private static func tryPlate(_ prompt: String) -> GenerationResult? {
        guard prompt.contains("plate") || prompt.contains("flat") || prompt.contains("sheet") else { return nil }
        let width = extractNumber(after: ["width", "w"], in: prompt) ?? 50.0
        let depth = extractNumber(after: ["depth", "length", "l"], in: prompt) ?? 50.0
        let thickness = extractNumber(after: ["thickness", "thick", "t", "height", "h"], in: prompt) ?? 3.0

        let sketch = SketchFeature.rectangleOnXY(width: width, depth: depth, name: "AI Plate Sketch")
        let extrude = ExtrudeFeature(
            name: "AI Plate",
            sketchID: sketch.id,
            depth: thickness,
            operation: .additive
        )

        return GenerationResult(
            features: [.sketch(sketch), .extrude(extrude)],
            description: "Plate \(width) x \(depth) x \(thickness)mm",
            confidence: 0.85
        )
    }

    private static func tryBracket(_ prompt: String) -> GenerationResult? {
        guard prompt.contains("bracket") || prompt.contains("l-shape") || matchesWord("angle", in: prompt) else { return nil }
        let size = extractNumber(after: ["size", "s"], in: prompt) ?? 30.0
        let thickness = extractNumber(after: ["thickness", "thick", "t"], in: prompt) ?? 3.0

        // L-bracket: vertical plate + horizontal plate
        let sketch1 = SketchFeature.rectangleOnXY(width: size, depth: thickness, name: "AI Base Sketch")
        let extrude1 = ExtrudeFeature(name: "AI Base Plate", sketchID: sketch1.id, depth: size, operation: .additive)

        let sketch2 = SketchFeature.rectangleOnXY(width: thickness, depth: size, name: "AI Wall Sketch")
        let extrude2 = ExtrudeFeature(name: "AI Wall Plate", sketchID: sketch2.id, depth: size, operation: .additive)

        return GenerationResult(
            features: [.sketch(sketch1), .extrude(extrude1), .sketch(sketch2), .extrude(extrude2)],
            description: "L-Bracket \(size)mm, \(thickness)mm thick",
            confidence: 0.7
        )
    }

    private static func tryEnclosure(_ prompt: String) -> GenerationResult? {
        guard prompt.contains("enclosure") || prompt.contains("case") || prompt.contains("housing") else { return nil }
        let width = extractNumber(after: ["width", "w"], in: prompt) ?? 60.0
        let depth = extractNumber(after: ["depth", "length", "l"], in: prompt) ?? 40.0
        let height = extractNumber(after: ["height", "h", "tall"], in: prompt) ?? 25.0
        let wall = extractNumber(after: ["wall", "thickness", "t"], in: prompt) ?? 2.0

        let sketch = SketchFeature.rectangleOnXY(width: width, depth: depth, name: "AI Enclosure Sketch")
        let extrude = ExtrudeFeature(
            name: "AI Enclosure Body",
            sketchID: sketch.id,
            depth: height,
            operation: .additive
        )
        let shell = ShellFeature(
            name: "AI Shell",
            thickness: wall,
            openFaceIndices: [0],
            targetID: extrude.id
        )

        return GenerationResult(
            features: [.sketch(sketch), .extrude(extrude), .shell(shell)],
            description: "Enclosure \(width) x \(depth) x \(height)mm, \(wall)mm walls",
            confidence: 0.8
        )
    }

    // MARK: - Word Matching

    /// Matches a word with word boundaries to avoid substring false positives.
    private static func matchesWord(_ word: String, in prompt: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
        let range = NSRange(prompt.startIndex..., in: prompt)
        return regex.firstMatch(in: prompt, range: range) != nil
    }

    // MARK: - Number Extraction

    private static func extractDimensions(from prompt: String) -> (Double, Double, Double)? {
        // Pattern: "30 x 20 x 10" or "30x20x10" or "30 by 20 by 10"
        let pattern = #"(\d+\.?\d*)\s*[x×by]+\s*(\d+\.?\d*)\s*[x×by]+\s*(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(prompt.startIndex..., in: prompt)
        guard let match = regex.firstMatch(in: prompt, range: range) else { return nil }

        guard let r1 = Range(match.range(at: 1), in: prompt),
              let r2 = Range(match.range(at: 2), in: prompt),
              let r3 = Range(match.range(at: 3), in: prompt),
              let v1 = Double(prompt[r1]),
              let v2 = Double(prompt[r2]),
              let v3 = Double(prompt[r3]) else { return nil }

        return (v1, v2, v3)
    }

    private static func extractNumber(after keywords: [String], in prompt: String) -> Double? {
        for keyword in keywords {
            let patterns = [
                "\(keyword)\\s*[:=]?\\s*(\\d+\\.?\\d*)",
                "(\\d+\\.?\\d*)\\s*(?:mm)?\\s*\(keyword)"
            ]
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
                let range = NSRange(prompt.startIndex..., in: prompt)
                if let match = regex.firstMatch(in: prompt, range: range) {
                    if let r = Range(match.range(at: 1), in: prompt),
                       let value = Double(prompt[r]) {
                        return value
                    }
                }
            }
        }
        return nil
    }
}

// MARK: - AI Backend Protocol

/// Protocol for pluggable AI backends.
/// Implementations can use local models, cloud APIs, or other inference engines.
public protocol AIFeatureBackend: Sendable {
    /// Generate features from a natural language prompt.
    func generate(prompt: String, context: AIGenerationContext) async throws -> FeatureGenerator.GenerationResult
}

/// Context provided to the AI backend for informed generation.
public struct AIGenerationContext: Sendable {
    /// Current feature tree (for understanding existing model)
    public let existingFeatures: [AnyFeature]
    /// Currently selected feature ID (for contextual operations)
    public let selectedFeatureID: FeatureID?
    /// Bounding box of current model
    public let modelBounds: (min: SIMD3<Float>, max: SIMD3<Float>)?

    public init(
        existingFeatures: [AnyFeature] = [],
        selectedFeatureID: FeatureID? = nil,
        modelBounds: (min: SIMD3<Float>, max: SIMD3<Float>)? = nil
    ) {
        self.existingFeatures = existingFeatures
        self.selectedFeatureID = selectedFeatureID
        self.modelBounds = modelBounds
    }
}
