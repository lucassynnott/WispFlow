# Technology Stack

**Analysis Date:** 2026-01-19

## Languages

**Primary:**
- Swift 5.9+ (6.2.3 installed) - All application code

**Secondary:**
- C/C++ - Underlying llama.cpp and WhisperKit inference engines (via pre-built binaries)

## Runtime

**Environment:**
- macOS 14.0+ (Sonoma) required
- Apple Silicon (arm64) primary target
- Native AppKit application (menu bar app)

**Package Manager:**
- Swift Package Manager (SPM)
- Lockfile: `Package.resolved` (present)

## Frameworks

**Core:**
- AppKit - Native macOS UI framework (menu bar app, windows, alerts)
- SwiftUI - Modern declarative UI (settings views, onboarding, main window)
- Foundation - Core utilities and data types
- Combine - Reactive state management (@Published, ObservableObject)

**ML/AI:**
- WhisperKit 0.15.0 - OpenAI Whisper speech-to-text via CoreML
- LlamaSwift 2.7721.0 - llama.cpp Swift bindings for local LLM inference

**System:**
- AVFoundation - Audio capture and microphone access
- CoreGraphics - CGEvent for global hotkey detection
- Carbon.HIToolbox - Virtual key codes for hotkey configuration
- Accessibility APIs (AXIsProcessTrusted) - Text insertion permissions

**Testing:**
- XCTest - Swift testing framework (not currently configured in Package.swift)

**Build/Dev:**
- Swift Package Manager - Dependency management and build
- Xcode Command Line Tools - Build toolchain

## Key Dependencies

**Critical:**
- WhisperKit 0.15.0 - Speech transcription engine (CoreML-based, on-device)
  - Repository: `https://github.com/argmaxinc/WhisperKit.git`
  - Models downloaded from Hugging Face: `argmaxinc/whisperkit-coreml`

- LlamaSwift 2.7721.0 - Local LLM for AI-powered text cleanup
  - Repository: `https://github.com/mattt/llama.swift.git`
  - Uses llama.cpp xcframework binaries
  - Models downloaded from Hugging Face (GGUF format)

**Transitive:**
- swift-argument-parser 1.7.0 - CLI argument parsing (WhisperKit dependency)
- swift-collections 1.3.0 - Extended collection types
- swift-jinja 2.0.2 - Jinja template support (LLM prompts)
- swift-transformers 1.1.6 - Hugging Face transformers support

## Configuration

**Environment:**
- No `.env` files used - all configuration via UserDefaults
- Build configuration via `Package.swift`
- App metadata in `Resources/Info.plist`

**Key UserDefaults Keys:**
- `selectedWhisperModel` - Whisper model size (tiny/base/small/medium)
- `selectedTranscriptionLanguage` - Language hint for transcription
- `selectedLLMModel` - LLM model selection
- `textCleanupEnabled` - Toggle text cleanup
- `preserveClipboard` - Clipboard preservation setting
- `hotkeyKeyCode`, `hotkeyModifiers` - Global hotkey configuration
- `hasCompletedOnboarding` - First-run tracking

**Build:**
- `Package.swift` - Swift Package Manager manifest
- Minimum Swift tools version: 5.9
- Target platform: macOS 14.0+

## Platform Requirements

**Development:**
- macOS 14.0+ (Sonoma or later)
- Xcode Command Line Tools or full Xcode
- Swift 5.9+ toolchain
- ~4GB disk space for ML model downloads

**Production:**
- macOS 14.0+ required (WhisperKit CoreML requirement)
- Apple Silicon recommended (significantly faster ML inference)
- Intel Macs supported but slower
- Microphone access permission
- Accessibility permission (for text insertion and global hotkeys)
- ~2-5GB storage for downloaded models

## Model Storage

**Whisper Models:**
- Location: `~/Library/Application Support/Voxa/Models/`
- Sizes: tiny (~75MB), base (~145MB), small (~485MB), medium (~1.5GB)

**LLM Models:**
- Location: `~/Library/Application Support/Voxa/LLMModels/`
- Supported: Qwen 2.5 1.5B (~1GB), Phi-3 Mini (~2GB), Gemma 2B (~1.4GB)
- Format: GGUF (quantized)

## Build Commands

```bash
# Build debug
swift build

# Build release
swift build -c release

# Run
swift run Voxa

# Clean build
swift package clean
```

---

*Stack analysis: 2026-01-19*
