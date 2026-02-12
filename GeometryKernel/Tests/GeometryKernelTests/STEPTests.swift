import XCTest
@testable import GeometryKernel

final class STEPTests: XCTestCase {

    func testWriteEmptyMeshProducesValidSTEP() {
        let mesh = TriangleMesh()
        let result = STEPWriter.write(mesh: mesh)

        XCTAssertTrue(result.hasPrefix("ISO-10303-21;"))
        XCTAssertTrue(result.hasSuffix("END-ISO-10303-21;"))
        XCTAssertTrue(result.contains("HEADER;"))
        XCTAssertTrue(result.contains("ENDSEC;"))
        XCTAssertTrue(result.contains("DATA;"))
    }

    func testWriteBoxMeshProducesEntities() {
        let params = PrimitiveParams(size: SIMD3<Float>(10, 10, 10), center: true)
        let mesh = CubeGenerator.generate(params: params)
        let result = STEPWriter.write(mesh: mesh)

        XCTAssertTrue(result.contains("CARTESIAN_POINT"))
        XCTAssertTrue(result.contains("ADVANCED_FACE"))
        XCTAssertTrue(result.contains("CLOSED_SHELL"))
        XCTAssertTrue(result.contains("MANIFOLD_SOLID_BREP"))
    }

    func testWriteWithCommentBlock() {
        let mesh = TriangleMesh()
        let comment = "/* @openioscad {\"version\":1} */"
        let result = STEPWriter.write(mesh: mesh, commentBlock: comment)

        XCTAssertTrue(result.contains("@openioscad"))
    }

    func testReadEmptyContent() {
        let mesh = STEPReader.read("")
        XCTAssertTrue(mesh.isEmpty)
    }

    func testReadCartesianPoints() {
        let content = """
        ISO-10303-21;
        HEADER;
        ENDSEC;
        DATA;
        #1=CARTESIAN_POINT('',(0.0,0.0,0.0));
        #2=CARTESIAN_POINT('',(10.0,0.0,0.0));
        #3=CARTESIAN_POINT('',(10.0,10.0,0.0));
        #4=CARTESIAN_POINT('',(0.0,10.0,0.0));
        #5=CARTESIAN_POINT('',(0.0,0.0,10.0));
        #6=CARTESIAN_POINT('',(10.0,0.0,10.0));
        #7=CARTESIAN_POINT('',(10.0,10.0,10.0));
        #8=CARTESIAN_POINT('',(0.0,10.0,10.0));
        ENDSEC;
        END-ISO-10303-21;
        """

        let mesh = STEPReader.read(content)
        // Should produce a bounding box approximation
        XCTAssertFalse(mesh.isEmpty)
    }

    func testWriteProducesValidFileSchema() {
        let mesh = TriangleMesh()
        let result = STEPWriter.write(mesh: mesh)
        XCTAssertTrue(result.contains("FILE_SCHEMA(('AUTOMOTIVE_DESIGN'))"))
        XCTAssertTrue(result.contains("FILE_DESCRIPTION(('OpeniOSCAD model'),'2;1')"))
    }
}
