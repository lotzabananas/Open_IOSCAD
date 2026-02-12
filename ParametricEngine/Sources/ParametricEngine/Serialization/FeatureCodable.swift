import Foundation

/// Serialization helpers for encoding/decoding feature trees as JSON.
/// Used for both STEP comment embedding and general persistence.
public enum FeatureSerialization {

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        JSONDecoder()
    }()

    /// Encode a FeatureTree to JSON Data.
    public static func encode(_ tree: FeatureTree) throws -> Data {
        try encoder.encode(tree)
    }

    /// Decode a FeatureTree from JSON Data.
    public static func decode(from data: Data) throws -> FeatureTree {
        try decoder.decode(FeatureTree.self, from: data)
    }

    /// Encode a FeatureTree to a JSON String.
    public static func encodeToString(_ tree: FeatureTree) throws -> String {
        let data = try encode(tree)
        guard let string = String(data: data, encoding: .utf8) else {
            throw SerializationError.encodingFailed
        }
        return string
    }

    /// Decode a FeatureTree from a JSON String.
    public static func decode(from string: String) throws -> FeatureTree {
        guard let data = string.data(using: .utf8) else {
            throw SerializationError.decodingFailed("Invalid UTF-8 string")
        }
        return try decode(from: data)
    }
}

public enum SerializationError: Error, Sendable {
    case encodingFailed
    case decodingFailed(String)
}
