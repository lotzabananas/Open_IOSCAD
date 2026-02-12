import SwiftUI
import SCADEngine

struct ParameterPanelView: View {
    let parameters: [CustomizerParam]
    let onValueChanged: (String, Value) -> Void
    var onDragStarted: (() -> Void)?
    var onDragEnded: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Customizer")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            ScrollView {
                LazyVStack(spacing: 12) {
                    let groups = groupedParams()
                    ForEach(Array(groups.keys.sorted()), id: \.self) { group in
                        if !group.isEmpty {
                            Text(group)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }

                        ForEach(groups[group] ?? [], id: \.name) { param in
                            parameterControl(for: param)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12, corners: [.topLeft, .topRight])
        .shadow(radius: 2)
    }

    @ViewBuilder
    private func parameterControl(for param: CustomizerParam) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(param.label)
                .font(.caption)
                .foregroundColor(.secondary)

            switch param.constraint {
            case .range(let min, let step, let max):
                ThrottledSliderControl(
                    param: param,
                    min: min,
                    max: max,
                    step: step,
                    onValueChanged: onValueChanged,
                    onDragStarted: onDragStarted,
                    onDragEnded: onDragEnded
                )

            case .enumList(let options):
                PickerControl(
                    param: param,
                    options: options,
                    onValueChanged: onValueChanged
                )

            case nil:
                switch param.defaultValue {
                case .boolean:
                    ToggleControl(param: param, onValueChanged: onValueChanged)
                case .string:
                    TextFieldControl(param: param, onValueChanged: onValueChanged)
                case .number:
                    NumberFieldControl(param: param, onValueChanged: onValueChanged)
                default:
                    TextFieldControl(param: param, onValueChanged: onValueChanged)
                }
            }
        }
    }

    private func groupedParams() -> [String: [CustomizerParam]] {
        var groups: [String: [CustomizerParam]] = [:]
        for param in parameters {
            let key = param.group ?? ""
            groups[key, default: []].append(param)
        }
        return groups
    }
}

// MARK: - Throttled Slider

/// Slider that throttles value updates to ~15fps during drag and pushes undo on release.
struct ThrottledSliderControl: View {
    let param: CustomizerParam
    let min: Double
    let max: Double
    let step: Double?
    let onValueChanged: (String, Value) -> Void
    var onDragStarted: (() -> Void)?
    var onDragEnded: (() -> Void)?

    @State private var value: Double = 0
    @State private var isDragging = false
    @State private var lastUpdateTime: Date = .distantPast

    private let throttleInterval: TimeInterval = 1.0 / 15.0 // ~15fps

    var body: some View {
        HStack {
            Slider(
                value: $value,
                in: min...max,
                step: step ?? ((max - min) / 100),
                onEditingChanged: { editing in
                    if editing && !isDragging {
                        isDragging = true
                        onDragStarted?()
                    } else if !editing && isDragging {
                        isDragging = false
                        // Final update on release
                        onValueChanged(param.name, .number(value))
                        onDragEnded?()
                    }
                }
            )
            .accessibilityIdentifier("param_slider_\(param.name)")
            .onAppear {
                value = param.defaultValue.asDouble ?? min
            }
            .onChange(of: value) {
                guard isDragging else {
                    // Not dragging (initial set or programmatic) — update immediately
                    onValueChanged(param.name, .number(value))
                    return
                }
                // Throttle during drag
                let now = Date()
                if now.timeIntervalSince(lastUpdateTime) >= throttleInterval {
                    lastUpdateTime = now
                    onValueChanged(param.name, .number(value))
                }
            }

            Text(formatNumber(value))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func formatNumber(_ n: Double) -> String {
        if n == n.rounded() && abs(n) < 1e10 { return "\(Int(n))" }
        return String(format: "%.1f", n)
    }
}

// MARK: - Other Controls

struct PickerControl: View {
    let param: CustomizerParam
    let options: [String]
    let onValueChanged: (String, Value) -> Void

    @State private var selected: String = ""

    var body: some View {
        Picker(param.label, selection: $selected) {
            ForEach(options, id: \.self) { option in
                Text(option).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("param_picker_\(param.name)")
        .onAppear {
            selected = param.defaultValue.asString ?? options.first ?? ""
        }
        .onChange(of: selected) {
            onValueChanged(param.name, .string(selected))
        }
    }
}

struct ToggleControl: View {
    let param: CustomizerParam
    let onValueChanged: (String, Value) -> Void

    @State private var isOn: Bool = false

    var body: some View {
        Toggle(param.label, isOn: $isOn)
            .accessibilityIdentifier("param_field_\(param.name)")
            .onAppear { isOn = param.defaultValue.asBool }
            .onChange(of: isOn) {
                onValueChanged(param.name, .boolean(isOn))
            }
    }
}

struct TextFieldControl: View {
    let param: CustomizerParam
    let onValueChanged: (String, Value) -> Void

    @State private var text: String = ""

    var body: some View {
        TextField(param.label, text: $text)
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("param_field_\(param.name)")
            .onAppear { text = param.defaultValue.asString ?? "" }
            .onSubmit {
                onValueChanged(param.name, .string(text))
            }
    }
}

struct NumberFieldControl: View {
    let param: CustomizerParam
    let onValueChanged: (String, Value) -> Void

    @State private var text: String = ""

    var body: some View {
        TextField(param.label, text: $text)
            .textFieldStyle(.roundedBorder)
            .keyboardType(.decimalPad)
            .accessibilityIdentifier("param_field_\(param.name)")
            .onAppear {
                if let n = param.defaultValue.asDouble {
                    text = n == n.rounded() ? "\(Int(n))" : "\(n)"
                }
            }
            .onSubmit {
                if let n = Double(text) {
                    onValueChanged(param.name, .number(n))
                }
            }
    }
}
