import Foundation

/// Snapshot-based undo/redo stack for the feature tree.
/// Each mutation pushes a snapshot. Undo/redo navigates through snapshots.
///
/// Memory: Feature trees are small value types.
/// 50 features x 100 undo levels < 1MB. No command pattern needed.
public final class UndoStack: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshots: [FeatureTree] = []
    private var currentIndex: Int = -1
    private let maxSnapshots: Int

    public init(maxSnapshots: Int = 100) {
        self.maxSnapshots = maxSnapshots
    }

    /// Push a new snapshot, discarding any redo states beyond current.
    public func push(_ tree: FeatureTree) {
        lock.lock()
        defer { lock.unlock() }

        // Discard redo history
        if currentIndex < snapshots.count - 1 {
            snapshots.removeSubrange((currentIndex + 1)...)
        }

        snapshots.append(tree)

        // Enforce max snapshots
        if snapshots.count > maxSnapshots {
            snapshots.removeFirst()
        }

        currentIndex = snapshots.count - 1
    }

    /// Undo: return the previous snapshot, or nil if at the beginning.
    public func undo() -> FeatureTree? {
        lock.lock()
        defer { lock.unlock() }

        guard currentIndex > 0 else { return nil }
        currentIndex -= 1
        return snapshots[currentIndex]
    }

    /// Redo: return the next snapshot, or nil if at the end.
    public func redo() -> FeatureTree? {
        lock.lock()
        defer { lock.unlock() }

        guard currentIndex < snapshots.count - 1 else { return nil }
        currentIndex += 1
        return snapshots[currentIndex]
    }

    public var canUndo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentIndex > 0
    }

    public var canRedo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentIndex < snapshots.count - 1
    }

    /// Reset the stack (e.g., when loading a new document).
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        snapshots.removeAll()
        currentIndex = -1
    }

    public var snapshotCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return snapshots.count
    }
}
