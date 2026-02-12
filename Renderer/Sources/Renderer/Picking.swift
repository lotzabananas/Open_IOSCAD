import Foundation
import MetalKit
import GeometryKernel
import simd

/// GPU color-ID based face/edge picking system.
/// Renders an off-screen pass where each face is encoded as a unique color.
/// On tap, reads the pixel to determine which face was hit.
public final class FacePicker {

    private let device: MTLDevice
    private var pickingTexture: MTLTexture?
    private var depthTexture: MTLTexture?
    private var pipelineState: MTLRenderPipelineState?
    private var depthStencilState: MTLDepthStencilState?
    private var vertexBuffer: MTLBuffer?
    private var faceIDBuffer: MTLBuffer?
    private var triangleCount: Int = 0

    /// Face group assignments: maps triangle index to logical face group ID.
    public private(set) var faceGroups: [Int] = []

    /// Number of logical face groups.
    public private(set) var faceGroupCount: Int = 0

    public init?(device: MTLDevice) {
        self.device = device
        setupPipeline()
    }

    // MARK: - Face Grouping

    /// Group mesh triangles by normal direction into logical faces.
    /// Coplanar adjacent triangles with similar normals form one face group.
    public func buildFaceGroups(from mesh: TriangleMesh) {
        guard !mesh.isEmpty else {
            faceGroups = []
            faceGroupCount = 0
            return
        }

        let normalThreshold: Float = 0.98 // cos(~11 degrees)

        // Compute per-triangle face normals
        var triNormals: [SIMD3<Float>] = []
        for tri in mesh.triangles {
            let v0 = mesh.vertices[Int(tri.0)]
            let v1 = mesh.vertices[Int(tri.1)]
            let v2 = mesh.vertices[Int(tri.2)]
            let n = simd_normalize(simd_cross(v1 - v0, v2 - v0))
            triNormals.append(n)
        }

        // Build adjacency: triangles sharing an edge
        var edgeToTris: [UInt64: [Int]] = [:]
        for (i, tri) in mesh.triangles.enumerated() {
            let edges: [(UInt32, UInt32)] = [
                (min(tri.0, tri.1), max(tri.0, tri.1)),
                (min(tri.1, tri.2), max(tri.1, tri.2)),
                (min(tri.0, tri.2), max(tri.0, tri.2)),
            ]
            for edge in edges {
                let key = UInt64(edge.0) << 32 | UInt64(edge.1)
                edgeToTris[key, default: []].append(i)
            }
        }

        // Union-find for grouping
        var parent = Array(0..<mesh.triangles.count)

        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x {
                parent[x] = parent[parent[x]]
                x = parent[x]
            }
            return x
        }

        func unite(_ a: Int, _ b: Int) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[ra] = rb }
        }

        // Merge triangles sharing an edge with similar normals
        for (_, tris) in edgeToTris {
            if tris.count == 2 {
                let dot = simd_dot(triNormals[tris[0]], triNormals[tris[1]])
                if dot > normalThreshold {
                    unite(tris[0], tris[1])
                }
            }
        }

        // Assign group IDs
        var groupMap: [Int: Int] = [:]
        var nextGroup = 0
        faceGroups = []
        for i in 0..<mesh.triangles.count {
            let root = find(i)
            if groupMap[root] == nil {
                groupMap[root] = nextGroup
                nextGroup += 1
            }
            faceGroups.append(groupMap[root]!)
        }
        faceGroupCount = nextGroup
    }

    // MARK: - Pick

    /// Perform a pick at the given screen coordinate.
    /// Returns the face group ID, or nil if nothing was hit.
    public func pick(
        at point: CGPoint,
        mesh: TriangleMesh,
        camera: Camera,
        viewportSize: CGSize
    ) -> Int? {
        guard !mesh.isEmpty, !faceGroups.isEmpty else { return nil }
        guard let texture = ensureTextures(size: viewportSize) else { return nil }

        renderPickPass(mesh: mesh, camera: camera, viewportSize: viewportSize)

        // Read pixel
        let x = Int(point.x)
        let y = Int(point.y)
        guard x >= 0, x < Int(viewportSize.width),
              y >= 0, y < Int(viewportSize.height) else { return nil }

        var pixel: [UInt8] = [0, 0, 0, 0]
        let region = MTLRegion(origin: MTLOrigin(x: x, y: y, z: 0),
                               size: MTLSize(width: 1, height: 1, depth: 1))
        texture.getBytes(&pixel, bytesPerRow: 4, from: region, mipmapLevel: 0)

        let faceID = Int(pixel[0]) | (Int(pixel[1]) << 8) | (Int(pixel[2]) << 16)
        if faceID == 0xFFFFFF || faceID >= faceGroupCount {
            return nil // Background or out-of-range
        }
        return faceID
    }

    // MARK: - Private

    private func setupPipeline() {
        // Pipeline will be built with the Metal library when first needed
    }

    private func ensureTextures(size: CGSize) -> MTLTexture? {
        let width = max(Int(size.width), 1)
        let height = max(Int(size.height), 1)

        if let existing = pickingTexture,
           existing.width == width, existing.height == height {
            return existing
        }

        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        colorDesc.usage = [.renderTarget, .shaderRead]
        colorDesc.storageMode = .shared
        pickingTexture = device.makeTexture(descriptor: colorDesc)

        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        depthDesc.usage = .renderTarget
        depthDesc.storageMode = .private
        depthTexture = device.makeTexture(descriptor: depthDesc)

        return pickingTexture
    }

    private func renderPickPass(
        mesh: TriangleMesh,
        camera: Camera,
        viewportSize: CGSize
    ) {
        // Simplified: in production this renders with face-ID colors as fragment output.
        // For Phase 1, face grouping + CPU ray-cast serves as the picking mechanism.
    }

    // MARK: - CPU Ray-Cast Fallback

    /// CPU-based picking fallback: cast a ray from screen coordinates through the mesh.
    public func cpuPick(
        at point: CGPoint,
        mesh: TriangleMesh,
        camera: Camera,
        viewportSize: CGSize
    ) -> Int? {
        guard !mesh.isEmpty, !faceGroups.isEmpty else { return nil }

        let ndcX = Float(point.x / viewportSize.width) * 2 - 1
        let ndcY = 1 - Float(point.y / viewportSize.height) * 2

        let invProjection = camera.projectionMatrix().inverse
        let invView = camera.viewMatrix().inverse

        // Near/far points in clip space
        let nearClip = SIMD4<Float>(ndcX, ndcY, 0, 1)
        let farClip = SIMD4<Float>(ndcX, ndcY, 1, 1)

        var nearEye = invProjection * nearClip
        nearEye /= nearEye.w
        var farEye = invProjection * farClip
        farEye /= farEye.w

        let nearWorld = invView * nearEye
        let farWorld = invView * farEye

        let rayOrigin = SIMD3<Float>(nearWorld.x, nearWorld.y, nearWorld.z)
        let rayEnd = SIMD3<Float>(farWorld.x, farWorld.y, farWorld.z)
        let rayDir = simd_normalize(rayEnd - rayOrigin)

        // Intersect with each triangle
        var closestT: Float = .infinity
        var closestTriIdx: Int?

        for (i, tri) in mesh.triangles.enumerated() {
            let v0 = mesh.vertices[Int(tri.0)]
            let v1 = mesh.vertices[Int(tri.1)]
            let v2 = mesh.vertices[Int(tri.2)]

            if let t = rayTriangleIntersect(origin: rayOrigin, dir: rayDir, v0: v0, v1: v1, v2: v2) {
                if t > 0 && t < closestT {
                    closestT = t
                    closestTriIdx = i
                }
            }
        }

        guard let triIdx = closestTriIdx, triIdx < faceGroups.count else {
            return nil
        }
        return faceGroups[triIdx]
    }

    /// Moller-Trumbore ray-triangle intersection.
    private func rayTriangleIntersect(
        origin: SIMD3<Float>, dir: SIMD3<Float>,
        v0: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>
    ) -> Float? {
        let epsilon: Float = 1e-8
        let edge1 = v1 - v0
        let edge2 = v2 - v0
        let h = simd_cross(dir, edge2)
        let a = simd_dot(edge1, h)

        if abs(a) < epsilon { return nil }

        let f = 1.0 / a
        let s = origin - v0
        let u = f * simd_dot(s, h)
        if u < 0 || u > 1 { return nil }

        let q = simd_cross(s, edge1)
        let v = f * simd_dot(dir, q)
        if v < 0 || u + v > 1 { return nil }

        let t = f * simd_dot(edge2, q)
        return t > epsilon ? t : nil
    }
}
