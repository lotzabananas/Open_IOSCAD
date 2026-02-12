import SwiftUI
import UniformTypeIdentifiers

struct ExportSheet: View {
    @ObservedObject var viewModel: ModelViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Button(action: exportSTL) {
                    Label("STL (Binary)", systemImage: "doc.badge.gearshape")
                }
                .accessibilityIdentifier("menu_export_stl")

                Button(action: export3MF) {
                    Label("3MF", systemImage: "cube")
                }
                .accessibilityIdentifier("menu_export_3mf")
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func exportSTL() {
        guard let data = viewModel.exportSTL() else { return }
        shareData(data, filename: "model.stl", contentType: .data)
    }

    private func export3MF() {
        guard let data = viewModel.export3MF() else { return }
        shareData(data, filename: "model.3mf", contentType: .data)
    }

    private func shareData(_ data: Data, filename: String, contentType: UTType) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        dismiss()
        viewModel.showExportSuccess = true
    }
}
