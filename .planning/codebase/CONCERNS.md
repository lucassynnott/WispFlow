# Codebase Concerns

**Analysis Date:** 2026-01-19

## Tech Debt

**MainWindow.swift Mega-File:**
- Issue: Single file contains ~9,400 lines with multiple views, view controllers, and UI components
- Files: `Sources/Voxa/MainWindow.swift`
- Impact: Difficult to navigate, maintain, and test. High risk of merge conflicts when multiple developers work on different features.
- Fix approach: Extract logical components into separate files:
  - Navigation views → `NavigationViews.swift`
  - Home dashboard → `HomeView.swift`
  - History view → `HistoryView.swift`
  - Snippets management → `SnippetsView.swift`
  - Dictionary management → `DictionaryView.swift`
  - Settings sections → `SettingsView.swift` (or further split by section)
  - Debug panel → `DebugView.swift`
  - Shared components → `SharedComponents.swift`

**Excessive Singleton Pattern Usage:**
- Issue: 14+ singletons throughout the codebase (all managers use `static let shared`)
- Files:
  - `Sources/Voxa/AudioManager.swift`
  - `Sources/Voxa/WhisperManager.swift`
  - `Sources/Voxa/LLMManager.swift`
  - `Sources/Voxa/TextCleanupManager.swift`
  - `Sources/Voxa/TextInserter.swift`
  - `Sources/Voxa/HotkeyManager.swift`
  - `Sources/Voxa/PermissionManager.swift`
  - `Sources/Voxa/ErrorLogger.swift`
  - `Sources/Voxa/DebugManager.swift`
  - `Sources/Voxa/ToastManager.swift`
  - `Sources/Voxa/OnboardingManager.swift`
  - `Sources/Voxa/UsageStatsManager.swift`
  - `Sources/Voxa/SnippetsManager.swift`
  - `Sources/Voxa/DictionaryManager.swift`
- Impact: Makes unit testing difficult (cannot inject mocks), creates tight coupling, hides dependencies
- Fix approach: Adopt dependency injection pattern. Pass dependencies explicitly to views and managers. Consider a lightweight DI container or environment-based injection for SwiftUI.

**Extensive print() Debugging Statements:**
- Issue: 400+ print() statements throughout production code
- Files: All source files in `Sources/Voxa/`
- Impact: Clutters console output, potential minor performance overhead, inconsistent logging levels
- Fix approach:
  1. Replace with structured logging using ErrorLogger.shared consistently
  2. Use conditional compilation (`#if DEBUG`) for verbose debug output
  3. Implement log levels (verbose/debug/info/warning/error) consistently

**AudioManager.swift Complexity:**
- Issue: 2,677 lines handling audio capture, device management, calibration, format negotiation, and buffer management
- Files: `Sources/Voxa/AudioManager.swift`
- Impact: High cognitive load, difficult to maintain and test individual responsibilities
- Fix approach: Extract into separate components:
  - `AudioDeviceManager.swift` - device enumeration, selection, hot-plug handling
  - `AudioCaptureEngine.swift` - AVAudioEngine management, buffer handling
  - `AudioCalibrationManager.swift` - device calibration logic
  - Keep `AudioManager.swift` as orchestrating facade

## Known Bugs

**No identified runtime bugs from code analysis.**
The codebase appears functional but would benefit from runtime testing for edge cases around:
- Audio device hot-plug during active recording
- Model loading failures mid-transcription
- Clipboard restoration race conditions

## Security Considerations

**Clipboard Data Exposure:**
- Risk: Transcribed text placed on clipboard could be accessed by other applications before restoration
- Files: `Sources/Voxa/TextInserter.swift`
- Current mitigation: Optional clipboard preservation/restoration with configurable delay (default 0.8s)
- Recommendations:
  - Consider using private pasteboard types
  - Document the security trade-off to users
  - Add option to disable clipboard-based insertion entirely (direct text input via accessibility APIs)

**UserDefaults for Sensitive Settings:**
- Risk: Settings stored in UserDefaults are not encrypted and accessible to other processes
- Files: Multiple files storing preferences via UserDefaults
- Current mitigation: None - standard macOS app behavior
- Recommendations:
  - For truly sensitive data (if any added in future), use Keychain
  - Current usage (model preferences, UI state) is appropriate for UserDefaults

**Model Downloads from External URLs:**
- Risk: Models downloaded from Hugging Face and external repos without integrity verification
- Files:
  - `Sources/Voxa/WhisperManager.swift` (WhisperKit downloads)
  - `Sources/Voxa/LLMManager.swift` (LLM model downloads)
- Current mitigation: File size validation only
- Recommendations:
  - Implement checksum verification for downloaded models
  - Pin specific model versions with known hashes

## Performance Bottlenecks

**Model Loading Time:**
- Problem: First transcription requires loading Whisper model (75MB-1.5GB) into memory
- Files: `Sources/Voxa/WhisperManager.swift`
- Cause: Core ML model compilation and loading is CPU/memory intensive
- Improvement path:
  - Pre-load model on app launch (current approach)
  - Consider lazy loading indicators in UI
  - Cache compiled model state if WhisperKit supports it

**Audio Buffer Allocation:**
- Problem: Large audio buffers for long recordings
- Files: `Sources/Voxa/AudioManager.swift` (masterBuffer array)
- Cause: Growing array for full recording duration (up to 5 min default max)
- Improvement path:
  - Consider ring buffer for memory-constrained scenarios
  - Stream audio to disk for very long recordings
  - Current 30s buffer timeout (US-608) helps after transcription

**LLM Inference Latency:**
- Problem: AI-powered text cleanup adds noticeable delay
- Files: `Sources/Voxa/LLMManager.swift`
- Cause: Local LLM inference even with quantized models (1-2GB)
- Improvement path:
  - Current approach uses smaller models (Qwen 1.5B)
  - Could add streaming output for progressive display
  - Consider caching common corrections

## Fragile Areas

**Recording State Machine:**
- Files: `Sources/Voxa/AppDelegate.swift`, `Sources/Voxa/StatusBarController.swift`
- Why fragile: State transitions spread across multiple classes with callbacks and notifications
- Safe modification: Trace full state flow before changes, add logging at each transition
- Test coverage: No automated tests - manual testing critical for recording start/stop/cancel flows

**Device Hot-Plug Handling:**
- Files: `Sources/Voxa/AudioManager.swift` (lines 500-620)
- Why fragile: Complex interaction between CoreAudio callbacks, recording state, and UI updates
- Safe modification: Test with physical device connect/disconnect during recording
- Test coverage: Gap - no automated tests for device change scenarios

**Text Insertion Pipeline:**
- Files: `Sources/Voxa/TextInserter.swift`, `Sources/Voxa/AppDelegate.swift`
- Why fragile: Depends on macOS accessibility APIs, clipboard state, and application focus
- Safe modification: Test across multiple target applications (Slack, VS Code, Safari, Notes, etc.)
- Test coverage: Gap - no automated tests for insertion behavior

## Scaling Limits

**Recording Duration:**
- Current capacity: Default 5 minute max recording (configurable)
- Limit: Memory grows linearly with duration at 16kHz sample rate
- Scaling path: Increase timeout in settings, but consider streaming to disk for very long recordings

**Snippet Storage:**
- Current capacity: Up to 100 snippets (hardcoded limit in SnippetsManager)
- Limit: All snippets stored in UserDefaults as JSON
- Scaling path: Migrate to SQLite/Core Data if limit needs to increase significantly

**Transcription History:**
- Current capacity: In-memory array with UserDefaults persistence
- Limit: Performance may degrade with thousands of entries
- Scaling path: Implement pagination, SQLite storage for large history

## Dependencies at Risk

**WhisperKit (0.9.0+):**
- Risk: Relatively new library, API may change
- Impact: Core transcription functionality
- Migration plan: Monitor releases, pin to specific version, test upgrades thoroughly

**llama.swift (2.7721.0+):**
- Risk: Wrapper around llama.cpp, may have compatibility issues with future llama.cpp releases
- Impact: AI-powered text cleanup
- Migration plan: Keep llama.swift updated, consider direct llama.cpp integration if wrapper becomes unmaintained

## Missing Critical Features

**Audio Import (Partial):**
- Problem: Audio import button exists but functionality shows "coming soon" toast
- Files: `Sources/Voxa/MainWindow.swift` (lines 527-543)
- Blocks: Users cannot transcribe pre-recorded audio files

**Offline-First Architecture:**
- Problem: No explicit handling for network failures during model downloads
- Files: `Sources/Voxa/WhisperManager.swift`, `Sources/Voxa/LLMManager.swift`
- Blocks: Graceful handling when starting without internet

## Test Coverage Gaps

**No Application Tests:**
- What's not tested: Entire application has no automated tests
- Files: Package.swift comments indicate "Tests require full Xcode installation"
- Risk: Any code change could introduce regressions undetected
- Priority: High - establish basic test infrastructure

**Critical Untested Paths:**
1. Audio recording start/stop/cancel flows
2. Transcription pipeline (audio → Whisper → text cleanup → insertion)
3. Model download/load/unload cycles
4. Permission request flows (microphone, accessibility)
5. Device hot-plug scenarios
6. Clipboard preservation/restoration

**Recommended Test Priority:**
1. Unit tests for managers (mock dependencies via DI)
2. Integration tests for transcription pipeline
3. UI tests for critical user journeys
4. Device simulation tests for audio scenarios

---

*Concerns audit: 2026-01-19*
