import SwiftUI
import ParametricEngine

/// Overlay view for sketch mode.
/// Provides 2D drawing tools on the selected sketch plane.
struct SketchCanvasView: View {
    @ObservedObject var viewModel: ModelViewModel
    @StateObject private var sketchVM = SketchViewModel()

    /// ID of the last sketch added, needed to create the extrude.
    @State private var lastSketchID: FeatureID?

    var body: some View {
        ZStack {
            // Dark overlay background
            Color(hex: 0x1A1A1A).opacity(0.75)
                .edgesIgnoringSafeArea(.all)

            // Grid
            SketchGridView()

            // Drawing canvas — captures touch
            SketchDrawingLayer(sketchVM: sketchVM)

            // Element previews
            ForEach(sketchVM.elements) { element in
                SketchElementShape(element: element)
            }

            // Current drawing preview
            if let preview = sketchVM.currentPreview {
                SketchElementShape(element: preview)
                    .opacity(0.5)
            }

            // Top toolbar
            VStack {
                SketchToolbar(sketchVM: sketchVM, onFinish: finishSketch, onCancel: cancelSketch)
                Spacer()

                // DOF indicator (when constraints exist)
                if !sketchVM.constraints.isEmpty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(sketchVM.solverDOF == 0 ? AppTheme.Colors.success : AppTheme.Colors.warning)
                            .frame(width: 8, height: 8)
                        Text(sketchVM.solverDOF == 0
                             ? "Fully constrained"
                             : "DOF: \(sketchVM.solverDOF)")
                            .font(AppTheme.Typography.small)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.surface.opacity(0.9))
                    .cornerRadius(AppTheme.CornerRadius.md)
                    .padding(.bottom, AppTheme.Spacing.lg)
                    .accessibilityIdentifier("sketch_dof_indicator")
                }
            }
        }
        .accessibilityIdentifier("sketch_canvas")
        .onChange(of: sketchVM.pendingOperation) { _, newOp in
            guard let operation = newOp, let sketchID = lastSketchID else { return }
            viewModel.addExtrudeForSketch(
                sketchID: sketchID,
                depth: sketchVM.extrudeDepth,
                operation: operation
            )
            exitSketchMode()
        }
    }

    private func finishSketch() {
        guard !sketchVM.elements.isEmpty else {
            cancelSketch()
            return
        }

        // Create the sketch feature with constraints and remember its ID
        let sketchID = FeatureID()
        let sketch = SketchFeature(
            id: sketchID,
            name: "Sketch",
            plane: viewModel.sketchPlane,
            elements: sketchVM.elements,
            constraints: sketchVM.constraints
        )
        viewModel.featureTree.append(.sketch(sketch))
        lastSketchID = sketchID

        // Prompt for extrude depth
        sketchVM.showExtrudePrompt = true
    }

    private func cancelSketch() {
        exitSketchMode()
    }

    private func exitSketchMode() {
        sketchVM.reset()
        lastSketchID = nil
        viewModel.isInSketchMode = false
    }
}

// MARK: - Grid

struct SketchGridView: View {
    let gridSpacing: CGFloat = 20
    let gridSize: Int = 30

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let centerY = size.height / 2

            // Grid lines
            for i in -gridSize...gridSize {
                let offset = CGFloat(i) * gridSpacing

                let isMajor = i % 5 == 0
                let isCenter = i == 0

                let lineColor: Color = isCenter
                    ? Color(hex: 0x4A9EFF).opacity(0.4)
                    : (isMajor ? Color(hex: 0x555555).opacity(0.4) : Color(hex: 0x3A3A3A).opacity(0.3))
                let lineWidth: CGFloat = isCenter ? 1.5 : (isMajor ? 0.7 : 0.4)

                // Vertical
                var vPath = Path()
                vPath.move(to: CGPoint(x: centerX + offset, y: 0))
                vPath.addLine(to: CGPoint(x: centerX + offset, y: size.height))
                context.stroke(vPath, with: .color(lineColor), lineWidth: lineWidth)

                // Horizontal
                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: centerY + offset))
                hPath.addLine(to: CGPoint(x: size.width, y: centerY + offset))
                context.stroke(hPath, with: .color(lineColor), lineWidth: lineWidth)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Drawing Layer

struct SketchDrawingLayer: View {
    @ObservedObject var sketchVM: SketchViewModel

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            let snapped = sketchVM.snapToGrid(
                                point: value.location,
                                in: geo.size
                            )
                            sketchVM.handleDrag(at: snapped)
                        }
                        .onEnded { value in
                            let snapped = sketchVM.snapToGrid(
                                point: value.location,
                                in: geo.size
                            )
                            sketchVM.handleDragEnd(at: snapped)
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            sketchVM.handleTap()
                        }
                )
        }
        .accessibilityIdentifier("sketch_drawing_layer")
    }
}

// MARK: - Element Shape Rendering

struct SketchElementShape: View {
    let element: SketchElement

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let scale: CGFloat = 20 // pixels per unit

            switch element {
            case .rectangle(_, let origin, let width, let height):
                Rectangle()
                    .stroke(AppTheme.Colors.textPrimary, lineWidth: 2)
                    .frame(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
                    .position(
                        x: center.x + CGFloat(origin.x + width / 2) * scale,
                        y: center.y - CGFloat(origin.y + height / 2) * scale
                    )

            case .circle(_, let c, let radius):
                Circle()
                    .stroke(AppTheme.Colors.textPrimary, lineWidth: 2)
                    .frame(width: CGFloat(radius) * 2 * scale, height: CGFloat(radius) * 2 * scale)
                    .position(
                        x: center.x + CGFloat(c.x) * scale,
                        y: center.y - CGFloat(c.y) * scale
                    )

            case .lineSegment(_, let start, let end):
                Path { path in
                    path.move(to: CGPoint(
                        x: center.x + CGFloat(start.x) * scale,
                        y: center.y - CGFloat(start.y) * scale
                    ))
                    path.addLine(to: CGPoint(
                        x: center.x + CGFloat(end.x) * scale,
                        y: center.y - CGFloat(end.y) * scale
                    ))
                }
                .stroke(AppTheme.Colors.textPrimary, lineWidth: 2)

            case .arc(_, let arcCenter, let radius, let startAngle, let sweepAngle):
                Path { path in
                    let cx = center.x + CGFloat(arcCenter.x) * scale
                    let cy = center.y - CGFloat(arcCenter.y) * scale
                    let r = CGFloat(radius) * scale
                    let sa = Angle(degrees: -startAngle)
                    let ea = Angle(degrees: -(startAngle + sweepAngle))
                    path.addArc(
                        center: CGPoint(x: cx, y: cy),
                        radius: r,
                        startAngle: sa,
                        endAngle: ea,
                        clockwise: sweepAngle > 0
                    )
                }
                .stroke(AppTheme.Colors.textPrimary, lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
    }
}
