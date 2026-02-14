import SwiftUI
import GeometryKernel
import Renderer

struct ViewportView: View {
    @Binding var mesh: TriangleMesh
    var onFaceTapped: ((Int?) -> Void)?

    var body: some View {
        ZStack {
            MetalViewport(mesh: $mesh, onFaceTapped: onFaceTapped)
                .accessibilityIdentifier("viewport_view")

            // Viewport UI overlays
            viewportOverlays
        }
    }

    // MARK: - Viewport Overlays

    private var viewportOverlays: some View {
        ZStack {
            // Orientation cube (top-right)
            VStack {
                HStack {
                    Spacer()
                    OrientationCubeView()
                        .padding(.trailing, AppTheme.Spacing.md)
                        .padding(.top, AppTheme.Spacing.md)
                }
                Spacer()
            }

            // Preset view buttons (right edge, vertical strip)
            HStack {
                Spacer()
                VStack(spacing: AppTheme.Spacing.xs) {
                    presetViewButton(icon: "square.fill", label: "Front", identifier: "view_front")
                    presetViewButton(icon: "square", label: "Back", identifier: "view_back")
                    presetViewButton(icon: "square.tophalf.filled", label: "Top", identifier: "view_top")
                    presetViewButton(icon: "square.bottomhalf.filled", label: "Bottom", identifier: "view_bottom")
                    presetViewButton(icon: "square.lefthalf.filled", label: "Left", identifier: "view_left")
                    presetViewButton(icon: "square.righthalf.filled", label: "Right", identifier: "view_right")
                    Rectangle()
                        .fill(AppTheme.Colors.border)
                        .frame(width: 20, height: 1)
                    presetViewButton(icon: "cube", label: "Iso", identifier: "view_iso")
                }
                .padding(.vertical, AppTheme.Spacing.sm)
                .padding(.horizontal, AppTheme.Spacing.xs)
                .background(AppTheme.Colors.background.opacity(0.85))
                .cornerRadius(AppTheme.CornerRadius.md)
                .padding(.trailing, AppTheme.Spacing.md)
            }

            // Zoom controls (bottom-right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: AppTheme.Spacing.xs) {
                        zoomButton(icon: "plus", identifier: "zoom_in")
                        zoomButton(icon: "minus", identifier: "zoom_out")
                        zoomButton(icon: "arrow.up.left.and.arrow.down.right", identifier: "zoom_fit")
                    }
                    .padding(AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.background.opacity(0.85))
                    .cornerRadius(AppTheme.CornerRadius.md)
                    .padding(.trailing, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.md)
                }
            }

            // XYZ Gizmo (bottom-left)
            VStack {
                Spacer()
                HStack {
                    XYZGizmoView()
                        .padding(.leading, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.md)
                    Spacer()
                }
            }
        }
    }

    private func presetViewButton(icon: String, label: String, identifier: String) -> some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(width: 28, height: 28)
        }
        .accessibilityIdentifier(identifier)
    }

    private func zoomButton(icon: String, identifier: String) -> some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(width: 30, height: 30)
        }
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Orientation Cube

struct OrientationCubeView: View {
    var body: some View {
        ZStack {
            // Simple 2D representation of orientation cube
            RoundedRectangle(cornerRadius: 4)
                .fill(AppTheme.Colors.surface)
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                )
                .overlay(
                    VStack(spacing: 2) {
                        Text("T")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        HStack(spacing: 8) {
                            Text("L")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            Text("F")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Text("R")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        Text("B")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                )
        }
        .accessibilityIdentifier("orientation_cube")
    }
}

// MARK: - XYZ Gizmo

struct XYZGizmoView: View {
    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width * 0.35, y: size.height * 0.65)
            let axisLength: CGFloat = 25

            // X axis (red) - going right
            var xPath = Path()
            xPath.move(to: origin)
            xPath.addLine(to: CGPoint(x: origin.x + axisLength, y: origin.y))
            context.stroke(xPath, with: .color(.red), lineWidth: 2)
            context.draw(
                Text("X").font(.system(size: 9, weight: .bold)).foregroundColor(.red),
                at: CGPoint(x: origin.x + axisLength + 8, y: origin.y)
            )

            // Y axis (green) - going up
            var yPath = Path()
            yPath.move(to: origin)
            yPath.addLine(to: CGPoint(x: origin.x, y: origin.y - axisLength))
            context.stroke(yPath, with: .color(.green), lineWidth: 2)
            context.draw(
                Text("Y").font(.system(size: 9, weight: .bold)).foregroundColor(.green),
                at: CGPoint(x: origin.x, y: origin.y - axisLength - 8)
            )

            // Z axis (blue) - going diagonal
            var zPath = Path()
            zPath.move(to: origin)
            zPath.addLine(to: CGPoint(x: origin.x - axisLength * 0.6, y: origin.y + axisLength * 0.4))
            context.stroke(zPath, with: .color(Color(hex: 0x4A9EFF)), lineWidth: 2)
            context.draw(
                Text("Z").font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: 0x4A9EFF)),
                at: CGPoint(x: origin.x - axisLength * 0.6 - 8, y: origin.y + axisLength * 0.4 + 4)
            )
        }
        .frame(width: 70, height: 70)
        .accessibilityIdentifier("xyz_gizmo")
    }
}
