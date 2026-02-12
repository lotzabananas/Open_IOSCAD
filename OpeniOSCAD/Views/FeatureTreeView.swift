import SwiftUI

struct FeatureTreeView: View {
    let features: [FeatureItem]
    @Binding var selectedIndex: Int?

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
                                isSelected: selectedIndex == feature.index,
                                onTap: { selectedIndex = feature.index }
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
    let feature: FeatureItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: iconForFeature(feature.name))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 24)

                Text(feature.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Text("L\(feature.lineNumber)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        Divider().padding(.leading, 48)
    }

    private func iconForFeature(_ name: String) -> String {
        switch name.lowercased() {
        case "cube": return "cube"
        case "cylinder": return "cylinder"
        case "sphere": return "circle"
        case "difference": return "minus.square"
        case "union": return "plus.square"
        case "intersection": return "square.on.square"
        case "translate": return "arrow.up.and.down.and.arrow.left.and.right"
        case "rotate": return "arrow.triangle.2.circlepath"
        case "scale": return "arrow.up.left.and.arrow.down.right"
        default: return "gearshape"
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
