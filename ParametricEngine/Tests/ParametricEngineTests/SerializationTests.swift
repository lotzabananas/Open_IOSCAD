import XCTest
@testable import ParametricEngine

final class SerializationTests: XCTestCase {

    func testSketchFeatureRoundTrip() throws {
        let sketch = SketchFeature.rectangleOnXY(width: 15, depth: 10, name: "My Sketch")
        let anyFeature = AnyFeature.sketch(sketch)

        let data = try JSONEncoder().encode(anyFeature)
        let decoded = try JSONDecoder().decode(AnyFeature.self, from: data)

        XCTAssertEqual(decoded.id, sketch.id)
        XCTAssertEqual(decoded.name, "My Sketch")

        if case .sketch(let decodedSketch) = decoded {
            XCTAssertEqual(decodedSketch.elements.count, 1)
            if case .rectangle(_, _, let w, let h) = decodedSketch.elements[0] {
                XCTAssertEqual(w, 15)
                XCTAssertEqual(h, 10)
            } else {
                XCTFail("Expected rectangle element")
            }
        } else {
            XCTFail("Expected sketch feature")
        }
    }

    func testExtrudeFeatureRoundTrip() throws {
        let sketchID = FeatureID()
        let extrude = ExtrudeFeature(
            name: "Extrude 1",
            sketchID: sketchID,
            depth: 25.5,
            operation: .subtractive
        )
        let anyFeature = AnyFeature.extrude(extrude)

        let data = try JSONEncoder().encode(anyFeature)
        let decoded = try JSONDecoder().decode(AnyFeature.self, from: data)

        if case .extrude(let decodedExtrude) = decoded {
            XCTAssertEqual(decodedExtrude.sketchID, sketchID)
            XCTAssertEqual(decodedExtrude.depth, 25.5)
            XCTAssertEqual(decodedExtrude.operation, .subtractive)
        } else {
            XCTFail("Expected extrude feature")
        }
    }

    func testCircleSketchRoundTrip() throws {
        let sketch = SketchFeature.circleOnXY(radius: 7.5, name: "Circle Sketch")
        let anyFeature = AnyFeature.sketch(sketch)

        let data = try JSONEncoder().encode(anyFeature)
        let decoded = try JSONDecoder().decode(AnyFeature.self, from: data)

        if case .sketch(let decodedSketch) = decoded {
            if case .circle(_, let center, let radius) = decodedSketch.elements[0] {
                XCTAssertEqual(radius, 7.5)
                XCTAssertEqual(center.x, 0)
                XCTAssertEqual(center.y, 0)
            } else {
                XCTFail("Expected circle element")
            }
        } else {
            XCTFail("Expected sketch feature")
        }
    }

    func testFeatureTreeRoundTrip() throws {
        var tree = FeatureTree()
        let sketch = SketchFeature.rectangleOnXY(width: 20, depth: 15, name: "S1")
        let extrude = ExtrudeFeature(name: "E1", sketchID: sketch.id, depth: 30, operation: .additive)

        tree.append(.sketch(sketch))
        tree.append(.extrude(extrude))

        let data = try FeatureSerialization.encode(tree)
        let decoded = try FeatureSerialization.decode(from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded.features[0].name, "S1")
        XCTAssertEqual(decoded.features[1].name, "E1")
        XCTAssertEqual(decoded.features[0].id, sketch.id)
        XCTAssertEqual(decoded.features[1].id, extrude.id)
    }

    func testFeatureTreeStringRoundTrip() throws {
        var tree = FeatureTree()
        let sketch = SketchFeature.circleOnXY(radius: 10, name: "Circle")
        tree.append(.sketch(sketch))

        let jsonString = try FeatureSerialization.encodeToString(tree)
        XCTAssertTrue(jsonString.contains("Circle"))

        let decoded = try FeatureSerialization.decode(from: jsonString)
        XCTAssertEqual(decoded.count, 1)
    }

    func testBooleanFeatureRoundTrip() throws {
        let boolean = BooleanFeature(
            name: "Union 1",
            booleanType: .union,
            targetIDs: [FeatureID(), FeatureID()]
        )
        let anyFeature = AnyFeature.boolean(boolean)

        let data = try JSONEncoder().encode(anyFeature)
        let decoded = try JSONDecoder().decode(AnyFeature.self, from: data)

        if case .boolean(let decodedBool) = decoded {
            XCTAssertEqual(decodedBool.booleanType, .union)
            XCTAssertEqual(decodedBool.targetIDs.count, 2)
        } else {
            XCTFail("Expected boolean feature")
        }
    }

    func testTransformFeatureRoundTrip() throws {
        let targetID = FeatureID()
        let transform = TransformFeature(
            name: "Translate 1",
            transformType: .translate,
            vector: SIMD3<Double>(10, 20, 30),
            targetID: targetID
        )
        let anyFeature = AnyFeature.transform(transform)

        let data = try JSONEncoder().encode(anyFeature)
        let decoded = try JSONDecoder().decode(AnyFeature.self, from: data)

        if case .transform(let decodedTransform) = decoded {
            XCTAssertEqual(decodedTransform.transformType, .translate)
            XCTAssertEqual(decodedTransform.vector.x, 10)
            XCTAssertEqual(decodedTransform.vector.y, 20)
            XCTAssertEqual(decodedTransform.vector.z, 30)
            XCTAssertEqual(decodedTransform.targetID, targetID)
        } else {
            XCTFail("Expected transform feature")
        }
    }

    func testSuppressedFeatureRoundTrip() throws {
        var sketch = SketchFeature.rectangleOnXY(width: 10, depth: 10, name: "S1")
        sketch.isSuppressed = true

        var tree = FeatureTree()
        tree.append(.sketch(sketch))

        let data = try FeatureSerialization.encode(tree)
        let decoded = try FeatureSerialization.decode(from: data)

        XCTAssertTrue(decoded.features[0].isSuppressed)
    }

    func testSketchPlaneRoundTrip() throws {
        let planes: [SketchPlane] = [
            .xy, .xz, .yz,
            .offsetXY(distance: 15.5),
            .faceOf(featureID: FeatureID(), faceIndex: 3)
        ]

        for plane in planes {
            let sketch = SketchFeature(name: "Test", plane: plane, elements: [])
            let data = try JSONEncoder().encode(AnyFeature.sketch(sketch))
            let decoded = try JSONDecoder().decode(AnyFeature.self, from: data)

            if case .sketch(let s) = decoded {
                XCTAssertEqual(s.plane, plane, "Plane \(plane) did not round-trip")
            } else {
                XCTFail("Expected sketch")
            }
        }
    }
}
