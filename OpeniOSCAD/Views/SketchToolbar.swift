import SwiftUI

/// Drawing tool palette for sketch mode.
struct SketchToolbar: View {
    @ObservedObject var sketchVM: SketchViewModel
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // Tool selection
            ForEach(SketchTool.allCases, id: \.self) { tool in
                Button(action: { sketchVM.selectedTool = tool }) {
                    Image(systemName: tool.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(sketchVM.selectedTool == tool ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(sketchVM.selectedTool == tool ? AppTheme.Colors.accentDim.opacity(0.3) : Color.clear)
                        .cornerRadius(AppTheme.CornerRadius.sm)
                }
                .accessibilityIdentifier("sketch_tool_\(tool.rawValue)")
            }

            Rectangle()
                .fill(AppTheme.Colors.border)
                .frame(width: 1, height: 24)

            // Finish
            Button(action: onFinish) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Colors.success)
            }
            .accessibilityIdentifier("sketch_finish")

            // Cancel
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Colors.error)
            }
            .accessibilityIdentifier("sketch_cancel")
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.background.opacity(0.92))
        .cornerRadius(AppTheme.CornerRadius.lg)
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        .padding(.top, 60)

        // Extrude prompt after finishing sketch
        if sketchVM.showExtrudePrompt {
            ExtrudePromptView(sketchVM: sketchVM)
        }
    }
}

/// Modal prompt for extrude depth after finishing a sketch.
struct ExtrudePromptView: View {
    @ObservedObject var sketchVM: SketchViewModel

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Text("Extrude Sketch")
                .font(AppTheme.Typography.heading)
                .foregroundColor(AppTheme.Colors.textPrimary)

            HStack(spacing: AppTheme.Spacing.sm) {
                Text("Depth")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                TextField("Depth", value: $sketchVM.extrudeDepth, format: .number)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs + 2)
                    .background(AppTheme.Colors.surfaceElevated)
                    .cornerRadius(AppTheme.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                            .stroke(AppTheme.Colors.border, lineWidth: 0.5)
                    )
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("extrude_prompt_depth")

                Text("mm")
                    .font(AppTheme.Typography.small)
                    .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.6))
            }

            HStack(spacing: AppTheme.Spacing.md) {
                Button("Extrude (Add)") {
                    sketchVM.pendingOperation = .additive
                    sketchVM.showExtrudePrompt = false
                }
                .font(AppTheme.Typography.captionBold)
                .foregroundColor(.white)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.Colors.accent)
                .cornerRadius(AppTheme.CornerRadius.md)
                .accessibilityIdentifier("extrude_prompt_add")

                Button("Cut") {
                    sketchVM.pendingOperation = .subtractive
                    sketchVM.showExtrudePrompt = false
                }
                .font(AppTheme.Typography.captionBold)
                .foregroundColor(.white)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.Colors.error)
                .cornerRadius(AppTheme.CornerRadius.md)
                .accessibilityIdentifier("extrude_prompt_cut")

                Button("Cancel") {
                    sketchVM.showExtrudePrompt = false
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .accessibilityIdentifier("extrude_prompt_cancel")
            }
        }
        .padding(AppTheme.Spacing.xl)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .stroke(AppTheme.Colors.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
        .padding(.horizontal, 40)
    }
}
