import AppKit
import Foundation

/// Manages text insertion into the active application using pasteboard and simulated keystrokes
/// Requires accessibility permissions to simulate Cmd+V keystroke
@MainActor
final class TextInserter: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide access
    /// US-701: Added for SettingsContentView in MainWindow
    static let shared = TextInserter()

    // MARK: - Types

    /// Insertion result
    enum InsertionResult {
        case success
        case noAccessibilityPermission
        case insertionFailed(String)
        /// US-515: Paste simulation failed but text is on clipboard for manual paste
        case fallbackToManualPaste(String)
    }

    /// Insertion status for UI feedback
    enum InsertionStatus: Equatable {
        case idle
        case inserting
        case completed
        case error(String)
    }

    /// US-029: Insertion mode options for text insertion
    /// Determines how transcribed text is inserted into applications
    enum InsertionMode: String, CaseIterable, Identifiable {
        case paste = "paste"
        case type = "type"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .paste: return "Paste (⌘V)"
            case .type: return "Type (Keystrokes)"
            }
        }

        var description: String {
            switch self {
            case .paste: return "Copies text to clipboard and simulates Cmd+V paste. Works in all applications."
            case .type: return "Simulates individual keystrokes. Better for apps that handle paste differently."
            }
        }

        var icon: String {
            switch self {
            case .paste: return "doc.on.clipboard"
            case .type: return "keyboard"
            }
        }

        var features: [String] {
            switch self {
            case .paste: return ["Universal compatibility", "Fast insertion", "Reliable"]
            case .type: return ["Character-by-character", "Native input feel", "No clipboard use"]
            }
        }
    }

    /// US-028: Paste format options for text insertion
    /// Determines how transcribed text is formatted when pasted
    enum PasteFormat: String, CaseIterable, Identifiable {
        case plainText = "plain_text"
        case richText = "rich_text"
        case markdown = "markdown"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .plainText: return "Plain Text"
            case .richText: return "Rich Text"
            case .markdown: return "Markdown"
            }
        }

        var description: String {
            switch self {
            case .plainText: return "Simple text without any formatting"
            case .richText: return "Formatted text with basic styling (bold, italic)"
            case .markdown: return "Text formatted using Markdown syntax"
            }
        }

        var icon: String {
            switch self {
            case .plainText: return "doc.plaintext"
            case .richText: return "doc.richtext"
            case .markdown: return "text.badge.checkmark"
            }
        }
    }
    
    // MARK: - Constants

    private struct Constants {
        static let preserveClipboardKey = "preserveClipboard"
        static let clipboardRestoreDelayKey = "clipboardRestoreDelay"
        // US-028: Paste format preference key
        static let pasteFormatKey = "pasteFormat"
        // US-029: Insertion mode preference key
        static let insertionModeKey = "insertionMode"
        static let defaultRestoreDelay: Double = 0.8  // US-513: 800ms as per acceptance criteria
        static let keystrokeDelay: UInt32 = 10_000    // US-514: 10ms in microseconds between key down and key up
        static let typeKeystrokeDelay: UInt32 = 5_000 // US-029: 5ms between keystrokes in type mode
        static let pasteboardReadyDelay: UInt32 = 50_000  // 50ms to ensure pasteboard is ready before paste
        static let permissionPollingInterval: TimeInterval = 1.0  // 1 second polling
    }
    
    // MARK: - Properties
    
    /// Whether to preserve and restore clipboard contents after insertion
    @Published var preserveClipboard: Bool {
        didSet {
            UserDefaults.standard.set(preserveClipboard, forKey: Constants.preserveClipboardKey)
        }
    }
    
    /// Delay before restoring clipboard contents (in seconds)
    @Published var clipboardRestoreDelay: Double {
        didSet {
            UserDefaults.standard.set(clipboardRestoreDelay, forKey: Constants.clipboardRestoreDelayKey)
        }
    }

    /// US-028: Selected paste format for text insertion
    /// Determines how transcribed text is formatted when pasted
    @Published var selectedPasteFormat: PasteFormat {
        didSet {
            UserDefaults.standard.set(selectedPasteFormat.rawValue, forKey: Constants.pasteFormatKey)
        }
    }

    /// US-029: Selected insertion mode (paste or type)
    /// Determines how transcribed text is inserted into applications
    @Published var selectedInsertionMode: InsertionMode {
        didSet {
            UserDefaults.standard.set(selectedInsertionMode.rawValue, forKey: Constants.insertionModeKey)
        }
    }

    /// Current insertion status
    @Published private(set) var insertionStatus: InsertionStatus = .idle
    
    /// Status message for UI display
    @Published private(set) var statusMessage: String = "Ready"
    
    /// Current accessibility permission status (updated reactively)
    @Published private(set) var hasAccessibilityPermission: Bool = false
    
    // MARK: - Callbacks
    
    /// Called when insertion completes successfully
    var onInsertionComplete: (() -> Void)?
    
    /// Called when an error occurs
    var onError: ((String) -> Void)?
    
    /// Called when permission status changes from denied to granted
    var onPermissionGranted: (() -> Void)?
    
    // MARK: - Private Properties
    
    /// Stored clipboard contents for restoration
    private var savedClipboardItems: [NSPasteboardItem]?
    
    /// Timer for polling permission status when not granted
    private var permissionPollingTimer: Timer?
    
    /// Observer for app activation to re-check permissions
    private var appActivationObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    init() {
        // Load saved preferences
        preserveClipboard = UserDefaults.standard.object(forKey: Constants.preserveClipboardKey) as? Bool ?? true
        clipboardRestoreDelay = UserDefaults.standard.object(forKey: Constants.clipboardRestoreDelayKey) as? Double ?? Constants.defaultRestoreDelay

        // US-028: Load saved paste format preference (default to plain text)
        if let savedFormat = UserDefaults.standard.string(forKey: Constants.pasteFormatKey),
           let format = PasteFormat(rawValue: savedFormat) {
            selectedPasteFormat = format
        } else {
            selectedPasteFormat = .plainText
        }

        // US-029: Load saved insertion mode preference (default to paste)
        if let savedMode = UserDefaults.standard.string(forKey: Constants.insertionModeKey),
           let mode = InsertionMode(rawValue: savedMode) {
            selectedInsertionMode = mode
        } else {
            selectedInsertionMode = .paste
        }

        // Check initial permission status
        hasAccessibilityPermission = AXIsProcessTrusted()

        // Set up app activation observer to re-check permissions when user returns from System Settings
        setupAppActivationObserver()

        // NOTE: Disabled automatic polling to prevent potential main thread blocking
        // Permissions will be refreshed when app becomes active or manually checked
        // if !hasAccessibilityPermission {
        //     startPermissionPolling()
        // }

        print("TextInserter initialized (preserveClipboard: \(preserveClipboard), restoreDelay: \(clipboardRestoreDelay)s, pasteFormat: \(selectedPasteFormat.rawValue), insertionMode: \(selectedInsertionMode.rawValue), permission: \(hasAccessibilityPermission))")
    }
    
    deinit {
        // Invalidate timer directly without calling the main actor method
        permissionPollingTimer?.invalidate()
        if let observer = appActivationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Permission Monitoring
    
    /// Set up observer for app activation to re-check permissions
    private func setupAppActivationObserver() {
        appActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Use Task to safely dispatch to MainActor
            Task { @MainActor in
                self?.recheckPermission()
            }
        }
    }
    
    /// Start polling for permission status
    private func startPermissionPolling() {
        guard permissionPollingTimer == nil else { return }
        
        print("TextInserter: Starting permission polling (every \(Constants.permissionPollingInterval)s)")
        
        // Timer fires on main thread, use Task to dispatch to MainActor
        permissionPollingTimer = Timer.scheduledTimer(withTimeInterval: Constants.permissionPollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recheckPermission()
            }
        }
    }
    
    /// Stop polling for permission status
    private func stopPermissionPolling() {
        if let timer = permissionPollingTimer {
            timer.invalidate()
            permissionPollingTimer = nil
            print("TextInserter: Stopped permission polling")
        }
    }
    
    /// Re-check accessibility permission status (fresh check, not cached)
    func recheckPermission() {
        let previousStatus = hasAccessibilityPermission
        let currentStatus = AXIsProcessTrusted()
        
        if currentStatus != previousStatus {
            hasAccessibilityPermission = currentStatus
            print("TextInserter: Permission status changed: \(previousStatus) -> \(currentStatus)")
            
            if currentStatus {
                // Permission was just granted
                stopPermissionPolling()
                onPermissionGranted?()
            } else {
                // Permission was revoked (rare but possible)
                startPermissionPolling()
            }
        }
    }
    
    // MARK: - Accessibility Permissions
    
    /// Request accessibility permissions
    /// - Parameter showPrompt: If true, shows the system prompt for enabling accessibility
    /// - Returns: True if permissions are already granted
    func requestAccessibilityPermission(showPrompt: Bool = true) -> Bool {
        let options: [String: Any]
        if showPrompt {
            // AXIsProcessTrustedWithOptions with kAXTrustedCheckOptionPrompt shows the SYSTEM dialog
            // We should NOT show our own alert on top of it
            options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        } else {
            options = [:]
        }
        
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !trusted {
            print("Accessibility permission not granted")
            // NOTE: Don't show our own alert - the system dialog is already shown (if showPrompt=true)
            // or onboarding/settings will guide the user
        }
        
        return trusted
    }
    
    /// Open System Settings to the Accessibility pane
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Text Insertion
    
    /// Insert text into the active application
    /// - Parameter text: The text to insert
    /// - Returns: The result of the insertion attempt
    func insertText(_ text: String) async -> InsertionResult {
        // US-507: Check accessibility permission first and prompt automatically if needed
        // If not granted, use PermissionManager for consistent prompting behavior
        if !hasAccessibilityPermission {
            print("TextInserter: [US-507] No accessibility permission on first text insertion attempt")
            
            // Use PermissionManager for automatic prompting (shows system dialog)
            // This ensures consistent behavior with microphone permission prompting
            _ = PermissionManager.shared.requestAccessibilityPermission()
            
            // Re-check our local status after the prompt
            recheckPermission()
            
            if !hasAccessibilityPermission {
                print("TextInserter: [US-507] Accessibility permission still not granted after prompt")
                insertionStatus = .error("Accessibility permission required")
                statusMessage = "Please grant accessibility permission in System Settings"
                onError?("Accessibility permission required")
                return .noAccessibilityPermission
            }
            
            print("TextInserter: [US-507] Accessibility permission granted, proceeding with insertion")
        }
        
        insertionStatus = .inserting
        statusMessage = "Inserting text..."

        // US-029: Route to appropriate insertion method based on selected mode
        let simulationResult: InsertionResult

        switch selectedInsertionMode {
        case .paste:
            simulationResult = await insertTextViaPaste(text)
        case .type:
            simulationResult = simulateTyping(text)
        }
        
        switch simulationResult {
        case .success:
            insertionStatus = .completed
            statusMessage = "Text inserted successfully"
            print("TextInserter: Text inserted successfully")
            onInsertionComplete?()

            // Restore clipboard if needed (with delay) - only applies to paste mode
            if selectedInsertionMode == .paste && preserveClipboard {
                scheduleClipboardRestore()
            }
            return .success

        case .insertionFailed(let message):
            // US-029: Handle failure differently based on insertion mode
            if selectedInsertionMode == .paste {
                // US-515: Fallback - text is already on clipboard, show toast for manual paste
                print("TextInserter: [US-515] Paste simulation failed, falling back to manual paste")
                print("TextInserter: [US-515] Error details: \(message)")

                // Log detailed error
                logSimulationError(message, phase: "pasteSimulation")

                // Update status to indicate fallback
                insertionStatus = .error("Paste failed - use Cmd+V manually")
                statusMessage = "Text copied - press Cmd+V to paste"

                // US-515: Show toast notification to user
                // Text is already on clipboard from the earlier setString call
                DispatchQueue.main.async {
                    ToastManager.shared.showManualPasteRequired()
                }

                // US-515: Do NOT restore original clipboard - user needs to paste manually
                // Clear the saved items so they don't get restored
                savedClipboardItems = nil

                // Notify error handler but with context that fallback is in effect
                onError?("Paste simulation failed - text copied to clipboard for manual paste")

                return .fallbackToManualPaste(message)
            } else {
                // US-029: Type mode failure - no clipboard fallback available
                print("TextInserter: [US-029] Type mode insertion failed: \(message)")
                logSimulationError(message, phase: "typeSimulation")

                insertionStatus = .error("Typing failed")
                statusMessage = "Failed to type text"
                onError?("Type simulation failed: \(message)")

                return .insertionFailed(message)
            }
            
        case .noAccessibilityPermission:
            // Should not happen since we checked above
            return .noAccessibilityPermission
            
        case .fallbackToManualPaste:
            // Should not happen from simulatePaste()
            return simulationResult
        }
    }
    
    /// US-514: Simulate Cmd+V (paste) keystroke using CGEvent
    /// US-515: Returns detailed error information for fallback handling
    /// 
    /// Implementation details per US-514 acceptance criteria:
    /// - Uses CGEvent for key simulation (not AppleScript)
    /// - Key down event with Command modifier
    /// - Small delay between down and up (10ms)
    /// - Key up event with Command modifier  
    /// - Events posted to HID event tap location (.cghidEventTap)
    /// - Works in all applications including Electron apps
    ///
    /// The virtual key code 0x09 corresponds to 'V' on ANSI keyboards (kVK_ANSI_V).
    /// CGEvent posting at .cghidEventTap level ensures events are processed by the
    /// window server and delivered to any focused application, including:
    /// - Native macOS apps (AppKit, SwiftUI)
    /// - Electron-based apps (VS Code, Slack, Discord, etc.)
    /// - Cross-platform apps (Java, Qt, etc.)
    ///
    /// US-515: If simulation fails, returns a detailed error for fallback handling
    private func simulatePaste() -> InsertionResult {
        print("TextInserter: [US-514] Simulating Cmd+V using CGEvent")
        
        // US-514: Create key down event for 'V' with Command modifier
        // Virtual key code 0x09 = kVK_ANSI_V (the 'V' key on ANSI keyboards)
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) else {
            let errorMsg = "Failed to create key down event - CGEvent initialization returned nil"
            print("TextInserter: [US-515] \(errorMsg)")
            logSimulationError(errorMsg, phase: "keyDownCreation")
            return .insertionFailed(errorMsg)
        }
        
        // US-514: Create key up event for 'V'
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else {
            let errorMsg = "Failed to create key up event - CGEvent initialization returned nil"
            print("TextInserter: [US-515] \(errorMsg)")
            logSimulationError(errorMsg, phase: "keyUpCreation")
            return .insertionFailed(errorMsg)
        }
        
        // US-514: Set Command modifier flag on both events
        keyDownEvent.flags = .maskCommand
        keyUpEvent.flags = .maskCommand
        
        // US-514: Post key down event to HID event tap location
        // .cghidEventTap ensures events are processed like real keyboard input,
        // making it work in all applications including Electron apps
        keyDownEvent.post(tap: .cghidEventTap)
        
        // US-514: Small delay between key down and key up (10ms)
        // This delay ensures the target application properly registers the key press
        usleep(Constants.keystrokeDelay)  // 10,000 microseconds = 10ms
        
        // US-514: Post key up event to HID event tap location
        keyUpEvent.post(tap: .cghidEventTap)
        
        print("TextInserter: [US-514] Cmd+V simulated successfully via CGEvent at .cghidEventTap")
        return .success
    }

    // MARK: - US-029: Paste Mode Insertion

    /// US-029: Insert text using paste mode (clipboard + Cmd+V)
    /// This is the original insertion method, now wrapped for mode selection
    private func insertTextViaPaste(_ text: String) async -> InsertionResult {
        print("TextInserter: [US-029] Using paste mode insertion")

        // Save current clipboard if needed
        if preserveClipboard {
            saveClipboardContents()
        }

        // US-028: Copy text to pasteboard using selected format
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = setPasteboardContent(text, pasteboard: pasteboard)

        guard success else {
            return .insertionFailed("Failed to copy text to clipboard")
        }

        // Small delay to ensure pasteboard is ready before simulating paste
        usleep(Constants.pasteboardReadyDelay)

        // Simulate Cmd+V keystroke
        return simulatePaste()
    }

    // MARK: - US-029: Type Mode Insertion

    /// US-029: Insert text using type mode (simulated keystrokes)
    /// Simulates individual key presses for each character in the text
    /// This method doesn't use the clipboard at all
    private func simulateTyping(_ text: String) -> InsertionResult {
        print("TextInserter: [US-029] Using type mode insertion for \(text.count) characters")

        for (index, character) in text.enumerated() {
            let result = simulateCharacterKeystroke(character)
            if case .insertionFailed(let message) = result {
                print("TextInserter: [US-029] Type mode failed at character \(index): \(message)")
                return result
            }

            // Small delay between keystrokes for reliability
            if index < text.count - 1 {
                usleep(Constants.typeKeystrokeDelay)
            }
        }

        print("TextInserter: [US-029] Type mode insertion completed successfully")
        return .success
    }

    /// US-029: Simulate a single character keystroke using CGEvent
    /// Uses Unicode input method for reliable character insertion
    private func simulateCharacterKeystroke(_ character: Character) -> InsertionResult {
        let string = String(character)

        // Get the UTF-16 code units for the character
        let utf16Array = Array(string.utf16)

        // Create a key down event with the Unicode character
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            return .insertionFailed("Failed to create key down event for character")
        }

        // Set the Unicode string on the event
        keyDownEvent.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)

        // Create a key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            return .insertionFailed("Failed to create key up event for character")
        }

        // Post the events
        keyDownEvent.post(tap: .cghidEventTap)
        usleep(1000) // 1ms delay between key down and key up
        keyUpEvent.post(tap: .cghidEventTap)

        return .success
    }

    /// US-515: Log detailed error information when keyboard simulation fails
    private func logSimulationError(_ message: String, phase: String) {
        print("""
        ╔════════════════════════════════════════════════════════════╗
        ║ [US-515] KEYBOARD SIMULATION ERROR                         ║
        ╠════════════════════════════════════════════════════════════╣
        ║ Phase: \(phase.padding(toLength: 50, withPad: " ", startingAt: 0)) ║
        ║ Error: \(message.prefix(50).padding(toLength: 50, withPad: " ", startingAt: 0)) ║
        ║ Accessibility: \(hasAccessibilityPermission ? "granted" : "denied").padding(toLength: 43, withPad: " ", startingAt: 0) ║
        ║ Timestamp: \(ISO8601DateFormatter().string(from: Date()).padding(toLength: 47, withPad: " ", startingAt: 0)) ║
        ╚════════════════════════════════════════════════════════════╝
        """)
    }
    
    // MARK: - Clipboard Preservation
    
    /// Save the current clipboard contents
    /// US-513: Saves clipboard before text insertion so it can be restored after paste
    private func saveClipboardContents() {
        let pasteboard = NSPasteboard.general
        
        // Get all items on the pasteboard
        guard let items = pasteboard.pasteboardItems else {
            savedClipboardItems = nil
            print("TextInserter: [US-513] No clipboard items to save (pasteboard empty)")
            return
        }
        
        // Create copies of the items (deep copy to preserve data)
        savedClipboardItems = items.compactMap { item -> NSPasteboardItem? in
            let newItem = NSPasteboardItem()
            
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            
            return newItem.types.isEmpty ? nil : newItem
        }
        
        // Log what was saved for debugging
        let itemCount = savedClipboardItems?.count ?? 0
        if itemCount > 0 {
            // Get a preview of saved content for debugging
            let preview = pasteboard.string(forType: .string)?.prefix(50) ?? "(non-text content)"
            print("TextInserter: [US-513] Saved \(itemCount) clipboard items (preview: \(preview))")
        } else {
            print("TextInserter: [US-513] No clipboard items to save")
        }
    }
    
    /// Schedule clipboard restoration after a delay
    /// US-513: Restoration happens in background thread to avoid blocking main thread
    private func scheduleClipboardRestore() {
        let delay = clipboardRestoreDelay
        let itemsToRestore = savedClipboardItems
        
        // Clear our reference since background thread will handle restoration
        savedClipboardItems = nil
        
        guard let items = itemsToRestore, !items.isEmpty else {
            print("TextInserter: [US-513] No items to schedule for restoration")
            return
        }
        
        // US-513: Use background thread for the delay, then dispatch to main for pasteboard access
        // Use @Sendable closure to satisfy Swift concurrency requirements
        DispatchQueue.global(qos: .utility).async { [items] in
            // Wait for the configured delay (800ms by default)
            Thread.sleep(forTimeInterval: delay)
            
            // Pasteboard operations must happen on main thread
            DispatchQueue.main.async {
                self.restoreClipboardContentsSync(items: items)
            }
        }
    }
    
    /// Restore clipboard contents synchronously (called from main thread after background delay)
    /// US-513: This is the actual restoration logic, separated for clarity
    private func restoreClipboardContentsSync(items: [NSPasteboardItem]?) {
        guard let items = items, !items.isEmpty else {
            print("TextInserter: [US-513] No clipboard items to restore")
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
        
        print("TextInserter: [US-513] Restored \(items.count) clipboard items after delay")
    }
    
    /// Restore the previously saved clipboard contents (immediate, used on error)
    /// US-513: Called immediately on insertion failure to restore clipboard
    private func restoreClipboardContents() {
        guard let items = savedClipboardItems, !items.isEmpty else {
            print("TextInserter: [US-513] No clipboard items to restore (immediate)")
            savedClipboardItems = nil
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
        
        print("TextInserter: [US-513] Restored \(items.count) clipboard items (immediate, on error)")
        savedClipboardItems = nil
    }
    
    // MARK: - Status

    /// Reset insertion status to idle
    func resetStatus() {
        insertionStatus = .idle
        statusMessage = "Ready"
    }

    // MARK: - US-026: Undo Support

    /// Result of an undo operation
    enum UndoResult {
        case success
        case noAccessibilityPermission
        case undoFailed(String)
    }

    /// US-026: Delete the last inserted text by simulating backspaces
    /// This works across different applications by simulating keyboard input
    /// - Parameter characterCount: Number of characters to delete
    /// - Returns: The result of the undo attempt
    func undoText(characterCount: Int) async -> UndoResult {
        // Check accessibility permission first
        if !hasAccessibilityPermission {
            print("TextInserter: [US-026] No accessibility permission for undo")
            recheckPermission()

            if !hasAccessibilityPermission {
                return .noAccessibilityPermission
            }
        }

        print("TextInserter: [US-026] Undoing \(characterCount) characters")

        insertionStatus = .inserting
        statusMessage = "Undoing..."

        // Simulate backspaces to delete the text
        let result = simulateBackspaces(count: characterCount)

        switch result {
        case .success:
            insertionStatus = .completed
            statusMessage = "Undo complete"
            print("TextInserter: [US-026] Undo successful")
            return .success

        case .insertionFailed(let message):
            insertionStatus = .error("Undo failed")
            statusMessage = "Undo failed"
            print("TextInserter: [US-026] Undo failed: \(message)")
            return .undoFailed(message)

        default:
            return .undoFailed("Unknown error")
        }
    }

    /// US-026: Simulate backspace keystrokes to delete text
    /// - Parameter count: Number of backspaces to simulate
    /// - Returns: InsertionResult indicating success or failure
    private func simulateBackspaces(count: Int) -> InsertionResult {
        print("TextInserter: [US-026] Simulating \(count) backspaces using CGEvent")

        // Virtual key code for Delete/Backspace (kVK_Delete = 0x33 = 51)
        let deleteKeyCode: UInt16 = 0x33

        for i in 0..<count {
            // Create key down event for backspace
            guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: deleteKeyCode, keyDown: true) else {
                let errorMsg = "Failed to create backspace key down event at character \(i)"
                print("TextInserter: [US-026] \(errorMsg)")
                return .insertionFailed(errorMsg)
            }

            // Create key up event for backspace
            guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: deleteKeyCode, keyDown: false) else {
                let errorMsg = "Failed to create backspace key up event at character \(i)"
                print("TextInserter: [US-026] \(errorMsg)")
                return .insertionFailed(errorMsg)
            }

            // Post the events
            keyDownEvent.post(tap: .cghidEventTap)
            usleep(1000) // 1ms delay between key down and key up
            keyUpEvent.post(tap: .cghidEventTap)

            // Small delay between backspaces to ensure they're processed
            if i < count - 1 {
                usleep(500) // 0.5ms between keystrokes
            }
        }

        print("TextInserter: [US-026] Successfully simulated \(count) backspaces")
        return .success
    }

    // MARK: - US-028: Paste Format Support

    /// US-028: Set pasteboard content based on selected paste format
    /// - Parameters:
    ///   - text: The text to add to pasteboard
    ///   - pasteboard: The pasteboard to write to
    /// - Returns: True if successful, false otherwise
    private func setPasteboardContent(_ text: String, pasteboard: NSPasteboard) -> Bool {
        switch selectedPasteFormat {
        case .plainText:
            return setPlainTextContent(text, pasteboard: pasteboard)
        case .richText:
            return setRichTextContent(text, pasteboard: pasteboard)
        case .markdown:
            return setMarkdownContent(text, pasteboard: pasteboard)
        }
    }

    /// US-028: Set plain text content on pasteboard
    private func setPlainTextContent(_ text: String, pasteboard: NSPasteboard) -> Bool {
        print("TextInserter: [US-028] Setting plain text format")
        return pasteboard.setString(text, forType: .string)
    }

    /// US-028: Set rich text (RTF) content on pasteboard
    /// Creates basic RTF with the system font
    private func setRichTextContent(_ text: String, pasteboard: NSPasteboard) -> Bool {
        print("TextInserter: [US-028] Setting rich text format")

        // Create an attributed string with default system font
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: NSColor.textColor
            ]
        )

        // Convert to RTF data
        let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]

        guard let rtfData = try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: documentAttributes
        ) else {
            print("TextInserter: [US-028] Failed to create RTF data, falling back to plain text")
            return pasteboard.setString(text, forType: .string)
        }

        // Set both RTF and plain text for maximum compatibility
        // Some apps prefer RTF, others only accept plain text
        let rtfSuccess = pasteboard.setData(rtfData, forType: .rtf)
        let stringSuccess = pasteboard.setString(text, forType: .string)

        return rtfSuccess || stringSuccess
    }

    /// US-028: Set markdown content on pasteboard
    /// Sets the raw markdown text (not converted to HTML/RTF)
    /// Apps that support markdown will render it, others will show plain text
    private func setMarkdownContent(_ text: String, pasteboard: NSPasteboard) -> Bool {
        print("TextInserter: [US-028] Setting markdown format")

        // Set as plain text - markdown is just specially formatted text
        // The user selects markdown when they want the raw markdown syntax preserved
        // This is useful for pasting into markdown editors, note apps, etc.
        return pasteboard.setString(text, forType: .string)
    }

    /// US-028: Convert plain text to basic markdown format
    /// This can be used if we want to apply markdown formatting to transcriptions
    /// Currently unused but available for future enhancement
    func convertToMarkdown(_ text: String) -> String {
        // Basic markdown conversions could be added here
        // For now, we just return the text as-is since transcriptions
        // are typically plain spoken text without formatting needs
        return text
    }
}
