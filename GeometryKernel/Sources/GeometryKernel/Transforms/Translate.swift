import Foundation
import simd

public enum TransformOperations {
    public static func matrix(for type: TransformType, params: TransformParams) -> simd_float4x4 {
        switch type {
        case .translate:
            return translationMatrix(params.vector)
        case .rotate:
            if let angle = params.angle, let axis = params.axis {
                return rotationMatrix(angle: angle, axis: axis)
            } else {
                return eulerRotationMatrix(params.vector)
            }
        case .scale:
            return scaleMatrix(params.vector)
        case .mirror:
            return mirrorMatrix(normal: params.vector)
        }
    }

    public static func requiresWindingFlip(type: TransformType, params: TransformParams) -> Bool {
        switch type {
        case .scale:
            let neg = (params.vector.x < 0 ? 1 : 0) + (params.vector.y < 0 ? 1 : 0) + (params.vector.z < 0 ? 1 : 0)
            return neg % 2 != 0
        case .mirror:
            return true
        default:
            return false
        }
    }

    // MARK: - Matrix builders

    public static func translationMatrix(_ v: SIMD3<Float>) -> simd_float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = SIMD4<Float>(v.x, v.y, v.z, 1)
        return m
    }

    public static func scaleMatrix(_ v: SIMD3<Float>) -> simd_float4x4 {
        var m = matrix_identity_float4x4
        m.columns.0.x = v.x
        m.columns.1.y = v.y
        m.columns.2.z = v.z
        return m
    }

    public static func eulerRotationMatrix(_ angles: SIMD3<Float>) -> simd_float4x4 {
        let rx = rotationMatrix(angle: angles.x, axis: SIMD3<Float>(1, 0, 0))
        let ry = rotationMatrix(angle: angles.y, axis: SIMD3<Float>(0, 1, 0))
        let rz = rotationMatrix(angle: angles.z, axis: SIMD3<Float>(0, 0, 1))
        return rz * ry * rx
    }

    public static func rotationMatrix(angle: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        let rad = angle * .pi / 180.0
        let n = simd_normalize(axis)
        let c = cos(rad)
        let s = sin(rad)
        let t = 1 - c

        let col0 = SIMD4<Float>(
            t * n.x * n.x + c,
            t * n.x * n.y + s * n.z,
            t * n.x * n.z - s * n.y,
            0
        )
        let col1 = SIMD4<Float>(
            t * n.x * n.y - s * n.z,
            t * n.y * n.y + c,
            t * n.y * n.z + s * n.x,
            0
        )
        let col2 = SIMD4<Float>(
            t * n.x * n.z + s * n.y,
            t * n.y * n.z - s * n.x,
            t * n.z * n.z + c,
            0
        )
        let col3 = SIMD4<Float>(0, 0, 0, 1)

        return simd_float4x4(col0, col1, col2, col3)
    }

    public static func mirrorMatrix(normal: SIMD3<Float>) -> simd_float4x4 {
        let n = simd_normalize(normal)
        var m = matrix_identity_float4x4
        m.columns.0.x = 1 - 2 * n.x * n.x
        m.columns.0.y = -2 * n.x * n.y
        m.columns.0.z = -2 * n.x * n.z
        m.columns.1.x = -2 * n.x * n.y
        m.columns.1.y = 1 - 2 * n.y * n.y
        m.columns.1.z = -2 * n.y * n.z
        m.columns.2.x = -2 * n.x * n.z
        m.columns.2.y = -2 * n.y * n.z
        m.columns.2.z = 1 - 2 * n.z * n.z
        return m
    }
}
