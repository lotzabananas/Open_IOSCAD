import XCTest
@testable import GeometryKernel

final class ExportTests: XCTestCase {

    // MARK: - DXF Export Tests

    func testDXFExportProducesValidContent() {
        let mesh = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true))
        let dxf = DXFExporter.export(mesh)

        XCTAssertTrue(dxf.contains("SECTION"))
        XCTAssertTrue(dxf.contains("ENTITIES"))
        XCTAssertTrue(dxf.contains("EOF"))
        XCTAssertTrue(dxf.contains("$ACADVER"))
        XCTAssertTrue(dxf.contains("AC1009"))
    }

    func testDXFExportContainsLayers() {
        let mesh = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true))
        let dxf = DXFExporter.export(mesh)

        XCTAssertTrue(dxf.contains("FRONT"))
        XCTAssertTrue(dxf.contains("TOP"))
        XCTAssertTrue(dxf.contains("RIGHT"))
        XCTAssertTrue(dxf.contains("LABELS"))
    }

    func testDXFExportContainsLineEntities() {
        let mesh = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true))
        let dxf = DXFExporter.export(mesh)

        // Should contain LINE entities for projected edges
        XCTAssertTrue(dxf.contains("LINE"))
    }

    func testDXFExportEmptyMesh() {
        let dxf = DXFExporter.export(TriangleMesh())
        XCTAssertTrue(dxf.contains("EOF"))
        XCTAssertFalse(dxf.contains("LINE"))
    }

    func testDXFSingleView() {
        let mesh = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true))
        let dxf = DXFExporter.exportSingleView(mesh, view: .front)

        XCTAssertTrue(dxf.contains("EOF"))
        XCTAssertTrue(dxf.contains("LINE"))
    }

    func testDXFExportContainsDimensions() {
        let mesh = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(20, 30, 40), center: true))
        let dxf = DXFExporter.export(mesh)

        // Should contain dimension text
        XCTAssertTrue(dxf.contains("TEXT"))
        XCTAssertTrue(dxf.contains("DIMENSIONS"))
    }

    // MARK: - PDF Export Tests

    func testPDFExportProducesData() {
        let mesh = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true))
        let pdfData = PDFDrawingExporter.export(mesh)

        XCTAssertNotNil(pdfData)
        XCTAssertGreaterThan(pdfData?.count ?? 0, 100) // PDF should have substantial content
    }

    func testPDFExportEmptyMeshReturnsNil() {
        let pdfData = PDFDrawingExporter.export(TriangleMesh())
        XCTAssertNil(pdfData)
    }

    func testPDFExportContainsPDFHeader() {
        let mesh = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true))
        guard let pdfData = PDFDrawingExporter.export(mesh) else {
            XCTFail("Expected PDF data")
            return
        }

        // PDF files start with %PDF
        let headerString = String(data: pdfData.prefix(5), encoding: .ascii)
        XCTAssertEqual(headerString, "%PDF-")
    }

    func testPDFExportA4Portrait() {
        let mesh = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true))
        let pdfData = PDFDrawingExporter.export(mesh, paperSize: .a4Portrait)
        XCTAssertNotNil(pdfData)
    }

    func testPDFExportLetterLandscape() {
        let mesh = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true))
        let pdfData = PDFDrawingExporter.export(mesh, paperSize: .letterLandscape)
        XCTAssertNotNil(pdfData)
    }

    // MARK: - STL Export Tests (existing, moved here for completeness)

    func testSTLBinaryExportLength() {
        let mesh = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true))
        let data = STLExporter.exportBinary(mesh)

        // STL binary: 80 header + 4 triangle count + 50 bytes per triangle
        let expected = 80 + 4 + mesh.triangleCount * 50
        XCTAssertEqual(data.count, expected)
    }

    func testSTLASCIIExportContent() {
        let mesh = CubeGenerator.generate(params: PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true))
        let ascii = STLExporter.exportASCII(mesh)

        XCTAssertTrue(ascii.hasPrefix("solid"))
        XCTAssertTrue(ascii.contains("facet normal"))
        XCTAssertTrue(ascii.contains("vertex"))
        XCTAssertTrue(ascii.hasSuffix("endsolid OpeniOSCAD"))
    }
}
