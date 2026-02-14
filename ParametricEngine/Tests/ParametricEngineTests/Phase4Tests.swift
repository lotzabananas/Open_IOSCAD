import XCTest
@testable import ParametricEngine
import GeometryKernel

final class Phase4Tests: XCTestCase {

    let evaluator = FeatureEvaluator()

    // MARK: - Sweep Feature

    func testSweepFeatureCreation() {
        let sweep = SweepFeature(
            name: "Test Sweep",
            profileSketchID: UUID(),
            pathSketchID: UUID()
        )
        XCTAssertEqual(sweep.name, "Test Sweep")
        XCTAssertEqual(sweep.twist, 0)
        XCTAssertEqual(sweep.scaleEnd, 1.0)
        XCTAssertEqual(sweep.operation, .additive)
    }

    func testSweepFeatureRoundTrip() throws {
        let sweep = SweepFeature(
            name: "Sweep1",
            profileSketchID: UUID(),
            pathSketchID: UUID(),
            twist: 45.0,
            scaleEnd: 0.5
        )

        let feature = AnyFeature.sweep(sweep)
        let data = try JSONEncoder().encode(feature)
        let decoded = try JSONDecoder().decode(AnyFeature.self, from: data)

        XCTAssertEqual(decoded.kind, .sweep)
        if case .sweep(let s) = decoded {
            XCTAssertEqual(s.twist, 45.0)
            XCTAssertEqual(s.scaleEnd, 0.5)
        } else {
            XCTFail("Expected sweep feature")
        }
    }

    // MARK: - Loft Feature

    func testLoftFeatureCreation() {
        let loft = LoftFeature(
            name: "Test Loft",
            profileSketchIDs: [UUID(), UUID()],
            heights: [0, 20],
            slicesPerSpan: 8
        )
        XCTAssertEqual(loft.name, "Test Loft")
        XCTAssertEqual(loft.profileSketchIDs.count, 2)
        XCTAssertEqual(loft.slicesPerSpan, 8)
    }

    func testLoftFeatureRoundTrip() throws {
        let id1 = UUID()
        let id2 = UUID()
        let loft = LoftFeature(
            name: "Loft1",
            profileSketchIDs: [id1, id2],
            heights: [0, 30],
            slicesPerSpan: 6
        )

        let feature = AnyFeature.loft(loft)
        let data = try JSONEncoder().encode(feature)
        let decoded = try JSONDecoder().decode(AnyFeature.self, from: data)

        XCTAssertEqual(decoded.kind, .loft)
        if case .loft(let l) = decoded {
            XCTAssertEqual(l.profileSketchIDs.count, 2)
            XCTAssertEqual(l.heights, [0, 30])
            XCTAssertEqual(l.slicesPerSpan, 6)
        } else {
            XCTFail("Expected loft feature")
        }
    }

    func testLoftEvaluatesWithMatchingProfiles() {
        var tree = FeatureTree()

        let sketch1 = SketchFeature.rectangleOnXY(width: 20, depth: 20, name: "Bottom")
        let sketch2 = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "Top")

        let loft = LoftFeature(
            name: "Loft1",
            profileSketchIDs: [sketch1.id, sketch2.id],
            heights: [0, 20],
            slicesPerSpan: 4
        )

        tree.append(.sketch(sketch1))
        tree.append(.sketch(sketch2))
        tree.append(.loft(loft))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.mesh.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testLoftWithMissingProfileProducesError() {
        var tree = FeatureTree()
        let loft = LoftFeature(
            name: "Loft1",
            profileSketchIDs: [UUID(), UUID()],
            heights: [0, 20]
        )
        tree.append(.loft(loft))

        let result = evaluator.evaluate(tree)
        XCTAssertFalse(result.errors.isEmpty)
    }

    // MARK: - AI Feature Generator

    func testAIGenerateBox() throws {
        let result = try FeatureGenerator.generate(from: "create a box 30x20x10")
        XCTAssertGreaterThanOrEqual(result.features.count, 2)
        XCTAssertTrue(result.description.contains("30"))
        XCTAssertGreaterThan(result.confidence, 0.5)
    }

    func testAIGenerateCylinder() throws {
        let result = try FeatureGenerator.generate(from: "cylinder radius 8 height 25")
        XCTAssertGreaterThanOrEqual(result.features.count, 2)
        XCTAssertTrue(result.description.lowercased().contains("cylinder"))
    }

    func testAIGeneratePlate() throws {
        let result = try FeatureGenerator.generate(from: "flat plate 50x30 thickness 2")
        XCTAssertGreaterThanOrEqual(result.features.count, 2)
        XCTAssertTrue(result.description.lowercased().contains("plate"))
    }

    func testAIGenerateEnclosure() throws {
        let result = try FeatureGenerator.generate(from: "enclosure width 60 depth 40 height 25 wall 2")
        XCTAssertGreaterThanOrEqual(result.features.count, 3) // sketch + extrude + shell
        XCTAssertTrue(result.description.lowercased().contains("enclosure"))
    }

    func testAIGenerateUnrecognized() {
        XCTAssertThrowsError(try FeatureGenerator.generate(from: "quantum entanglement device")) { error in
            guard case FeatureGenerator.GenerationError.unrecognizedPrompt = error else {
                XCTFail("Expected unrecognizedPrompt error")
                return
            }
        }
    }

    func testAIGeneratedFeaturesEvaluate() throws {
        let result = try FeatureGenerator.generate(from: "box 20x20x20")
        var tree = FeatureTree()
        for feature in result.features {
            tree.append(feature)
        }

        let evalResult = evaluator.evaluate(tree)
        XCTAssertFalse(evalResult.mesh.isEmpty)
        XCTAssertTrue(evalResult.errors.isEmpty)
    }

    // MARK: - Feature Kind Round-Trip

    func testAllNewFeatureKinds() {
        XCTAssertTrue(FeatureKind.allCases.contains(.sweep))
        XCTAssertTrue(FeatureKind.allCases.contains(.loft))
    }
}
