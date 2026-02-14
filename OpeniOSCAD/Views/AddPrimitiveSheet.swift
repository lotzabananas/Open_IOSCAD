import SwiftUI

/// Sheet for adding shapes via convenience commands.
/// Behind the scenes, these create sketch + extrude/revolve features.
struct AddShapeSheet: View {
    @ObservedObject var viewModel: ModelViewModel
    @Environment(\.dismiss) var dismiss

    @State private var boxWidth: Double = 20
    @State private var boxDepth: Double = 20
    @State private var boxHeight: Double = 20
    @State private var cylRadius: Double = 10
    @State private var cylHeight: Double = 20
    @State private var sphereRadius: Double = 10
    @State private var torusMajorRadius: Double = 15
    @State private var torusMinorRadius: Double = 5
    @State private var holeRadius: Double = 5
    @State private var holeDepth: Double = 100

    // Phase 3 parameters
    @State private var filletRadius: Double = 2.0
    @State private var chamferDistance: Double = 1.0
    @State private var shellThickness: Double = 1.0
    @State private var patternCount: Double = 3
    @State private var patternSpacing: Double = 20.0

    // AI prompt
    @State private var aiPrompt: String = ""
    @State private var aiResult: String?

    @State private var expandedSection: String?

    var body: some View {
        NavigationView {
            List {
                Section("Shapes") {
                    // Box
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSection == "box" },
                            set: { expandedSection = $0 ? "box" : nil }
                        )
                    ) {
                        paramField("Width", value: $boxWidth, identifier: "box_width")
                        paramField("Depth", value: $boxDepth, identifier: "box_depth")
                        paramField("Height", value: $boxHeight, identifier: "box_height")
                        Button("Add Box") {
                            viewModel.addBox(width: boxWidth, depth: boxDepth, height: boxHeight)
                            dismiss()
                        }
                        .accessibilityIdentifier("add_box_confirm")
                    } label: {
                        Label("Box", systemImage: "cube")
                    }
                    .accessibilityIdentifier("add_box_section")

                    // Cylinder
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSection == "cylinder" },
                            set: { expandedSection = $0 ? "cylinder" : nil }
                        )
                    ) {
                        paramField("Radius", value: $cylRadius, identifier: "cyl_radius")
                        paramField("Height", value: $cylHeight, identifier: "cyl_height")
                        Button("Add Cylinder") {
                            viewModel.addCylinder(radius: cylRadius, height: cylHeight)
                            dismiss()
                        }
                        .accessibilityIdentifier("add_cylinder_confirm")
                    } label: {
                        Label("Cylinder", systemImage: "cylinder")
                    }
                    .accessibilityIdentifier("add_cylinder_section")

                    // Sphere
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSection == "sphere" },
                            set: { expandedSection = $0 ? "sphere" : nil }
                        )
                    ) {
                        paramField("Radius", value: $sphereRadius, identifier: "sphere_radius")
                        Button("Add Sphere") {
                            viewModel.addSphere(radius: sphereRadius)
                            dismiss()
                        }
                        .accessibilityIdentifier("add_sphere_confirm")
                    } label: {
                        Label("Sphere", systemImage: "globe")
                    }
                    .accessibilityIdentifier("add_sphere_section")

                    // Torus
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSection == "torus" },
                            set: { expandedSection = $0 ? "torus" : nil }
                        )
                    ) {
                        paramField("Major R", value: $torusMajorRadius, identifier: "torus_major_radius")
                        paramField("Minor R", value: $torusMinorRadius, identifier: "torus_minor_radius")
                        Button("Add Torus") {
                            viewModel.addTorus(majorRadius: torusMajorRadius, minorRadius: torusMinorRadius)
                            dismiss()
                        }
                        .accessibilityIdentifier("add_torus_confirm")
                    } label: {
                        Label("Torus", systemImage: "circle.circle")
                    }
                    .accessibilityIdentifier("add_torus_section")

                    // Hole (cut)
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSection == "hole" },
                            set: { expandedSection = $0 ? "hole" : nil }
                        )
                    ) {
                        paramField("Radius", value: $holeRadius, identifier: "hole_radius")
                        paramField("Depth", value: $holeDepth, identifier: "hole_depth")
                        Button("Add Hole (Cut)") {
                            viewModel.addHole(radius: holeRadius, depth: holeDepth)
                            dismiss()
                        }
                        .accessibilityIdentifier("add_hole_confirm")
                    } label: {
                        Label("Hole", systemImage: "circle.dashed")
                    }
                    .accessibilityIdentifier("add_hole_section")
                }

                Section("Operations") {
                    // Fillet
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSection == "fillet" },
                            set: { expandedSection = $0 ? "fillet" : nil }
                        )
                    ) {
                        paramField("Radius", value: $filletRadius, identifier: "fillet_add_radius")
                        Button("Add Fillet") {
                            viewModel.addFillet(radius: filletRadius)
                            dismiss()
                        }
                        .accessibilityIdentifier("add_fillet_confirm")
                    } label: {
                        Label("Fillet", systemImage: "circle.bottomhalf.filled")
                    }
                    .accessibilityIdentifier("add_fillet_section")

                    // Chamfer
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSection == "chamfer" },
                            set: { expandedSection = $0 ? "chamfer" : nil }
                        )
                    ) {
                        paramField("Distance", value: $chamferDistance, identifier: "chamfer_add_distance")
                        Button("Add Chamfer") {
                            viewModel.addChamfer(distance: chamferDistance)
                            dismiss()
                        }
                        .accessibilityIdentifier("add_chamfer_confirm")
                    } label: {
                        Label("Chamfer", systemImage: "triangle")
                    }
                    .accessibilityIdentifier("add_chamfer_section")

                    // Shell
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSection == "shell" },
                            set: { expandedSection = $0 ? "shell" : nil }
                        )
                    ) {
                        paramField("Thickness", value: $shellThickness, identifier: "shell_add_thickness")
                        Button("Add Shell") {
                            viewModel.addShell(thickness: shellThickness)
                            dismiss()
                        }
                        .accessibilityIdentifier("add_shell_confirm")
                    } label: {
                        Label("Shell", systemImage: "cube.transparent")
                    }
                    .accessibilityIdentifier("add_shell_section")

                    // Linear Pattern
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSection == "linear_pattern" },
                            set: { expandedSection = $0 ? "linear_pattern" : nil }
                        )
                    ) {
                        paramField("Count", value: $patternCount, identifier: "pattern_add_count")
                        paramField("Spacing", value: $patternSpacing, identifier: "pattern_add_spacing")
                        Button("Add Linear Pattern") {
                            viewModel.addLinearPattern(count: Int(patternCount), spacing: patternSpacing)
                            dismiss()
                        }
                        .accessibilityIdentifier("add_linear_pattern_confirm")
                    } label: {
                        Label("Linear Pattern", systemImage: "square.grid.3x1.below.line.grid.1x2")
                    }
                    .accessibilityIdentifier("add_linear_pattern_section")

                    // Circular Pattern
                    Button(action: {
                        viewModel.addCircularPattern()
                        dismiss()
                    }) {
                        Label("Circular Pattern", systemImage: "circle.grid.2x2")
                    }
                    .accessibilityIdentifier("add_circular_pattern")

                    // Mirror
                    Button(action: {
                        viewModel.addMirrorPattern()
                        dismiss()
                    }) {
                        Label("Mirror", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    }
                    .accessibilityIdentifier("add_mirror_pattern")
                }

                Section("Assembly") {
                    Button(action: {
                        viewModel.addAssembly()
                        dismiss()
                    }) {
                        Label("New Body Group", systemImage: "square.3.layers.3d")
                    }
                    .accessibilityIdentifier("add_assembly")
                }

                Section("AI Generate") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Describe what to create...", text: $aiPrompt)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("ai_prompt_field")

                        Button("Generate") {
                            if let description = viewModel.generateFromPrompt(aiPrompt) {
                                aiResult = description
                                dismiss()
                            } else {
                                aiResult = "Could not understand prompt. Try: 'box 30x20x10' or 'cylinder radius 5 height 20'"
                            }
                        }
                        .disabled(aiPrompt.isEmpty)
                        .accessibilityIdentifier("ai_generate_button")

                        if let result = aiResult {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Sketch") {
                    Button(action: {
                        viewModel.isInSketchMode = true
                        viewModel.sketchPlane = .xy
                        dismiss()
                    }) {
                        Label("New Sketch on XY", systemImage: "pencil.and.outline")
                    }
                    .accessibilityIdentifier("new_sketch_xy")

                    Button(action: {
                        viewModel.isInSketchMode = true
                        viewModel.sketchPlane = .xz
                        dismiss()
                    }) {
                        Label("New Sketch on XZ", systemImage: "pencil.and.outline")
                    }
                    .accessibilityIdentifier("new_sketch_xz")

                    Button(action: {
                        viewModel.isInSketchMode = true
                        viewModel.sketchPlane = .yz
                        dismiss()
                    }) {
                        Label("New Sketch on YZ", systemImage: "pencil.and.outline")
                    }
                    .accessibilityIdentifier("new_sketch_yz")
                }
            }
            .navigationTitle("Add Shape")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("add_shape_cancel")
                }
            }
        }
    }

    private func paramField(_ label: String, value: Binding<Double>, identifier: String) -> some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            TextField(label, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier(identifier)
            Text("mm")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}
