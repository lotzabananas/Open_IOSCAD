import Foundation

/// Gauss-Newton iterative solver for 2D sketch constraints.
///
/// Parameterizes sketch elements as a flat vector of doubles, expresses
/// constraints as error functions, and iteratively minimizes residual error
/// using the normal equations (J^T J) dx = -J^T f.
public enum SketchSolver {

    /// Result of constraint solving.
    public struct SolverResult: Sendable {
        /// Elements with positions adjusted to satisfy constraints.
        public let elements: [SketchElement]
        /// Remaining degrees of freedom (total params minus independent constraints).
        public let degreesOfFreedom: Int
        /// Whether the solver converged within tolerance.
        public let converged: Bool
        /// Final root-mean-square residual of constraint errors.
        public let residual: Double
    }

    /// Solve constraints on a set of sketch elements.
    public static func solve(
        elements: [SketchElement],
        constraints: [SketchConstraint],
        maxIterations: Int = 50,
        tolerance: Double = 1e-10
    ) -> SolverResult {
        guard !constraints.isEmpty else {
            let totalDOF = elements.reduce(0) { $0 + paramCount(for: $1) }
            return SolverResult(
                elements: elements,
                degreesOfFreedom: totalDOF,
                converged: true,
                residual: 0
            )
        }

        // Build parameter offset map: elementID → starting index in param vector
        var paramOffsets: [ElementID: Int] = [:]
        var totalParams = 0
        for element in elements {
            paramOffsets[element.id] = totalParams
            totalParams += paramCount(for: element)
        }

        // Extract initial parameter vector
        var params = extractParams(from: elements)

        // Gauss-Newton iteration
        var converged = false
        var residual = Double.infinity
        let numErrors = countErrors(constraints: constraints, elements: elements)

        for _ in 0..<maxIterations {
            let errors = evaluateErrors(
                params: params,
                constraints: constraints,
                elements: elements,
                paramOffsets: paramOffsets
            )

            residual = rms(errors)

            if residual < tolerance {
                converged = true
                break
            }

            let jacobian = computeJacobian(
                params: params,
                constraints: constraints,
                elements: elements,
                paramOffsets: paramOffsets,
                numErrors: numErrors
            )

            // Normal equations: (J^T J) delta = -J^T errors
            let jt = transpose(jacobian, rows: numErrors, cols: totalParams)
            let jtj = matMul(jt, rows1: totalParams, cols1: numErrors,
                             jacobian, cols2: totalParams)
            let jte = matVecMul(jt, rows: totalParams, cols: numErrors, vec: errors)
            let negJte = jte.map { -$0 }

            guard let delta = solveLinearSystem(jtj, negJte, size: totalParams) else {
                break // Singular — stop iterating
            }

            // Apply update
            for i in 0..<totalParams {
                params[i] += delta[i]
            }

            // Clamp radius and dimension parameters to stay positive
            var offset = 0
            for element in elements {
                switch element {
                case .rectangle:
                    // width and height must be positive
                    params[offset + 2] = max(1e-6, params[offset + 2])
                    params[offset + 3] = max(1e-6, params[offset + 3])
                    offset += 4
                case .circle:
                    // radius must be positive
                    params[offset + 2] = max(1e-6, params[offset + 2])
                    offset += 3
                case .lineSegment:
                    offset += 4
                case .arc:
                    // radius must be positive
                    params[offset + 2] = max(1e-6, params[offset + 2])
                    offset += 5
                }
            }
        }

        let solvedElements = applyParams(params, to: elements)
        let dof = max(0, totalParams - numErrors)

        return SolverResult(
            elements: solvedElements,
            degreesOfFreedom: dof,
            converged: converged,
            residual: residual
        )
    }

    // MARK: - Parameterization

    /// Number of scalar parameters for an element.
    public static func paramCount(for element: SketchElement) -> Int {
        switch element {
        case .rectangle: return 4   // origin.x, origin.y, width, height
        case .circle: return 3      // center.x, center.y, radius
        case .lineSegment: return 4 // start.x, start.y, end.x, end.y
        case .arc: return 5         // center.x, center.y, radius, startAngle, sweepAngle
        }
    }

    /// Extract a flat parameter vector from all elements.
    static func extractParams(from elements: [SketchElement]) -> [Double] {
        var params: [Double] = []
        for element in elements {
            switch element {
            case .rectangle(_, let origin, let width, let height):
                params.append(contentsOf: [origin.x, origin.y, width, height])
            case .circle(_, let center, let radius):
                params.append(contentsOf: [center.x, center.y, radius])
            case .lineSegment(_, let start, let end):
                params.append(contentsOf: [start.x, start.y, end.x, end.y])
            case .arc(_, let center, let radius, let startAngle, let sweepAngle):
                params.append(contentsOf: [center.x, center.y, radius, startAngle, sweepAngle])
            }
        }
        return params
    }

    /// Reconstruct elements from a parameter vector, preserving IDs.
    static func applyParams(_ params: [Double], to elements: [SketchElement]) -> [SketchElement] {
        var result: [SketchElement] = []
        var offset = 0
        for element in elements {
            switch element {
            case .rectangle(let id, _, _, _):
                result.append(.rectangle(
                    id: id,
                    origin: Point2D(x: params[offset], y: params[offset + 1]),
                    width: params[offset + 2],
                    height: params[offset + 3]
                ))
                offset += 4
            case .circle(let id, _, _):
                result.append(.circle(
                    id: id,
                    center: Point2D(x: params[offset], y: params[offset + 1]),
                    radius: params[offset + 2]
                ))
                offset += 3
            case .lineSegment(let id, _, _):
                result.append(.lineSegment(
                    id: id,
                    start: Point2D(x: params[offset], y: params[offset + 1]),
                    end: Point2D(x: params[offset + 2], y: params[offset + 3])
                ))
                offset += 4
            case .arc(let id, _, _, _, _):
                result.append(.arc(
                    id: id,
                    center: Point2D(x: params[offset], y: params[offset + 1]),
                    radius: params[offset + 2],
                    startAngle: params[offset + 3],
                    sweepAngle: params[offset + 4]
                ))
                offset += 5
            }
        }
        return result
    }

    // MARK: - Point Resolution

    /// Resolve a PointRef to (paramIndex_x, paramIndex_y) in the param vector.
    /// For computed points (arc start/end), returns nil — those are handled specially.
    private static func resolvePointIndices(
        _ ref: PointRef,
        elements: [SketchElement],
        paramOffsets: [ElementID: Int]
    ) -> (Int, Int)? {
        guard let element = elements.first(where: { $0.id == ref.elementID }),
              let base = paramOffsets[ref.elementID] else { return nil }

        switch (element, ref.position) {
        case (.rectangle, .origin):
            return (base, base + 1)
        case (.circle, .center):
            return (base, base + 1)
        case (.lineSegment, .start):
            return (base, base + 1)
        case (.lineSegment, .end):
            return (base + 2, base + 3)
        case (.arc, .center):
            return (base, base + 1)
        default:
            return nil
        }
    }

    /// Resolve a PointRef to (x, y) coordinates from the current param vector.
    private static func resolvePointValues(
        _ ref: PointRef,
        params: [Double],
        elements: [SketchElement],
        paramOffsets: [ElementID: Int]
    ) -> (Double, Double)? {
        guard let base = paramOffsets[ref.elementID],
              let element = elements.first(where: { $0.id == ref.elementID }) else { return nil }

        switch (element, ref.position) {
        case (.rectangle, .origin):
            return (params[base], params[base + 1])
        case (.circle, .center):
            return (params[base], params[base + 1])
        case (.lineSegment, .start):
            return (params[base], params[base + 1])
        case (.lineSegment, .end):
            return (params[base + 2], params[base + 3])
        case (.arc, .center):
            return (params[base], params[base + 1])
        case (.arc, .start):
            let cx = params[base], cy = params[base + 1]
            let r = params[base + 2], sa = params[base + 3]
            let rad = sa * .pi / 180
            return (cx + r * cos(rad), cy + r * sin(rad))
        case (.arc, .end):
            let cx = params[base], cy = params[base + 1]
            let r = params[base + 2], sa = params[base + 3], sw = params[base + 4]
            let rad = (sa + sw) * .pi / 180
            return (cx + r * cos(rad), cy + r * sin(rad))
        default:
            return nil
        }
    }

    // MARK: - Error Evaluation

    /// Count total constraint equations.
    static func countErrors(constraints: [SketchConstraint], elements: [SketchElement]) -> Int {
        var count = 0
        for constraint in constraints {
            switch constraint {
            case .coincident: count += 2
            case .horizontal: count += 1
            case .vertical: count += 1
            case .parallel: count += 1
            case .perpendicular: count += 1
            case .tangent: count += 1
            case .equal: count += 1
            case .concentric: count += 2
            case .distance: count += 1
            case .radius: count += 1
            case .angle: count += 1
            case .fixedPoint: count += 2
            }
        }
        return count
    }

    /// Evaluate all constraint error functions. Each constraint contributes one or more
    /// scalar error values — zero when the constraint is satisfied.
    static func evaluateErrors(
        params: [Double],
        constraints: [SketchConstraint],
        elements: [SketchElement],
        paramOffsets: [ElementID: Int]
    ) -> [Double] {
        var errors: [Double] = []

        for constraint in constraints {
            switch constraint {

            case .coincident(_, let p1, let p2):
                guard let (x1, y1) = resolvePointValues(p1, params: params, elements: elements, paramOffsets: paramOffsets),
                      let (x2, y2) = resolvePointValues(p2, params: params, elements: elements, paramOffsets: paramOffsets)
                else {
                    errors.append(contentsOf: [0, 0]); continue
                }
                errors.append(x1 - x2)
                errors.append(y1 - y2)

            case .horizontal(_, let eid):
                guard let base = paramOffsets[eid],
                      let element = elements.first(where: { $0.id == eid }) else {
                    errors.append(0); continue
                }
                switch element {
                case .lineSegment:
                    errors.append(params[base + 1] - params[base + 3]) // start.y - end.y
                default:
                    errors.append(0)
                }

            case .vertical(_, let eid):
                guard let base = paramOffsets[eid],
                      let element = elements.first(where: { $0.id == eid }) else {
                    errors.append(0); continue
                }
                switch element {
                case .lineSegment:
                    errors.append(params[base] - params[base + 2]) // start.x - end.x
                default:
                    errors.append(0)
                }

            case .parallel(_, let eid1, let eid2):
                guard let b1 = paramOffsets[eid1], let b2 = paramOffsets[eid2],
                      let e1 = elements.first(where: { $0.id == eid1 }),
                      let e2 = elements.first(where: { $0.id == eid2 }),
                      case .lineSegment = e1, case .lineSegment = e2 else {
                    errors.append(0); continue
                }
                let dx1 = params[b1 + 2] - params[b1]
                let dy1 = params[b1 + 3] - params[b1 + 1]
                let dx2 = params[b2 + 2] - params[b2]
                let dy2 = params[b2 + 3] - params[b2 + 1]
                // Cross product = 0 for parallel
                errors.append(dx1 * dy2 - dy1 * dx2)

            case .perpendicular(_, let eid1, let eid2):
                guard let b1 = paramOffsets[eid1], let b2 = paramOffsets[eid2],
                      let e1 = elements.first(where: { $0.id == eid1 }),
                      let e2 = elements.first(where: { $0.id == eid2 }),
                      case .lineSegment = e1, case .lineSegment = e2 else {
                    errors.append(0); continue
                }
                let dx1 = params[b1 + 2] - params[b1]
                let dy1 = params[b1 + 3] - params[b1 + 1]
                let dx2 = params[b2 + 2] - params[b2]
                let dy2 = params[b2 + 3] - params[b2 + 1]
                // Dot product = 0 for perpendicular
                errors.append(dx1 * dx2 + dy1 * dy2)

            case .tangent(_, let eid1, let eid2):
                // Line tangent to circle/arc: distance from center to line = radius
                guard let b1 = paramOffsets[eid1], let b2 = paramOffsets[eid2],
                      let e1 = elements.first(where: { $0.id == eid1 }),
                      let e2 = elements.first(where: { $0.id == eid2 }) else {
                    errors.append(0); continue
                }
                if let err = tangentError(e1, b1, e2, b2, params) {
                    errors.append(err)
                } else if let err = tangentError(e2, b2, e1, b1, params) {
                    errors.append(err)
                } else {
                    errors.append(0)
                }

            case .equal(_, let eid1, let eid2):
                guard let b1 = paramOffsets[eid1], let b2 = paramOffsets[eid2],
                      let e1 = elements.first(where: { $0.id == eid1 }),
                      let e2 = elements.first(where: { $0.id == eid2 }) else {
                    errors.append(0); continue
                }
                let size1 = elementSize(e1, base: b1, params: params)
                let size2 = elementSize(e2, base: b2, params: params)
                errors.append(size1 - size2)

            case .concentric(_, let eid1, let eid2):
                guard let b1 = paramOffsets[eid1], let b2 = paramOffsets[eid2] else {
                    errors.append(contentsOf: [0, 0]); continue
                }
                // Both circles/arcs: center params are at base+0, base+1
                errors.append(params[b1] - params[b2])
                errors.append(params[b1 + 1] - params[b2 + 1])

            case .distance(_, let p1, let p2, let value):
                guard let (x1, y1) = resolvePointValues(p1, params: params, elements: elements, paramOffsets: paramOffsets),
                      let (x2, y2) = resolvePointValues(p2, params: params, elements: elements, paramOffsets: paramOffsets)
                else {
                    errors.append(0); continue
                }
                let dx = x1 - x2, dy = y1 - y2
                // Use squared distance error to avoid NaN gradient at dist=0
                let distSq = dx * dx + dy * dy
                errors.append(distSq - value * value)

            case .radius(_, let eid, let value):
                guard let base = paramOffsets[eid],
                      let element = elements.first(where: { $0.id == eid }) else {
                    errors.append(0); continue
                }
                switch element {
                case .circle:
                    errors.append(params[base + 2] - value)
                case .arc:
                    errors.append(params[base + 2] - value)
                default:
                    errors.append(0)
                }

            case .angle(_, let eid1, let eid2, let value):
                guard let b1 = paramOffsets[eid1], let b2 = paramOffsets[eid2],
                      let e1 = elements.first(where: { $0.id == eid1 }),
                      let e2 = elements.first(where: { $0.id == eid2 }),
                      case .lineSegment = e1, case .lineSegment = e2 else {
                    errors.append(0); continue
                }
                let dx1 = params[b1 + 2] - params[b1]
                let dy1 = params[b1 + 3] - params[b1 + 1]
                let dx2 = params[b2 + 2] - params[b2]
                let dy2 = params[b2 + 3] - params[b2 + 1]
                let dot = dx1 * dx2 + dy1 * dy2
                let cross = dx1 * dy2 - dy1 * dx2
                let angleDeg = atan2(cross, dot) * 180 / .pi
                // Normalize angle error to [-180, 180] to handle wraparound
                var err = angleDeg - value
                while err > 180 { err -= 360 }
                while err < -180 { err += 360 }
                errors.append(err)

            case .fixedPoint(_, let p, let fx, let fy):
                guard let (px, py) = resolvePointValues(p, params: params, elements: elements, paramOffsets: paramOffsets)
                else {
                    errors.append(contentsOf: [0, 0]); continue
                }
                errors.append(px - fx)
                errors.append(py - fy)
            }
        }

        return errors
    }

    // MARK: - Tangent Helper

    /// Compute tangent error when e1 is a line and e2 is a circle/arc.
    /// Returns nil if this arrangement doesn't apply.
    private static func tangentError(
        _ eLine: SketchElement, _ bLine: Int,
        _ eCirc: SketchElement, _ bCirc: Int,
        _ params: [Double]
    ) -> Double? {
        guard case .lineSegment = eLine else { return nil }

        let circRadius: Double
        let cx: Double, cy: Double
        switch eCirc {
        case .circle:
            cx = params[bCirc]; cy = params[bCirc + 1]; circRadius = params[bCirc + 2]
        case .arc:
            cx = params[bCirc]; cy = params[bCirc + 1]; circRadius = params[bCirc + 2]
        default:
            return nil
        }

        let sx = params[bLine], sy = params[bLine + 1]
        let ex = params[bLine + 2], ey = params[bLine + 3]
        let dx = ex - sx, dy = ey - sy
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 1e-12 else { return 0 }

        // Signed distance from center to line
        let dist = abs((cy - sy) * dx - (cx - sx) * dy) / len
        return dist - circRadius
    }

    // MARK: - Element Size

    /// Return the characteristic size of an element (length for lines, radius for circles/arcs).
    private static func elementSize(_ element: SketchElement, base: Int, params: [Double]) -> Double {
        switch element {
        case .lineSegment:
            let dx = params[base + 2] - params[base]
            let dy = params[base + 3] - params[base + 1]
            return (dx * dx + dy * dy).squareRoot()
        case .circle, .arc:
            return params[base + 2] // radius
        case .rectangle:
            return params[base + 2] // width
        }
    }

    // MARK: - Jacobian (numerical finite differences)

    static func computeJacobian(
        params: [Double],
        constraints: [SketchConstraint],
        elements: [SketchElement],
        paramOffsets: [ElementID: Int],
        numErrors: Int
    ) -> [Double] {
        let n = params.count
        let eps = 1e-7

        // Row-major: jacobian[errIdx * n + paramIdx]
        var jacobian = [Double](repeating: 0, count: numErrors * n)

        let baseErrors = evaluateErrors(
            params: params, constraints: constraints,
            elements: elements, paramOffsets: paramOffsets
        )

        var perturbedParams = params
        for j in 0..<n {
            let orig = perturbedParams[j]
            perturbedParams[j] = orig + eps

            let perturbedErrors = evaluateErrors(
                params: perturbedParams, constraints: constraints,
                elements: elements, paramOffsets: paramOffsets
            )

            for i in 0..<numErrors {
                jacobian[i * n + j] = (perturbedErrors[i] - baseErrors[i]) / eps
            }

            perturbedParams[j] = orig
        }

        return jacobian
    }

    // MARK: - Linear Algebra

    /// Transpose a row-major matrix.
    static func transpose(_ m: [Double], rows: Int, cols: Int) -> [Double] {
        var result = [Double](repeating: 0, count: rows * cols)
        for i in 0..<rows {
            for j in 0..<cols {
                result[j * rows + i] = m[i * cols + j]
            }
        }
        return result
    }

    /// Row-major matrix multiply: C = A(rows1 x cols1) * B(cols1 x cols2).
    static func matMul(
        _ a: [Double], rows1: Int, cols1: Int,
        _ b: [Double], cols2: Int
    ) -> [Double] {
        var c = [Double](repeating: 0, count: rows1 * cols2)
        for i in 0..<rows1 {
            for k in 0..<cols1 {
                let aik = a[i * cols1 + k]
                for j in 0..<cols2 {
                    c[i * cols2 + j] += aik * b[k * cols2 + j]
                }
            }
        }
        return c
    }

    /// Matrix-vector multiply: result = M(rows x cols) * vec.
    static func matVecMul(_ m: [Double], rows: Int, cols: Int, vec: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: rows)
        for i in 0..<rows {
            var sum = 0.0
            for j in 0..<cols {
                sum += m[i * cols + j] * vec[j]
            }
            result[i] = sum
        }
        return result
    }

    /// Solve A * x = b using Gaussian elimination with partial pivoting.
    /// A is row-major size x size. Returns nil if singular.
    static func solveLinearSystem(_ a: [Double], _ b: [Double], size n: Int) -> [Double]? {
        guard n > 0 else { return [] }

        // Augmented matrix [A | b]
        var aug = [Double](repeating: 0, count: n * (n + 1))
        for i in 0..<n {
            for j in 0..<n {
                aug[i * (n + 1) + j] = a[i * n + j]
            }
            aug[i * (n + 1) + n] = b[i]
        }

        // Forward elimination with partial pivoting
        for col in 0..<n {
            // Find pivot
            var maxVal = abs(aug[col * (n + 1) + col])
            var maxRow = col
            for row in (col + 1)..<n {
                let val = abs(aug[row * (n + 1) + col])
                if val > maxVal {
                    maxVal = val
                    maxRow = row
                }
            }

            // Swap rows
            if maxRow != col {
                for j in 0...(n) {
                    let temp = aug[col * (n + 1) + j]
                    aug[col * (n + 1) + j] = aug[maxRow * (n + 1) + j]
                    aug[maxRow * (n + 1) + j] = temp
                }
            }

            // Add regularization after swap to avoid singularity
            if maxVal < 1e-14 {
                aug[col * (n + 1) + col] += 1e-8
            }

            let pivot = aug[col * (n + 1) + col]
            guard abs(pivot) > 1e-14 else { return nil }

            // Eliminate
            for row in (col + 1)..<n {
                let factor = aug[row * (n + 1) + col] / pivot
                for j in col...(n) {
                    aug[row * (n + 1) + j] -= factor * aug[col * (n + 1) + j]
                }
            }
        }

        // Back substitution
        var x = [Double](repeating: 0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            var sum = aug[i * (n + 1) + n]
            for j in (i + 1)..<n {
                sum -= aug[i * (n + 1) + j] * x[j]
            }
            let diag = aug[i * (n + 1) + i]
            guard abs(diag) > 1e-14 else { return nil }
            x[i] = sum / diag
        }

        return x
    }

    /// Root-mean-square of a vector.
    private static func rms(_ v: [Double]) -> Double {
        guard !v.isEmpty else { return 0 }
        let sumSq = v.reduce(0) { $0 + $1 * $1 }
        return (sumSq / Double(v.count)).squareRoot()
    }
}
