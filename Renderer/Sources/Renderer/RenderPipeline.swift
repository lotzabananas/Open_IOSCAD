import Foundation
import simd
import Metal
import MetalKit
import GeometryKernel

/// Interleaved vertex layout matching the Metal shader `Vertex` struct.
struct PackedVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
}

/// Uniforms layout matching the Metal shader `Uniforms` struct.
struct Uniforms {
    var modelViewProjection: simd_float4x4
    var modelView: simd_float4x4
    var normalMatrix: simd_float3x3
    var lightDirection: SIMD3<Float>
    var _pad0: Float = 0                // align to 16 bytes after float3
    var modelColor: SIMD4<Float>
    var isEdgePass: UInt32
    var _pad1: SIMD3<UInt32> = .zero    // pad to 16-byte alignment
}

/// Metal render pipeline that draws a `TriangleMesh` with Phong shading and edge overlay.
public class RenderPipeline {

    // MARK: - Metal State

    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue

    private let solidPipelineState: MTLRenderPipelineState
    private let edgePipelineState: MTLRenderPipelineState
    private let backgroundPipelineState: MTLRenderPipelineState
    private let solidDepthState: MTLDepthStencilState
    private let edgeDepthState: MTLDepthStencilState
    private let backgroundDepthState: MTLDepthStencilState

    // MARK: - Mesh Buffers

    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var indexCount: Int = 0

    // MARK: - Init

    /// Creates the pipeline. Throws if Metal is not available.
    public init?() {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        guard let queue = device.makeCommandQueue() else { return nil }

        self.device = device
        self.commandQueue = queue

        // Load the shader library from the Swift Package bundle.
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.module) else {
            return nil
        }

        // ── Solid fill pipeline ──────────────────────────────────────────
        guard let solidPSO = RenderPipeline.makeSolidPipeline(device: device, library: library) else {
            return nil
        }
        self.solidPipelineState = solidPSO

        // ── Edge (wireframe) pipeline ────────────────────────────────────
        guard let edgePSO = RenderPipeline.makeEdgePipeline(device: device, library: library) else {
            return nil
        }
        self.edgePipelineState = edgePSO

        // ── Background gradient pipeline ─────────────────────────────────
        guard let bgPSO = RenderPipeline.makeBackgroundPipeline(device: device, library: library) else {
            return nil
        }
        self.backgroundPipelineState = bgPSO

        // ── Depth / stencil states ───────────────────────────────────────
        let solidDepthDesc = MTLDepthStencilDescriptor()
        solidDepthDesc.depthCompareFunction = .less
        solidDepthDesc.isDepthWriteEnabled = true
        guard let solidDS = device.makeDepthStencilState(descriptor: solidDepthDesc) else { return nil }
        self.solidDepthState = solidDS

        let edgeDepthDesc = MTLDepthStencilDescriptor()
        edgeDepthDesc.depthCompareFunction = .lessEqual
        edgeDepthDesc.isDepthWriteEnabled = false
        guard let edgeDS = device.makeDepthStencilState(descriptor: edgeDepthDesc) else { return nil }
        self.edgeDepthState = edgeDS

        let bgDepthDesc = MTLDepthStencilDescriptor()
        bgDepthDesc.depthCompareFunction = .always
        bgDepthDesc.isDepthWriteEnabled = false
        guard let bgDS = device.makeDepthStencilState(descriptor: bgDepthDesc) else { return nil }
        self.backgroundDepthState = bgDS
    }

    // MARK: - Mesh Upload

    /// Convert a `TriangleMesh` into Metal vertex and index buffers.
    public func updateMesh(_ mesh: TriangleMesh) {
        guard !mesh.isEmpty else {
            vertexBuffer = nil
            indexBuffer = nil
            indexCount = 0
            return
        }

        // Build interleaved vertex data.
        var packed: [PackedVertex] = []
        packed.reserveCapacity(mesh.vertices.count)
        for i in 0..<mesh.vertices.count {
            let normal = i < mesh.normals.count ? mesh.normals[i] : SIMD3<Float>(0, 1, 0)
            packed.append(PackedVertex(position: mesh.vertices[i], normal: normal))
        }

        vertexBuffer = device.makeBuffer(
            bytes: packed,
            length: MemoryLayout<PackedVertex>.stride * packed.count,
            options: .storageModeShared
        )

        // Build index buffer (UInt32).
        var indices: [UInt32] = []
        indices.reserveCapacity(mesh.triangles.count * 3)
        for tri in mesh.triangles {
            indices.append(tri.0)
            indices.append(tri.1)
            indices.append(tri.2)
        }
        indexCount = indices.count

        indexBuffer = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt32>.stride * indices.count,
            options: .storageModeShared
        )
    }

    // MARK: - Render

    /// Render the current mesh into the given `MTKView`.
    public func render(in view: MTKView, camera: Camera) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }

        // Light gray clear color.
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.75, green: 0.77, blue: 0.80, alpha: 1.0)
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        // ── 1. Background gradient ───────────────────────────────────────
        encoder.setRenderPipelineState(backgroundPipelineState)
        encoder.setDepthStencilState(backgroundDepthState)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        // ── 2. Solid model pass ──────────────────────────────────────────
        if let vb = vertexBuffer, let ib = indexBuffer, indexCount > 0 {
            let view4x4 = camera.viewMatrix()
            let proj4x4 = camera.projectionMatrix()
            let mv = view4x4
            let mvp = proj4x4 * mv
            let normalMat = mv.upperLeft3x3.inverse.transpose

            // Light coming from upper-right-front in view space.
            let lightDir = simd_normalize(SIMD3<Float>(0.5, 1.0, 0.8))

            var solidUniforms = Uniforms(
                modelViewProjection: mvp,
                modelView: mv,
                normalMatrix: normalMat,
                lightDirection: lightDir,
                modelColor: SIMD4<Float>(0.6, 0.72, 0.84, 1.0),  // soft blue-gray
                isEdgePass: 0
            )

            encoder.setRenderPipelineState(solidPipelineState)
            encoder.setDepthStencilState(solidDepthState)
            encoder.setCullMode(.back)
            encoder.setVertexBuffer(vb, offset: 0, index: 0)
            encoder.setVertexBytes(&solidUniforms, length: MemoryLayout<Uniforms>.size, index: 1)
            encoder.setFragmentBytes(&solidUniforms, length: MemoryLayout<Uniforms>.size, index: 1)
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: indexCount,
                indexType: .uint32,
                indexBuffer: ib,
                indexBufferOffset: 0
            )

            // ── 3. Edge overlay pass ─────────────────────────────────────
            var edgeUniforms = solidUniforms
            edgeUniforms.isEdgePass = 1

            encoder.setRenderPipelineState(edgePipelineState)
            encoder.setDepthStencilState(edgeDepthState)
            encoder.setCullMode(.none)
            encoder.setTriangleFillMode(.lines)
            encoder.setVertexBuffer(vb, offset: 0, index: 0)
            encoder.setVertexBytes(&edgeUniforms, length: MemoryLayout<Uniforms>.size, index: 1)
            encoder.setFragmentBytes(&edgeUniforms, length: MemoryLayout<Uniforms>.size, index: 1)
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: indexCount,
                indexType: .uint32,
                indexBuffer: ib,
                indexBufferOffset: 0
            )
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Pipeline State Builders

    private static func makeSolidPipeline(device: MTLDevice, library: MTLLibrary) -> MTLRenderPipelineState? {
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "model_vertex")
        desc.fragmentFunction = library.makeFunction(name: "model_fragment")
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        desc.depthAttachmentPixelFormat = .depth32Float
        return try? device.makeRenderPipelineState(descriptor: desc)
    }

    private static func makeEdgePipeline(device: MTLDevice, library: MTLLibrary) -> MTLRenderPipelineState? {
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "model_vertex")
        desc.fragmentFunction = library.makeFunction(name: "model_fragment")
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        // Enable blending for semi-transparent edges.
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        desc.colorAttachments[0].sourceAlphaBlendFactor = .one
        desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        desc.depthAttachmentPixelFormat = .depth32Float
        return try? device.makeRenderPipelineState(descriptor: desc)
    }

    private static func makeBackgroundPipeline(device: MTLDevice, library: MTLLibrary) -> MTLRenderPipelineState? {
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "background_vertex")
        desc.fragmentFunction = library.makeFunction(name: "background_fragment")
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        desc.depthAttachmentPixelFormat = .depth32Float
        return try? device.makeRenderPipelineState(descriptor: desc)
    }
}

