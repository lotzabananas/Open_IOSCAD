import SwiftUI
import ParametricEngine
import Renderer

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
        .preferredColorScheme(.dark)
    }

    // MARK: - iPad Layout (Sidebar + Viewport)

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            // Left sidebar: Feature Tree + Property Inspector
            VStack(spacing: 0) {
                // Toolbar at top of sidebar
                iPadToolbar
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.background)

                Rectangle()
                    .fill(AppTheme.Colors.border)
                    .frame(height: 1)

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
                    Rectangle()
                        .fill(AppTheme.Colors.border)
                        .frame(height: 1)

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
            .background(AppTheme.Colors.background)

            Rectangle()
                .fill(AppTheme.Colors.border)
                .frame(width: 1)

            // Main viewport area
            ZStack {
                ViewportView(mesh: $viewModel.currentMesh) { faceIndex in
                    viewModel.selectFace(at: faceIndex)
                }
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
        HStack(spacing: AppTheme.Spacing.lg) {
            Button(action: { viewModel.undo() }) {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundColor(viewModel.canUndo ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary.opacity(0.3))
            }
            .disabled(!viewModel.canUndo)
            .accessibilityIdentifier("undo_button")

            Button(action: { viewModel.redo() }) {
                Image(systemName: "arrow.uturn.forward")
                    .foregroundColor(viewModel.canRedo ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary.opacity(0.3))
            }
            .disabled(!viewModel.canRedo)
            .accessibilityIdentifier("redo_button")

            Rectangle()
                .fill(AppTheme.Colors.border)
                .frame(width: 1, height: 20)

            Button(action: { viewModel.showAddMenu = true }) {
                Label("Add", systemImage: "plus.circle.fill")
                    .foregroundColor(AppTheme.Colors.accent)
            }
            .accessibilityIdentifier("toolbar_add_button")

            Spacer()

            Button(action: { viewModel.showExportSheet = true }) {
                Label("Export", systemImage: "square.and.arrow.up")
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .accessibilityIdentifier("menu_export")
        }
        .padding(.horizontal)
    }

    // MARK: - iPhone Layout (Tab-based)

    @State private var selectedTab: Int = 0

    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            // Viewport Tab
            viewportTab
                .tabItem {
                    Label("Viewport", systemImage: "cube")
                }
                .tag(0)

            // Features Tab
            featuresTab
                .tabItem {
                    Label("Features", systemImage: "list.bullet")
                }
                .tag(1)

            // Properties Tab
            propertiesTab
                .tabItem {
                    Label("Properties", systemImage: "slider.horizontal.3")
                }
                .tag(2)
        }
        .tint(AppTheme.Colors.accent)
    }

    private var viewportTab: some View {
        ZStack {
            // 3D Viewport (always visible)
            ViewportView(mesh: $viewModel.currentMesh) { faceIndex in
                viewModel.selectFace(at: faceIndex)
            }
            .edgesIgnoringSafeArea(.all)

            // Sketch mode overlay
            if viewModel.isInSketchMode {
                SketchCanvasView(viewModel: viewModel)
                    .transition(.opacity)
            }

            // Floating toolbar at top
            if !viewModel.isInSketchMode {
                VStack {
                    ToolbarView(viewModel: viewModel, onShowFeatures: { selectedTab = 1 })
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, 8)

                    Spacer()
                }
            }

            // Error banner
            if let error = viewModel.lastError {
                VStack {
                    errorBanner(error)
                        .padding(.top, 60)
                        .padding(.horizontal)
                    Spacer()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isInSketchMode)
    }

    private var featuresTab: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Feature Tree")
                    .font(AppTheme.Typography.heading)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Button(action: { viewModel.showAddMenu = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.Colors.accent)
                }
                .accessibilityIdentifier("features_add_button")
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.Colors.background)

            FeatureTreeView(
                features: viewModel.featureItems,
                selectedID: viewModel.selectedFeatureID,
                onSelect: { viewModel.selectFeature(at: $0) },
                onSuppress: { viewModel.suppressFeature(at: $0) },
                onDelete: { viewModel.deleteFeature(at: $0) },
                onRename: { viewModel.renameFeature(at: $0, to: $1) },
                onMove: { viewModel.moveFeature(from: $0, to: $1) }
            )

            // Property Inspector (below feature tree when selected)
            if viewModel.showPropertyInspector, let feature = viewModel.selectedFeature {
                Rectangle()
                    .fill(AppTheme.Colors.border)
                    .frame(height: 1)

                PropertyInspectorView(
                    feature: feature,
                    onUpdate: { viewModel.updateFeature($0) },
                    onDismiss: { viewModel.deselectFeature() }
                )
                .frame(maxHeight: 300)
                .transition(.move(edge: .bottom))
            }
        }
        .background(AppTheme.Colors.background)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showPropertyInspector)
    }

    private var propertiesTab: some View {
        VStack(spacing: 0) {
            if let feature = viewModel.selectedFeature {
                PropertyInspectorView(
                    feature: feature,
                    onUpdate: { viewModel.updateFeature($0) },
                    onDismiss: { viewModel.deselectFeature() }
                )
            } else {
                Spacer()
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.4))
                    Text("No feature selected")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("Select a feature in the Features tab to edit its properties.")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            }
        }
        .background(AppTheme.Colors.background)
    }

    // MARK: - Shared Components

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Rectangle()
                .fill(AppTheme.Colors.error)
                .frame(width: 3)

            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.Colors.error)
                .font(.caption)

            Text(error)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)

            Spacer()

            Button(action: { viewModel.lastError = nil }) {
                Image(systemName: "xmark")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .font(.caption)
            }
            .accessibilityIdentifier("error_dismiss")
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .padding(.trailing, AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                .stroke(AppTheme.Colors.border, lineWidth: 0.5)
        )
    }
}
