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

            // Feature Tree toggle
            Button(action: { withAnimation { viewModel.showFeatureTree.toggle() }}) {
                VStack(spacing: 2) {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                    Text("Features")
                        .font(.caption2)
                }
            }
            .accessibilityIdentifier("toolbar_features_button")
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
