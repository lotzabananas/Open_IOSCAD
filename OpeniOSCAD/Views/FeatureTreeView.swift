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
            // Section header
            HStack {
                Text("Features")
                    .font(AppTheme.Typography.captionBold)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(features.count)")
                    .font(AppTheme.Typography.small)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppTheme.Colors.surfaceElevated)
                    .cornerRadius(AppTheme.CornerRadius.sm)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)

            if features.isEmpty {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 28))
                        .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.4))
                    Text("No features yet")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("Tap + to add a shape")
                        .font(AppTheme.Typography.small)
                        .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
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
        .background(AppTheme.Colors.background)
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

    private var featureColor: Color {
        AppTheme.colorForFeatureKind(feature.kind)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.sm) {
                // Color-coded feature icon
                Image(systemName: iconForFeature(feature))
                    .font(.system(size: 14))
                    .foregroundColor(feature.isSuppressed ? AppTheme.Colors.textSecondary.opacity(0.3) : featureColor)
                    .frame(width: 24, height: 24)

                // Eye icon for suppress toggle
                Button(action: { onSuppress?() }) {
                    Image(systemName: feature.isSuppressed ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundColor(feature.isSuppressed ? AppTheme.Colors.textSecondary.opacity(0.3) : AppTheme.Colors.textSecondary)
                        .frame(width: 20)
                }
                .accessibilityIdentifier("feature_tree_item_\(feature.index)_eye")
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    if isEditing {
                        TextField("Name", text: $editName, onCommit: {
                            onRename?(editName)
                            isEditing = false
                        })
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.surfaceElevated)
                        .cornerRadius(AppTheme.CornerRadius.sm)
                    } else {
                        Text(feature.name)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(feature.isSuppressed ? AppTheme.Colors.textSecondary.opacity(0.4) : AppTheme.Colors.textPrimary)
                            .strikethrough(feature.isSuppressed)
                            .onTapGesture(count: 2) {
                                editName = feature.name
                                isEditing = true
                            }
                    }

                    Text(feature.detail)
                        .font(AppTheme.Typography.small)
                        .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.7))
                }

                Spacer()

                // Index badge
                Text("\(feature.index + 1)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.5))

                // Drag handle (visual only)
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.3))
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(isSelected ? AppTheme.Colors.accentDim.opacity(0.3) : AppTheme.Colors.surface)
            .overlay(
                Rectangle()
                    .fill(isSelected ? AppTheme.Colors.accent : Color.clear)
                    .frame(width: 3),
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
        .opacity(feature.isSuppressed ? 0.5 : 1.0)
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
