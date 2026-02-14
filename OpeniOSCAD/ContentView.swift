import SwiftUI
import ParametricEngine

struct ContentView: View {
    @StateObject private var viewModel = ModelViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
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

    // MARK: - iPad Layout (Sidebar + Viewport)

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            // Left sidebar: Feature Tree + Property Inspector
            VStack(spacing: 0) {
                // Toolbar at top of sidebar
                iPadToolbar
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)

                Divider()

                // Feature Tree
                FeatureTreeView(
                    features: viewModel.featureItems,
                    selectedID: viewModel.selectedFeatureID,
                    onSelect: { viewModel.selectFeature(at: $0) },
                    onSuppress: { viewModel.suppressFeature(at: $0) },
                    onDelete: { viewModel.deleteFeature(at: $0) },
                    onRename: { viewModel.renameFeature(at: $0, to: $1) },
                    onMove: { viewModel.moveFeature(from: $0, to: $1) }
                )
                .accessibilityIdentifier("ipad_feature_tree")

                // Property Inspector (below feature tree when selected)
                if viewModel.showPropertyInspector, let feature = viewModel.selectedFeature {
                    Divider()
                    PropertyInspectorView(
                        feature: feature,
                        onUpdate: { viewModel.updateFeature($0) },
                        onDismiss: { viewModel.deselectFeature() }
                    )
                    .frame(maxHeight: 300)
                    .transition(.move(edge: .bottom))
                }
            }
            .frame(width: 300)
            .background(Color(.systemBackground))

            Divider()

            // Main viewport area
            ZStack(alignment: .bottom) {
                ViewportView(mesh: $viewModel.currentMesh) { faceIndex in
                    viewModel.selectFace(at: faceIndex)
                }
                .accessibilityIdentifier("viewport_view")
                .edgesIgnoringSafeArea(.all)

                // Sketch overlay
                if viewModel.isInSketchMode {
                    SketchCanvasView(viewModel: viewModel)
                        .transition(.opacity)
                }

                // Error banner (floating over viewport)
                if let error = viewModel.lastError {
                    VStack {
                        errorBanner(error)
                            .padding()
                        Spacer()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.showPropertyInspector)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isInSketchMode)
    }

    private var iPadToolbar: some View {
        HStack(spacing: 16) {
            Button(action: { viewModel.undo() }) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!viewModel.canUndo)
            .accessibilityIdentifier("undo_button")

            Button(action: { viewModel.redo() }) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!viewModel.canRedo)
            .accessibilityIdentifier("redo_button")

            Divider().frame(height: 20)

            Button(action: { viewModel.showAddMenu = true }) {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .accessibilityIdentifier("toolbar_add_button")

            Spacer()

            Button(action: { viewModel.showExportSheet = true }) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("menu_export")
        }
        .padding(.horizontal)
    }

    // MARK: - iPhone Layout (Compact, original)

    private var iPhoneLayout: some View {
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
                    errorBanner(error)
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
    }

    // MARK: - Shared Components

    private func errorBanner(_ error: String) -> some View {
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
}
