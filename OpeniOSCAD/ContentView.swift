import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ModelViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // 3D Viewport (always visible)
            ViewportView(mesh: $viewModel.currentMesh)
                .accessibilityIdentifier("viewport_view")
                .edgesIgnoringSafeArea(.all)

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
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                // Feature Tree (collapsible)
                if viewModel.showFeatureTree {
                    FeatureTreeView(
                        features: viewModel.features,
                        selectedIndex: $viewModel.selectedFeatureIndex,
                        onSuppress: { viewModel.suppressFeature(at: $0) },
                        onDelete: { viewModel.deleteFeature(at: $0) },
                        onRename: { viewModel.renameFeature(at: $0, to: $1) },
                        onMove: { viewModel.moveFeature(from: $0, to: $1) }
                    )
                    .frame(maxHeight: 200)
                    .transition(.move(edge: .bottom))
                }

                // Script Editor (toggled)
                if viewModel.showScriptEditor {
                    ScriptEditorView(
                        text: $viewModel.scriptText,
                        onCommit: { viewModel.rebuildFromScript() }
                    )
                    .frame(height: 250)
                    .transition(.move(edge: .bottom))
                    .accessibilityIdentifier("script_editor_view")
                }

                // Customizer Panel (toggled)
                if viewModel.showCustomizer {
                    ParameterPanelView(
                        parameters: viewModel.customizerParams,
                        onValueChanged: { name, value in
                            viewModel.updateParameterDuringDrag(name: name, value: value)
                        },
                        onDragStarted: { viewModel.beginParameterDrag() },
                        onDragEnded: { viewModel.endParameterDrag() }
                    )
                    .frame(maxHeight: 300)
                    .transition(.move(edge: .bottom))
                }

                // Toolbar
                ToolbarView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.showScriptEditor)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showCustomizer)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showFeatureTree)
        .sheet(isPresented: $viewModel.showExportSheet) {
            ExportSheet(viewModel: viewModel)
        }
        .alert("Export Complete", isPresented: $viewModel.showExportSuccess) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $viewModel.showAddMenu) {
            AddPrimitiveSheet(viewModel: viewModel)
        }
    }
}
