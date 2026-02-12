import Foundation
import simd

/// Geometry operation tree produced by the evaluator, consumed by the kernel.
public indirect enum GeometryOp: Sendable, Hashable {
    case primitive(PrimitiveType, PrimitiveParams)
    case boolean(BooleanType, [GeometryOp])
    case transform(TransformType, TransformParams, GeometryOp)
    case extrude(ExtrudeType, ExtrudeParams, GeometryOp)
    case color(SIMD4<Float>, GeometryOp)
    case group([GeometryOp])
    case empty
}

public enum PrimitiveType: String, Sendable, Hashable {
    case cube, cylinder, sphere, polyhedron
    case circle, square, polygon
}

public struct PrimitiveParams: Sendable, Hashable {
    public var size: SIMD3<Float>?
    public var radius: Float?
    public var radius1: Float?
    public var radius2: Float?
    public var height: Float?
    public var center: Bool
    public var fn: Int
    public var fa: Float
    public var fs: Float
    public var points: [[SIMD3<Float>]]?
    public var faces: [[Int]]?
    public var points2D: [SIMD2<Float>]?

    public init(
        size: SIMD3<Float>? = nil,
        radius: Float? = nil,
        radius1: Float? = nil,
        radius2: Float? = nil,
        height: Float? = nil,
        center: Bool = false,
        fn: Int = 0,
        fa: Float = 12.0,
        fs: Float = 2.0,
        points: [[SIMD3<Float>]]? = nil,
        faces: [[Int]]? = nil,
        points2D: [SIMD2<Float>]? = nil
    ) {
        self.size = size
        self.radius = radius
        self.radius1 = radius1
        self.radius2 = radius2
        self.height = height
        self.center = center
        self.fn = fn
        self.fa = fa
        self.fs = fs
        self.points = points
        self.faces = faces
        self.points2D = points2D
    }

    public func resolvedSegments(forRadius r: Float) -> Int {
        if fn > 0 { return max(fn, 3) }
        let byAngle = Int(ceil(360.0 / fa))
        let bySize = r > 0 ? Int(ceil(2.0 * .pi * r / fs)) : 16
        return max(min(byAngle, bySize), 3)
    }
}

public enum BooleanType: String, Sendable, Hashable {
    case union, difference, intersection
}

public enum TransformType: String, Sendable, Hashable {
    case translate, rotate, scale, mirror
}

public struct TransformParams: Sendable, Hashable {
    public var vector: SIMD3<Float>
    public var angle: Float?
    public var axis: SIMD3<Float>?

    public init(vector: SIMD3<Float>, angle: Float? = nil, axis: SIMD3<Float>? = nil) {
        self.vector = vector
        self.angle = angle
        self.axis = axis
    }
}

public enum ExtrudeType: String, Sendable, Hashable {
    case linear, rotate
}

public struct ExtrudeParams: Sendable, Hashable {
    public var height: Float
    public var center: Bool
    public var twist: Float
    public var scale: SIMD2<Float>
    public var slices: Int
    public var angle: Float
    public var fn: Int

    public init(
        height: Float = 1.0,
        center: Bool = false,
        twist: Float = 0.0,
        scale: SIMD2<Float> = SIMD2<Float>(1, 1),
        slices: Int = 1,
        angle: Float = 360.0,
        fn: Int = 0
    ) {
        self.height = height
        self.center = center
        self.twist = twist
        self.scale = scale
        self.slices = slices
        self.angle = angle
        self.fn = fn
    }
}

/// 2D polygon for extrusion operations
public struct Polygon2D: Sendable, Hashable {
    public var points: [SIMD2<Float>]

    public init(points: [SIMD2<Float>] = []) {
        self.points = points
    }

    public var isClockwise: Bool {
        var sum: Float = 0
        for i in points.indices {
            let j = (i + 1) % points.count
            sum += (points[j].x - points[i].x) * (points[j].y + points[i].y)
        }
        return sum > 0
    }

    public mutating func ensureCounterClockwise() {
        if isClockwise {
            points.reverse()
        }
    }
}
