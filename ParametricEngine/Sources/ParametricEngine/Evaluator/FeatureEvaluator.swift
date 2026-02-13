import Foundation
import GeometryKernel

/// Evaluates a FeatureTree top-to-bottom, producing a TriangleMesh.
///
/// Two-pass design:
///   Pass 1 — Walk features in tree order. Sketches produce profiles.
///            Extrudes produce meshes. Revolves produce meshes.
///            Transforms modify their target's mesh.
///            Booleans combine their targets into a single mesh.
///   Pass 2 — Combine surviving per-feature meshes in tree order using
///            each feature's operation (additive → union, subtractive → difference).
public final class FeatureEvaluator {
    private let kernel: GeometryKernel

    /// Accumulated mesh at the time of the last evaluation, used for face-based plane queries.
    private var accumulatedMeshForFace: TriangleMesh?

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
        var sketchProfiles: [FeatureID: Polygon2D] = [:]
        var featureMeshes: [FeatureID: TriangleMesh] = [:]
        var meshOperations: [FeatureID: MeshOperation] = [:]
        var errors: [EvaluationError] = []

        // ── Pass 1: produce per-feature meshes ──

        // Track accumulated mesh for face-based plane queries
        var runningMesh = TriangleMesh()

        for feature in tree.activeFeatures {
            // Make the current accumulated mesh available for face-based sketch planes
            accumulatedMeshForFace = runningMesh
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
                        detail: "Referenced sketch not found or suppressed"
                    ))
                    continue
                }

                let extrudedMesh = extrudePolygon(
                    polygon,
                    depth: extrude.depth,
                    plane: sketchPlane(for: extrude.sketchID, in: tree)
                )

                featureMeshes[extrude.id] = extrudedMesh
                meshOperations[extrude.id] = extrude.operation == .additive
                    ? .additive : .subtractive

            case .revolve(let revolve):
                guard let polygon = sketchProfiles[revolve.sketchID] else {
                    errors.append(.missingReference(
                        featureName: revolve.name,
                        referencedID: revolve.sketchID,
                        detail: "Referenced sketch not found or suppressed"
                    ))
                    continue
                }

                let revolvedMesh = revolvePolygon(
                    polygon,
                    angle: revolve.angle,
                    plane: sketchPlane(for: revolve.sketchID, in: tree)
                )

                featureMeshes[revolve.id] = revolvedMesh
                meshOperations[revolve.id] = revolve.operation == .additive
                    ? .additive : .subtractive

            case .transform(let transform):
                guard let targetMesh = featureMeshes[transform.targetID] else {
                    errors.append(.missingReference(
                        featureName: transform.name,
                        referencedID: transform.targetID,
                        detail: "Transform target not found or has no geometry"
                    ))
                    continue
                }

                var transformedMesh = targetMesh
                let matrix = buildTransformMatrix(transform)
                transformedMesh.apply(transform: matrix)

                if requiresWindingFlip(transform) {
                    transformedMesh.flipWinding()
                }

                // Replace the target's mesh with the transformed version.
                // The target keeps its original operation (additive/subtractive).
                featureMeshes[transform.targetID] = transformedMesh

            case .boolean(let boolean):
                let targetMeshes: [TriangleMesh] = boolean.targetIDs.compactMap {
                    featureMeshes[$0]
                }

                guard targetMeshes.count >= 2 else {
                    errors.append(.invalidParameter(
                        featureName: boolean.name,
                        parameterName: "targetIDs",
                        detail: "Boolean requires at least 2 targets with geometry, found \(targetMeshes.count)"
                    ))
                    continue
                }

                let boolType = kernelBooleanType(boolean.booleanType)
                let result = CSGOperations.perform(boolType, on: targetMeshes)

                // Remove the consumed targets and store the boolean result
                for id in boolean.targetIDs {
                    featureMeshes.removeValue(forKey: id)
                    meshOperations.removeValue(forKey: id)
                }

                featureMeshes[boolean.id] = result
                meshOperations[boolean.id] = .additive
            }

            // Update running mesh for face-based plane resolution
            if let mesh = featureMeshes[feature.id], !mesh.isEmpty {
                let op = meshOperations[feature.id] ?? .additive
                switch op {
                case .additive:
                    if runningMesh.isEmpty {
                        runningMesh = mesh
                    } else {
                        runningMesh = CSGOperations.perform(.union, on: [runningMesh, mesh])
                    }
                case .subtractive:
                    if !runningMesh.isEmpty {
                        runningMesh = CSGOperations.perform(.difference, on: [runningMesh, mesh])
                    }
                }
            }
        }

        // runningMesh already has all features combined in tree order from Pass 1.
        return EvaluationResult(mesh: runningMesh, errors: errors)
    }

    // MARK: - Private

    /// How a feature's mesh participates in the final combination.
    private enum MeshOperation {
        case additive
        case subtractive
    }

    private func evaluateSketch(_ sketch: SketchFeature) -> Result<Polygon2D, ProfileError> {
        // Phase 2: solve constraints before extracting the profile
        let elements: [SketchElement]
        if !sketch.constraints.isEmpty {
            let result = SketchSolver.solve(
                elements: sketch.elements,
                constraints: sketch.constraints
            )
            elements = result.elements
        } else {
            elements = sketch.elements
        }
        return ProfileExtractor.extractProfile(from: elements)
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

    private func revolvePolygon(_ polygon: Polygon2D, angle: Double, plane: SketchPlane?) -> TriangleMesh {
        let params = ExtrudeParams(angle: Float(angle))
        let profileOp = polygonToOp(polygon)
        let revolveOp = GeometryOp.extrude(.rotate, params, profileOp)

        var mesh = kernel.evaluate(revolveOp)

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

    // MARK: - Transform helpers

    private func buildTransformMatrix(_ transform: TransformFeature) -> simd_float4x4 {
        let type: TransformType
        switch transform.transformType {
        case .translate: type = .translate
        case .rotate:    type = .rotate
        case .scale:     type = .scale
        case .mirror:    type = .mirror
        }

        let params: TransformParams
        switch transform.transformType {
        case .translate, .scale, .mirror:
            params = TransformParams(
                vector: SIMD3<Float>(
                    Float(transform.vectorX),
                    Float(transform.vectorY),
                    Float(transform.vectorZ)
                )
            )
        case .rotate:
            params = TransformParams(
                vector: SIMD3<Float>(
                    Float(transform.vectorX),
                    Float(transform.vectorY),
                    Float(transform.vectorZ)
                ),
                angle: Float(transform.angle),
                axis: SIMD3<Float>(
                    Float(transform.axisX),
                    Float(transform.axisY),
                    Float(transform.axisZ)
                )
            )
        }

        return TransformOperations.matrix(for: type, params: params)
    }

    private func requiresWindingFlip(_ transform: TransformFeature) -> Bool {
        let type: TransformType
        switch transform.transformType {
        case .translate: type = .translate
        case .rotate:    type = .rotate
        case .scale:     type = .scale
        case .mirror:    type = .mirror
        }

        let params = TransformParams(
            vector: SIMD3<Float>(
                Float(transform.vectorX),
                Float(transform.vectorY),
                Float(transform.vectorZ)
            )
        )

        return TransformOperations.requiresWindingFlip(type: type, params: params)
    }

    private func kernelBooleanType(_ op: BooleanFeature.BooleanOp) -> BooleanType {
        switch op {
        case .union:        return .union
        case .intersection: return .intersection
        case .difference:   return .difference
        }
    }

    // MARK: - Plane transforms

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

        case .faceOf(_, let faceIndex):
            // Phase 2: extract face normal and centroid from mesh to build plane transform.
            if let featureMesh = accumulatedMeshForFace,
               let transform = FaceQuery.faceTransform(of: featureMesh, faceIndex: faceIndex) {
                return transform
            }
            // Fallback to identity if face data is unavailable.
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
