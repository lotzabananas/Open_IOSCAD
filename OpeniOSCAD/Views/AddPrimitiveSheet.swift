import SwiftUI

struct AddPrimitiveSheet: View {
    @ObservedObject var viewModel: ModelViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("3D Primitives") {
                    Button(action: { addAndDismiss("Cube") }) {
                        Label("Cube", systemImage: "cube")
                    }

                    Button(action: { addAndDismiss("Cylinder") }) {
                        Label("Cylinder", systemImage: "cylinder")
                    }

                    Button(action: { addAndDismiss("Sphere") }) {
                        Label("Sphere", systemImage: "circle")
                    }
                }

                Section("Operations") {
                    Button(action: { addBooleanAndDismiss("difference") }) {
                        Label("Difference", systemImage: "minus.square")
                    }

                    Button(action: { addBooleanAndDismiss("union") }) {
                        Label("Union", systemImage: "plus.square")
                    }

                    Button(action: { addBooleanAndDismiss("intersection") }) {
                        Label("Intersection", systemImage: "square.on.square")
                    }
                }
            }
            .navigationTitle("Add Primitive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addAndDismiss(_ type: String) {
        viewModel.addPrimitive(type)
        dismiss()
    }

    private func addBooleanAndDismiss(_ op: String) {
        viewModel.addBooleanOp(op)
        dismiss()
    }
}
