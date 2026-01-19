# Architecture

**Analysis Date:** 2026-01-19

## Pattern Overview

**Overall:** Menu Bar Application with Manager/Singleton Pattern

**Key Characteristics:**
- Native macOS menu bar application (accessory activation policy)
- AppKit-based with SwiftUI for main window views
- Manager classes as singletons for cross-component access
- Callback-based communication between components
- Event-driven architecture with NotificationCenter for cross-view communication
- MainActor isolation for UI-related managers

## Layers

**Application Layer:**
- Purpose: Application lifecycle and coordination
- Location: `Sources/Voxa/main.swift`, `Sources/Voxa/AppDelegate.swift`
- Contains: Entry point, delegate, component initialization, event routing
- Depends on: All managers, UI controllers
- Used by: macOS system

**UI Layer:**
- Purpose: User interface and presentation
- Location: `Sources/Voxa/MainWindow.swift`, `Sources/Voxa/StatusBarController.swift`, `Sources/Voxa/RecordingIndicatorWindow.swift`, `Sources/Voxa/OnboardingWindow.swift`, `Sources/Voxa/ToastView.swift`
- Contains: SwiftUI views, AppKit windows, status bar, visual feedback
- Depends on: Design system, managers (via singletons or injection)
- Used by: AppDelegate, user interactions

**Manager Layer:**
- Purpose: Business logic and state management
- Location: `Sources/Voxa/` (all *Manager.swift files)
- Contains: Singleton managers for specific domains
- Depends on: System frameworks (AVFoundation, WhisperKit, LlamaSwift)
- Used by: UI layer, AppDelegate

**Data Layer:**
- Purpose: Persistence and data models
- Location: `Sources/Voxa/UsageStatsManager.swift`, `Sources/Voxa/SnippetsManager.swift`, `Sources/Voxa/DictionaryManager.swift`
- Contains: Data models (Codable structs), UserDefaults persistence
- Depends on: Foundation
- Used by: Manager layer, UI layer

**Design System:**
- Purpose: Consistent styling and theming
- Location: `Sources/Voxa/DesignSystem.swift`
- Contains: Color tokens, typography, spacing, animations, component styles
- Depends on: SwiftUI, AppKit
- Used by: All UI components

## Data Flow

**Recording to Text Insertion:**

1. User triggers recording via hotkey (HotkeyManager) or status bar click
2. StatusBarController toggles RecordingState and notifies AppDelegate
3. AppDelegate starts AudioManager.startCapturing()
4. AudioManager captures audio via AVAudioEngine, buffers PCM data
5. User stops recording, AudioManager returns AudioCaptureResult
6. AppDelegate sends audio data to WhisperManager.transcribe()
7. WhisperManager converts to float samples, runs WhisperKit inference
8. Transcribed text passes to TextCleanupManager.processText()
9. TextCleanupManager applies rule-based or LLM cleanup
10. AppDelegate calls TextInserter.insertText()
11. TextInserter copies to pasteboard and simulates Cmd+V via CGEvents

**State Management:**
- Managers use @Published properties for reactive UI updates
- Combine publishers for observing model status changes
- UserDefaults for persisting user preferences and data
- Callbacks for inter-manager communication

## Key Abstractions

**Manager Singleton:**
- Purpose: Centralized access to domain-specific functionality
- Examples: `Sources/Voxa/AudioManager.swift`, `Sources/Voxa/WhisperManager.swift`, `Sources/Voxa/LLMManager.swift`, `Sources/Voxa/TextCleanupManager.swift`, `Sources/Voxa/TextInserter.swift`, `Sources/Voxa/HotkeyManager.swift`, `Sources/Voxa/PermissionManager.swift`, `Sources/Voxa/DebugManager.swift`
- Pattern: `static let shared = ManagerName()`, MainActor isolation for UI managers

**RecordingState:**
- Purpose: Simple state machine for recording toggle
- Examples: `Sources/Voxa/RecordingState.swift`
- Pattern: Enum with toggle() method, iconName property

**ModelStatus:**
- Purpose: Track download/load state of ML models
- Examples: Used in WhisperManager, LLMManager, TextCleanupManager
- Pattern: Enum with cases: notDownloaded, downloading(progress), downloaded, loading, ready, error(String)

**NavigationItem:**
- Purpose: Sidebar navigation for main window
- Examples: `Sources/Voxa/MainWindow.swift`
- Pattern: Enum conforming to CaseIterable and Identifiable

## Entry Points

**main.swift:**
- Location: `Sources/Voxa/main.swift`
- Triggers: macOS application launch
- Responsibilities: Create NSApplication, set accessory policy, assign AppDelegate, run

**AppDelegate.applicationDidFinishLaunching:**
- Location: `Sources/Voxa/AppDelegate.swift`
- Triggers: Application launch complete
- Responsibilities: Initialize all managers, set up callbacks, auto-load models, show onboarding if first launch

**HotkeyManager Global Hotkey:**
- Location: `Sources/Voxa/HotkeyManager.swift`
- Triggers: User presses configured hotkey (default: Cmd+Shift+Space)
- Responsibilities: Toggle recording state via callback to AppDelegate

**StatusBar Click:**
- Location: `Sources/Voxa/StatusBarController.swift`
- Triggers: Left-click on menu bar icon
- Responsibilities: Toggle recording, update icon state

**StatusBar Right-Click Menu:**
- Location: `Sources/Voxa/StatusBarController.swift`
- Triggers: Right-click on menu bar icon
- Responsibilities: Show menu with Open Voxa, Settings, Audio Input, Launch at Login, Quit

## Error Handling

**Strategy:** Callback-based error propagation with user-facing alerts

**Patterns:**
- Managers have `onError: ((String) -> Void)?` callbacks
- WhisperManager has typed TranscriptionError enum with isRetryable flag
- AppDelegate shows NSAlert for user-facing errors
- ErrorLogger singleton writes to `~/.ralph/errors.log`
- ToastManager for non-blocking notifications (warnings, success, info)
- Retry support: audio buffer stored for 30 seconds for transcription retry

## Cross-Cutting Concerns

**Logging:**
- ErrorLogger singleton for file-based error logging
- DebugManager for in-app debug log viewing
- Categories: audio, transcription, model, textCleanup, textInsertion, permission, general

**Validation:**
- AudioManager validates minimum duration, silence detection
- WhisperManager validates audio sample rate, duration range
- TextInserter checks accessibility permission before insertion

**Authentication:**
- Not applicable (local-only application, no remote services)

**Permissions:**
- PermissionManager tracks microphone and accessibility status
- Published properties for reactive UI updates
- Automatic prompting with system dialogs or Settings redirect

---

*Architecture analysis: 2026-01-19*
