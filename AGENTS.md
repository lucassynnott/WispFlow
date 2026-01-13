# WispFlow - Agent Instructions

## Build

```bash
# Quick build (just compile)
swift build

# Build app bundle (creates .build/WispFlow.app)
./scripts/build-app.sh

# Build release app bundle
./scripts/build-app.sh --release
```

## Run

```bash
# Run from app bundle (preferred)
open .build/WispFlow.app

# Or run directly
.build/debug/WispFlow
```

## Verification

```bash
# Verify compilation
swift build
```

## Project Structure

- `Sources/WispFlow/` - Main application source code
  - `main.swift` - Application entry point
  - `AppDelegate.swift` - App lifecycle management
  - `StatusBarController.swift` - Menu bar status item controller
  - `RecordingState.swift` - Recording state enum
- `Resources/Info.plist` - App bundle configuration (LSUIElement for no dock icon)
- `scripts/build-app.sh` - Script to create .app bundle

## Requirements

- macOS 13.0+ (Ventura or later)
- Swift 5.9+
- For tests: Full Xcode installation (Command Line Tools only won't support XCTest)

## Notes

- This is a menu bar app (LSUIElement) - no dock icon appears
- Use `swift build` for verification (compilation)
- Use `./scripts/build-app.sh` to create runnable .app bundle
- Running the app requires a display and will show in menu bar
