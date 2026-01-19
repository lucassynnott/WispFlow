# External Integrations

**Analysis Date:** 2026-01-19

## APIs & External Services

**Hugging Face Model Hub:**
- Purpose: ML model downloads (Whisper + LLM models)
- SDK/Client: URLSession with direct HTTPS downloads
- Auth: None required (public models)
- Download URLs:
  - Whisper: `https://huggingface.co/argmaxinc/whisperkit-coreml/`
  - LLM: `https://huggingface.co/{model-repo}/resolve/main/{filename}.gguf`
- Implementation: `WhisperManager.swift`, `LLMManager.swift`

**No Other External APIs:**
- All ML inference runs locally on-device
- No cloud transcription services
- No analytics or telemetry
- No user authentication services

## Data Storage

**Databases:**
- None - No database used

**Persistent Storage:**
- UserDefaults - All app settings and preferences
  - Keys defined in each manager class
  - Used for: model selection, hotkey config, UI preferences, onboarding state
- Local filesystem - ML model files
  - Whisper: `~/Library/Application Support/Voxa/Models/`
  - LLM: `~/Library/Application Support/Voxa/LLMModels/`

**File Storage:**
- ML model files stored in Application Support directory
- Audio recordings optionally saved to Documents (debug mode only)
- Path: `~/Documents/Voxa Recordings/` (when auto-save enabled)
- Implementation: `AudioExporter.swift`

**Caching:**
- UserDefaults caches permission states for quick startup
- Keys: `PermissionManager.microphoneLastKnownStatus`, `PermissionManager.accessibilityLastKnownStatus`
- ML models cached after first download

## Authentication & Identity

**Auth Provider:**
- None - No user authentication required

**macOS Permissions (System-level):**
- Microphone access - Required for audio capture
  - API: `AVCaptureDevice.requestAccess(for: .audio)`
  - Implementation: `PermissionManager.swift`
- Accessibility access - Required for text insertion and global hotkeys
  - API: `AXIsProcessTrusted()`, `AXIsProcessTrustedWithOptions()`
  - Implementation: `PermissionManager.swift`, `TextInserter.swift`

## Monitoring & Observability

**Error Tracking:**
- Internal logging only via `ErrorLogger.swift`
- No external error tracking service (Sentry, Crashlytics, etc.)
- Logs to console and optional debug log window

**Logs:**
- Console output via `print()` statements
- Structured logging with categories in `ErrorLogger.swift`:
  - Categories: `.audio`, `.model`, `.system`, `.network`
  - Severity levels: `.info`, `.warning`, `.error`
- Debug log window for user inspection (`DebugLogWindow.swift`)
- Debug manager tracks:
  - Audio data for visualization
  - Raw vs cleaned transcription comparison
  - Processing times

## CI/CD & Deployment

**Hosting:**
- Local macOS application (no server deployment)
- Distribution: Direct download or potential Mac App Store

**CI Pipeline:**
- Not detected - No CI configuration files found
- Potential: GitHub Actions, Xcode Cloud

**Build:**
- Swift Package Manager for dependency resolution
- Command line build: `swift build -c release`
- Xcode for full app bundling (when needed)

## Environment Configuration

**Required env vars:**
- None - Application does not use environment variables

**App Configuration (Info.plist):**
- `CFBundleIdentifier`: `com.wispflow.Voxa`
- `LSUIElement`: `true` (menu bar app, no dock icon)
- `LSMinimumSystemVersion`: `14.0`
- `NSMicrophoneUsageDescription`: Privacy description for microphone
- `NSAppleEventsUsageDescription`: Privacy description for accessibility

**Secrets location:**
- No secrets required - all public APIs and local processing

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## System Integration Points

**Pasteboard (Clipboard):**
- Used for text insertion via simulated Cmd+V
- Implementation: `TextInserter.swift`
- Preserves and restores original clipboard contents

**Global Hotkeys:**
- CGEvent tap at `kCGSessionEventTap` level
- Default: Cmd+Shift+Space
- Requires accessibility permission
- Implementation: `HotkeyManager.swift`

**System Settings Deep Links:**
- Microphone: `x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`
- Accessibility: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- Implementation: `PermissionManager.swift`

**Menu Bar:**
- NSStatusItem with dropdown menu
- Implementation: `StatusBarController.swift`

## Network Requirements

**Internet Access:**
- Required only for initial model downloads
- After models downloaded, app works fully offline
- Download sizes: 75MB - 2GB depending on model selection

**Firewall Considerations:**
- Outbound HTTPS to huggingface.co
- No inbound connections required

---

*Integration audit: 2026-01-19*
