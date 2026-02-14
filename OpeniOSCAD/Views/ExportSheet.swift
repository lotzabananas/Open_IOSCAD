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

                Button(action: exportSCAD) {
                    Label("OpenSCAD (.scad)", systemImage: "doc.text")
                }
                .accessibilityIdentifier("menu_export_scad")

                Button(action: exportCadQuery) {
                    Label("CadQuery (.py)", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .accessibilityIdentifier("menu_export_cadquery")

                Section("2D Drawings") {
                    Button(action: exportDXF) {
                        Label("DXF (AutoCAD)", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("menu_export_dxf")

                    Button(action: exportPDF) {
                        Label("PDF Drawing", systemImage: "doc.richtext")
                    }
                    .accessibilityIdentifier("menu_export_pdf")
                }
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

    private func exportSCAD() {
        guard let data = viewModel.exportSCAD() else { return }
        shareData(data, filename: "model.scad", contentType: .plainText)
    }

    private func exportCadQuery() {
        guard let data = viewModel.exportCadQuery() else { return }
        shareData(data, filename: "model.py", contentType: .pythonScript)
    }

    private func exportDXF() {
        guard let data = viewModel.exportDXF() else { return }
        shareData(data, filename: "drawing.dxf", contentType: .data)
    }

    private func exportPDF() {
        guard let data = viewModel.exportPDF() else { return }
        shareData(data, filename: "drawing.pdf", contentType: .pdf)
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
