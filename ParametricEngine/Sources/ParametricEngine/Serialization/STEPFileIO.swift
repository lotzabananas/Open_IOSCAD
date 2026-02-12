import Foundation
import GeometryKernel

/// High-level STEP file I/O that combines GeometryKernel's STEPWriter
/// with ParametricEngine's HistoryComment for full save/load.
public enum STEPFileIO {

    /// Write a model to a STEP file string.
    /// Embeds the feature history as an @openioscad comment in the DATA section.
    public static func write(tree: FeatureTree, mesh: TriangleMesh) throws -> String {
        let historyComment = try HistoryComment.encode(tree: tree)
        return STEPWriter.write(mesh: mesh, commentBlock: historyComment)
    }

    /// Read a STEP file string.
    /// Returns (featureTree, mesh) — if the file has an @openioscad block,
    /// the tree is reconstructed; otherwise returns nil tree and imported geometry.
    public static func read(_ content: String) throws -> (tree: FeatureTree?, mesh: TriangleMesh) {
        // Try to extract feature history
        let tree = try HistoryComment.decode(from: content)

        // Parse geometry from STEP entities
        let mesh = STEPReader.read(content)

        return (tree, mesh)
    }
}
