import Foundation
import GeometryKernel
import simd

public final class Evaluator {
    private var globalEnv: Environment
    private var errors: [EvaluationError] = []

    public init() {
        globalEnv = Environment()
    }

    public struct EvalResult {
        public let geometry: GeometryOp
        public let errors: [EvaluationError]
    }

    public func evaluate(program: ASTNode) -> EvalResult {
        errors = []
        globalEnv = Environment()
        let geom = evaluateNode(program, env: globalEnv)
        return EvalResult(geometry: geom, errors: errors)
    }

    // MARK: - Node Evaluation

    private func evaluateNode(_ node: ASTNode, env: Environment) -> GeometryOp {
        switch node {
        case .program(let statements):
            return evaluateStatements(statements, env: env)

        case .block(let statements):
            return evaluateStatements(statements, env: env)

        case .moduleDefinition(let def):
            env.setModule(def.name, def)
            return .empty

        case .functionDefinition(let def):
            env.setFunction(def.name, def)
            return .empty

        case .assignment(let assignment):
            let value = evaluateExpression(assignment.value, env: env)
            env.set(assignment.name, value)
            return .empty

        case .moduleInstantiation(let inst):
            if inst.modifier == .disable { return .empty }
            return evaluateModuleInstantiation(inst, env: env)

        case .ifStatement(let stmt):
            let condition = evaluateExpression(stmt.condition, env: env)
            if condition.asBool {
                return evaluateNode(stmt.thenBranch, env: env)
            } else if let elseBranch = stmt.elseBranch {
                return evaluateNode(elseBranch, env: env)
            }
            return .empty

        case .forStatement(let stmt):
            return evaluateForStatement(stmt, env: env)

        case .letExpression(let letExpr):
            let childEnv = Environment(parent: env)
            for (name, expr) in letExpr.assignments {
                let value = evaluateExpression(expr, env: childEnv)
                childEnv.set(name, value)
            }
            return evaluateNode(letExpr.body, env: childEnv)

        case .useStatement, .includeStatement:
            return .empty

        case .expression:
            return .empty

        case .empty:
            return .empty
        }
    }

    private func evaluateStatements(_ statements: [ASTNode], env: Environment) -> GeometryOp {
        // OpenSCAD: process all assignments first (last assignment wins)
        let childEnv = Environment(parent: env)

        // First pass: collect all assignments
        var assignmentValues: [(String, Expression)] = []
        for stmt in statements {
            if case .assignment(let assignment) = stmt {
                assignmentValues.append((assignment.name, assignment.value))
            }
            if case .moduleDefinition(let def) = stmt {
                childEnv.setModule(def.name, def)
            }
            if case .functionDefinition(let def) = stmt {
                childEnv.setFunction(def.name, def)
            }
        }

        // Last assignment wins for each variable
        var lastAssignments: [String: Expression] = [:]
        for (name, expr) in assignmentValues {
            lastAssignments[name] = expr
        }

        // Evaluate assignments (allowing forward references within same scope)
        for (name, expr) in lastAssignments {
            let value = evaluateExpression(expr, env: childEnv)
            childEnv.set(name, value)
        }

        // Second pass: evaluate geometry-producing statements
        var ops: [GeometryOp] = []
        for stmt in statements {
            switch stmt {
            case .assignment, .moduleDefinition, .functionDefinition:
                continue
            default:
                let op = evaluateNode(stmt, env: childEnv)
                if case .empty = op { continue }
                ops.append(op)
            }
        }

        if ops.isEmpty { return .empty }
        if ops.count == 1 { return ops[0] }
        return .group(ops)
    }

    private func evaluateForStatement(_ stmt: ForStatement, env: Environment) -> GeometryOp {
        let iterable = evaluateExpression(stmt.iterable, env: env)
        var ops: [GeometryOp] = []

        switch iterable {
        case .vector(let values):
            for val in values {
                let loopEnv = Environment(parent: env)
                loopEnv.set(stmt.variable, val)
                let op = evaluateNode(stmt.body, env: loopEnv)
                if case .empty = op { continue }
                ops.append(op)
            }
        case .range(let start, let step, let end):
            let s = step ?? 1.0
            if s > 0 {
                var i = start
                while i <= end + 1e-10 {
                    let loopEnv = Environment(parent: env)
                    loopEnv.set(stmt.variable, .number(i))
                    let op = evaluateNode(stmt.body, env: loopEnv)
                    if case .empty = op {} else { ops.append(op) }
                    i += s
                }
            }
        default:
            break
        }

        if ops.isEmpty { return .empty }
        if ops.count == 1 { return ops[0] }
        return .group(ops)
    }

    // MARK: - Module Instantiation

    private func evaluateModuleInstantiation(_ inst: ModuleInstantiation, env: Environment) -> GeometryOp {
        let args = inst.arguments.map { arg -> (String?, Value) in
            (arg.name, evaluateExpression(arg.value, env: env))
        }

        // Check for user-defined module
        if let moduleDef = env.getModule(inst.name) {
            return evaluateUserModule(moduleDef, args: args, children: inst.children, env: env)
        }

        // Builtin modules
        return evaluateBuiltinModule(inst.name, args: args, children: inst.children, env: env)
    }

    private func evaluateUserModule(_ def: ModuleDefinition, args: [(String?, Value)], children: ASTNode?, env: Environment) -> GeometryOp {
        let moduleEnv = Environment(parent: env)

        // Bind parameters
        for (i, param) in def.parameters.enumerated() {
            var value: Value = .undef
            // Try named argument
            if let namedArg = args.first(where: { $0.0 == param.name }) {
                value = namedArg.1
            } else if i < args.count && args[i].0 == nil {
                value = args[i].1
            } else if let defaultExpr = param.defaultValue {
                value = evaluateExpression(defaultExpr, env: moduleEnv)
            }
            moduleEnv.set(param.name, value)
        }

        // Set $children
        var childCount = 0
        if let children = children {
            if case .block(let stmts) = children {
                childCount = stmts.count
            } else {
                childCount = 1
            }
        }
        moduleEnv.set("$children", .number(Double(childCount)))

        return evaluateNode(def.body, env: moduleEnv)
    }

    private func evaluateBuiltinModule(_ name: String, args: [(String?, Value)], children: ASTNode?, env: Environment) -> GeometryOp {
        switch name {
        case "cube":
            return evaluateCube(args, env: env)
        case "cylinder":
            return evaluateCylinder(args, env: env)
        case "sphere":
            return evaluateSphere(args, env: env)
        case "polyhedron":
            return evaluatePolyhedron(args, env: env)
        case "union":
            return evaluateCSG(.union, children: children, env: env)
        case "difference":
            return evaluateCSG(.difference, children: children, env: env)
        case "intersection":
            return evaluateCSG(.intersection, children: children, env: env)
        case "translate":
            return evaluateTransform(.translate, args: args, children: children, env: env)
        case "rotate":
            return evaluateRotate(args: args, children: children, env: env)
        case "scale":
            return evaluateTransform(.scale, args: args, children: children, env: env)
        case "mirror":
            return evaluateTransform(.mirror, args: args, children: children, env: env)
        case "linear_extrude":
            return evaluateLinearExtrude(args: args, children: children, env: env)
        case "rotate_extrude":
            return evaluateRotateExtrude(args: args, children: children, env: env)
        case "color":
            return evaluateColor(args: args, children: children, env: env)
        case "echo":
            evaluateEcho(args)
            return .empty
        case "assert":
            evaluateAssert(args, env: env)
            return .empty
        case "children":
            // children() is handled at module instantiation level
            return .empty
        case "circle":
            return evaluateCircle(args, env: env)
        case "square":
            return evaluateSquare(args, env: env)
        case "polygon":
            return evaluatePolygon2D(args, env: env)
        default:
            errors.append(.unknownModule(name))
            return .empty
        }
    }

    // MARK: - Primitive Evaluation

    private func evaluateCube(_ args: [(String?, Value)], env: Environment) -> GeometryOp {
        var params = PrimitiveParams()
        params.fn = getSpecialInt("$fn", env: env)
        params.fa = getSpecialFloat("$fa", env: env)
        params.fs = getSpecialFloat("$fs", env: env)

        if let size = getArg(args, positional: 0, named: "size") {
            if let v = size.asDouble {
                params.size = SIMD3<Float>(Float(v), Float(v), Float(v))
            } else if let arr = size.asFloat3 {
                params.size = SIMD3<Float>(arr[0], arr[1], arr[2])
            }
        } else {
            params.size = SIMD3<Float>(1, 1, 1)
        }

        if let center = getArg(args, positional: 1, named: "center") {
            params.center = center.asBool
        }

        return .primitive(.cube, params)
    }

    private func evaluateCylinder(_ args: [(String?, Value)], env: Environment) -> GeometryOp {
        var params = PrimitiveParams()
        params.fn = getSpecialInt("$fn", env: env)
        params.fa = getSpecialFloat("$fa", env: env)
        params.fs = getSpecialFloat("$fs", env: env)

        if let h = getArg(args, positional: 0, named: "h") {
            params.height = h.asFloat ?? 1.0
        } else {
            params.height = 1.0
        }

        if let r = getArg(args, positional: 1, named: "r") {
            params.radius = r.asFloat ?? 1.0
        }
        if let r1 = getArg(args, positional: nil, named: "r1") {
            params.radius1 = r1.asFloat
        }
        if let r2 = getArg(args, positional: nil, named: "r2") {
            params.radius2 = r2.asFloat
        }
        if let d = getArg(args, positional: nil, named: "d") {
            params.radius = (d.asFloat ?? 2.0) / 2.0
        }
        if let d1 = getArg(args, positional: nil, named: "d1") {
            params.radius1 = (d1.asFloat ?? 2.0) / 2.0
        }
        if let d2 = getArg(args, positional: nil, named: "d2") {
            params.radius2 = (d2.asFloat ?? 2.0) / 2.0
        }
        if params.radius == nil && params.radius1 == nil {
            params.radius = 1.0
        }
        if let center = getArg(args, positional: nil, named: "center") {
            params.center = center.asBool
        }

        return .primitive(.cylinder, params)
    }

    private func evaluateSphere(_ args: [(String?, Value)], env: Environment) -> GeometryOp {
        var params = PrimitiveParams()
        params.fn = getSpecialInt("$fn", env: env)
        params.fa = getSpecialFloat("$fa", env: env)
        params.fs = getSpecialFloat("$fs", env: env)

        if let r = getArg(args, positional: 0, named: "r") {
            params.radius = r.asFloat ?? 1.0
        } else if let d = getArg(args, positional: nil, named: "d") {
            params.radius = (d.asFloat ?? 2.0) / 2.0
        } else {
            params.radius = 1.0
        }

        return .primitive(.sphere, params)
    }

    private func evaluatePolyhedron(_ args: [(String?, Value)], env: Environment) -> GeometryOp {
        var params = PrimitiveParams()

        if let pointsVal = getArg(args, positional: 0, named: "points") {
            if case .vector(let pts) = pointsVal {
                params.points = [pts.compactMap { pt -> SIMD3<Float>? in
                    guard let arr = pt.asFloat3 else { return nil }
                    return SIMD3<Float>(arr[0], arr[1], arr[2])
                }]
            }
        }

        if let facesVal = getArg(args, positional: 1, named: "faces") {
            if case .vector(let faces) = facesVal {
                params.faces = faces.compactMap { face -> [Int]? in
                    guard case .vector(let indices) = face else { return nil }
                    return indices.compactMap { idx -> Int? in
                        guard case .number(let n) = idx else { return nil }
                        return Int(n)
                    }
                }
            }
        }

        return .primitive(.polyhedron, params)
    }

    private func evaluateCircle(_ args: [(String?, Value)], env: Environment) -> GeometryOp {
        var params = PrimitiveParams()
        params.fn = getSpecialInt("$fn", env: env)
        params.fa = getSpecialFloat("$fa", env: env)
        params.fs = getSpecialFloat("$fs", env: env)

        if let r = getArg(args, positional: 0, named: "r") {
            params.radius = r.asFloat ?? 1.0
        } else if let d = getArg(args, positional: nil, named: "d") {
            params.radius = (d.asFloat ?? 2.0) / 2.0
        } else {
            params.radius = 1.0
        }
        return .primitive(.circle, params)
    }

    private func evaluateSquare(_ args: [(String?, Value)], env: Environment) -> GeometryOp {
        var params = PrimitiveParams()
        if let size = getArg(args, positional: 0, named: "size") {
            if let v = size.asDouble {
                params.size = SIMD3<Float>(Float(v), Float(v), 0)
            } else if let arr = size.asDoubleArray, arr.count >= 2 {
                params.size = SIMD3<Float>(Float(arr[0]), Float(arr[1]), 0)
            }
        } else {
            params.size = SIMD3<Float>(1, 1, 0)
        }
        if let center = getArg(args, positional: 1, named: "center") {
            params.center = center.asBool
        }
        return .primitive(.square, params)
    }

    private func evaluatePolygon2D(_ args: [(String?, Value)], env: Environment) -> GeometryOp {
        var params = PrimitiveParams()
        if let pointsVal = getArg(args, positional: 0, named: "points") {
            if case .vector(let pts) = pointsVal {
                params.points2D = pts.compactMap { pt -> SIMD2<Float>? in
                    guard let arr = pt.asDoubleArray, arr.count >= 2 else { return nil }
                    return SIMD2<Float>(Float(arr[0]), Float(arr[1]))
                }
            }
        }
        return .primitive(.polygon, params)
    }

    // MARK: - CSG

    private func evaluateCSG(_ type: BooleanType, children: ASTNode?, env: Environment) -> GeometryOp {
        guard let children = children else { return .empty }
        let childOps = evaluateChildren(children, env: env)
        if childOps.isEmpty { return .empty }
        if childOps.count == 1 { return childOps[0] }
        return .boolean(type, childOps)
    }

    // MARK: - Transforms

    private func evaluateTransform(_ type: TransformType, args: [(String?, Value)], children: ASTNode?, env: Environment) -> GeometryOp {
        guard let children = children else { return .empty }
        let childOp = evaluateChildrenAsGroup(children, env: env)
        if case .empty = childOp { return .empty }

        guard let vec = getArg(args, positional: 0, named: "v")?.asFloat3 ??
              getArg(args, positional: 0, named: nil)?.asFloat3 else {
            return childOp
        }

        let params = TransformParams(vector: SIMD3<Float>(vec[0], vec[1], vec[2]))
        return .transform(type, params, childOp)
    }

    private func evaluateRotate(args: [(String?, Value)], children: ASTNode?, env: Environment) -> GeometryOp {
        guard let children = children else { return .empty }
        let childOp = evaluateChildrenAsGroup(children, env: env)
        if case .empty = childOp { return .empty }

        let firstArg = getArg(args, positional: 0, named: "a")
        let axisArg = getArg(args, positional: nil, named: "v")

        if let angle = firstArg?.asDouble, let axis = axisArg?.asFloat3 {
            let params = TransformParams(
                vector: SIMD3<Float>(0, 0, 0),
                angle: Float(angle),
                axis: SIMD3<Float>(axis[0], axis[1], axis[2])
            )
            return .transform(.rotate, params, childOp)
        } else if let vec = firstArg?.asFloat3 {
            let params = TransformParams(vector: SIMD3<Float>(vec[0], vec[1], vec[2]))
            return .transform(.rotate, params, childOp)
        } else if let angle = firstArg?.asDouble {
            let params = TransformParams(
                vector: SIMD3<Float>(0, 0, 0),
                angle: Float(angle),
                axis: SIMD3<Float>(0, 0, 1)
            )
            return .transform(.rotate, params, childOp)
        }

        return childOp
    }

    // MARK: - Extrusions

    private func evaluateLinearExtrude(args: [(String?, Value)], children: ASTNode?, env: Environment) -> GeometryOp {
        guard let children = children else { return .empty }
        let childOp = evaluateChildrenAsGroup(children, env: env)
        if case .empty = childOp { return .empty }

        var params = ExtrudeParams()
        if let h = getArg(args, positional: 0, named: "height") {
            params.height = h.asFloat ?? 1.0
        }
        if let center = getArg(args, positional: nil, named: "center") {
            params.center = center.asBool
        }
        if let twist = getArg(args, positional: nil, named: "twist") {
            params.twist = twist.asFloat ?? 0
        }
        if let scale = getArg(args, positional: nil, named: "scale") {
            if let v = scale.asDouble {
                params.scale = SIMD2<Float>(Float(v), Float(v))
            } else if let arr = scale.asDoubleArray, arr.count >= 2 {
                params.scale = SIMD2<Float>(Float(arr[0]), Float(arr[1]))
            }
        }
        if let slices = getArg(args, positional: nil, named: "slices") {
            params.slices = Int(slices.asDouble ?? 1)
        }
        params.fn = getSpecialInt("$fn", env: env)

        return .extrude(.linear, params, childOp)
    }

    private func evaluateRotateExtrude(args: [(String?, Value)], children: ASTNode?, env: Environment) -> GeometryOp {
        guard let children = children else { return .empty }
        let childOp = evaluateChildrenAsGroup(children, env: env)
        if case .empty = childOp { return .empty }

        var params = ExtrudeParams()
        if let angle = getArg(args, positional: nil, named: "angle") {
            params.angle = angle.asFloat ?? 360
        }
        params.fn = getSpecialInt("$fn", env: env)

        return .extrude(.rotate, params, childOp)
    }

    // MARK: - Color

    private func evaluateColor(args: [(String?, Value)], children: ASTNode?, env: Environment) -> GeometryOp {
        guard let children = children else { return .empty }
        let childOp = evaluateChildrenAsGroup(children, env: env)
        if case .empty = childOp { return .empty }

        var color = SIMD4<Float>(0.8, 0.8, 0.8, 1.0)
        if let colorArg = getArg(args, positional: 0, named: nil) {
            if let arr = colorArg.asDoubleArray {
                if arr.count >= 3 {
                    color = SIMD4<Float>(Float(arr[0]), Float(arr[1]), Float(arr[2]), arr.count >= 4 ? Float(arr[3]) : 1.0)
                }
            } else if let name = colorArg.asString {
                color = namedColor(name)
            }
        }

        return .color(color, childOp)
    }

    private func namedColor(_ name: String) -> SIMD4<Float> {
        switch name.lowercased() {
        case "red": return SIMD4(1, 0, 0, 1)
        case "green": return SIMD4(0, 0.5, 0, 1)
        case "blue": return SIMD4(0, 0, 1, 1)
        case "yellow": return SIMD4(1, 1, 0, 1)
        case "cyan": return SIMD4(0, 1, 1, 1)
        case "magenta": return SIMD4(1, 0, 1, 1)
        case "white": return SIMD4(1, 1, 1, 1)
        case "black": return SIMD4(0, 0, 0, 1)
        case "orange": return SIMD4(1, 0.65, 0, 1)
        case "gray", "grey": return SIMD4(0.5, 0.5, 0.5, 1)
        default: return SIMD4(0.8, 0.8, 0.8, 1)
        }
    }

    // MARK: - Echo/Assert

    private func evaluateEcho(_ args: [(String?, Value)]) {
        let parts = args.map { arg -> String in
            if let name = arg.0 {
                return "\(name) = \(arg.1)"
            }
            return "\(arg.1)"
        }
        print("ECHO: \(parts.joined(separator: ", "))")
    }

    private func evaluateAssert(_ args: [(String?, Value)], env: Environment) {
        guard let condition = args.first?.1 else { return }
        if !condition.asBool {
            let message = args.count > 1 ? (args[1].1.asString ?? "Assertion failed") : "Assertion failed"
            errors.append(.assertionFailed(message))
        }
    }

    // MARK: - Children Helpers

    private func evaluateChildren(_ node: ASTNode, env: Environment) -> [GeometryOp] {
        switch node {
        case .block(let stmts):
            return stmts.compactMap { stmt -> GeometryOp? in
                let op = evaluateNode(stmt, env: env)
                if case .empty = op { return nil }
                return op
            }
        default:
            let op = evaluateNode(node, env: env)
            if case .empty = op { return [] }
            return [op]
        }
    }

    private func evaluateChildrenAsGroup(_ node: ASTNode, env: Environment) -> GeometryOp {
        let ops = evaluateChildren(node, env: env)
        if ops.isEmpty { return .empty }
        if ops.count == 1 { return ops[0] }
        return .group(ops)
    }

    // MARK: - Expression Evaluation

    func evaluateExpression(_ expr: Expression, env: Environment) -> Value {
        switch expr {
        case .number(let n): return .number(n)
        case .string(let s): return .string(s)
        case .boolean(let b): return .boolean(b)
        case .undef: return .undef
        case .identifier(let name): return env.get(name)
        case .specialVariable(let name): return env.getSpecial(name)

        case .unaryOp(let op, let operand):
            return evaluateUnary(op, operand: operand, env: env)

        case .binaryOp(let op, let left, let right):
            return evaluateBinary(op, left: left, right: right, env: env)

        case .ternary(let condition, let thenExpr, let elseExpr):
            return evaluateExpression(condition, env: env).asBool ?
                evaluateExpression(thenExpr, env: env) :
                evaluateExpression(elseExpr, env: env)

        case .functionCall(let name, let args):
            return evaluateFunctionCall(name, args: args, env: env)

        case .listLiteral(let elements):
            return .vector(elements.map { evaluateExpression($0, env: env) })

        case .range(let start, let step, let end):
            let s = evaluateExpression(start, env: env).asDouble ?? 0
            let e = evaluateExpression(end, env: env).asDouble ?? 0
            let st = step.map { evaluateExpression($0, env: env).asDouble ?? 1 }
            return .range(s, st, e)

        case .indexAccess(let array, let index):
            return evaluateIndexAccess(array: array, index: index, env: env)

        case .memberAccess(let object, let member):
            let val = evaluateExpression(object, env: env)
            switch (val, member) {
            case (.vector(let v), "x") where v.count > 0: return v[0]
            case (.vector(let v), "y") where v.count > 1: return v[1]
            case (.vector(let v), "z") where v.count > 2: return v[2]
            default: return .undef
            }

        case .listComprehension(let comp):
            return evaluateListComprehension(comp, env: env)

        case .letInExpression(let assignments, let body):
            let letEnv = Environment(parent: env)
            for (name, valExpr) in assignments {
                letEnv.set(name, evaluateExpression(valExpr, env: letEnv))
            }
            return evaluateExpression(body, env: letEnv)
        }
    }

    private func evaluateUnary(_ op: UnaryOperator, operand: Expression, env: Environment) -> Value {
        let val = evaluateExpression(operand, env: env)
        switch op {
        case .negate:
            if let n = val.asDouble { return .number(-n) }
            if case .vector(let v) = val {
                return .vector(v.map { elem in
                    if let n = elem.asDouble { return .number(-n) }
                    return elem
                })
            }
            return .undef
        case .not:
            return .boolean(!val.asBool)
        case .plus:
            return val
        }
    }

    private func evaluateBinary(_ op: BinaryOperator, left: Expression, right: Expression, env: Environment) -> Value {
        let l = evaluateExpression(left, env: env)
        let r = evaluateExpression(right, env: env)

        // Vector operations
        if case .vector(let lv) = l, case .vector(let rv) = r {
            return vectorBinaryOp(op, lv, rv)
        }
        if case .vector(let lv) = l, let rn = r.asDouble {
            return vectorScalarOp(op, lv, rn)
        }
        if let ln = l.asDouble, case .vector(let rv) = r, op == .multiply {
            return vectorScalarOp(.multiply, rv, ln)
        }

        guard let ln = l.asDouble, let rn = r.asDouble else {
            // String concatenation
            if op == .add, let ls = l.asString, let rs = r.asString {
                return .string(ls + rs)
            }
            // Comparison
            switch op {
            case .equal: return .boolean(l == r)
            case .notEqual: return .boolean(l != r)
            default: return .undef
            }
        }

        switch op {
        case .add: return .number(ln + rn)
        case .subtract: return .number(ln - rn)
        case .multiply: return .number(ln * rn)
        case .divide: return rn == 0 ? .undef : .number(ln / rn)
        case .modulo: return rn == 0 ? .undef : .number(ln.truncatingRemainder(dividingBy: rn))
        case .power: return .number(pow(ln, rn))
        case .lessThan: return .boolean(ln < rn)
        case .greaterThan: return .boolean(ln > rn)
        case .lessEqual: return .boolean(ln <= rn)
        case .greaterEqual: return .boolean(ln >= rn)
        case .equal: return .boolean(ln == rn)
        case .notEqual: return .boolean(ln != rn)
        case .and: return .boolean(l.asBool && r.asBool)
        case .or: return .boolean(l.asBool || r.asBool)
        }
    }

    private func vectorBinaryOp(_ op: BinaryOperator, _ l: [Value], _ r: [Value]) -> Value {
        let count = max(l.count, r.count)
        var result: [Value] = []
        for i in 0..<count {
            let lv = i < l.count ? l[i].asDouble ?? 0 : 0
            let rv = i < r.count ? r[i].asDouble ?? 0 : 0
            switch op {
            case .add: result.append(.number(lv + rv))
            case .subtract: result.append(.number(lv - rv))
            case .multiply: result.append(.number(lv * rv))
            case .divide: result.append(rv == 0 ? .undef : .number(lv / rv))
            default: return .undef
            }
        }
        return .vector(result)
    }

    private func vectorScalarOp(_ op: BinaryOperator, _ v: [Value], _ s: Double) -> Value {
        .vector(v.map { elem in
            guard let n = elem.asDouble else { return Value.undef }
            switch op {
            case .multiply: return .number(n * s)
            case .divide: return s == 0 ? .undef : .number(n / s)
            case .add: return .number(n + s)
            case .subtract: return .number(n - s)
            default: return .undef
            }
        })
    }

    private func evaluateIndexAccess(array: Expression, index: Expression, env: Environment) -> Value {
        let arrVal = evaluateExpression(array, env: env)
        let idxVal = evaluateExpression(index, env: env)

        if case .vector(let v) = arrVal, let idx = idxVal.asDouble {
            let i = Int(idx)
            if i >= 0 && i < v.count { return v[i] }
        }
        if case .string(let s) = arrVal, let idx = idxVal.asDouble {
            let i = Int(idx)
            let chars = Array(s)
            if i >= 0 && i < chars.count { return .string(String(chars[i])) }
        }
        return .undef
    }

    private func evaluateListComprehension(_ comp: ListComprehension, env: Environment) -> Value {
        let iterable = evaluateExpression(comp.iterable, env: env)
        var results: [Value] = []

        let values: [Value]
        switch iterable {
        case .vector(let v): values = v
        case .range(let start, let step, let end):
            let s = step ?? 1.0
            var vals: [Value] = []
            var i = start
            while i <= end + 1e-10 {
                vals.append(.number(i))
                i += s
            }
            values = vals
        default: return .vector([])
        }

        for val in values {
            let loopEnv = Environment(parent: env)
            loopEnv.set(comp.variable, val)
            if let cond = comp.condition {
                let condVal = evaluateExpression(cond, env: loopEnv)
                if !condVal.asBool { continue }
            }
            results.append(evaluateExpression(comp.body, env: loopEnv))
        }

        return .vector(results)
    }

    // MARK: - Builtin Functions

    private func evaluateFunctionCall(_ name: String, args: [Argument], env: Environment) -> Value {
        let evalArgs = args.map { (name: $0.name, value: evaluateExpression($0.value, env: env)) }

        // Check user-defined function
        if let funcDef = env.getFunction(name) {
            let funcEnv = Environment(parent: env)
            for (i, param) in funcDef.parameters.enumerated() {
                if let namedArg = evalArgs.first(where: { $0.name == param.name }) {
                    funcEnv.set(param.name, namedArg.value)
                } else if i < evalArgs.count && evalArgs[i].name == nil {
                    funcEnv.set(param.name, evalArgs[i].value)
                } else if let defaultExpr = param.defaultValue {
                    funcEnv.set(param.name, evaluateExpression(defaultExpr, env: funcEnv))
                }
            }
            return evaluateExpression(funcDef.body, env: funcEnv)
        }

        // Builtin functions
        let vals = evalArgs.map(\.value)
        return evaluateBuiltinFunction(name, args: vals)
    }

    private func evaluateBuiltinFunction(_ name: String, args: [Value]) -> Value {
        switch name {
        // Math functions
        case "abs": return mathFunc(args) { abs($0) }
        case "sign": return mathFunc(args) { $0 > 0 ? 1 : ($0 < 0 ? -1 : 0) }
        case "sin": return mathFunc(args) { sin($0 * .pi / 180) }
        case "cos": return mathFunc(args) { cos($0 * .pi / 180) }
        case "tan": return mathFunc(args) { tan($0 * .pi / 180) }
        case "asin": return mathFunc(args) { asin($0) * 180 / .pi }
        case "acos": return mathFunc(args) { acos($0) * 180 / .pi }
        case "atan": return mathFunc(args) { atan($0) * 180 / .pi }
        case "atan2":
            guard args.count >= 2, let y = args[0].asDouble, let x = args[1].asDouble else { return .undef }
            return .number(atan2(y, x) * 180 / .pi)
        case "floor": return mathFunc(args) { floor($0) }
        case "ceil": return mathFunc(args) { ceil($0) }
        case "round": return mathFunc(args) { ($0).rounded() }
        case "ln": return mathFunc(args) { log($0) }
        case "log": return mathFunc(args) { log10($0) }
        case "pow":
            guard args.count >= 2, let b = args[0].asDouble, let e = args[1].asDouble else { return .undef }
            return .number(pow(b, e))
        case "sqrt": return mathFunc(args) { sqrt($0) }
        case "exp": return mathFunc(args) { exp($0) }
        case "min":
            let nums = args.compactMap(\.asDouble)
            return nums.isEmpty ? .undef : .number(nums.min()!)
        case "max":
            let nums = args.compactMap(\.asDouble)
            return nums.isEmpty ? .undef : .number(nums.max()!)

        // Type functions
        case "len":
            if case .vector(let v) = args.first { return .number(Double(v.count)) }
            if case .string(let s) = args.first { return .number(Double(s.count)) }
            return .undef
        case "str":
            return .string(args.map(\.description).joined())
        case "chr":
            guard let n = args.first?.asDouble else { return .undef }
            return .string(String(UnicodeScalar(Int(n))!))
        case "ord":
            guard let s = args.first?.asString, let c = s.first else { return .undef }
            return .number(Double(c.asciiValue ?? 0))
        case "is_num":
            if case .number = args.first { return .boolean(true) }
            return .boolean(false)
        case "is_string":
            if case .string = args.first { return .boolean(true) }
            return .boolean(false)
        case "is_list":
            if case .vector = args.first { return .boolean(true) }
            return .boolean(false)
        case "is_bool":
            if case .boolean = args.first { return .boolean(true) }
            return .boolean(false)
        case "is_undef":
            if case .undef = args.first { return .boolean(true) }
            return .boolean(false)

        // List functions
        case "concat":
            var result: [Value] = []
            for arg in args {
                if case .vector(let v) = arg {
                    result.append(contentsOf: v)
                } else {
                    result.append(arg)
                }
            }
            return .vector(result)

        case "lookup":
            guard args.count >= 2, let key = args[0].asDouble, case .vector(let table) = args[1] else { return .undef }
            return lookupInTable(key, table: table)

        case "search":
            return .vector([]) // Simplified

        // Vector math
        case "cross":
            guard args.count >= 2,
                  let a = args[0].asDoubleArray, a.count >= 3,
                  let b = args[1].asDoubleArray, b.count >= 3 else { return .undef }
            return .vector([
                .number(a[1]*b[2] - a[2]*b[1]),
                .number(a[2]*b[0] - a[0]*b[2]),
                .number(a[0]*b[1] - a[1]*b[0])
            ])

        case "norm":
            guard let v = args.first?.asDoubleArray else { return .undef }
            return .number(sqrt(v.reduce(0) { $0 + $1*$1 }))

        case "each":
            return args.first ?? .undef

        default:
            errors.append(.unknownFunction(name))
            return .undef
        }
    }

    private func mathFunc(_ args: [Value], _ fn: (Double) -> Double) -> Value {
        guard let n = args.first?.asDouble else { return .undef }
        return .number(fn(n))
    }

    private func lookupInTable(_ key: Double, table: [Value]) -> Value {
        var pairs: [(Double, Double)] = []
        for entry in table {
            if case .vector(let v) = entry, v.count >= 2, let k = v[0].asDouble, let val = v[1].asDouble {
                pairs.append((k, val))
            }
        }
        pairs.sort { $0.0 < $1.0 }
        guard !pairs.isEmpty else { return .undef }
        if key <= pairs.first!.0 { return .number(pairs.first!.1) }
        if key >= pairs.last!.0 { return .number(pairs.last!.1) }
        for i in 0..<(pairs.count - 1) {
            if key >= pairs[i].0 && key <= pairs[i+1].0 {
                let t = (key - pairs[i].0) / (pairs[i+1].0 - pairs[i].0)
                return .number(pairs[i].1 + t * (pairs[i+1].1 - pairs[i].1))
            }
        }
        return .undef
    }

    // MARK: - Argument Helpers

    private func getArg(_ args: [(String?, Value)], positional: Int?, named: String?) -> Value? {
        if let name = named {
            if let val = args.first(where: { $0.0 == name }) { return val.1 }
        }
        if let pos = positional, pos < args.count && args[pos].0 == nil {
            return args[pos].1
        }
        return nil
    }

    private func getSpecialInt(_ name: String, env: Environment) -> Int {
        Int(env.getSpecial(name).asDouble ?? 0)
    }

    private func getSpecialFloat(_ name: String, env: Environment) -> Float {
        Float(env.getSpecial(name).asDouble ?? (name == "$fa" ? 12 : 2))
    }
}

// MARK: - Evaluation Errors

public enum EvaluationError: Error, CustomStringConvertible {
    case unknownModule(String)
    case unknownFunction(String)
    case assertionFailed(String)
    case typeError(String)

    public var description: String {
        switch self {
        case .unknownModule(let name): return "Unknown module: \(name)"
        case .unknownFunction(let name): return "Unknown function: \(name)"
        case .assertionFailed(let msg): return "Assertion failed: \(msg)"
        case .typeError(let msg): return "Type error: \(msg)"
        }
    }
}
