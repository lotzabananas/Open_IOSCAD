import SwiftUI
import ParametricEngine

struct ContentView: View {
    @StateObject private var viewModel = ModelViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // 3D Viewport (always visible)
            ViewportView(mesh: $viewModel.currentMesh) { faceIndex in
                viewModel.selectFace(at: faceIndex)
            }
            .accessibilityIdentifier("viewport_view")
            .edgesIgnoringSafeArea(.all)

            // Sketch mode overlay
            if viewModel.isInSketchMode {
                SketchCanvasView(viewModel: viewModel)
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                Spacer()

                // Error banner
                if let error = viewModel.lastError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Spacer()
                        Button(action: { viewModel.lastError = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                        }
                        .accessibilityIdentifier("error_dismiss")
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                // Property Inspector (when feature selected)
                if viewModel.showPropertyInspector, let feature = viewModel.selectedFeature {
                    PropertyInspectorView(
                        feature: feature,
                        onUpdate: { viewModel.updateFeature($0) },
                        onDismiss: { viewModel.deselectFeature() }
                    )
                    .frame(maxHeight: 200)
                    .transition(.move(edge: .bottom))
                }

                // Feature Tree (collapsible)
                if viewModel.showFeatureTree && !viewModel.isInSketchMode {
                    FeatureTreeView(
                        features: viewModel.featureItems,
                        selectedID: viewModel.selectedFeatureID,
                        onSelect: { viewModel.selectFeature(at: $0) },
                        onSuppress: { viewModel.suppressFeature(at: $0) },
                        onDelete: { viewModel.deleteFeature(at: $0) },
                        onRename: { viewModel.renameFeature(at: $0, to: $1) },
                        onMove: { viewModel.moveFeature(from: $0, to: $1) }
                    )
                    .frame(maxHeight: 200)
                    .transition(.move(edge: .bottom))
                }

                // Toolbar (hidden during sketch mode)
                if !viewModel.isInSketchMode {
                    ToolbarView(viewModel: viewModel)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.showFeatureTree)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isInSketchMode)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showPropertyInspector)
        .sheet(isPresented: $viewModel.showExportSheet) {
            ExportSheet(viewModel: viewModel)
        }
        .alert("Export Complete", isPresented: $viewModel.showExportSuccess) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $viewModel.showAddMenu) {
            AddShapeSheet(viewModel: viewModel)
        }
    }
}
