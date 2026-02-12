import SwiftUI
import UniformTypeIdentifiers
import ParametricEngine
import GeometryKernel

/// UTType for STEP files.
extension UTType {
    static var stepFile: UTType {
        UTType(importedAs: "com.openioscad.step", conformingTo: .data)
    }
}

/// Document type for OpeniOSCAD's STEP-based file format.
/// Conforms to ReferenceFileDocument for SwiftUI document-based app integration.
final class CADDocument: ReferenceFileDocument {
    typealias Snapshot = Data

    static var readableContentTypes: [UTType] { [.stepFile, .plainText] }
    static var writableContentTypes: [UTType] { [.stepFile] }

    @Published var featureTree: FeatureTree
    @Published var mesh: TriangleMesh

    init() {
        self.featureTree = FeatureTree()
        self.mesh = TriangleMesh()
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }

        let result = try STEPFileIO.read(content)
        if let tree = result.tree {
            self.featureTree = tree
            // Re-evaluate to get mesh from features
            let evaluator = FeatureEvaluator()
            let evalResult = evaluator.evaluate(tree)
            self.mesh = evalResult.mesh
        } else {
            self.featureTree = FeatureTree()
            self.mesh = result.mesh
        }
    }

    func snapshot(contentType: UTType) throws -> Data {
        let content = try STEPFileIO.write(tree: featureTree, mesh: mesh)
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return data
    }

    func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: snapshot)
    }
}
