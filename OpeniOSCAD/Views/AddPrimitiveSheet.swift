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
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Shapes
                    sectionHeader("SHAPES")
                    shapesSection

                    // Operations
                    sectionHeader("OPERATIONS")
                    operationsSection

                    // Assembly
                    sectionHeader("ASSEMBLY")
                    assemblySection

                    // AI Generate
                    sectionHeader("AI GENERATE")
                    aiSection

                    // Sketch
                    sectionHeader("SKETCH")
                    sketchSection
                }
                .padding(AppTheme.Spacing.lg)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Add Shape")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.Colors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .accessibilityIdentifier("add_shape_cancel")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.captionBold)
                .foregroundColor(AppTheme.Colors.textSecondary)
            Spacer()
        }
    }

    // MARK: - Shapes Section

    private var shapesSection: some View {
        VStack(spacing: 1) {
            // Box
            expandableCard(
                icon: "cube.fill",
                name: "Box",
                color: AppTheme.Colors.featureSolid,
                sectionKey: "box",
                identifier: "add_box_section"
            ) {
                paramField("Width", value: $boxWidth, identifier: "box_width")
                paramField("Depth", value: $boxDepth, identifier: "box_depth")
                paramField("Height", value: $boxHeight, identifier: "box_height")
                confirmButton("Add Box", identifier: "add_box_confirm") {
                    viewModel.addBox(width: boxWidth, depth: boxDepth, height: boxHeight)
                    dismiss()
                }
            }

            // Cylinder
            expandableCard(
                icon: "cylinder.fill",
                name: "Cylinder",
                color: AppTheme.Colors.featureSolid,
                sectionKey: "cylinder",
                identifier: "add_cylinder_section"
            ) {
                paramField("Radius", value: $cylRadius, identifier: "cyl_radius")
                paramField("Height", value: $cylHeight, identifier: "cyl_height")
                confirmButton("Add Cylinder", identifier: "add_cylinder_confirm") {
                    viewModel.addCylinder(radius: cylRadius, height: cylHeight)
                    dismiss()
                }
            }

            // Sphere
            expandableCard(
                icon: "globe",
                name: "Sphere",
                color: AppTheme.Colors.featureSolid,
                sectionKey: "sphere",
                identifier: "add_sphere_section"
            ) {
                paramField("Radius", value: $sphereRadius, identifier: "sphere_radius")
                confirmButton("Add Sphere", identifier: "add_sphere_confirm") {
                    viewModel.addSphere(radius: sphereRadius)
                    dismiss()
                }
            }

            // Torus
            expandableCard(
                icon: "circle.circle",
                name: "Torus",
                color: AppTheme.Colors.featureSolid,
                sectionKey: "torus",
                identifier: "add_torus_section"
            ) {
                paramField("Major R", value: $torusMajorRadius, identifier: "torus_major_radius")
                paramField("Minor R", value: $torusMinorRadius, identifier: "torus_minor_radius")
                confirmButton("Add Torus", identifier: "add_torus_confirm") {
                    viewModel.addTorus(majorRadius: torusMajorRadius, minorRadius: torusMinorRadius)
                    dismiss()
                }
            }

            // Hole (cut)
            expandableCard(
                icon: "circle.dashed",
                name: "Hole (Cut)",
                color: AppTheme.Colors.error,
                sectionKey: "hole",
                identifier: "add_hole_section"
            ) {
                paramField("Radius", value: $holeRadius, identifier: "hole_radius")
                paramField("Depth", value: $holeDepth, identifier: "hole_depth")
                confirmButton("Add Hole", identifier: "add_hole_confirm") {
                    viewModel.addHole(radius: holeRadius, depth: holeDepth)
                    dismiss()
                }
            }
        }
        .cornerRadius(AppTheme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                .stroke(AppTheme.Colors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Operations Section

    private var operationsSection: some View {
        VStack(spacing: 1) {
            // Fillet
            expandableCard(
                icon: "circle.bottomhalf.filled",
                name: "Fillet",
                color: AppTheme.Colors.featureModifier,
                sectionKey: "fillet",
                identifier: "add_fillet_section"
            ) {
                paramField("Radius", value: $filletRadius, identifier: "fillet_add_radius")
                confirmButton("Add Fillet", identifier: "add_fillet_confirm") {
                    viewModel.addFillet(radius: filletRadius)
                    dismiss()
                }
            }

            // Chamfer
            expandableCard(
                icon: "triangle",
                name: "Chamfer",
                color: AppTheme.Colors.featureModifier,
                sectionKey: "chamfer",
                identifier: "add_chamfer_section"
            ) {
                paramField("Distance", value: $chamferDistance, identifier: "chamfer_add_distance")
                confirmButton("Add Chamfer", identifier: "add_chamfer_confirm") {
                    viewModel.addChamfer(distance: chamferDistance)
                    dismiss()
                }
            }

            // Shell
            expandableCard(
                icon: "cube.transparent",
                name: "Shell",
                color: AppTheme.Colors.featureModifier,
                sectionKey: "shell",
                identifier: "add_shell_section"
            ) {
                paramField("Thickness", value: $shellThickness, identifier: "shell_add_thickness")
                confirmButton("Add Shell", identifier: "add_shell_confirm") {
                    viewModel.addShell(thickness: shellThickness)
                    dismiss()
                }
            }

            // Linear Pattern
            expandableCard(
                icon: "square.grid.3x1.below.line.grid.1x2",
                name: "Linear Pattern",
                color: AppTheme.Colors.featurePattern,
                sectionKey: "linear_pattern",
                identifier: "add_linear_pattern_section"
            ) {
                paramField("Count", value: $patternCount, identifier: "pattern_add_count")
                paramField("Spacing", value: $patternSpacing, identifier: "pattern_add_spacing")
                confirmButton("Add Linear Pattern", identifier: "add_linear_pattern_confirm") {
                    viewModel.addLinearPattern(count: Int(patternCount), spacing: patternSpacing)
                    dismiss()
                }
            }

            // Circular Pattern
            actionCard(
                icon: "circle.grid.2x2",
                name: "Circular Pattern",
                color: AppTheme.Colors.featurePattern,
                identifier: "add_circular_pattern"
            ) {
                viewModel.addCircularPattern()
                dismiss()
            }

            // Mirror
            actionCard(
                icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                name: "Mirror",
                color: AppTheme.Colors.featurePattern,
                identifier: "add_mirror_pattern"
            ) {
                viewModel.addMirrorPattern()
                dismiss()
            }
        }
        .cornerRadius(AppTheme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                .stroke(AppTheme.Colors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Assembly Section

    private var assemblySection: some View {
        actionCard(
            icon: "square.3.layers.3d",
            name: "New Body Group",
            color: AppTheme.Colors.featureAssembly,
            identifier: "add_assembly"
        ) {
            viewModel.addAssembly()
            dismiss()
        }
        .cornerRadius(AppTheme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                .stroke(AppTheme.Colors.border, lineWidth: 0.5)
        )
    }

    // MARK: - AI Section

    private var aiSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            TextField("Describe what to create...", text: $aiPrompt)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surfaceElevated)
                .cornerRadius(AppTheme.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .stroke(AppTheme.Colors.border, lineWidth: 0.5)
                )
                .accessibilityIdentifier("ai_prompt_field")

            Button(action: {
                if let description = viewModel.generateFromPrompt(aiPrompt) {
                    aiResult = description
                    dismiss()
                } else {
                    aiResult = "Could not understand prompt. Try: 'box 30x20x10' or 'cylinder radius 5 height 20'"
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate")
                }
                .font(AppTheme.Typography.body)
                .foregroundColor(aiPrompt.isEmpty ? AppTheme.Colors.textSecondary.opacity(0.3) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(aiPrompt.isEmpty ? AppTheme.Colors.surfaceElevated : AppTheme.Colors.accent)
                .cornerRadius(AppTheme.CornerRadius.md)
            }
            .disabled(aiPrompt.isEmpty)
            .accessibilityIdentifier("ai_generate_button")

            if let result = aiResult {
                Text(result)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                .stroke(AppTheme.Colors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Sketch Section

    private var sketchSection: some View {
        VStack(spacing: 1) {
            actionCard(icon: "pencil.and.outline", name: "New Sketch on XY", color: AppTheme.Colors.featureSketch, identifier: "new_sketch_xy") {
                viewModel.isInSketchMode = true
                viewModel.sketchPlane = .xy
                dismiss()
            }

            actionCard(icon: "pencil.and.outline", name: "New Sketch on XZ", color: AppTheme.Colors.featureSketch, identifier: "new_sketch_xz") {
                viewModel.isInSketchMode = true
                viewModel.sketchPlane = .xz
                dismiss()
            }

            actionCard(icon: "pencil.and.outline", name: "New Sketch on YZ", color: AppTheme.Colors.featureSketch, identifier: "new_sketch_yz") {
                viewModel.isInSketchMode = true
                viewModel.sketchPlane = .yz
                dismiss()
            }
        }
        .cornerRadius(AppTheme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                .stroke(AppTheme.Colors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Reusable Components

    private func expandableCard<Content: View>(
        icon: String,
        name: String,
        color: Color,
        sectionKey: String,
        identifier: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedSection = expandedSection == sectionKey ? nil : sectionKey
                }
            }) {
                HStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                        .frame(width: 28)

                    Text(name)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Spacer()

                    Image(systemName: expandedSection == sectionKey ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface)
            }
            .accessibilityIdentifier(identifier)

            if expandedSection == sectionKey {
                VStack(spacing: AppTheme.Spacing.sm) {
                    content()
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface.opacity(0.8))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func actionCard(
        icon: String,
        name: String,
        color: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 28)

                Text(name)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
        }
        .accessibilityIdentifier(identifier)
    }

    private func confirmButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.captionBold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.Colors.accent)
                .cornerRadius(AppTheme.CornerRadius.md)
        }
        .accessibilityIdentifier(identifier)
    }

    private func paramField(_ label: String, value: Binding<Double>, identifier: String) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(width: 80, alignment: .leading)
            TextField(label, value: value, format: .number)
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
                .accessibilityIdentifier(identifier)
            Text("mm")
                .font(AppTheme.Typography.small)
                .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.6))
        }
    }
}
