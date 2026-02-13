import SwiftUI
import ParametricEngine

/// Available sketch drawing tools.
enum SketchTool: String, CaseIterable {
    case rectangle
    case circle
    case line
    case arc

    var displayName: String {
        switch self {
        case .rectangle: return "Rect"
        case .circle: return "Circle"
        case .line: return "Line"
        case .arc: return "Arc"
        }
    }

    var iconName: String {
        switch self {
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .line: return "line.diagonal"
        case .arc: return "arc"
        }
    }
}

/// Manages sketch mode state: tool selection, drawing, element creation.
@MainActor
final class SketchViewModel: ObservableObject {
    @Published var selectedTool: SketchTool = .rectangle
    @Published var elements: [SketchElement] = []
    @Published var constraints: [SketchConstraint] = []
    @Published var currentPreview: SketchElement?
    @Published var showExtrudePrompt: Bool = false
    @Published var extrudeDepth: Double = 10
    @Published var pendingOperation: ExtrudeFeature.Operation?

    // Constraint solver feedback
    @Published var solverDOF: Int = 0
    @Published var solverConverged: Bool = true

    // Grid snapping
    let gridSpacing: Double = 1.0  // 1mm grid

    // Drawing state
    private var dragStart: Point2D?

    func snapToGrid(point: CGPoint, in size: CGSize) -> Point2D {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let scale: Double = 20 // pixels per unit (matches SketchElementShape)

        let x = Double(point.x - centerX) / scale
        let y = -Double(point.y - centerY) / scale // Flip Y

        let snappedX = (x / gridSpacing).rounded() * gridSpacing
        let snappedY = (y / gridSpacing).rounded() * gridSpacing

        return Point2D(x: snappedX, y: snappedY)
    }

    func handleDrag(at point: Point2D) {
        if dragStart == nil {
            dragStart = point
        }
        guard let start = dragStart else { return }

        switch selectedTool {
        case .rectangle:
            let width = abs(point.x - start.x)
            let height = abs(point.y - start.y)
            let origin = Point2D(
                x: min(start.x, point.x),
                y: min(start.y, point.y)
            )
            currentPreview = .rectangle(
                id: ElementID(),
                origin: origin,
                width: max(width, 0.1),
                height: max(height, 0.1)
            )

        case .circle:
            let dx = point.x - start.x
            let dy = point.y - start.y
            let radius = (dx * dx + dy * dy).squareRoot()
            currentPreview = .circle(
                id: ElementID(),
                center: start,
                radius: max(radius, 0.1)
            )

        case .line:
            currentPreview = .lineSegment(
                id: ElementID(),
                start: start,
                end: point
            )

        case .arc:
            // Arc drawing: drag from center, radius = distance to cursor,
            // sweep defaults to 180 degrees
            let dx = point.x - start.x
            let dy = point.y - start.y
            let radius = (dx * dx + dy * dy).squareRoot()
            let startAngle = atan2(dy, dx) * 180 / .pi
            currentPreview = .arc(
                id: ElementID(),
                center: start,
                radius: max(radius, 0.1),
                startAngle: startAngle,
                sweepAngle: 180
            )
        }
    }

    func handleDragEnd(at point: Point2D) {
        guard dragStart != nil else { return }

        if let preview = currentPreview {
            // Validate the element has meaningful size
            switch preview {
            case .rectangle(_, _, let w, let h) where w > 0.01 && h > 0.01:
                elements.append(preview)
            case .circle(_, _, let r) where r > 0.01:
                elements.append(preview)
            case .lineSegment(_, let s, let e)
                where abs(s.x - e.x) > 0.01 || abs(s.y - e.y) > 0.01:
                elements.append(preview)
            case .arc(_, _, let r, _, let sweep) where r > 0.01 && abs(sweep) > 0.1:
                elements.append(preview)
            default:
                break
            }
        }

        dragStart = nil
        currentPreview = nil

        // Re-solve constraints after adding element
        runSolver()
    }

    func handleTap() {
        // For line tool: tap to place individual points (future enhancement)
    }

    // MARK: - Constraint Management

    func addConstraint(_ constraint: SketchConstraint) {
        constraints.append(constraint)
        runSolver()
    }

    func removeConstraint(id: ConstraintID) {
        constraints.removeAll { $0.id == id }
        runSolver()
    }

    /// Run the constraint solver and update elements with solved positions.
    func runSolver() {
        guard !constraints.isEmpty else {
            let totalDOF = elements.reduce(0) { sum, el in
                sum + SketchSolver.paramCount(for: el)
            }
            solverDOF = totalDOF
            solverConverged = true
            return
        }

        let result = SketchSolver.solve(
            elements: elements,
            constraints: constraints
        )
        elements = result.elements
        solverDOF = result.degreesOfFreedom
        solverConverged = result.converged
    }

    func reset() {
        elements.removeAll()
        constraints.removeAll()
        currentPreview = nil
        dragStart = nil
        showExtrudePrompt = false
        pendingOperation = nil
        solverDOF = 0
        solverConverged = true
    }
}
