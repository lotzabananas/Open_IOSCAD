import SwiftUI
import ParametricEngine

struct FeatureTreeView: View {
    let features: [FeatureDisplayItem]
    let selectedID: FeatureID?
    var onSelect: ((Int) -> Void)?
    var onSuppress: ((Int) -> Void)?
    var onDelete: ((Int) -> Void)?
    var onRename: ((Int, String) -> Void)?
    var onMove: ((Int, Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Features")
                    .font(.headline)
                    .padding(.horizontal)
                Spacer()
                Text("\(features.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            if features.isEmpty {
                Text("No features yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(features) { feature in
                            FeatureRow(
                                feature: feature,
                                isSelected: selectedID == feature.id,
                                onTap: { onSelect?(feature.index) },
                                onSuppress: { onSuppress?(feature.index) },
                                onDelete: { onDelete?(feature.index) },
                                onRename: { newName in onRename?(feature.index, newName) }
                            )
                            .accessibilityIdentifier("feature_tree_item_\(feature.index)")
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12, corners: [.topLeft, .topRight])
        .shadow(radius: 2)
    }
}

struct FeatureRow: View {
    let feature: FeatureDisplayItem
    let isSelected: Bool
    let onTap: () -> Void
    var onSuppress: (() -> Void)?
    var onDelete: (() -> Void)?
    var onRename: ((String) -> Void)?

    @State private var isEditing = false
    @State private var editName = ""

    var body: some View {
        Button(action: onTap) {
            HStack {
                // Eye icon for suppress toggle
                Button(action: { onSuppress?() }) {
                    Image(systemName: feature.isSuppressed ? "eye.slash" : "eye")
                        .foregroundColor(feature.isSuppressed ? .secondary : .blue)
                        .frame(width: 24)
                }
                .accessibilityIdentifier("feature_tree_item_\(feature.index)_eye")
                .buttonStyle(.plain)

                Image(systemName: iconForFeature(feature))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    if isEditing {
                        TextField("Name", text: $editName, onCommit: {
                            onRename?(editName)
                            isEditing = false
                        })
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                    } else {
                        Text(feature.name)
                            .font(.subheadline)
                            .foregroundColor(feature.isSuppressed ? .secondary : .primary)
                            .strikethrough(feature.isSuppressed)
                            .onTapGesture(count: 2) {
                                editName = feature.name
                                isEditing = true
                            }
                    }

                    Text(feature.detail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(feature.index + 1)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                onSuppress?()
            } label: {
                Label(
                    feature.isSuppressed ? "Show" : "Hide",
                    systemImage: feature.isSuppressed ? "eye" : "eye.slash"
                )
            }
            .tint(.orange)
        }
        Divider().padding(.leading, 48)
    }

    private func iconForFeature(_ f: FeatureDisplayItem) -> String {
        switch f.kind {
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

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                               cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
