import XCTest
@testable import ParametricEngine
import GeometryKernel

final class Phase5Tests: XCTestCase {

    let evaluator = FeatureEvaluator()

    // MARK: - Assembly Feature

    func testAssemblyFeatureCreation() {
        let assembly = AssemblyFeature(
            name: "Body 1",
            memberFeatureIDs: [UUID(), UUID()]
        )
        XCTAssertEqual(assembly.name, "Body 1")
        XCTAssertEqual(assembly.memberFeatureIDs.count, 2)
        XCTAssertEqual(assembly.positionX, 0)
        XCTAssertEqual(assembly.positionY, 0)
        XCTAssertEqual(assembly.positionZ, 0)
    }

    func testAssemblyFeatureRoundTrip() throws {
        let assembly = AssemblyFeature(
            name: "Test Assembly",
            memberFeatureIDs: [UUID(), UUID(), UUID()],
            color: [1, 0, 0, 1],
            positionX: 10, positionY: 20, positionZ: 30,
            rotationX: 45, rotationY: 90, rotationZ: 0
        )

        let feature = AnyFeature.assembly(assembly)
        let data = try JSONEncoder().encode(feature)
        let decoded = try JSONDecoder().decode(AnyFeature.self, from: data)

        XCTAssertEqual(decoded.kind, .assembly)
        if case .assembly(let a) = decoded {
            XCTAssertEqual(a.name, "Test Assembly")
            XCTAssertEqual(a.memberFeatureIDs.count, 3)
            XCTAssertEqual(a.positionX, 10)
            XCTAssertEqual(a.rotationX, 45)
            XCTAssertEqual(a.color, [1, 0, 0, 1])
        } else {
            XCTFail("Expected assembly feature")
        }
    }

    func testAssemblyEvaluatesWithoutError() {
        var tree = FeatureTree()

        let sketch = SketchFeature.rectangleOnXY(width: 20, depth: 20, name: "Base")
        let extrude = ExtrudeFeature(name: "Box", sketchID: sketch.id, depth: 10, operation: .additive)
        let assembly = AssemblyFeature(
            name: "Body 1",
            memberFeatureIDs: [sketch.id, extrude.id]
        )

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))
        tree.append(.assembly(assembly))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testAssemblyKindExists() {
        XCTAssertTrue(FeatureKind.allCases.contains(.assembly))
    }

    // MARK: - DXF Export Integration

    func testDXFExportFromFeatureTree() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 30, depth: 20, name: "Base")
        let extrude = ExtrudeFeature(name: "Box", sketchID: sketch.id, depth: 15, operation: .additive)
        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        let result = evaluator.evaluate(tree)
        let dxf = DXFExporter.export(result.mesh)

        XCTAssertTrue(dxf.contains("EOF"))
        XCTAssertTrue(dxf.contains("LINE"))
        XCTAssertTrue(dxf.contains("FRONT"))
    }

    // MARK: - PDF Export Integration

    func testPDFExportFromFeatureTree() {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 30, depth: 20, name: "Base")
        let extrude = ExtrudeFeature(name: "Box", sketchID: sketch.id, depth: 15, operation: .additive)
        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        let result = evaluator.evaluate(tree)
        let pdfData = PDFDrawingExporter.export(result.mesh)

        XCTAssertNotNil(pdfData)
        XCTAssertGreaterThan(pdfData?.count ?? 0, 100)
    }

    // MARK: - SCAD Export with Assembly

    func testSCADExportAssembly() {
        var tree = FeatureTree()
        let assembly = AssemblyFeature(name: "Body 1", memberFeatureIDs: [UUID()])
        tree.append(.assembly(assembly))

        let scad = SCADExporter.export(tree)
        XCTAssertTrue(scad.contains("Assembly"))
    }

    // MARK: - CadQuery Export with Assembly

    func testCadQueryExportAssembly() {
        var tree = FeatureTree()
        let assembly = AssemblyFeature(name: "Body 1", memberFeatureIDs: [UUID()])
        tree.append(.assembly(assembly))

        let cq = CadQueryExporter.export(tree)
        XCTAssertTrue(cq.contains("Assembly"))
    }

    // MARK: - All Feature Kinds Present

    func testAllFeatureKindsRegistered() {
        let allKinds = FeatureKind.allCases
        XCTAssertTrue(allKinds.contains(.sketch))
        XCTAssertTrue(allKinds.contains(.extrude))
        XCTAssertTrue(allKinds.contains(.revolve))
        XCTAssertTrue(allKinds.contains(.boolean))
        XCTAssertTrue(allKinds.contains(.transform))
        XCTAssertTrue(allKinds.contains(.fillet))
        XCTAssertTrue(allKinds.contains(.chamfer))
        XCTAssertTrue(allKinds.contains(.shell))
        XCTAssertTrue(allKinds.contains(.pattern))
        XCTAssertTrue(allKinds.contains(.sweep))
        XCTAssertTrue(allKinds.contains(.loft))
        XCTAssertTrue(allKinds.contains(.assembly))
        XCTAssertEqual(allKinds.count, 12)
    }
}
