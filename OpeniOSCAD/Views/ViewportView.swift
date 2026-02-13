import SwiftUI
import GeometryKernel
import Renderer

struct ViewportView: View {
    @Binding var mesh: TriangleMesh
    var onFaceTapped: ((Int?) -> Void)?

    var body: some View {
        MetalViewport(mesh: $mesh, onFaceTapped: onFaceTapped)
            .accessibilityIdentifier("viewport_view")
    }
}
