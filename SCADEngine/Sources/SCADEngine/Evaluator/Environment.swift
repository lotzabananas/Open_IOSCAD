import Foundation

/// OpenSCAD value type
public enum Value: Equatable, Sendable, CustomStringConvertible {
    case number(Double)
    case string(String)
    case boolean(Bool)
    case vector([Value])
    case undef
    case range(Double, Double?, Double) // start, step?, end

    public var description: String {
        switch self {
        case .number(let n): return "\(n)"
        case .string(let s): return "\"\(s)\""
        case .boolean(let b): return b ? "true" : "false"
        case .vector(let v): return "[\(v.map(\.description).joined(separator: ", "))]"
        case .undef: return "undef"
        case .range(let start, let step, let end):
            if let step = step { return "[\(start):\(step):\(end)]" }
            return "[\(start):\(end)]"
        }
    }

    public var asDouble: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    public var asFloat: Float? {
        if case .number(let n) = self { return Float(n) }
        return nil
    }

    public var asBool: Bool {
        switch self {
        case .boolean(let b): return b
        case .number(let n): return n != 0
        case .string(let s): return !s.isEmpty
        case .vector(let v): return !v.isEmpty
        case .undef: return false
        case .range: return true
        }
    }

    public var asString: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var asVector: [Value]? {
        if case .vector(let v) = self { return v }
        return nil
    }

    public var asDoubleArray: [Double]? {
        guard case .vector(let v) = self else { return nil }
        return v.compactMap(\.asDouble)
    }

    public var asFloat3: [Float]? {
        guard let arr = asDoubleArray, arr.count >= 3 else { return nil }
        return arr.prefix(3).map { Float($0) }
    }
}

/// OpenSCAD scoping environment
public final class Environment {
    private var variables: [String: Value] = [:]
    private var functions: [String: FunctionDefinition] = [:]
    private var modules: [String: ModuleDefinition] = [:]
    public let parent: Environment?

    public init(parent: Environment? = nil) {
        self.parent = parent
    }

    public func get(_ name: String) -> Value {
        if let val = variables[name] { return val }
        return parent?.get(name) ?? .undef
    }

    public func set(_ name: String, _ value: Value) {
        variables[name] = value
    }

    public func getFunction(_ name: String) -> FunctionDefinition? {
        if let f = functions[name] { return f }
        return parent?.getFunction(name)
    }

    public func setFunction(_ name: String, _ def: FunctionDefinition) {
        functions[name] = def
    }

    public func getModule(_ name: String) -> ModuleDefinition? {
        if let m = modules[name] { return m }
        return parent?.getModule(name)
    }

    public func setModule(_ name: String, _ def: ModuleDefinition) {
        modules[name] = def
    }

    /// OpenSCAD special variable lookup (dynamic scoping - search up the call stack)
    public func getSpecial(_ name: String) -> Value {
        if let val = variables[name] { return val }
        return parent?.getSpecial(name) ?? defaultSpecialVariable(name)
    }

    private func defaultSpecialVariable(_ name: String) -> Value {
        switch name {
        case "$fn": return .number(0)
        case "$fa": return .number(12)
        case "$fs": return .number(2)
        case "$t": return .number(0)
        case "$children": return .number(0)
        default: return .undef
        }
    }

    /// Collect all assignments from a scope (for OpenSCAD "last assignment wins" semantics)
    public func collectLastAssignments(from statements: [ASTNode]) {
        // First pass: collect all assignments (last one wins per variable)
        var lastAssignments: [String: Value] = [:]
        for stmt in statements {
            if case .assignment(let assignment) = stmt {
                // We can't evaluate here - just mark that assignment exists
                _ = assignment
            }
        }
        // Actual evaluation happens in the evaluator
        _ = lastAssignments
    }
}
