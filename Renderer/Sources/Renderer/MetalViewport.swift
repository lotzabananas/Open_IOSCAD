import SwiftUI
import MetalKit
import GeometryKernel

#if canImport(UIKit)
import UIKit

/// A SwiftUI view that renders a `TriangleMesh` using Metal with orbit/pan/zoom gestures.
public struct MetalViewport: UIViewRepresentable {

    @Binding public var mesh: TriangleMesh
    public var onFaceTapped: ((Int?) -> Void)?

    public init(mesh: Binding<TriangleMesh>, onFaceTapped: ((Int?) -> Void)? = nil) {
        self._mesh = mesh
        self.onFaceTapped = onFaceTapped
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        let coordinator = context.coordinator

        guard let pipeline = RenderPipeline() else {
            // Metal not available; return a blank view.
            return mtkView
        }

        coordinator.pipeline = pipeline
        coordinator.camera = Camera()
        coordinator.facePicker = FacePicker(device: pipeline.device)
        coordinator.onFaceTapped = onFaceTapped

        mtkView.device = pipeline.device
        mtkView.delegate = coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.75, green: 0.77, blue: 0.80, alpha: 1.0)
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60

        // Gesture recognizers
        let panGesture = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        mtkView.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePinch(_:)))
        mtkView.addGestureRecognizer(pinchGesture)

        let twoFingerPan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        mtkView.addGestureRecognizer(twoFingerPan)

        let tapGesture = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        mtkView.addGestureRecognizer(tapGesture)

        // Make sure tap doesn't interfere with pan
        panGesture.require(toFail: tapGesture)

        // Upload the initial mesh.
        if !mesh.isEmpty {
            pipeline.updateMesh(mesh)
            coordinator.camera.fitAll(boundingBox: mesh.boundingBox)
        }

        return mtkView
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {
        let coordinator = context.coordinator
        guard let pipeline = coordinator.pipeline else { return }

        coordinator.onFaceTapped = onFaceTapped

        // Re-upload mesh when it changes.
        if coordinator.lastMesh != mesh {
            pipeline.updateMesh(mesh)
            coordinator.lastMesh = mesh

            // Rebuild face groups for picking
            coordinator.facePicker?.buildFaceGroups(from: mesh)

            // Auto-fit on first non-empty mesh.
            if !mesh.isEmpty && !coordinator.hasAutoFit {
                coordinator.camera.fitAll(boundingBox: mesh.boundingBox)
                coordinator.hasAutoFit = true
            }
        }
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject, MTKViewDelegate {
        var pipeline: RenderPipeline?
        var camera = Camera()
        var lastMesh: TriangleMesh?
        var hasAutoFit = false
        var facePicker: FacePicker?
        var onFaceTapped: ((Int?) -> Void)?

        // Track if the gesture moved significantly (to distinguish tap from drag)
        private var panStarted = false

        // MARK: MTKViewDelegate

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            guard size.width > 0, size.height > 0 else { return }
            camera.aspectRatio = Float(size.width / size.height)
        }

        public func draw(in view: MTKView) {
            pipeline?.render(in: view, camera: camera)
        }

        // MARK: Gesture Handlers

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            camera.orbit(deltaX: Float(translation.x), deltaY: Float(translation.y))
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .changed {
                let factor = 1.0 / Float(gesture.scale)
                camera.zoom(factor: factor)
                gesture.scale = 1.0
            }
        }

        @objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            camera.pan(deltaX: Float(translation.x), deltaY: Float(translation.y))
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  let view = gesture.view,
                  let mesh = lastMesh,
                  let picker = facePicker else { return }

            let location = gesture.location(in: view)
            let viewportSize = view.bounds.size

            // Use CPU ray-cast picking
            let faceID = picker.cpuPick(
                at: location,
                mesh: mesh,
                camera: camera,
                viewportSize: viewportSize
            )

            onFaceTapped?(faceID)
        }
    }
}

#endif
