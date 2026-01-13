import AppKit
import Carbon.HIToolbox

/// Manager for handling global keyboard shortcuts
/// Uses NSEvent.addGlobalMonitorForEvents for monitoring hotkeys from any application
final class HotkeyManager {
    
    /// Default hotkey: Cmd+Shift+Space
    struct HotkeyConfiguration {
        var keyCode: UInt16
        var modifierFlags: NSEvent.ModifierFlags
        
        static let defaultHotkey = HotkeyConfiguration(
            keyCode: UInt16(kVK_Space),
            modifierFlags: [.command, .shift]
        )
        
        /// Human-readable string for the hotkey
        var displayString: String {
            var parts: [String] = []
            if modifierFlags.contains(.command) { parts.append("⌘") }
            if modifierFlags.contains(.shift) { parts.append("⇧") }
            if modifierFlags.contains(.option) { parts.append("⌥") }
            if modifierFlags.contains(.control) { parts.append("⌃") }
            parts.append(keyCodeToString(keyCode))
            return parts.joined()
        }
        
        private func keyCodeToString(_ keyCode: UInt16) -> String {
            switch Int(keyCode) {
            case kVK_Space: return "Space"
            case kVK_Return: return "↩"
            case kVK_Tab: return "⇥"
            case kVK_Delete: return "⌫"
            case kVK_Escape: return "⎋"
            case kVK_ANSI_A...kVK_ANSI_Z:
                // Letter key code mapping
                let keyMap: [Int: String] = [
                    kVK_ANSI_A: "A", kVK_ANSI_S: "S", kVK_ANSI_D: "D",
                    kVK_ANSI_F: "F", kVK_ANSI_H: "H", kVK_ANSI_G: "G",
                    kVK_ANSI_Z: "Z", kVK_ANSI_X: "X", kVK_ANSI_C: "C",
                    kVK_ANSI_V: "V", kVK_ANSI_B: "B", kVK_ANSI_Q: "Q",
                    kVK_ANSI_W: "W", kVK_ANSI_E: "E", kVK_ANSI_R: "R",
                    kVK_ANSI_Y: "Y", kVK_ANSI_T: "T", kVK_ANSI_O: "O",
                    kVK_ANSI_U: "U", kVK_ANSI_I: "I", kVK_ANSI_P: "P",
                    kVK_ANSI_L: "L", kVK_ANSI_J: "J", kVK_ANSI_K: "K",
                    kVK_ANSI_N: "N", kVK_ANSI_M: "M"
                ]
                return keyMap[Int(keyCode)] ?? "?"
            default:
                return "Key\(keyCode)"
            }
        }
    }
    
    // MARK: - Properties
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var configuration: HotkeyConfiguration
    
    /// Callback triggered when the hotkey is pressed
    var onHotkeyPressed: (() -> Void)?
    
    // MARK: - Initialization
    
    init(configuration: HotkeyConfiguration = .defaultHotkey) {
        self.configuration = configuration
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public API
    
    /// Start listening for global hotkey events
    /// Note: This requires accessibility permissions to work from other applications
    func start() {
        // Stop any existing monitors
        stop()
        
        // Global monitor - for key events in other applications
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Local monitor - for key events when our app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consume the event
            }
            return event
        }
        
        print("HotkeyManager started - listening for \(configuration.displayString)")
    }
    
    /// Stop listening for global hotkey events
    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        print("HotkeyManager stopped")
    }
    
    /// Update the hotkey configuration
    func updateConfiguration(_ newConfig: HotkeyConfiguration) {
        configuration = newConfig
        // Restart monitors with new configuration
        if globalMonitor != nil || localMonitor != nil {
            start()
        }
    }
    
    /// Get current hotkey display string
    var hotkeyDisplayString: String {
        return configuration.displayString
    }
    
    // MARK: - Private Methods
    
    /// Handle a key event and check if it matches our hotkey
    /// Returns true if the event was consumed (matched our hotkey)
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check if the key code matches
        guard event.keyCode == configuration.keyCode else {
            return false
        }
        
        // Check modifier flags
        // We need to mask out irrelevant flags (like caps lock, function, etc.)
        let relevantFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let eventFlags = event.modifierFlags.intersection(relevantFlags)
        let requiredFlags = configuration.modifierFlags.intersection(relevantFlags)
        
        guard eventFlags == requiredFlags else {
            return false
        }
        
        // Hotkey matched!
        print("Hotkey pressed: \(configuration.displayString)")
        onHotkeyPressed?()
        return true
    }
}
