import Foundation
import GeometryKernel
import simd

/// Persistent naming scheme for mesh faces and edges that survives feature tree mutations.
///
/// The problem: triangle indices change when the mesh is re-evaluated (e.g., after
/// inserting a feature earlier in the tree). A raw face index from one evaluation
/// is meaningless after re-evaluation.
///
/// The solution: identify faces and edges by geometric properties that are stable
/// across re-evaluation — specifically, the face/edge normal direction and centroid
/// position. When the user selects a face, we store a `FaceRef` with the normal and
/// centroid. On re-evaluation, we find the closest matching face in the new mesh.
public enum TopologicalNaming {

    /// A stable reference to a mesh face that survives re-evaluation.
    public struct FaceRef: Codable, Sendable, Hashable {
        /// Normal direction of the referenced face (unit vector).
        public let normal: CodableSIMD3
        /// Centroid position of the referenced face.
        public let centroid: CodableSIMD3
        /// The feature that produced this face (for scoping the search).
        public let featureID: FeatureID

        public init(normal: SIMD3<Float>, centroid: SIMD3<Float>, featureID: FeatureID) {
            self.normal = CodableSIMD3(normal)
            self.centroid = CodableSIMD3(centroid)
            self.featureID = featureID
        }
    }

    /// A stable reference to a mesh edge.
    public struct EdgeRef: Codable, Sendable, Hashable {
        /// Midpoint of the edge.
        public let midpoint: CodableSIMD3
        /// Direction of the edge (unit vector).
        public let direction: CodableSIMD3
        /// The feature that produced this edge.
        public let featureID: FeatureID

        public init(midpoint: SIMD3<Float>, direction: SIMD3<Float>, featureID: FeatureID) {
            self.midpoint = CodableSIMD3(midpoint)
            self.direction = CodableSIMD3(direction)
            self.featureID = featureID
        }
    }

    /// Create a FaceRef from a mesh and face index.
    public static func faceRef(
        from mesh: TriangleMesh,
        faceIndex: Int,
        featureID: FeatureID
    ) -> FaceRef? {
        guard let plane = FaceQuery.facePlane(of: mesh, faceIndex: faceIndex) else { return nil }
        return FaceRef(normal: plane.normal, centroid: plane.position, featureID: featureID)
    }

    /// Resolve a FaceRef back to a face index in a (potentially re-evaluated) mesh.
    /// Returns the index of the best-matching face, or nil if no good match is found.
    public static func resolve(
        faceRef: FaceRef,
        in mesh: TriangleMesh,
        normalTolerance: Float = 0.05,     // ~3 degrees
        positionTolerance: Float = 1.0      // 1mm
    ) -> Int? {
        let refNormal = faceRef.normal.simd
        let refCentroid = faceRef.centroid.simd

        var bestIndex: Int?
        var bestScore: Float = .infinity

        for i in 0..<mesh.triangles.count {
            guard let plane = FaceQuery.facePlane(of: mesh, faceIndex: i) else { continue }

            // Check normal alignment
            let normalDot = simd_dot(plane.normal, refNormal)
            guard normalDot > (1 - normalTolerance) else { continue }

            // Check centroid proximity
            let dist = simd_length(plane.position - refCentroid)
            guard dist < positionTolerance else { continue }

            // Score: lower is better (prefer exact matches)
            let score = (1 - normalDot) * 10 + dist
            if score < bestScore {
                bestScore = score
                bestIndex = i
            }
        }

        return bestIndex
    }

    /// Resolve a FaceRef and return the average plane for the face group.
    public static func resolvePlane(
        faceRef: FaceRef,
        in mesh: TriangleMesh
    ) -> FaceQuery.FacePlane? {
        guard let faceIndex = resolve(faceRef: faceRef, in: mesh) else { return nil }
        return FaceQuery.averageFacePlane(of: mesh, seedFaceIndex: faceIndex)
    }
}

/// Codable wrapper for SIMD3<Float> (SIMD types don't conform to Codable).
public struct CodableSIMD3: Codable, Sendable, Hashable {
    public let x: Float
    public let y: Float
    public let z: Float

    public init(_ v: SIMD3<Float>) {
        self.x = v.x
        self.y = v.y
        self.z = v.z
    }

    public var simd: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }
}
