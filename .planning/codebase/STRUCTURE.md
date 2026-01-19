# Codebase Structure

**Analysis Date:** 2026-01-19

## Directory Layout

```
WispFlow/
├── Sources/
│   └── Voxa/                    # All Swift source files (flat structure)
├── Resources/                   # App resources (icons, assets, Info.plist)
│   ├── AppIcon.icns             # Application icon
│   ├── AppIcon.iconset/         # Icon source images
│   ├── Assets.xcassets/         # Asset catalog
│   ├── Info.plist               # Application manifest
│   ├── menubar.png              # Menu bar icon
│   └── menubar@2x.png           # Retina menu bar icon
├── .planning/                   # Planning and documentation
│   └── codebase/                # Codebase analysis documents
├── .build/                      # Swift Package Manager build artifacts (generated)
├── .ralph/                      # User data directory (created at runtime in ~/)
├── scripts/                     # Build/automation scripts
├── dist/                        # Distribution output
├── Package.swift                # Swift Package Manager manifest
├── Package.resolved             # Locked dependency versions
└── AGENTS.md                    # AI agent instructions
```

## Directory Purposes

**Sources/Voxa/:**
- Purpose: All application Swift source code
- Contains: Managers, views, controllers, utilities
- Key files: `main.swift`, `AppDelegate.swift`, `MainWindow.swift`
- Note: Flat directory structure (no subdirectories), ~24 Swift files

**Resources/:**
- Purpose: Application bundle resources
- Contains: Icons, assets, Info.plist configuration
- Key files: `AppIcon.icns`, `Info.plist`, `menubar.png`
- Generated: No
- Committed: Yes

**.planning/codebase/:**
- Purpose: Codebase analysis and planning documents
- Contains: Architecture, structure, conventions, testing, concerns docs
- Generated: By GSD commands
- Committed: Yes

**.build/:**
- Purpose: Swift Package Manager build output
- Contains: Compiled artifacts, checkouts of dependencies
- Generated: Yes (by swift build)
- Committed: No (in .gitignore)

## Key File Locations

**Entry Points:**
- `Sources/Voxa/main.swift`: Application entry point, creates NSApplication and AppDelegate
- `Sources/Voxa/AppDelegate.swift`: Application lifecycle, component initialization, event routing

**Configuration:**
- `Package.swift`: Swift Package Manager manifest, dependencies, targets
- `Resources/Info.plist`: macOS application manifest (bundle ID, version, permissions)

**Core Logic:**
- `Sources/Voxa/AudioManager.swift`: Audio capture via AVAudioEngine (~3700 lines)
- `Sources/Voxa/WhisperManager.swift`: Whisper model management and transcription (~1200 lines)
- `Sources/Voxa/TextCleanupManager.swift`: Text cleanup (rule-based + LLM) (~550 lines)
- `Sources/Voxa/LLMManager.swift`: Local LLM via llama.cpp (~1100 lines)
- `Sources/Voxa/TextInserter.swift`: Pasteboard + simulated paste (~550 lines)

**UI Components:**
- `Sources/Voxa/MainWindow.swift`: Main window with sidebar navigation (~9000 lines, contains all views)
- `Sources/Voxa/StatusBarController.swift`: Menu bar icon and dropdown menu (~570 lines)
- `Sources/Voxa/RecordingIndicatorWindow.swift`: Floating recording indicator (~700 lines)
- `Sources/Voxa/OnboardingWindow.swift`: First-launch onboarding wizard (~2100 lines)
- `Sources/Voxa/ToastView.swift`: Toast notification system (~600 lines)
- `Sources/Voxa/DesignSystem.swift`: Color tokens, typography, spacing, components (~1200 lines)

**Data Management:**
- `Sources/Voxa/UsageStatsManager.swift`: Usage statistics and transcription history (~500 lines)
- `Sources/Voxa/SnippetsManager.swift`: Text snippets storage (~350 lines)
- `Sources/Voxa/DictionaryManager.swift`: Custom dictionary entries (~450 lines)

**System Integration:**
- `Sources/Voxa/HotkeyManager.swift`: Global hotkey via CGEvent tap (~550 lines)
- `Sources/Voxa/PermissionManager.swift`: Microphone and accessibility permissions (~400 lines)
- `Sources/Voxa/DebugManager.swift`: Debug mode and logging (~600 lines)

**Utilities:**
- `Sources/Voxa/ErrorLogger.swift`: File-based error logging (~200 lines)
- `Sources/Voxa/AudioExporter.swift`: Export audio to file (~500 lines)
- `Sources/Voxa/AudioWaveformView.swift`: Waveform visualization (~100 lines)
- `Sources/Voxa/DebugLogWindow.swift`: Debug log viewer window (~400 lines)

**State Models:**
- `Sources/Voxa/RecordingState.swift`: Recording state enum (~37 lines)

## Naming Conventions

**Files:**
- PascalCase for all Swift files: `AudioManager.swift`, `MainWindow.swift`
- *Manager.swift for singleton managers: `WhisperManager.swift`, `LLMManager.swift`
- *Window.swift for AppKit windows: `OnboardingWindow.swift`, `DebugLogWindow.swift`
- *View.swift suffix for SwiftUI views (inside MainWindow.swift)
- *Controller.swift for AppKit controllers: `StatusBarController.swift`

**Directories:**
- PascalCase for source directories: `Sources/Voxa/`
- lowercase for tooling directories: `.planning/`, `.build/`, `scripts/`

**Code Conventions:**
- Types: PascalCase (`AudioManager`, `RecordingState`, `TranscriptionEntry`)
- Functions/Methods: camelCase (`startCapturing()`, `processTranscription()`)
- Properties: camelCase (`audioManager`, `recordingState`, `isReady`)
- Constants: camelCase in structs (`static let selectedModelKey`)
- Enums: PascalCase type, camelCase cases (`enum ModelStatus { case notDownloaded }`)

## Where to Add New Code

**New Feature/Manager:**
- Primary code: `Sources/Voxa/NewFeatureManager.swift`
- Follow singleton pattern: `static let shared = NewFeatureManager()`
- Add initialization in `Sources/Voxa/AppDelegate.swift` setupX method
- Add @Published properties for observable state

**New View/Screen:**
- Implementation: Add as struct inside `Sources/Voxa/MainWindow.swift`
- Add NavigationItem case if needs sidebar entry
- Create ContentView struct following pattern: `NewFeatureContentView`
- Use Color.Voxa.* tokens from DesignSystem

**New Data Model:**
- Implementation: Add Codable struct in relevant manager file
- Follow pattern: `struct NewEntry: Codable, Identifiable { let id: UUID ... }`
- Add persistence via UserDefaults in manager

**New Menu Bar Action:**
- Add to setupMenu() in `Sources/Voxa/StatusBarController.swift`
- Create @objc selector method
- Add callback property and wire in AppDelegate

**Utilities:**
- Shared helpers: `Sources/Voxa/` (create new file if substantial)
- Small extensions: Add to relevant manager or DesignSystem.swift

**New Notification:**
- Add extension in `Sources/Voxa/MainWindow.swift` (bottom of file)
- Pattern: `extension Notification.Name { static let newNotification = Notification.Name("newNotification") }`

## Special Directories

**.build/:**
- Purpose: Swift Package Manager build output and dependency checkouts
- Generated: Yes
- Committed: No

**.ralph/:**
- Purpose: User data directory (created at `~/.ralph/` at runtime)
- Contains: `errors.log`
- Generated: Yes (at runtime)
- Committed: No

**dist/:**
- Purpose: Distribution artifacts (built app bundles)
- Generated: Yes (by build scripts)
- Committed: No

**stitch_voxa_minimalist_dashboard_v1/:**
- Purpose: Design reference assets
- Generated: No
- Committed: Yes

## Module Structure

**Main Target: Voxa**
- Type: Executable
- Path: `Sources/Voxa/`
- Dependencies: WhisperKit, LlamaSwift

**Dependencies (Package.swift):**
- WhisperKit (0.9.0+): Speech-to-text via WhisperKit/argmaxinc
- LlamaSwift (2.7721.0+): Local LLM via mattt/llama.swift

**Platforms:**
- macOS 14.0+ (required by WhisperKit)

---

*Structure analysis: 2026-01-19*
