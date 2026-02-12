import XCTest
import simd
@testable import Renderer

final class RendererTests: XCTestCase {

    // MARK: - Camera Tests

    func testCameraDefaultPosition() {
        let camera = Camera()
        let pos = camera.position
        // Default orbit: azimuth=pi/4, elevation=pi/6, distance=5
        // Position should be non-zero and away from the origin.
        XCTAssertGreaterThan(simd_length(pos), 0)
    }

    func testViewMatrixIsValid() {
        let camera = Camera()
        let view = camera.viewMatrix()
        // A valid view matrix should have a non-zero determinant.
        let det = simd_determinant(view)
        XCTAssertNotEqual(det, 0, accuracy: 1e-6, "View matrix determinant should be non-zero")
    }

    func testProjectionMatrixIsValid() {
        let camera = Camera()
        camera.aspectRatio = 16.0 / 9.0
        let proj = camera.projectionMatrix()
        // The projection matrix should have a non-zero determinant.
        let det = simd_determinant(proj)
        XCTAssertNotEqual(det, 0, accuracy: 1e-6, "Projection matrix determinant should be non-zero")
    }

    func testOrbitChangesAngles() {
        let camera = Camera()
        let initialAzimuth = camera.azimuth
        let initialElevation = camera.elevation

        camera.orbit(deltaX: 100, deltaY: 50)

        XCTAssertNotEqual(camera.azimuth, initialAzimuth, "Azimuth should change after orbit")
        XCTAssertNotEqual(camera.elevation, initialElevation, "Elevation should change after orbit")
    }

    func testOrbitClampsElevation() {
        let camera = Camera()

        // Orbit way up -- elevation should be clamped below pi/2.
        camera.orbit(deltaX: 0, deltaY: -100000)
        XCTAssertLessThan(camera.elevation, Float.pi / 2)

        // Orbit way down -- elevation should be clamped above -pi/2.
        camera.orbit(deltaX: 0, deltaY: 200000)
        XCTAssertGreaterThan(camera.elevation, -Float.pi / 2)
    }

    func testZoomAdjustsDistance() {
        let camera = Camera()
        let initialDistance = camera.distance

        camera.zoom(factor: 0.5)
        XCTAssertLessThan(camera.distance, initialDistance, "Zoom in should reduce distance")

        camera.zoom(factor: 4.0)
        XCTAssertGreaterThan(camera.distance, initialDistance, "Zoom out should increase distance")
    }

    func testPanMovesTarget() {
        let camera = Camera()
        let initialTarget = camera.target

        camera.pan(deltaX: 50, deltaY: 50)

        let moved = simd_length(camera.target - initialTarget)
        XCTAssertGreaterThan(moved, 0, "Pan should move the target")
    }

    func testFitAllWithKnownBoundingBox() {
        let camera = Camera()

        let bbMin = SIMD3<Float>(-1, -1, -1)
        let bbMax = SIMD3<Float>(1, 1, 1)
        camera.fitAll(boundingBox: (min: bbMin, max: bbMax))

        // Target should be at center of the bounding box.
        let expectedCenter = SIMD3<Float>(0, 0, 0)
        XCTAssertEqual(camera.target.x, expectedCenter.x, accuracy: 1e-5)
        XCTAssertEqual(camera.target.y, expectedCenter.y, accuracy: 1e-5)
        XCTAssertEqual(camera.target.z, expectedCenter.z, accuracy: 1e-5)

        // Distance should be large enough to see the whole bounding box.
        let radius = simd_length(bbMax - bbMin) * 0.5
        XCTAssertGreaterThanOrEqual(camera.distance, radius, "Distance should be at least the bounding sphere radius")
    }

    func testFitAllWithOffCenterBoundingBox() {
        let camera = Camera()

        let bbMin = SIMD3<Float>(10, 20, 30)
        let bbMax = SIMD3<Float>(14, 24, 34)
        camera.fitAll(boundingBox: (min: bbMin, max: bbMax))

        // Target should move to the center of this bounding box.
        XCTAssertEqual(camera.target.x, 12.0, accuracy: 1e-5)
        XCTAssertEqual(camera.target.y, 22.0, accuracy: 1e-5)
        XCTAssertEqual(camera.target.z, 32.0, accuracy: 1e-5)
    }

    func testLookAtProducesValidMatrix() {
        let eye = SIMD3<Float>(0, 0, 5)
        let center = SIMD3<Float>(0, 0, 0)
        let up = SIMD3<Float>(0, 1, 0)
        let mat = Camera.lookAt(eye: eye, center: center, up: up)
        let det = simd_determinant(mat)
        XCTAssertNotEqual(det, 0, accuracy: 1e-6)
    }

    func testPerspectiveProducesValidMatrix() {
        let mat = Camera.perspective(fovY: Float.pi / 4, aspect: 1.5, near: 0.1, far: 100.0)
        let det = simd_determinant(mat)
        XCTAssertNotEqual(det, 0, accuracy: 1e-6)
    }

    // MARK: - RenderPipeline Tests

    func testRenderPipelineInitialization() {
        // On CI or environments without Metal GPU, this will return nil.
        // We just verify it does not crash.
        let pipeline = RenderPipeline()
        if pipeline != nil {
            XCTAssertNotNil(pipeline?.device, "Device should be set when Metal is available")
            XCTAssertNotNil(pipeline?.commandQueue, "Command queue should be set")
        } else {
            // Metal not available in this test environment; that is acceptable.
            print("Metal not available -- skipping GPU pipeline tests")
        }
    }
}
