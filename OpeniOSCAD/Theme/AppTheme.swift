import SwiftUI
import ParametricEngine

/// Centralized design token system for the Dark Pro mechanical CAD theme.
enum AppTheme {

    // MARK: - Colors

    enum Colors {
        // Surface hierarchy
        static let background = Color(hex: 0x1E1E1E)
        static let surface = Color(hex: 0x2D2D2D)
        static let surfaceElevated = Color(hex: 0x3A3A3A)
        static let border = Color(hex: 0x4A4A4A)

        // Text
        static let textPrimary = Color(hex: 0xE8E8E8)
        static let textSecondary = Color(hex: 0xA0A0A0)

        // Accent
        static let accent = Color(hex: 0x4A9EFF)
        static let accentDim = Color(hex: 0x2A5A8F)

        // Status
        static let success = Color(hex: 0x4CAF50)
        static let warning = Color(hex: 0xFF9800)
        static let error = Color(hex: 0xF44336)

        // Feature type colors
        static let featureSketch = Color(hex: 0xFFB74D)
        static let featureSolid = Color(hex: 0x64B5F6)
        static let featureBoolean = Color(hex: 0x81C784)
        static let featureModifier = Color(hex: 0xCE93D8)
        static let featurePattern = Color(hex: 0x4DD0E1)
        static let featureAssembly = Color(hex: 0xFFD54F)

        // Viewport
        static let viewportBackgroundTop = Color(hex: 0x2B2B2B)
        static let viewportBackgroundBottom = Color(hex: 0x1A1A1A)
        static let gridMinor = Color(hex: 0x3A3A3A)
        static let gridMajor = Color(hex: 0x555555)
        static let modelSilver = Color(hex: 0xB0B0B0)
        static let edges = Color(hex: 0x555555)
    }

    // MARK: - Spacing (4pt grid)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
    }

    // MARK: - Typography

    enum Typography {
        static let title = Font.system(.title2, design: .default, weight: .semibold)
        static let heading = Font.system(.headline, design: .default, weight: .semibold)
        static let body = Font.system(.subheadline, design: .default, weight: .regular)
        static let caption = Font.system(.caption, design: .default, weight: .regular)
        static let captionBold = Font.system(.caption, design: .default, weight: .semibold)
        static let small = Font.system(.caption2, design: .default, weight: .regular)
    }

    // MARK: - Feature Color Helper

    static func colorForFeatureKind(_ kind: FeatureKind) -> Color {
        switch kind {
        case .sketch: return Colors.featureSketch
        case .extrude, .revolve: return Colors.featureSolid
        case .boolean: return Colors.featureBoolean
        case .fillet, .chamfer, .shell: return Colors.featureModifier
        case .pattern, .sweep, .loft: return Colors.featurePattern
        case .transform: return Colors.featureModifier
        case .assembly: return Colors.featureAssembly
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - View Modifiers

extension AppTheme {

    struct CardModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .background(Colors.surface)
                .cornerRadius(CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Colors.border, lineWidth: 0.5)
                )
        }
    }

    struct FloatingToolbarModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .background(Colors.background.opacity(0.92))
                .cornerRadius(CornerRadius.lg)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
    }

    struct DarkInputFieldModifier: ViewModifier {
        var isFocused: Bool = false

        func body(content: Content) -> some View {
            content
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs + 2)
                .background(Colors.surfaceElevated)
                .foregroundColor(Colors.textPrimary)
                .cornerRadius(CornerRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(isFocused ? Colors.accent : Colors.border, lineWidth: 1)
                )
        }
    }

    struct PillButtonModifier: ViewModifier {
        var isActive: Bool = false
        var isDisabled: Bool = false

        func body(content: Content) -> some View {
            content
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(
                    isDisabled
                        ? Colors.textSecondary.opacity(0.3)
                        : (isActive ? Colors.accent : Colors.textPrimary)
                )
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isActive ? Colors.accentDim.opacity(0.3) : Colors.surfaceElevated)
                .cornerRadius(CornerRadius.sm)
        }
    }
}

// MARK: - View Modifier Extensions

extension View {
    func cardStyle() -> some View {
        modifier(AppTheme.CardModifier())
    }

    func floatingToolbarStyle() -> some View {
        modifier(AppTheme.FloatingToolbarModifier())
    }

    func darkInputField(isFocused: Bool = false) -> some View {
        modifier(AppTheme.DarkInputFieldModifier(isFocused: isFocused))
    }

    func pillButton(isActive: Bool = false, isDisabled: Bool = false) -> some View {
        modifier(AppTheme.PillButtonModifier(isActive: isActive, isDisabled: isDisabled))
    }
}
