import SwiftUI

struct ScriptEditorView: View {
    @Binding var text: String
    var onCommit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Script Editor")
                    .font(.headline)
                Spacer()
                Button(action: onCommit) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.green)
                }
                .accessibilityIdentifier("script_run_button")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isFocused)
                .accessibilityIdentifier("script_editor_view")
                .onChange(of: text) { _ in
                    // Debounced rebuild handled by ViewModel
                }
        }
        .background(Color(.systemBackground))
    }
}
