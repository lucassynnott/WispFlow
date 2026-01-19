# Coding Conventions

**Analysis Date:** 2026-01-19

## Naming Patterns

**Files:**
- Swift: PascalCase with descriptive suffixes (e.g., `AudioManager.swift`, `TextCleanupManager.swift`, `RecordingState.swift`)
- Manager classes: `{Feature}Manager.swift` (e.g., `WhisperManager.swift`, `HotkeyManager.swift`, `SnippetsManager.swift`)
- Views: `{Feature}View.swift` or `{Feature}Window.swift` (e.g., `ToastView.swift`, `MainWindow.swift`)
- TypeScript: camelCase files (e.g., `client.ts`, `types.ts`, `snapshot.test.ts`)

**Classes/Structs:**
- PascalCase for all types: `AudioManager`, `TranscriptionEntry`, `ToastItem`
- Protocols: Descriptive naming without prefixes (e.g., `ObservableObject`)
- Enums: PascalCase with PascalCase cases (e.g., `RecordingState.idle`, `ModelStatus.downloading`)

**Functions/Methods:**
- camelCase: `processTranscription()`, `handleRecordingStateChange()`, `refreshMicrophoneStatus()`
- Use `on` prefix for callbacks: `onTranscriptionComplete`, `onError`, `onHotkeyPressed`
- Use `setup` prefix for initialization: `setupAudioManager()`, `setupWhisperManager()`
- Boolean getters: `isReady`, `isCleanupEnabled`, `hasActivity`, `isAtCapacity`

**Variables:**
- camelCase for all variables and properties
- Private properties: no prefix, use `private` keyword
- Published properties: use `@Published` attribute
- Constants: PascalCase in nested `Constants` struct (e.g., `Constants.targetSampleRate`)

**Types:**
- Nested enums within parent class for scoped types: `WhisperManager.TranscriptionError`, `AudioManager.DeviceQuality`
- Use `Identifiable` protocol with `id` property for SwiftUI lists
- Use `Equatable` for value comparison
- Use `Codable` for persistence

## Code Style

**Formatting:**
- Swift: Standard Xcode formatting (4-space indentation)
- TypeScript: Prettier with 2-space indentation
- Max line length: ~120 characters (not strictly enforced)

**Linting:**
- No explicit linter config files found
- TypeScript: Uses `strict: true` in tsconfig.json
- Swift: Relies on Xcode's built-in warnings

## Import Organization

**Swift Order:**
1. Foundation/Standard library: `import Foundation`
2. Apple frameworks: `import SwiftUI`, `import AppKit`, `import AVFoundation`
3. Third-party libraries: `import WhisperKit`
4. No local module imports (single target project)

**Example from `Sources/Voxa/MainWindow.swift`:**
```swift
import SwiftUI
import AppKit
import ServiceManagement
import Combine
import UniformTypeIdentifiers
```

**TypeScript Order:**
1. External packages: `import { chromium } from "playwright"`
2. Type imports: `import type { Browser, BrowserContext } from "playwright"`
3. Local imports with path aliases: `import { getSnapshotScript } from "../browser-script"`

**Path Aliases:**
- TypeScript uses `@/*` alias for `./src/*` (configured in `tsconfig.json`)

## Error Handling

**Swift Patterns:**
- Use `enum` for domain-specific errors with `LocalizedError` conformance:
```swift
enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case noSpeechDetected(details: String)
    case audioValidationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Model Not Loaded"
        // ...
        }
    }

    var recoverySuggestion: String? { /* ... */ }
    var isRetryable: Bool { /* ... */ }
}
```

- Callback-based error handling with `onError` closures:
```swift
var onError: ((String) -> Void)?
var onTranscriptionError: ((TranscriptionError, Data?, Double) -> Void)?
```

- Use `guard let` for early exit:
```swift
guard let whisper = whisperManager, whisper.isReady else {
    showModelNotReadyAlert()
    return
}
```

- Log errors with `ErrorLogger.shared`:
```swift
ErrorLogger.shared.log(
    "Audio capture error",
    category: .audio,
    severity: .error,
    context: ["deviceName": device.name]
)
```

**Result Types:**
- Use enums for operation results (not Swift's `Result` type):
```swift
enum ExportResult {
    case success(URL)
    case noAudioData
    case exportFailed(String)
}

enum InsertionResult {
    case success
    case noAccessibilityPermission
    case insertionFailed(String)
    case fallbackToManualPaste(String)
}
```

## Logging

**Framework:** `print()` for console output + custom `ErrorLogger` singleton

**Patterns:**
- Use print with context prefix for debugging:
```swift
print("Voxa started successfully")
print("AppDelegate: [US-507] Microphone permission not granted")
print("SnippetsManager: [US-635] Created snippet '\(title)' - Total: \(snippets.count)")
```

- US ticket references in log messages: `[US-XXX]` prefix
- Use `ErrorLogger.shared` for persistent error logs:
```swift
ErrorLogger.shared.log(
    "Recording timeout warning",
    category: .audio,
    severity: .warning,
    context: ["remainingSeconds": "\(remainingSeconds)"]
)
```

- Error categories: `.audio`, `.transcription`, `.model`, `.textCleanup`, `.textInsertion`, `.permission`, `.general`
- Severity levels: `.info`, `.warning`, `.error`, `.critical`

## Comments

**When to Comment:**
- MARK sections for code organization: `// MARK: - Types`, `// MARK: - Setup`
- User story references: `// US-632: Main Window with Sidebar Navigation`
- Complex logic explanations
- Design decision documentation in block comments

**Block Comment Style (Design System):**
```swift
// MARK: - Voxa Color Palette
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ Voxa Design System - Minimalist Color Tokens                                 ║
// ║                                                                              ║
// ║ Design Philosophy:                                                           ║
// ║ - Editorial, minimalist aesthetic with warm undertones                       ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
```

**JSDoc/TSDoc:**
- Swift uses triple-slash doc comments with parameter descriptions:
```swift
/// Log an error with category, severity, and message
/// - Parameters:
///   - message: The error message to log
///   - category: Category of the error (audio, transcription, etc.)
///   - severity: Severity level (info, warning, error, critical)
///   - context: Optional additional context (dictionary of key-value pairs)
func log(_ message: String, category: ErrorCategory, severity: ErrorSeverity, context: [String: Any]?)
```

## Function Design

**Size:** Functions typically 10-50 lines, larger functions broken into `setup*` helpers

**Parameters:**
- Use named parameters with defaults:
```swift
func createSnippet(title: String, content: String, shortcut: String? = nil) -> Snippet?
```

- Use trailing closures for callbacks:
```swift
audioManager?.onCaptureError = { error in
    print("Audio capture error: \(error.localizedDescription)")
}
```

**Return Values:**
- Use optionals for fallible operations: `-> Snippet?`
- Use enums for operations with multiple outcomes (see Error Handling)
- Use `@discardableResult` when return value may be ignored

## Module Design

**Exports:**
- Single target Swift project - no explicit exports
- TypeScript: Named exports only (no default exports)

**Singleton Pattern:**
```swift
@MainActor
final class SnippetsManager: ObservableObject {
    static let shared = SnippetsManager()

    private init() {
        // Load from UserDefaults
    }
}
```

**Manager Pattern:**
- All feature managers follow singleton pattern with `shared` static property
- Use `@MainActor` for UI-related managers
- Use `@Published` properties for SwiftUI bindings
- Implement callbacks for cross-component communication

**Property Persistence:**
- Use `UserDefaults` for settings and small data
- Store keys as constants in nested `Constants` struct:
```swift
private struct Constants {
    static let selectedModeKey = "selectedCleanupMode"
    static let cleanupEnabledKey = "textCleanupEnabled"
}
```

---

*Convention analysis: 2026-01-19*
