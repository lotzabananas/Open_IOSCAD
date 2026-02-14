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
            // Header
            HStack {
                Text(feature.name)
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityIdentifier("property_inspector_dismiss")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            ScrollView {
                VStack(spacing: 12) {
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
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12, corners: [.topLeft, .topRight])
        .shadow(radius: 2)
    }
}

// MARK: - Sketch Inspector

private struct SketchInspector: View {
    let sketch: SketchFeature
    let onUpdate: (SketchFeature) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plane: \(sketch.plane.displayName)")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(Array(sketch.elements.enumerated()), id: \.element.id) { index, element in
                elementEditor(element, at: index)
            }

            ConstraintListView(constraints: sketch.constraints)
        }
    }

    @ViewBuilder
    private func elementEditor(_ element: SketchElement, at index: Int) -> some View {
        switch element {
        case .rectangle(let id, let origin, let width, let height):
            VStack(alignment: .leading, spacing: 4) {
                Text("Rectangle")
                    .font(.caption.bold())
                NumericField("Width", value: width, identifier: "sketch_rect_width") { newVal in
                    var updated = sketch
                    updated.elements[index] = .rectangle(id: id, origin: origin, width: newVal, height: height)
                    onUpdate(updated)
                }
                NumericField("Height", value: height, identifier: "sketch_rect_height") { newVal in
                    var updated = sketch
                    updated.elements[index] = .rectangle(id: id, origin: origin, width: width, height: newVal)
                    onUpdate(updated)
                }
                NumericField("Origin X", value: origin.x, identifier: "sketch_rect_ox") { newVal in
                    var updated = sketch
                    updated.elements[index] = .rectangle(id: id, origin: Point2D(x: newVal, y: origin.y), width: width, height: height)
                    onUpdate(updated)
                }
                NumericField("Origin Y", value: origin.y, identifier: "sketch_rect_oy") { newVal in
                    var updated = sketch
                    updated.elements[index] = .rectangle(id: id, origin: Point2D(x: origin.x, y: newVal), width: width, height: height)
                    onUpdate(updated)
                }
            }

        case .circle(let id, let center, let radius):
            VStack(alignment: .leading, spacing: 4) {
                Text("Circle")
                    .font(.caption.bold())
                NumericField("Radius", value: radius, identifier: "sketch_circle_radius") { newVal in
                    var updated = sketch
                    updated.elements[index] = .circle(id: id, center: center, radius: newVal)
                    onUpdate(updated)
                }
                NumericField("Center X", value: center.x, identifier: "sketch_circle_cx") { newVal in
                    var updated = sketch
                    updated.elements[index] = .circle(id: id, center: Point2D(x: newVal, y: center.y), radius: radius)
                    onUpdate(updated)
                }
                NumericField("Center Y", value: center.y, identifier: "sketch_circle_cy") { newVal in
                    var updated = sketch
                    updated.elements[index] = .circle(id: id, center: Point2D(x: center.x, y: newVal), radius: radius)
                    onUpdate(updated)
                }
            }

        case .lineSegment(let id, let start, let end):
            VStack(alignment: .leading, spacing: 4) {
                Text("Line Segment")
                    .font(.caption.bold())
                NumericField("Start X", value: start.x, identifier: "sketch_line_sx") { newVal in
                    var updated = sketch
                    updated.elements[index] = .lineSegment(id: id, start: Point2D(x: newVal, y: start.y), end: end)
                    onUpdate(updated)
                }
                NumericField("Start Y", value: start.y, identifier: "sketch_line_sy") { newVal in
                    var updated = sketch
                    updated.elements[index] = .lineSegment(id: id, start: Point2D(x: start.x, y: newVal), end: end)
                    onUpdate(updated)
                }
                NumericField("End X", value: end.x, identifier: "sketch_line_ex") { newVal in
                    var updated = sketch
                    updated.elements[index] = .lineSegment(id: id, start: start, end: Point2D(x: newVal, y: end.y))
                    onUpdate(updated)
                }
                NumericField("End Y", value: end.y, identifier: "sketch_line_ey") { newVal in
                    var updated = sketch
                    updated.elements[index] = .lineSegment(id: id, start: start, end: Point2D(x: end.x, y: newVal))
                    onUpdate(updated)
                }
            }

        case .arc(let id, let center, let radius, let startAngle, let sweepAngle):
            VStack(alignment: .leading, spacing: 4) {
                Text("Arc")
                    .font(.caption.bold())
                NumericField("Radius", value: radius, identifier: "sketch_arc_radius") { newVal in
                    var updated = sketch
                    updated.elements[index] = .arc(id: id, center: center, radius: newVal, startAngle: startAngle, sweepAngle: sweepAngle)
                    onUpdate(updated)
                }
                NumericField("Start", value: startAngle, identifier: "sketch_arc_start") { newVal in
                    var updated = sketch
                    updated.elements[index] = .arc(id: id, center: center, radius: radius, startAngle: newVal, sweepAngle: sweepAngle)
                    onUpdate(updated)
                }
                NumericField("Sweep", value: sweepAngle, identifier: "sketch_arc_sweep") { newVal in
                    var updated = sketch
                    updated.elements[index] = .arc(id: id, center: center, radius: radius, startAngle: startAngle, sweepAngle: newVal)
                    onUpdate(updated)
                }
                NumericField("Center X", value: center.x, identifier: "sketch_arc_cx") { newVal in
                    var updated = sketch
                    updated.elements[index] = .arc(id: id, center: Point2D(x: newVal, y: center.y), radius: radius, startAngle: startAngle, sweepAngle: sweepAngle)
                    onUpdate(updated)
                }
                NumericField("Center Y", value: center.y, identifier: "sketch_arc_cy") { newVal in
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
        if !constraints.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Constraints")
                    .font(.caption.bold())
                ForEach(constraints) { constraint in
                    HStack {
                        Image(systemName: constraint.isDimensional ? "ruler" : "link")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(constraint.typeName)
                            .font(.caption)
                    }
                    .accessibilityIdentifier("constraint_\(constraint.id.uuidString.prefix(8))")
                }
            }
        }
    }
}

// MARK: - Extrude Inspector

private struct ExtrudeInspector: View {
    let extrude: ExtrudeFeature
    let onUpdate: (ExtrudeFeature) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(extrude.operation == .additive ? "Additive (Boss)" : "Subtractive (Cut)")
                .font(.caption)
                .foregroundColor(.secondary)

            NumericField("Depth", value: extrude.depth, identifier: "extrude_depth") { newVal in
                var updated = extrude
                updated.depth = newVal
                onUpdate(updated)
            }

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
        VStack(alignment: .leading, spacing: 8) {
            Text(revolve.operation == .additive ? "Additive" : "Subtractive")
                .font(.caption)
                .foregroundColor(.secondary)

            NumericField("Angle", value: revolve.angle, identifier: "revolve_angle") { newVal in
                var updated = revolve
                updated.angle = max(0.1, min(360.0, newVal))
                onUpdate(updated)
            }

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
        VStack(alignment: .leading, spacing: 8) {
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
        VStack(alignment: .leading, spacing: 8) {
            NumericField("X", value: transform.vector.x, identifier: "transform_x") { newVal in
                var updated = transform
                updated.vector.x = newVal
                onUpdate(updated)
            }
            NumericField("Y", value: transform.vector.y, identifier: "transform_y") { newVal in
                var updated = transform
                updated.vector.y = newVal
                onUpdate(updated)
            }
            NumericField("Z", value: transform.vector.z, identifier: "transform_z") { newVal in
                var updated = transform
                updated.vector.z = newVal
                onUpdate(updated)
            }
            if transform.transformType == .rotate {
                NumericField("Angle", value: transform.angle, identifier: "transform_angle") { newVal in
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Fillet (Round Edges)")
                .font(.caption)
                .foregroundColor(.secondary)

            NumericField("Radius", value: fillet.radius, identifier: "fillet_radius") { newVal in
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Chamfer (Bevel Edges)")
                .font(.caption)
                .foregroundColor(.secondary)

            NumericField("Distance", value: chamfer.distance, identifier: "chamfer_distance") { newVal in
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Shell (Hollow)")
                .font(.caption)
                .foregroundColor(.secondary)

            NumericField("Thickness", value: shell.thickness, identifier: "shell_thickness") { newVal in
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
        VStack(alignment: .leading, spacing: 8) {
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

            if pattern.patternType != .mirror {
                NumericField("Count", value: Double(pattern.count), identifier: "pattern_count") { newVal in
                    var updated = pattern
                    updated.count = max(1, Int(newVal))
                    onUpdate(updated)
                }
            }

            if pattern.patternType == .linear {
                NumericField("Spacing", value: pattern.spacing, identifier: "pattern_spacing") { newVal in
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

            if pattern.patternType == .circular {
                NumericField("Angle", value: pattern.totalAngle, identifier: "pattern_total_angle") { newVal in
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Sweep (Profile Along Path)")
                .font(.caption)
                .foregroundColor(.secondary)

            NumericField("Twist", value: sweep.twist, identifier: "sweep_twist") { newVal in
                var updated = sweep
                updated.twist = newVal
                onUpdate(updated)
            }
            NumericField("End Scale", value: sweep.scaleEnd, identifier: "sweep_scale_end") { newVal in
                var updated = sweep
                updated.scaleEnd = max(0.01, newVal)
                onUpdate(updated)
            }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Loft (Blend Profiles)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(loft.profileSketchIDs.count) profiles")
                .font(.caption)
                .accessibilityIdentifier("loft_profile_count")

            NumericField("Slices", value: Double(loft.slicesPerSpan), identifier: "loft_slices") { newVal in
                var updated = loft
                updated.slicesPerSpan = max(1, Int(newVal))
                onUpdate(updated)
            }

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

// MARK: - Numeric Field

private struct NumericField: View {
    let label: String
    let value: Double
    let identifier: String
    let onChange: (Double) -> Void

    @State private var textValue: String

    init(_ label: String, value: Double, identifier: String, onChange: @escaping (Double) -> Void) {
        self.label = label
        self.value = value
        self.identifier = identifier
        self.onChange = onChange
        self._textValue = State(initialValue: String(format: "%.2f", value))
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 60, alignment: .leading)
            TextField(label, text: $textValue)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier(identifier)
                .onSubmit {
                    if let newVal = Double(textValue) {
                        onChange(newVal)
                    }
                }
        }
    }
}
