import SwiftUI
import GeometryKernel
import Renderer

struct ViewportView: View {
    @Binding var mesh: TriangleMesh

    var body: some View {
        MetalViewport(mesh: $mesh)
            .accessibilityIdentifier("viewport_view")
    }
}
