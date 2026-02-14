import Foundation
import simd

/// Creates copies of geometry in patterns (linear, circular, mirror).
public enum PatternOperation {

    /// Create a linear pattern of copies along a direction.
    public static func linear(
        mesh: TriangleMesh,
        direction: SIMD3<Float>,
        count: Int,
        spacing: Float
    ) -> TriangleMesh {
        guard !mesh.isEmpty, count > 1 else { return mesh }

        let dir = simd_normalize(direction)
        var result = mesh

        for i in 1..<count {
            let offset = dir * Float(i) * spacing
            let matrix = TransformOperations.translationMatrix(offset)
            var copy = mesh
            copy.apply(transform: matrix)
            result.merge(copy)
        }

        return result
    }

    /// Create a circular pattern of copies around an axis.
    public static func circular(
        mesh: TriangleMesh,
        axis: SIMD3<Float>,
        count: Int,
        totalAngle: Float,
        equalSpacing: Bool
    ) -> TriangleMesh {
        guard !mesh.isEmpty, count > 1 else { return mesh }

        let normalizedAxis = simd_normalize(axis)
        var result = mesh

        for i in 1..<count {
            let angle: Float
            if equalSpacing {
                angle = totalAngle * Float(i) / Float(count)
            } else {
                angle = totalAngle / Float(count - 1) * Float(i)
            }

            let radians = angle * .pi / 180.0
            let matrix = rotationMatrix(angle: radians, axis: normalizedAxis)
            var copy = mesh
            copy.apply(transform: matrix)
            result.merge(copy)
        }

        return result
    }

    /// Create a mirror copy across a plane defined by its normal.
    public static func mirror(
        mesh: TriangleMesh,
        planeNormal: SIMD3<Float>
    ) -> TriangleMesh {
        guard !mesh.isEmpty else { return mesh }

        let n = simd_normalize(planeNormal)
        let mirrorMatrix = simd_float4x4(
            SIMD4<Float>(1 - 2 * n.x * n.x, -2 * n.x * n.y, -2 * n.x * n.z, 0),
            SIMD4<Float>(-2 * n.y * n.x, 1 - 2 * n.y * n.y, -2 * n.y * n.z, 0),
            SIMD4<Float>(-2 * n.z * n.x, -2 * n.z * n.y, 1 - 2 * n.z * n.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )

        var mirrored = mesh
        mirrored.apply(transform: mirrorMatrix)
        mirrored.flipWinding()

        var result = mesh
        result.merge(mirrored)
        return result
    }

    // MARK: - Private

    private static func rotationMatrix(angle: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        let c = cos(angle)
        let s = sin(angle)
        let t = 1 - c
        let x = axis.x, y = axis.y, z = axis.z

        return simd_float4x4(
            SIMD4<Float>(t * x * x + c,     t * x * y + s * z, t * x * z - s * y, 0),
            SIMD4<Float>(t * x * y - s * z, t * y * y + c,     t * y * z + s * x, 0),
            SIMD4<Float>(t * x * z + s * y, t * y * z - s * x, t * z * z + c,     0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
}
