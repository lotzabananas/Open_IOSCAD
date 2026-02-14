import SwiftUI

/// Floating toolbar for the viewport (iPhone: top of viewport, iPad: sidebar header).
struct ToolbarView: View {
    @ObservedObject var viewModel: ModelViewModel
    var onShowFeatures: (() -> Void)?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            // Undo
            toolbarButton(
                icon: "arrow.uturn.backward",
                identifier: "undo_button",
                isDisabled: !viewModel.canUndo
            ) {
                viewModel.undo()
            }

            // Redo
            toolbarButton(
                icon: "arrow.uturn.forward",
                identifier: "redo_button",
                isDisabled: !viewModel.canRedo
            ) {
                viewModel.redo()
            }

            Rectangle()
                .fill(AppTheme.Colors.border)
                .frame(width: 1, height: 20)

            // Add shape
            toolbarButton(
                icon: "plus.circle.fill",
                identifier: "toolbar_add_button",
                color: AppTheme.Colors.accent
            ) {
                viewModel.showAddMenu = true
            }

            // Features toggle
            toolbarButton(
                icon: "list.bullet",
                identifier: "toolbar_features_button"
            ) {
                onShowFeatures?()
            }

            Spacer()

            // Export
            toolbarButton(
                icon: "square.and.arrow.up",
                identifier: "menu_export"
            ) {
                viewModel.showExportSheet = true
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
        .floatingToolbarStyle()
    }

    private func toolbarButton(
        icon: String,
        identifier: String,
        isDisabled: Bool = false,
        color: Color = AppTheme.Colors.textPrimary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isDisabled ? AppTheme.Colors.textSecondary.opacity(0.3) : color)
        }
        .disabled(isDisabled)
        .accessibilityIdentifier(identifier)
    }
}
