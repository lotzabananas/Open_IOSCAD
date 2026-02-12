import Foundation
import simd

/// Orbit camera that revolves around a target point.
/// Position is computed from the target, distance, azimuth (horizontal) and elevation (vertical) angles.
public class Camera {

    // MARK: - Properties

    /// The point the camera orbits around.
    public var target: SIMD3<Float> = SIMD3<Float>(0, 0, 0)

    /// Distance from the target.
    public var distance: Float = 5.0

    /// Horizontal rotation angle in radians (around the Y axis).
    public var azimuth: Float = Float.pi / 4

    /// Vertical rotation angle in radians (above/below the horizon).
    public var elevation: Float = Float.pi / 6

    /// Viewport aspect ratio (width / height).
    public var aspectRatio: Float = 1.0

    /// Vertical field of view in radians.
    public var fov: Float = Float.pi / 4

    /// Near clipping plane distance.
    public var nearClip: Float = 0.01

    /// Far clipping plane distance.
    public var farClip: Float = 1000.0

    // MARK: - Computed

    /// Camera position computed from orbit parameters.
    public var position: SIMD3<Float> {
        let cosElev = cos(elevation)
        let sinElev = sin(elevation)
        let cosAzi = cos(azimuth)
        let sinAzi = sin(azimuth)

        return target + distance * SIMD3<Float>(
            cosElev * sinAzi,
            sinElev,
            cosElev * cosAzi
        )
    }

    // MARK: - Init

    public init() {}

    // MARK: - Matrices

    /// View matrix (world -> camera).
    public func viewMatrix() -> simd_float4x4 {
        return Camera.lookAt(eye: position, center: target, up: SIMD3<Float>(0, 1, 0))
    }

    /// Perspective projection matrix.
    public func projectionMatrix() -> simd_float4x4 {
        return Camera.perspective(fovY: fov, aspect: aspectRatio, near: nearClip, far: farClip)
    }

    // MARK: - Interaction

    /// Orbit the camera around the target.
    /// - Parameters:
    ///   - deltaX: Horizontal drag delta (pixels or points). Positive = rotate right.
    ///   - deltaY: Vertical drag delta. Positive = rotate up.
    public func orbit(deltaX: Float, deltaY: Float) {
        let sensitivity: Float = 0.005
        azimuth -= deltaX * sensitivity
        elevation += deltaY * sensitivity

        // Clamp elevation to avoid gimbal lock at the poles.
        let limit = Float.pi / 2 - 0.01
        elevation = max(-limit, min(limit, elevation))
    }

    /// Pan (translate) the camera target in the view plane.
    /// - Parameters:
    ///   - deltaX: Horizontal drag delta.
    ///   - deltaY: Vertical drag delta.
    public func pan(deltaX: Float, deltaY: Float) {
        let sensitivity: Float = 0.003 * distance
        let view = viewMatrix()

        // Extract right and up vectors from the view matrix (inverse transpose of the rotation part).
        let right = SIMD3<Float>(view.columns.0.x, view.columns.1.x, view.columns.2.x)
        let up = SIMD3<Float>(view.columns.0.y, view.columns.1.y, view.columns.2.y)

        target -= right * deltaX * sensitivity
        target += up * deltaY * sensitivity
    }

    /// Zoom by adjusting distance from target.
    /// - Parameter factor: Multiplicative factor. > 1 zooms out, < 1 zooms in.
    public func zoom(factor: Float) {
        distance *= factor
        distance = max(nearClip * 2, min(farClip * 0.5, distance))
    }

    /// Adjust camera so the given bounding box is fully visible.
    /// - Parameter boundingBox: Tuple of (min, max) corners.
    public func fitAll(boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>)) {
        let center = (boundingBox.min + boundingBox.max) * 0.5
        let extents = boundingBox.max - boundingBox.min
        let radius = simd_length(extents) * 0.5

        target = center

        // Compute distance so the bounding sphere fits within the field of view.
        let halfFov = fov * 0.5
        let requiredDistance = radius / sin(halfFov)
        distance = max(requiredDistance, nearClip * 2)
    }

    // MARK: - Matrix Helpers

    /// Construct a look-at view matrix (right-handed).
    public static func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let f = simd_normalize(center - eye)
        let s = simd_normalize(simd_cross(f, up))
        let u = simd_cross(s, f)

        var result = matrix_identity_float4x4
        result.columns.0 = SIMD4<Float>(s.x, u.x, -f.x, 0)
        result.columns.1 = SIMD4<Float>(s.y, u.y, -f.y, 0)
        result.columns.2 = SIMD4<Float>(s.z, u.z, -f.z, 0)
        result.columns.3 = SIMD4<Float>(-simd_dot(s, eye), -simd_dot(u, eye), simd_dot(f, eye), 1)
        return result
    }

    /// Construct a perspective projection matrix (right-handed, Metal NDC: z in [0, 1]).
    public static func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let yScale = 1.0 / tan(fovY * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near

        var result = matrix_identity_float4x4
        result.columns.0 = SIMD4<Float>(xScale, 0, 0, 0)
        result.columns.1 = SIMD4<Float>(0, yScale, 0, 0)
        result.columns.2 = SIMD4<Float>(0, 0, -(far) / zRange, -1.0)
        result.columns.3 = SIMD4<Float>(0, 0, -(far * near) / zRange, 0)
        return result
    }
}
