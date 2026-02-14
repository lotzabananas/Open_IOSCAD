import SwiftUI
import UniformTypeIdentifiers

struct ExportSheet: View {
    @ObservedObject var viewModel: ModelViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {
                    // 3D Formats
                    exportSection(title: "3D FORMATS") {
                        let columns = [
                            GridItem(.flexible(), spacing: AppTheme.Spacing.md),
                            GridItem(.flexible(), spacing: AppTheme.Spacing.md)
                        ]

                        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
                            exportCard(
                                icon: "doc.badge.gearshape",
                                name: "STL",
                                detail: "Binary mesh",
                                identifier: "menu_export_stl",
                                action: exportSTL
                            )

                            exportCard(
                                icon: "cube",
                                name: "3MF",
                                detail: "3D Manufacturing",
                                identifier: "menu_export_3mf",
                                action: export3MF
                            )
                        }
                    }

                    // Script Formats
                    exportSection(title: "SCRIPT") {
                        let columns = [
                            GridItem(.flexible(), spacing: AppTheme.Spacing.md),
                            GridItem(.flexible(), spacing: AppTheme.Spacing.md)
                        ]

                        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
                            exportCard(
                                icon: "doc.text",
                                name: "OpenSCAD",
                                detail: ".scad script",
                                identifier: "menu_export_scad",
                                action: exportSCAD
                            )

                            exportCard(
                                icon: "chevron.left.forwardslash.chevron.right",
                                name: "CadQuery",
                                detail: ".py script",
                                identifier: "menu_export_cadquery",
                                action: exportCadQuery
                            )
                        }
                    }

                    // 2D Drawings
                    exportSection(title: "2D DRAWINGS") {
                        let columns = [
                            GridItem(.flexible(), spacing: AppTheme.Spacing.md),
                            GridItem(.flexible(), spacing: AppTheme.Spacing.md)
                        ]

                        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
                            exportCard(
                                icon: "square.and.pencil",
                                name: "DXF",
                                detail: "AutoCAD drawing",
                                identifier: "menu_export_dxf",
                                action: exportDXF
                            )

                            exportCard(
                                icon: "doc.richtext",
                                name: "PDF",
                                detail: "Drawing sheet",
                                identifier: "menu_export_pdf",
                                action: exportPDF
                            )
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.Colors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Export Section

    private func exportSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Typography.captionBold)
                .foregroundColor(AppTheme.Colors.textSecondary)

            content()
        }
    }

    // MARK: - Export Card

    private func exportCard(icon: String, name: String, detail: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.Colors.accent)

                VStack(spacing: 2) {
                    Text(name)
                        .font(AppTheme.Typography.captionBold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text(detail)
                        .font(AppTheme.Typography.small)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.lg)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(AppTheme.Colors.border, lineWidth: 0.5)
            )
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Export Functions

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
