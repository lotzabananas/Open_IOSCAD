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
                    case .boolean(let boolean):
                        BooleanInspector(boolean: boolean, onUpdate: { updated in
                            onUpdate(.boolean(updated))
                        })
                    case .transform(let transform):
                        TransformInspector(transform: transform, onUpdate: { updated in
                            onUpdate(.transform(updated))
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
