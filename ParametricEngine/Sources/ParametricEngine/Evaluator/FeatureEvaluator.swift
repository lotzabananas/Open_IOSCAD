import Foundation
import GeometryKernel

/// Evaluates a FeatureTree top-to-bottom, producing a GeometryOp tree
/// that GeometryKernel can evaluate to a TriangleMesh.
public final class FeatureEvaluator {
    private let kernel: GeometryKernel

    public init(kernel: GeometryKernel = GeometryKernel()) {
        self.kernel = kernel
    }

    /// Result of evaluation: final mesh plus any errors encountered.
    public struct EvaluationResult: Sendable {
        public let mesh: TriangleMesh
        public let errors: [EvaluationError]

        public init(mesh: TriangleMesh, errors: [EvaluationError] = []) {
            self.mesh = mesh
            self.errors = errors
        }
    }

    /// Evaluate the full feature tree and return a final TriangleMesh.
    public func evaluate(_ tree: FeatureTree) -> EvaluationResult {
        var accumulatedMesh = TriangleMesh()
        var sketchProfiles: [FeatureID: Polygon2D] = [:]
        var errors: [EvaluationError] = []

        for feature in tree.activeFeatures {
            switch feature {
            case .sketch(let sketch):
                let result = evaluateSketch(sketch)
                switch result {
                case .success(let polygon):
                    sketchProfiles[sketch.id] = polygon
                case .failure(let error):
                    errors.append(.profileExtraction(
                        featureName: sketch.name,
                        detail: "\(error)"
                    ))
                }

            case .extrude(let extrude):
                guard let polygon = sketchProfiles[extrude.sketchID] else {
                    errors.append(.missingReference(
                        featureName: extrude.name,
                        referencedID: extrude.sketchID,
                        detail: "Referenced sketch not found"
                    ))
                    continue
                }

                let extrudedMesh = extrudePolygon(
                    polygon,
                    depth: extrude.depth,
                    plane: sketchPlane(for: extrude.sketchID, in: tree)
                )

                switch extrude.operation {
                case .additive:
                    if accumulatedMesh.isEmpty {
                        accumulatedMesh = extrudedMesh
                    } else {
                        accumulatedMesh = CSGOperations.perform(.union, on: [accumulatedMesh, extrudedMesh])
                    }
                case .subtractive:
                    if !accumulatedMesh.isEmpty && !extrudedMesh.isEmpty {
                        accumulatedMesh = CSGOperations.perform(.difference, on: [accumulatedMesh, extrudedMesh])
                    }
                }

            case .boolean:
                // Boolean feature combines bodies — not common in Phase 1 simple workflow
                break

            case .transform:
                // Transform feature — applied to accumulated geometry
                break
            }
        }

        return EvaluationResult(mesh: accumulatedMesh, errors: errors)
    }

    // MARK: - Private

    private func evaluateSketch(_ sketch: SketchFeature) -> Result<Polygon2D, ProfileError> {
        ProfileExtractor.extractProfile(from: sketch.elements)
    }

    private func extrudePolygon(_ polygon: Polygon2D, depth: Double, plane: SketchPlane?) -> TriangleMesh {
        let params = ExtrudeParams(height: Float(depth))
        let profileOp = polygonToOp(polygon)
        let extrudeOp = GeometryOp.extrude(.linear, params, profileOp)

        var mesh = kernel.evaluate(extrudeOp)

        // Apply plane transform if not on XY
        if let plane = plane {
            let transform = planeTransform(plane)
            if transform != matrix_identity_float4x4 {
                mesh.apply(transform: transform)
            }
        }

        return mesh
    }

    private func polygonToOp(_ polygon: Polygon2D) -> GeometryOp {
        .primitive(.polygon, PrimitiveParams(points2D: polygon.points))
    }

    private func sketchPlane(for sketchID: FeatureID, in tree: FeatureTree) -> SketchPlane? {
        guard let feature = tree.feature(byID: sketchID),
              case .sketch(let sketch) = feature else {
            return nil
        }
        return sketch.plane
    }

    /// Build a 4x4 transform matrix to position extruded geometry
    /// according to the sketch plane.
    private func planeTransform(_ plane: SketchPlane) -> simd_float4x4 {
        switch plane {
        case .xy:
            return matrix_identity_float4x4

        case .xz:
            // Rotate -90 degrees around X to map Z up to Y direction
            let angle: Float = -.pi / 2
            let c = cos(angle)
            let s = sin(angle)
            return simd_float4x4(
                SIMD4<Float>(1, 0, 0, 0),
                SIMD4<Float>(0, c, s, 0),
                SIMD4<Float>(0, -s, c, 0),
                SIMD4<Float>(0, 0, 0, 1)
            )

        case .yz:
            // Rotate 90 degrees around Y
            let angle: Float = .pi / 2
            let c = cos(angle)
            let s = sin(angle)
            return simd_float4x4(
                SIMD4<Float>(c, 0, -s, 0),
                SIMD4<Float>(0, 1, 0, 0),
                SIMD4<Float>(s, 0, c, 0),
                SIMD4<Float>(0, 0, 0, 1)
            )

        case .offsetXY(let distance):
            return simd_float4x4(
                SIMD4<Float>(1, 0, 0, 0),
                SIMD4<Float>(0, 1, 0, 0),
                SIMD4<Float>(0, 0, 1, 0),
                SIMD4<Float>(0, 0, Float(distance), 1)
            )

        case .faceOf:
            // Face-based planes need face normal/position from the mesh.
            // For Phase 1, fall back to identity (XY).
            return matrix_identity_float4x4
        }
    }
}

/// Errors from feature evaluation.
public enum EvaluationError: Error, Sendable {
    case profileExtraction(featureName: String, detail: String)
    case missingReference(featureName: String, referencedID: FeatureID, detail: String)
    case invalidParameter(featureName: String, parameterName: String, detail: String)
}
