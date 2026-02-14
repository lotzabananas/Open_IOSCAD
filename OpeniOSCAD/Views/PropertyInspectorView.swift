import SwiftUI
import ParametricEngine

/// Property inspector panel that appears when a feature is selected.
/// Displays editable parameters for the selected feature.
struct PropertyInspectorView: View {
    let feature: AnyFeature
    let onUpdate: (AnyFeature) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with feature icon and name
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: iconForFeature(feature))
                    .foregroundColor(AppTheme.colorForFeatureKind(feature.kind))
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 1) {
                    Text(feature.name)
                        .font(AppTheme.Typography.heading)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text(feature.kind.rawValue.capitalized)
                        .font(AppTheme.Typography.small)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.Colors.surfaceElevated)
                        .cornerRadius(AppTheme.CornerRadius.sm)
                }
                .accessibilityIdentifier("property_inspector_dismiss")
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)

            Rectangle()
                .fill(AppTheme.Colors.border)
                .frame(height: 1)

            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    switch feature {
                    case .sketch(let sketch):
                        SketchInspector(sketch: sketch, onUpdate: { updated in
                            onUpdate(.sketch(updated))
                        })
                    case .extrude(let extrude):
                        ExtrudeInspector(extrude: extrude, onUpdate: { updated in
                            onUpdate(.extrude(updated))
                        })
                    case .revolve(let revolve):
                        RevolveInspector(revolve: revolve, onUpdate: { updated in
                            onUpdate(.revolve(updated))
                        })
                    case .boolean(let boolean):
                        BooleanInspector(boolean: boolean, onUpdate: { updated in
                            onUpdate(.boolean(updated))
                        })
                    case .transform(let transform):
                        TransformInspector(transform: transform, onUpdate: { updated in
                            onUpdate(.transform(updated))
                        })
                    case .fillet(let fillet):
                        FilletInspector(fillet: fillet, onUpdate: { updated in
                            onUpdate(.fillet(updated))
                        })
                    case .chamfer(let chamfer):
                        ChamferInspector(chamfer: chamfer, onUpdate: { updated in
                            onUpdate(.chamfer(updated))
                        })
                    case .shell(let shell):
                        ShellInspector(shell: shell, onUpdate: { updated in
                            onUpdate(.shell(updated))
                        })
                    case .pattern(let pattern):
                        PatternInspector(pattern: pattern, onUpdate: { updated in
                            onUpdate(.pattern(updated))
                        })
                    case .sweep(let sweep):
                        SweepInspector(sweep: sweep, onUpdate: { updated in
                            onUpdate(.sweep(updated))
                        })
                    case .loft(let loft):
                        LoftInspector(loft: loft, onUpdate: { updated in
                            onUpdate(.loft(updated))
                        })
                    case .assembly(let assembly):
                        AssemblyInspector(assembly: assembly, onUpdate: { updated in
                            onUpdate(.assembly(updated))
                        })
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
        }
        .background(AppTheme.Colors.background)
    }

    private func iconForFeature(_ f: AnyFeature) -> String {
        switch f {
        case .sketch: return "pencil.and.outline"
        case .extrude: return "arrow.up.to.line"
        case .revolve: return "arrow.triangle.2.circlepath"
        case .boolean: return "square.on.square"
        case .transform: return "arrow.up.and.down.and.arrow.left.and.right"
        case .fillet: return "circle.bottomhalf.filled"
        case .chamfer: return "triangle"
        case .shell: return "cube.transparent"
        case .pattern: return "square.grid.3x1.below.line.grid.1x2"
        case .sweep: return "point.topleft.down.to.point.bottomright.curvepath"
        case .loft: return "trapezoid.and.line.vertical"
        case .assembly: return "square.3.layers.3d"
        }
    }
}

// MARK: - Inspector Section Container

private struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Typography.captionBold)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: AppTheme.Spacing.sm) {
                content()
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(AppTheme.Colors.border, lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Sketch Inspector

private struct SketchInspector: View {
    let sketch: SketchFeature
    let onUpdate: (SketchFeature) -> Void

    var body: some View {
        InspectorSection(title: "Sketch") {
            HStack {
                Text("Plane")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Spacer()
                Text(sketch.plane.displayName)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
        }

        ForEach(Array(sketch.elements.enumerated()), id: \.element.id) { index, element in
            elementEditor(element, at: index)
        }

        if !sketch.constraints.isEmpty {
            InspectorSection(title: "Constraints") {
                ConstraintListView(constraints: sketch.constraints)
            }
        }
    }

    @ViewBuilder
    private func elementEditor(_ element: SketchElement, at index: Int) -> some View {
        switch element {
        case .rectangle(let id, let origin, let width, let height):
            InspectorSection(title: "Rectangle") {
                NumericField("Width", value: width, unit: "mm", identifier: "sketch_rect_width") { newVal in
                    var updated = sketch
                    updated.elements[index] = .rectangle(id: id, origin: origin, width: newVal, height: height)
                    onUpdate(updated)
                }
                NumericField("Height", value: height, unit: "mm", identifier: "sketch_rect_height") { newVal in
                    var updated = sketch
                    updated.elements[index] = .rectangle(id: id, origin: origin, width: width, height: newVal)
                    onUpdate(updated)
                }
                NumericField("Origin X", value: origin.x, unit: "mm", identifier: "sketch_rect_ox") { newVal in
                    var updated = sketch
                    updated.elements[index] = .rectangle(id: id, origin: Point2D(x: newVal, y: origin.y), width: width, height: height)
                    onUpdate(updated)
                }
                NumericField("Origin Y", value: origin.y, unit: "mm", identifier: "sketch_rect_oy") { newVal in
                    var updated = sketch
                    updated.elements[index] = .rectangle(id: id, origin: Point2D(x: origin.x, y: newVal), width: width, height: height)
                    onUpdate(updated)
                }
            }

        case .circle(let id, let center, let radius):
            InspectorSection(title: "Circle") {
                NumericField("Radius", value: radius, unit: "mm", identifier: "sketch_circle_radius") { newVal in
                    var updated = sketch
                    updated.elements[index] = .circle(id: id, center: center, radius: newVal)
                    onUpdate(updated)
                }
                NumericField("Center X", value: center.x, unit: "mm", identifier: "sketch_circle_cx") { newVal in
                    var updated = sketch
                    updated.elements[index] = .circle(id: id, center: Point2D(x: newVal, y: center.y), radius: radius)
                    onUpdate(updated)
                }
                NumericField("Center Y", value: center.y, unit: "mm", identifier: "sketch_circle_cy") { newVal in
                    var updated = sketch
                    updated.elements[index] = .circle(id: id, center: Point2D(x: center.x, y: newVal), radius: radius)
                    onUpdate(updated)
                }
            }

        case .lineSegment(let id, let start, let end):
            InspectorSection(title: "Line Segment") {
                NumericField("Start X", value: start.x, unit: "mm", identifier: "sketch_line_sx") { newVal in
                    var updated = sketch
                    updated.elements[index] = .lineSegment(id: id, start: Point2D(x: newVal, y: start.y), end: end)
                    onUpdate(updated)
                }
                NumericField("Start Y", value: start.y, unit: "mm", identifier: "sketch_line_sy") { newVal in
                    var updated = sketch
                    updated.elements[index] = .lineSegment(id: id, start: Point2D(x: start.x, y: newVal), end: end)
                    onUpdate(updated)
                }
                NumericField("End X", value: end.x, unit: "mm", identifier: "sketch_line_ex") { newVal in
                    var updated = sketch
                    updated.elements[index] = .lineSegment(id: id, start: start, end: Point2D(x: newVal, y: end.y))
                    onUpdate(updated)
                }
                NumericField("End Y", value: end.y, unit: "mm", identifier: "sketch_line_ey") { newVal in
                    var updated = sketch
                    updated.elements[index] = .lineSegment(id: id, start: start, end: Point2D(x: end.x, y: newVal))
                    onUpdate(updated)
                }
            }

        case .arc(let id, let center, let radius, let startAngle, let sweepAngle):
            InspectorSection(title: "Arc") {
                NumericField("Radius", value: radius, unit: "mm", identifier: "sketch_arc_radius") { newVal in
                    var updated = sketch
                    updated.elements[index] = .arc(id: id, center: center, radius: newVal, startAngle: startAngle, sweepAngle: sweepAngle)
                    onUpdate(updated)
                }
                NumericField("Start", value: startAngle, unit: "\u{00B0}", identifier: "sketch_arc_start") { newVal in
                    var updated = sketch
                    updated.elements[index] = .arc(id: id, center: center, radius: radius, startAngle: newVal, sweepAngle: sweepAngle)
                    onUpdate(updated)
                }
                NumericField("Sweep", value: sweepAngle, unit: "\u{00B0}", identifier: "sketch_arc_sweep") { newVal in
                    var updated = sketch
                    updated.elements[index] = .arc(id: id, center: center, radius: radius, startAngle: startAngle, sweepAngle: newVal)
                    onUpdate(updated)
                }
                NumericField("Center X", value: center.x, unit: "mm", identifier: "sketch_arc_cx") { newVal in
                    var updated = sketch
                    updated.elements[index] = .arc(id: id, center: Point2D(x: newVal, y: center.y), radius: radius, startAngle: startAngle, sweepAngle: sweepAngle)
                    onUpdate(updated)
                }
                NumericField("Center Y", value: center.y, unit: "mm", identifier: "sketch_arc_cy") { newVal in
                    var updated = sketch
                    updated.elements[index] = .arc(id: id, center: Point2D(x: center.x, y: newVal), radius: radius, startAngle: startAngle, sweepAngle: sweepAngle)
                    onUpdate(updated)
                }
            }
        }
    }
}

// MARK: - Constraint List (in Sketch Inspector)

private struct ConstraintListView: View {
    let constraints: [SketchConstraint]

    var body: some View {
        ForEach(constraints) { constraint in
            HStack {
                Image(systemName: constraint.isDimensional ? "ruler" : "link")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text(constraint.typeName)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .accessibilityIdentifier("constraint_\(constraint.id.uuidString.prefix(8))")
        }
    }
}

// MARK: - Extrude Inspector

private struct ExtrudeInspector: View {
    let extrude: ExtrudeFeature
    let onUpdate: (ExtrudeFeature) -> Void

    var body: some View {
        InspectorSection(title: "Dimensions") {
            NumericField("Depth", value: extrude.depth, unit: "mm", identifier: "extrude_depth") { newVal in
                var updated = extrude
                updated.depth = newVal
                onUpdate(updated)
            }
        }

        InspectorSection(title: "Operation") {
            Picker("Operation", selection: Binding(
                get: { extrude.operation },
                set: { newOp in
                    var updated = extrude
                    updated.operation = newOp
                    onUpdate(updated)
                }
            )) {
                Text("Additive").tag(ExtrudeFeature.Operation.additive)
                Text("Subtractive").tag(ExtrudeFeature.Operation.subtractive)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("extrude_operation_picker")
        }
    }
}

// MARK: - Revolve Inspector

private struct RevolveInspector: View {
    let revolve: RevolveFeature
    let onUpdate: (RevolveFeature) -> Void

    var body: some View {
        InspectorSection(title: "Dimensions") {
            NumericField("Angle", value: revolve.angle, unit: "\u{00B0}", identifier: "revolve_angle") { newVal in
                var updated = revolve
                updated.angle = max(0.1, min(360.0, newVal))
                onUpdate(updated)
            }
        }

        InspectorSection(title: "Operation") {
            Picker("Operation", selection: Binding(
                get: { revolve.operation },
                set: { newOp in
                    var updated = revolve
                    updated.operation = newOp
                    onUpdate(updated)
                }
            )) {
                Text("Additive").tag(RevolveFeature.Operation.additive)
                Text("Subtractive").tag(RevolveFeature.Operation.subtractive)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("revolve_operation_picker")
        }
    }
}

// MARK: - Boolean Inspector

private struct BooleanInspector: View {
    let boolean: BooleanFeature
    let onUpdate: (BooleanFeature) -> Void

    var body: some View {
        InspectorSection(title: "Boolean Type") {
            Picker("Type", selection: Binding(
                get: { boolean.booleanType },
                set: { newType in
                    var updated = boolean
                    updated.booleanType = newType
                    onUpdate(updated)
                }
            )) {
                Text("Union").tag(BooleanFeature.BooleanOp.union)
                Text("Intersection").tag(BooleanFeature.BooleanOp.intersection)
                Text("Difference").tag(BooleanFeature.BooleanOp.difference)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("boolean_type_picker")
        }
    }
}

// MARK: - Transform Inspector

private struct TransformInspector: View {
    let transform: TransformFeature
    let onUpdate: (TransformFeature) -> Void

    var body: some View {
        InspectorSection(title: "Position") {
            NumericField("X", value: transform.vector.x, unit: "mm", identifier: "transform_x") { newVal in
                var updated = transform
                updated.vector.x = newVal
                onUpdate(updated)
            }
            NumericField("Y", value: transform.vector.y, unit: "mm", identifier: "transform_y") { newVal in
                var updated = transform
                updated.vector.y = newVal
                onUpdate(updated)
            }
            NumericField("Z", value: transform.vector.z, unit: "mm", identifier: "transform_z") { newVal in
                var updated = transform
                updated.vector.z = newVal
                onUpdate(updated)
            }
        }

        if transform.transformType == .rotate {
            InspectorSection(title: "Rotation") {
                NumericField("Angle", value: transform.angle, unit: "\u{00B0}", identifier: "transform_angle") { newVal in
                    var updated = transform
                    updated.angle = newVal
                    onUpdate(updated)
                }
            }
        }
    }
}

// MARK: - Fillet Inspector

private struct FilletInspector: View {
    let fillet: FilletFeature
    let onUpdate: (FilletFeature) -> Void

    var body: some View {
        InspectorSection(title: "Dimensions") {
            NumericField("Radius", value: fillet.radius, unit: "mm", identifier: "fillet_radius") { newVal in
                var updated = fillet
                updated.radius = max(0.1, newVal)
                onUpdate(updated)
            }
        }
    }
}

// MARK: - Chamfer Inspector

private struct ChamferInspector: View {
    let chamfer: ChamferFeature
    let onUpdate: (ChamferFeature) -> Void

    var body: some View {
        InspectorSection(title: "Dimensions") {
            NumericField("Distance", value: chamfer.distance, unit: "mm", identifier: "chamfer_distance") { newVal in
                var updated = chamfer
                updated.distance = max(0.1, newVal)
                onUpdate(updated)
            }
        }
    }
}

// MARK: - Shell Inspector

private struct ShellInspector: View {
    let shell: ShellFeature
    let onUpdate: (ShellFeature) -> Void

    var body: some View {
        InspectorSection(title: "Dimensions") {
            NumericField("Thickness", value: shell.thickness, unit: "mm", identifier: "shell_thickness") { newVal in
                var updated = shell
                updated.thickness = max(0.1, newVal)
                onUpdate(updated)
            }
        }
    }
}

// MARK: - Pattern Inspector

private struct PatternInspector: View {
    let pattern: PatternFeature
    let onUpdate: (PatternFeature) -> Void

    var body: some View {
        InspectorSection(title: "Pattern Type") {
            Picker("Type", selection: Binding(
                get: { pattern.patternType },
                set: { newType in
                    var updated = pattern
                    updated.patternType = newType
                    onUpdate(updated)
                }
            )) {
                Text("Linear").tag(PatternFeature.PatternKind.linear)
                Text("Circular").tag(PatternFeature.PatternKind.circular)
                Text("Mirror").tag(PatternFeature.PatternKind.mirror)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("pattern_type_picker")
        }

        if pattern.patternType != .mirror {
            InspectorSection(title: "Count") {
                NumericField("Count", value: Double(pattern.count), identifier: "pattern_count") { newVal in
                    var updated = pattern
                    updated.count = max(1, Int(newVal))
                    onUpdate(updated)
                }
            }
        }

        if pattern.patternType == .linear {
            InspectorSection(title: "Spacing & Direction") {
                NumericField("Spacing", value: pattern.spacing, unit: "mm", identifier: "pattern_spacing") { newVal in
                    var updated = pattern
                    updated.spacing = max(0.1, newVal)
                    onUpdate(updated)
                }
                NumericField("Dir X", value: pattern.directionX, identifier: "pattern_dir_x") { newVal in
                    var updated = pattern
                    updated.directionX = newVal
                    onUpdate(updated)
                }
                NumericField("Dir Y", value: pattern.directionY, identifier: "pattern_dir_y") { newVal in
                    var updated = pattern
                    updated.directionY = newVal
                    onUpdate(updated)
                }
                NumericField("Dir Z", value: pattern.directionZ, identifier: "pattern_dir_z") { newVal in
                    var updated = pattern
                    updated.directionZ = newVal
                    onUpdate(updated)
                }
            }
        }

        if pattern.patternType == .circular {
            InspectorSection(title: "Angle") {
                NumericField("Total Angle", value: pattern.totalAngle, unit: "\u{00B0}", identifier: "pattern_total_angle") { newVal in
                    var updated = pattern
                    updated.totalAngle = max(1, min(360, newVal))
                    onUpdate(updated)
                }
            }
        }
    }
}

// MARK: - Sweep Inspector

private struct SweepInspector: View {
    let sweep: SweepFeature
    let onUpdate: (SweepFeature) -> Void

    var body: some View {
        InspectorSection(title: "Parameters") {
            NumericField("Twist", value: sweep.twist, unit: "\u{00B0}", identifier: "sweep_twist") { newVal in
                var updated = sweep
                updated.twist = newVal
                onUpdate(updated)
            }
            NumericField("End Scale", value: sweep.scaleEnd, identifier: "sweep_scale_end") { newVal in
                var updated = sweep
                updated.scaleEnd = max(0.01, newVal)
                onUpdate(updated)
            }
        }

        InspectorSection(title: "Operation") {
            Picker("Operation", selection: Binding(
                get: { sweep.operation },
                set: { newOp in
                    var updated = sweep
                    updated.operation = newOp
                    onUpdate(updated)
                }
            )) {
                Text("Additive").tag(ExtrudeFeature.Operation.additive)
                Text("Subtractive").tag(ExtrudeFeature.Operation.subtractive)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("sweep_operation_picker")
        }
    }
}

// MARK: - Loft Inspector

private struct LoftInspector: View {
    let loft: LoftFeature
    let onUpdate: (LoftFeature) -> Void

    var body: some View {
        InspectorSection(title: "Profiles") {
            HStack {
                Text("Profiles")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Spacer()
                Text("\(loft.profileSketchIDs.count)")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .accessibilityIdentifier("loft_profile_count")

            NumericField("Slices", value: Double(loft.slicesPerSpan), identifier: "loft_slices") { newVal in
                var updated = loft
                updated.slicesPerSpan = max(1, Int(newVal))
                onUpdate(updated)
            }
        }

        InspectorSection(title: "Operation") {
            Picker("Operation", selection: Binding(
                get: { loft.operation },
                set: { newOp in
                    var updated = loft
                    updated.operation = newOp
                    onUpdate(updated)
                }
            )) {
                Text("Additive").tag(ExtrudeFeature.Operation.additive)
                Text("Subtractive").tag(ExtrudeFeature.Operation.subtractive)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("loft_operation_picker")
        }
    }
}

// MARK: - Assembly Inspector

private struct AssemblyInspector: View {
    let assembly: AssemblyFeature
    let onUpdate: (AssemblyFeature) -> Void

    var body: some View {
        InspectorSection(title: "Members") {
            HStack {
                Text("Members")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Spacer()
                Text("\(assembly.memberFeatureIDs.count)")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .accessibilityIdentifier("assembly_member_count")
        }

        InspectorSection(title: "Position") {
            NumericField("X", value: assembly.positionX, unit: "mm", identifier: "assembly_pos_x") { newVal in
                var updated = assembly
                updated.positionX = newVal
                onUpdate(updated)
            }
            NumericField("Y", value: assembly.positionY, unit: "mm", identifier: "assembly_pos_y") { newVal in
                var updated = assembly
                updated.positionY = newVal
                onUpdate(updated)
            }
            NumericField("Z", value: assembly.positionZ, unit: "mm", identifier: "assembly_pos_z") { newVal in
                var updated = assembly
                updated.positionZ = newVal
                onUpdate(updated)
            }
        }

        InspectorSection(title: "Rotation") {
            NumericField("X", value: assembly.rotationX, unit: "\u{00B0}", identifier: "assembly_rot_x") { newVal in
                var updated = assembly
                updated.rotationX = newVal
                onUpdate(updated)
            }
            NumericField("Y", value: assembly.rotationY, unit: "\u{00B0}", identifier: "assembly_rot_y") { newVal in
                var updated = assembly
                updated.rotationY = newVal
                onUpdate(updated)
            }
            NumericField("Z", value: assembly.rotationZ, unit: "\u{00B0}", identifier: "assembly_rot_z") { newVal in
                var updated = assembly
                updated.rotationZ = newVal
                onUpdate(updated)
            }
        }
    }
}

// MARK: - Numeric Field (Dark Themed)

private struct NumericField: View {
    let label: String
    let value: Double
    var unit: String = ""
    let identifier: String
    let onChange: (Double) -> Void

    @State private var textValue: String

    init(_ label: String, value: Double, unit: String = "", identifier: String, onChange: @escaping (Double) -> Void) {
        self.label = label
        self.value = value
        self.unit = unit
        self.identifier = identifier
        self.onChange = onChange
        self._textValue = State(initialValue: String(format: "%.2f", value))
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(width: 60, alignment: .leading)

            TextField(label, text: $textValue)
                .font(.system(.caption, design: .monospaced))
                .keyboardType(.decimalPad)
                .accessibilityIdentifier(identifier)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs + 2)
                .background(AppTheme.Colors.surfaceElevated)
                .cornerRadius(AppTheme.CornerRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                        .stroke(AppTheme.Colors.border, lineWidth: 0.5)
                )
                .onSubmit {
                    if let newVal = Double(textValue) {
                        onChange(newVal)
                    }
                }

            if !unit.isEmpty {
                Text(unit)
                    .font(AppTheme.Typography.small)
                    .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.6))
                    .frame(width: 22, alignment: .leading)
            }
        }
    }
}
