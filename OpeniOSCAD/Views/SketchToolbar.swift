import SwiftUI

/// Drawing tool palette for sketch mode.
struct SketchToolbar: View {
    @ObservedObject var sketchVM: SketchViewModel
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Tool selection
            ForEach(SketchTool.allCases, id: \.self) { tool in
                Button(action: { sketchVM.selectedTool = tool }) {
                    VStack(spacing: 2) {
                        Image(systemName: tool.iconName)
                            .font(.title3)
                        Text(tool.displayName)
                            .font(.caption2)
                    }
                    .foregroundColor(sketchVM.selectedTool == tool ? .blue : .primary)
                }
                .accessibilityIdentifier("sketch_tool_\(tool.rawValue)")
            }

            Divider().frame(height: 30)

            // Finish
            Button(action: onFinish) {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Finish")
                        .font(.caption2)
                }
                .foregroundColor(.green)
            }
            .accessibilityIdentifier("sketch_finish")

            // Cancel
            Button(action: onCancel) {
                VStack(spacing: 2) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                    Text("Cancel")
                        .font(.caption2)
                }
                .foregroundColor(.red)
            }
            .accessibilityIdentifier("sketch_cancel")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
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
        VStack(spacing: 12) {
            Text("Extrude Sketch")
                .font(.headline)

            HStack {
                Text("Depth")
                TextField("Depth", value: $sketchVM.extrudeDepth, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("extrude_prompt_depth")
                Text("mm")
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                Button("Extrude (Add)") {
                    sketchVM.pendingOperation = .additive
                    sketchVM.showExtrudePrompt = false
                }
                .accessibilityIdentifier("extrude_prompt_add")

                Button("Cut") {
                    sketchVM.pendingOperation = .subtractive
                    sketchVM.showExtrudePrompt = false
                }
                .accessibilityIdentifier("extrude_prompt_cut")

                Button("Cancel") {
                    sketchVM.showExtrudePrompt = false
                }
                .foregroundColor(.red)
                .accessibilityIdentifier("extrude_prompt_cancel")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 40)
    }
}
