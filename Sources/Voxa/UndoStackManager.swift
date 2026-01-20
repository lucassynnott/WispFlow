import Foundation

// MARK: - Undo Stack Manager
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ US-026: Full Undo Stack for Transcriptions                                   ║
// ║ US-027: Multiple Undo Levels with Configurable History Depth & Redo          ║
// ║                                                                              ║
// ║ Tracks transcription insertions to enable Cmd+Z undo functionality:          ║
// ║ - Maintains a stack of recent insertions with text and character counts      ║
// ║ - Supports undo across different applications                                ║
// ║ - Provides character count for deletion simulation                           ║
// ║ - US-027: Configurable history depth with redo support                       ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// Data model for an undo entry representing an inserted transcription
struct UndoEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let characterCount: Int
    let timestamp: Date

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.characterCount = text.count
        self.timestamp = Date()
    }
}

/// Manager for tracking transcription insertions for undo functionality
/// Thread-safe singleton pattern
@MainActor
final class UndoStackManager: ObservableObject {
    // MARK: - Singleton

    static let shared = UndoStackManager()

    // MARK: - Constants

    private enum Constants {
        static let defaultMaxUndoLevels = 20 // Default undo history depth
        static let minUndoLevels = 5 // Minimum configurable depth
        static let maxUndoLevels = 100 // Maximum configurable depth
        static let undoTimeoutSeconds: TimeInterval = 300 // 5 minutes - entries older than this are cleared
        static let maxUndoLevelsKey = "undoHistoryMaxLevels"
    }

    // MARK: - Published Properties

    /// Current undo stack (newest first)
    @Published private(set) var undoStack: [UndoEntry] = []

    /// US-027: Redo stack for entries that have been undone
    @Published private(set) var redoStack: [UndoEntry] = []

    /// US-027: Configurable maximum undo history depth
    @Published var maxUndoLevels: Int {
        didSet {
            // Clamp to valid range
            let clamped = max(Constants.minUndoLevels, min(Constants.maxUndoLevels, maxUndoLevels))
            if clamped != maxUndoLevels {
                maxUndoLevels = clamped
            }
            // Save to UserDefaults
            UserDefaults.standard.set(maxUndoLevels, forKey: Constants.maxUndoLevelsKey)
            // Trim stacks if needed
            trimStacks()
            print("UndoStackManager: [US-027] Max undo levels set to \(maxUndoLevels)")
        }
    }

    /// Whether there's an entry available to undo
    var canUndo: Bool {
        return !undoStack.isEmpty
    }

    /// US-027: Whether there's an entry available to redo
    var canRedo: Bool {
        return !redoStack.isEmpty
    }

    /// The most recent entry that can be undone
    var topEntry: UndoEntry? {
        return undoStack.first
    }

    /// US-027: The most recent entry that can be redone
    var topRedoEntry: UndoEntry? {
        return redoStack.first
    }

    /// US-027: Range for configurable undo levels
    static var undoLevelsRange: ClosedRange<Int> {
        return Constants.minUndoLevels...Constants.maxUndoLevels
    }

    // MARK: - Initialization

    private init() {
        // Load saved max undo levels from UserDefaults
        let savedLevels = UserDefaults.standard.integer(forKey: Constants.maxUndoLevelsKey)
        self.maxUndoLevels = savedLevels > 0 ? savedLevels : Constants.defaultMaxUndoLevels
        print("UndoStackManager: [US-027] Initialized with maxUndoLevels=\(self.maxUndoLevels)")
    }

    // MARK: - Public Methods

    /// Record a new transcription insertion for potential undo
    /// - Parameter text: The text that was inserted
    func recordInsertion(_ text: String) {
        // Skip empty text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let entry = UndoEntry(text: text)

        // Add to stack (newest first)
        undoStack.insert(entry, at: 0)

        // US-027: Clear redo stack when new insertion is recorded (standard undo/redo behavior)
        redoStack.removeAll()

        // Trim stacks to configured max
        trimStacks()

        // Clean up old entries
        cleanupOldEntries()

        print("UndoStackManager: [US-027] Recorded insertion - \(entry.characterCount) characters, undo stack: \(undoStack.count), redo stack: \(redoStack.count)")
    }

    /// Pop the most recent entry from the stack and move it to redo stack (after successful undo)
    /// - Returns: The entry that was removed, or nil if stack is empty
    @discardableResult
    func popTopEntry() -> UndoEntry? {
        guard !undoStack.isEmpty else {
            return nil
        }

        let entry = undoStack.removeFirst()

        // US-027: Move to redo stack for potential redo
        redoStack.insert(entry, at: 0)
        trimStacks()

        print("UndoStackManager: [US-027] Popped entry to redo - \(entry.characterCount) characters, undo: \(undoStack.count), redo: \(redoStack.count)")
        return entry
    }

    /// US-027: Pop from redo stack to perform redo
    /// - Returns: The entry to redo, or nil if redo stack is empty
    @discardableResult
    func popRedoEntry() -> UndoEntry? {
        guard !redoStack.isEmpty else {
            return nil
        }

        let entry = redoStack.removeFirst()

        // Move back to undo stack
        undoStack.insert(entry, at: 0)
        trimStacks()

        print("UndoStackManager: [US-027] Popped redo entry - \(entry.characterCount) characters, undo: \(undoStack.count), redo: \(redoStack.count)")
        return entry
    }

    /// Clear the entire undo and redo stacks
    func clearStack() {
        undoStack.removeAll()
        redoStack.removeAll()
        print("UndoStackManager: [US-027] Stacks cleared")
    }

    /// US-027: Reset to default settings
    func resetToDefaults() {
        maxUndoLevels = Constants.defaultMaxUndoLevels
        print("UndoStackManager: [US-027] Reset to defaults (maxUndoLevels=\(maxUndoLevels))")
    }

    // MARK: - Private Methods

    /// US-027: Trim both stacks to the configured max size
    private func trimStacks() {
        if undoStack.count > maxUndoLevels {
            undoStack = Array(undoStack.prefix(maxUndoLevels))
        }
        if redoStack.count > maxUndoLevels {
            redoStack = Array(redoStack.prefix(maxUndoLevels))
        }
    }

    /// Remove entries older than the timeout threshold
    private func cleanupOldEntries() {
        let cutoffDate = Date().addingTimeInterval(-Constants.undoTimeoutSeconds)
        let undoBeforeCount = undoStack.count
        undoStack.removeAll { $0.timestamp < cutoffDate }

        let redoBeforeCount = redoStack.count
        redoStack.removeAll { $0.timestamp < cutoffDate }

        let totalCleaned = (undoBeforeCount - undoStack.count) + (redoBeforeCount - redoStack.count)
        if totalCleaned > 0 {
            print("UndoStackManager: [US-027] Cleaned up \(totalCleaned) old entries")
        }
    }
}
