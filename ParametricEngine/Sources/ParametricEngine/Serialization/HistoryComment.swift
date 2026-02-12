import Foundation

/// Handles embedding and extracting the `@openioscad` feature history
/// JSON block within STEP file comments.
public enum HistoryComment {

    /// Version of the history format.
    public static let version = 1

    /// Marker prefix for the comment block.
    private static let marker = "@openioscad"

    /// Wrap for embedding in STEP comment block.
    public struct HistoryBlock: Codable, Sendable {
        public let version: Int
        public let features: [AnyFeature]

        public init(version: Int = HistoryComment.version, features: [AnyFeature]) {
            self.version = version
            self.features = features
        }
    }

    /// Generate the comment block string to embed in a STEP file.
    /// Returns string like: `/* @openioscad {...json...} */`
    public static func encode(tree: FeatureTree) throws -> String {
        let block = HistoryBlock(features: tree.features)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(block)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SerializationError.encodingFailed
        }
        return "/* \(marker) \(json) */"
    }

    /// Extract the feature tree from a STEP file's content string.
    /// Returns nil if no `@openioscad` comment block is found.
    public static func decode(from stepContent: String) throws -> FeatureTree? {
        guard let range = stepContent.range(of: "/* \(marker) ") else {
            return nil
        }

        let afterMarker = stepContent[range.upperBound...]
        guard let endRange = afterMarker.range(of: " */") else {
            return nil
        }

        let json = String(afterMarker[..<endRange.lowerBound])
        guard let data = json.data(using: .utf8) else {
            throw SerializationError.decodingFailed("Invalid UTF-8 in history block")
        }

        let block = try JSONDecoder().decode(HistoryBlock.self, from: data)
        return FeatureTree(features: block.features)
    }
}
