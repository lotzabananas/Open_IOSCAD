import SwiftUI

struct ToolbarView: View {
    @ObservedObject var viewModel: ModelViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Undo
            Button(action: { viewModel.undo() }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
            }
            .disabled(!viewModel.canUndo)
            .accessibilityIdentifier("undo_button")
            .frame(maxWidth: .infinity)

            // Redo
            Button(action: { viewModel.redo() }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.title3)
            }
            .disabled(!viewModel.canRedo)
            .accessibilityIdentifier("redo_button")
            .frame(maxWidth: .infinity)

            Divider().frame(height: 24)

            // Add
            Button(action: { viewModel.showAddMenu = true }) {
                VStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("Add")
                        .font(.caption2)
                }
            }
            .accessibilityIdentifier("toolbar_add_button")
            .frame(maxWidth: .infinity)

            // Edit / Customizer
            Button(action: { withAnimation { viewModel.showCustomizer.toggle() }}) {
                VStack(spacing: 2) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                    Text("Edit")
                        .font(.caption2)
                }
            }
            .accessibilityIdentifier("toolbar_customizer_button")
            .frame(maxWidth: .infinity)

            // Script toggle
            Button(action: { withAnimation { viewModel.showScriptEditor.toggle() }}) {
                VStack(spacing: 2) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.title2)
                    Text("Script")
                        .font(.caption2)
                }
            }
            .accessibilityIdentifier("toolbar_script_button")
            .frame(maxWidth: .infinity)

            Divider().frame(height: 24)

            // Export
            Button(action: { viewModel.showExportSheet = true }) {
                VStack(spacing: 2) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                    Text("Export")
                        .font(.caption2)
                }
            }
            .accessibilityIdentifier("menu_export")
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
