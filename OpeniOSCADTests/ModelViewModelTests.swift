import XCTest
@testable import OpeniOSCAD

final class ModelViewModelTests: XCTestCase {

    @MainActor
    func testAddPrimitiveAppendsFeature() {
        let vm = ModelViewModel()
        vm.addPrimitive("Cube")
        XCTAssertEqual(vm.features.count, 1)
        XCTAssertEqual(vm.features[0].name, "Cube 1")
        XCTAssertEqual(vm.features[0].type, "cube")
        XCTAssertFalse(vm.features[0].isSuppressed)
    }

    @MainActor
    func testAddMultiplePrimitivesIncrements() {
        let vm = ModelViewModel()
        vm.addPrimitive("Cube")
        vm.addPrimitive("Cube")
        vm.addPrimitive("Cylinder")
        XCTAssertEqual(vm.features.count, 3)
        XCTAssertEqual(vm.features[0].name, "Cube 1")
        XCTAssertEqual(vm.features[1].name, "Cube 2")
        XCTAssertEqual(vm.features[2].name, "Cylinder 1")
    }

    @MainActor
    func testDeleteFeature() {
        let vm = ModelViewModel()
        vm.addPrimitive("Cube")
        vm.addPrimitive("Cylinder")
        vm.deleteFeature(at: 0)
        XCTAssertEqual(vm.features.count, 1)
        XCTAssertEqual(vm.features[0].name, "Cylinder 1")
        XCTAssertEqual(vm.features[0].index, 0)
    }

    @MainActor
    func testSuppressFeature() {
        let vm = ModelViewModel()
        vm.addPrimitive("Cube")
        XCTAssertFalse(vm.features[0].isSuppressed)
        vm.suppressFeature(at: 0)
        XCTAssertTrue(vm.features[0].isSuppressed)
        vm.suppressFeature(at: 0)
        XCTAssertFalse(vm.features[0].isSuppressed)
    }

    @MainActor
    func testRenameFeature() {
        let vm = ModelViewModel()
        vm.addPrimitive("Cube")
        vm.renameFeature(at: 0, to: "Base Plate")
        XCTAssertEqual(vm.features[0].name, "Base Plate")
    }

    @MainActor
    func testMoveFeature() {
        let vm = ModelViewModel()
        vm.addPrimitive("Cube")
        vm.addPrimitive("Cylinder")
        vm.addPrimitive("Sphere")
        vm.moveFeature(from: 0, to: 2)
        XCTAssertEqual(vm.features[0].name, "Cylinder 1")
        XCTAssertEqual(vm.features[1].name, "Cube 1")
        XCTAssertEqual(vm.features[2].name, "Sphere 1")
    }

    @MainActor
    func testDeleteClearsSelection() {
        let vm = ModelViewModel()
        vm.addPrimitive("Cube")
        vm.selectedFeatureIndex = 0
        vm.deleteFeature(at: 0)
        XCTAssertNil(vm.selectedFeatureIndex)
    }
}
