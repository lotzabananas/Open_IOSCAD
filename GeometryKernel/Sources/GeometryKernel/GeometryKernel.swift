import Foundation
import simd

/// Main entry point for evaluating geometry operations into triangle meshes.
/// Includes a subtree cache to skip recomputation of unchanged geometry.
public final class GeometryKernel {
    /// Cache mapping GeometryOp hash → TriangleMesh.
    /// Cleared on each top-level evaluate, populated as subtrees are computed.
    private var cache: [Int: TriangleMesh] = [:]
    private var cacheHits = 0
    private var cacheMisses = 0

    public init() {}

    /// Evaluate a GeometryOp tree with caching.
    /// The cache persists across calls — call `clearCache()` to reset.
    public func evaluate(_ op: GeometryOp) -> TriangleMesh {
        let key = op.hashValue

        if let cached = cache[key] {
            cacheHits += 1
            return cached
        }

        cacheMisses += 1
        let result = evaluateUncached(op)
        cache[key] = result
        return result
    }

    /// Clear the geometry cache. Call when a full re-evaluation is needed
    /// (e.g., structural script changes beyond variable updates).
    public func clearCache() {
        cache.removeAll()
        cacheHits = 0
        cacheMisses = 0
    }

    /// Returns (hits, misses) for performance monitoring.
    public var cacheStats: (hits: Int, misses: Int) {
        (cacheHits, cacheMisses)
    }

    private func evaluateUncached(_ op: GeometryOp) -> TriangleMesh {
        switch op {
        case .primitive(let type, let params):
            return evaluatePrimitive(type, params)
        case .boolean(let type, let children):
            return evaluateBoolean(type, children)
        case .transform(let type, let params, let child):
            return evaluateTransform(type, params, child)
        case .extrude(let type, let params, let child):
            return evaluateExtrude(type, params, child)
        case .color(_, let child):
            return evaluate(child)
        case .group(let children):
            var mesh = TriangleMesh()
            for child in children {
                mesh.merge(evaluate(child))
            }
            return mesh
        case .empty:
            return TriangleMesh()
        }
    }

    private func evaluatePrimitive(_ type: PrimitiveType, _ params: PrimitiveParams) -> TriangleMesh {
        switch type {
        case .cube:
            return CubeGenerator.generate(params: params)
        case .cylinder:
            return CylinderGenerator.generate(params: params)
        case .sphere:
            return SphereGenerator.generate(params: params)
        case .polyhedron:
            return PolyhedronGenerator.generate(params: params)
        case .circle:
            return TriangleMesh()
        case .square:
            return TriangleMesh()
        case .polygon:
            return TriangleMesh()
        }
    }

    private func evaluateBoolean(_ type: BooleanType, _ children: [GeometryOp]) -> TriangleMesh {
        guard !children.isEmpty else { return TriangleMesh() }
        let meshes = children.map { evaluate($0) }
        return CSGOperations.perform(type, on: meshes)
    }

    private func evaluateTransform(_ type: TransformType, _ params: TransformParams, _ child: GeometryOp) -> TriangleMesh {
        var mesh = evaluate(child)
        let matrix = TransformOperations.matrix(for: type, params: params)
        mesh.apply(transform: matrix)
        if TransformOperations.requiresWindingFlip(type: type, params: params) {
            mesh.flipWinding()
        }
        return mesh
    }

    private func evaluateExtrude(_ type: ExtrudeType, _ params: ExtrudeParams, _ child: GeometryOp) -> TriangleMesh {
        let polygon = extractPolygon(from: child)
        switch type {
        case .linear:
            return LinearExtrudeOperation.extrude(polygon: polygon, params: params)
        case .rotate:
            return RotateExtrudeOperation.extrude(polygon: polygon, params: params)
        }
    }

    private func extractPolygon(from op: GeometryOp) -> Polygon2D {
        switch op {
        case .primitive(let type, let params):
            switch type {
            case .circle:
                let r = params.radius ?? 1.0
                let segments = params.resolvedSegments(forRadius: r)
                var pts: [SIMD2<Float>] = []
                for i in 0..<segments {
                    let angle = Float(i) / Float(segments) * 2.0 * .pi
                    pts.append(SIMD2<Float>(r * cos(angle), r * sin(angle)))
                }
                return Polygon2D(points: pts)
            case .square:
                let s = params.size ?? SIMD3<Float>(1, 1, 0)
                if params.center {
                    let hx = s.x / 2, hy = s.y / 2
                    return Polygon2D(points: [
                        SIMD2(-hx, -hy), SIMD2(hx, -hy),
                        SIMD2(hx, hy), SIMD2(-hx, hy)
                    ])
                } else {
                    return Polygon2D(points: [
                        SIMD2(0, 0), SIMD2(s.x, 0),
                        SIMD2(s.x, s.y), SIMD2(0, s.y)
                    ])
                }
            case .polygon:
                if let pts2D = params.points2D {
                    return Polygon2D(points: pts2D)
                }
                return Polygon2D()
            default:
                return Polygon2D()
            }
        case .group(let children):
            if let first = children.first {
                return extractPolygon(from: first)
            }
            return Polygon2D()
        case .transform(_, let tParams, let child):
            var poly = extractPolygon(from: child)
            for i in poly.points.indices {
                poly.points[i].x += tParams.vector.x
                poly.points[i].y += tParams.vector.y
            }
            return poly
        default:
            return Polygon2D()
        }
    }
}

extension TriangleMesh {
    public mutating func flipWinding() {
        triangles = triangles.map { ($0.0, $0.2, $0.1) }
        normals = normals.map { -$0 }
    }
}
