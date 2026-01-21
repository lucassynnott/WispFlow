<div align="center">

# VOXA

### Fully private local AI powered voice to text for Mac

<img src=".github/screenshot.png" alt="Voxa App Screenshot" width="800">

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Transform your voice into text instantly, privately, and locally on your Mac.**

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Building](#building) • [Contributing](#contributing)

</div>

---

## ✨ Features

### 🎤 **Universal Hotkey Recording**
- Press your custom hotkey anywhere on macOS to start recording
- Works across all applications - no switching required
- Single-key or modifier combinations supported
- Visual feedback with elegant recording indicator

### 🧠 **100% Private & Local AI**
- All transcription happens on your device using Whisper AI
- No internet connection required
- Your voice data never leaves your Mac
- Zero cloud dependencies or third-party services

### ⚡ **Lightning Fast**
- Optimized for Apple Silicon (M1/M2/M3)
- Real-time transcription as you speak
- Smart text cleanup with local LLM processing
- Adaptive animations for battery efficiency

### 🎯 **Smart Text Insertion**
- Automatically inserts transcribed text where your cursor is
- Works in any text field, document, or application
- Preserves your clipboard contents
- Native macOS accessibility integration

### 🎨 **Beautiful Native Interface**
- Clean, modern macOS design
- Dark mode support
- Menu bar app - stays out of your way
- Smooth animations and transitions
- Professional onboarding flow

### 🔧 **Highly Configurable**
- Customize your recording hotkey
- Choose from multiple Whisper models (tiny, base, small, medium)
- Adjust audio sensitivity and detection
- Control text formatting and cleanup
- Per-device audio calibration

---

## 📦 Installation

### Option 1: Download DMG (Recommended)

1. Download the latest `Voxa-Installer.dmg` from [Releases](https://github.com/lucassynnott/WispFlow/releases)
2. Open the DMG and drag Voxa to your Applications folder
3. Launch Voxa and follow the onboarding setup

### Option 2: Build from Source

See [Building from Source](#building-from-source) below.

---

## 🚀 Usage

### First Launch

1. **Grant Permissions**: Voxa needs two permissions to work:
   - **Microphone Access**: To record your voice
   - **Accessibility Access**: To insert text into other apps

2. **Audio Test**: Test your microphone to ensure optimal recording quality

3. **Configure Hotkey**: Set your preferred recording shortcut (default: ⌥⌘R)

### Recording Your Voice

1. Press your hotkey in any application
2. Speak naturally - you'll see a recording indicator
3. Release the hotkey when done
4. Voxa transcribes and inserts the text at your cursor

### Menu Bar Controls

Click the Voxa icon in your menu bar to:
- Start/stop recording manually
- View transcription history
- Download or switch Whisper models
- Adjust settings and preferences
- Access help and documentation

---

## 🛠 Building from Source

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ with Command Line Tools
- Swift 5.9+
- Python 3 with Pillow (for DMG creation)

### Build Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/lucassynnott/WispFlow.git
   cd WispFlow
   ```

2. **Build the app**
   ```bash
   ./scripts/build-app.sh --release
   ```

3. **Run the app**
   ```bash
   open .build/Voxa.app
   ```

### Creating a Distribution Package

```bash
# Complete build, sign, and package workflow
./scripts/package-release.sh

# Your DMG will be created at: .build/Voxa-Installer.dmg
```

For detailed build and distribution instructions, see [RELEASE.md](RELEASE.md).

---

## 🏗 Architecture

### Core Technologies

- **SwiftUI**: Modern, declarative UI framework
- **AppKit**: Native macOS integration for menu bar and system features
- **Whisper.cpp**: High-performance local speech recognition
- **LLaMA.cpp**: Optional local LLM for text cleanup and formatting
- **AVFoundation**: Audio recording and processing
- **Carbon**: Global hotkey registration

### Key Components

```
Sources/Voxa/
├── AppDelegate.swift          # App lifecycle and coordination
├── AudioManager.swift          # Audio recording and processing
├── WhisperManager.swift        # Whisper model management and transcription
├── LLMManager.swift            # Local LLM for text cleanup
├── HotkeyManager.swift         # Global hotkey handling
├── TextInserter.swift          # Clipboard-based text insertion
├── StatusBarController.swift   # Menu bar UI
├── MainWindow.swift            # Settings and main interface
├── OnboardingWindow.swift      # First-run onboarding
└── RecordingIndicatorWindow.swift  # Visual recording feedback
```

---

## ⚙️ Configuration

### Settings File Location

Voxa stores its settings in standard macOS locations:
```
~/Library/Application Support/com.wispflow.Voxa/
~/Library/Preferences/com.wispflow.Voxa.plist
```

### Whisper Models

Models are downloaded on first use and cached locally:
```
~/Library/Application Support/com.wispflow.Voxa/models/
```

Available models:
- **Tiny** (~75MB): Fastest, good for quick notes
- **Base** (~142MB): Balanced speed and accuracy
- **Small** (~466MB): Better accuracy, slightly slower
- **Medium** (~1.5GB): Best accuracy, requires more resources

---

## 🔒 Privacy & Security

- **100% Local Processing**: All audio processing happens on your device
- **No Network Requests**: App works completely offline
- **No Telemetry**: We don't collect any usage data
- **Secure Sandboxing**: App uses macOS sandboxing for security
- **Open Source**: Full source code available for audit

### Required Permissions

- **Microphone**: To record audio for transcription
- **Accessibility**: To insert transcribed text into other applications
- **Developer ID Signed**: App is signed and notarized by Apple

---

## 🐛 Troubleshooting

### Microphone Permission Issues

If the permission dialog doesn't appear:
```bash
# Reset TCC permissions
tccutil reset Microphone com.wispflow.Voxa
tccutil reset Accessibility com.wispflow.Voxa

# Restart the app
```

### Hotkey Not Working

1. Check System Settings → Privacy & Security → Accessibility
2. Ensure Voxa is enabled
3. Try restarting the app
4. Check for hotkey conflicts with other apps

### Audio Quality Issues

1. Open Voxa settings
2. Run the audio calibration tool
3. Adjust your microphone input level in System Settings
4. Try different Whisper models

### Performance Issues

- Use a smaller Whisper model (tiny or base)
- Close other resource-intensive applications
- Ensure you're using Apple Silicon (M1/M2/M3) for best performance

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Reporting Issues

- Check existing [Issues](https://github.com/lucassynnott/WispFlow/issues)
- Provide detailed steps to reproduce
- Include your macOS version and Mac model
- Attach relevant logs if possible

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with clear commit messages
4. Test thoroughly on macOS
5. Submit a pull request with a detailed description

### Development Guidelines

- Follow Swift style conventions
- Add comments for complex logic
- Update documentation for new features
- Test on both Intel and Apple Silicon if possible

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Whisper.cpp**: Georgi Gerganov's high-performance Whisper implementation
- **LLaMA.cpp**: Efficient local LLM inference
- **Apple**: For the excellent native frameworks and tools
- **Contributors**: Everyone who has contributed code, bug reports, and ideas

---

## 📧 Support

- **Issues**: [GitHub Issues](https://github.com/lucassynnott/WispFlow/issues)
- **Discussions**: [GitHub Discussions](https://github.com/lucassynnott/WispFlow/discussions)
- **Email**: support@wispflow.com

---

<div align="center">

**Made with ❤️ for Mac users who value privacy**

⭐ Star this repo if you find Voxa useful!

[Download](https://github.com/lucassynnott/WispFlow/releases) • [Report Bug](https://github.com/lucassynnott/WispFlow/issues) • [Request Feature](https://github.com/lucassynnott/WispFlow/issues)

</div>
