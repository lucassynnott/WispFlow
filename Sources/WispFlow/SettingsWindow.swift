import SwiftUI

/// Settings window for WispFlow configuration
/// Includes model management, audio settings, and general preferences
struct SettingsView: View {
    @ObservedObject var whisperManager: WhisperManager
    @ObservedObject var textCleanupManager: TextCleanupManager
    @ObservedObject var textInserter: TextInserter
    @ObservedObject var hotkeyManager: HotkeyManager
    @State private var isLoadingWhisperModel = false
    @State private var isLoadingCleanupModel = false
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: WhisperManager.ModelSize?
    
    var body: some View {
        TabView {
            // General tab (hotkey, launch at login)
            GeneralSettingsView(hotkeyManager: hotkeyManager)
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            // Transcription tab
            TranscriptionSettingsView(
                whisperManager: whisperManager,
                isLoadingModel: $isLoadingWhisperModel,
                showDeleteConfirmation: $showDeleteConfirmation,
                modelToDelete: $modelToDelete
            )
            .tabItem {
                Label("Transcription", systemImage: "waveform")
            }
            
            // Text Cleanup tab
            TextCleanupSettingsView(
                textCleanupManager: textCleanupManager,
                isLoadingModel: $isLoadingCleanupModel
            )
            .tabItem {
                Label("Text Cleanup", systemImage: "text.badge.checkmark")
            }
            
            // Text Insertion tab
            TextInsertionSettingsView(textInserter: textInserter)
            .tabItem {
                Label("Text Insertion", systemImage: "doc.on.clipboard")
            }
        }
        .frame(width: 520, height: 520)
        .alert("Delete Model?", isPresented: $showDeleteConfirmation, presenting: modelToDelete) { model in
            Button("Delete", role: .destructive) {
                Task {
                    await whisperManager.deleteModel(model)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { model in
            Text("Are you sure you want to delete the \(model.displayName) model? You can re-download it later.")
        }
    }
}

// MARK: - Transcription Settings

struct TranscriptionSettingsView: View {
    @ObservedObject var whisperManager: WhisperManager
    @Binding var isLoadingModel: Bool
    @Binding var showDeleteConfirmation: Bool
    @Binding var modelToDelete: WhisperManager.ModelSize?
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Model selection
                    Text("Whisper Model")
                        .font(.headline)
                    
                    Text("Select a model size. Larger models are more accurate but slower and use more memory.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Model Size", selection: Binding(
                        get: { whisperManager.selectedModel },
                        set: { model in
                            Task {
                                await whisperManager.selectModel(model)
                            }
                        }
                    )) {
                        ForEach(WhisperManager.ModelSize.allCases) { model in
                            HStack {
                                Text(model.displayName)
                                if whisperManager.isModelDownloaded(model) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                            .tag(model)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    
                    // Model description
                    Text(whisperManager.selectedModel.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // Status display
                    HStack {
                        Text("Status:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        StatusBadge(status: whisperManager.modelStatus)
                    }
                    
                    Text(whisperManager.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        // Load/Download button
                        Button(action: {
                            Task {
                                isLoadingModel = true
                                await whisperManager.loadModel()
                                isLoadingModel = false
                            }
                        }) {
                            HStack {
                                if isLoadingModel {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: buttonIconName)
                                }
                                Text(buttonTitle)
                            }
                            .frame(minWidth: 120)
                        }
                        .disabled(isLoadingModel || whisperManager.modelStatus == .ready)
                        .buttonStyle(.borderedProminent)
                        
                        // Delete button (if model is downloaded)
                        if whisperManager.isModelDownloaded(whisperManager.selectedModel) {
                            Button(action: {
                                modelToDelete = whisperManager.selectedModel
                                showDeleteConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                            }
                            .disabled(isLoadingModel)
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Downloaded Models")
                        .font(.headline)
                    
                    let downloadedModels = whisperManager.getDownloadedModels()
                    if downloadedModels.isEmpty {
                        Text("No models downloaded yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(downloadedModels) { model in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(model.displayName)
                                    .font(.caption)
                                Spacer()
                                if model == whisperManager.selectedModel && whisperManager.modelStatus == .ready {
                                    Text("Active")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private var buttonTitle: String {
        switch whisperManager.modelStatus {
        case .ready:
            return "Model Loaded"
        case .loading:
            return "Loading..."
        case .downloading:
            return "Downloading..."
        case .notDownloaded:
            return whisperManager.isModelDownloaded(whisperManager.selectedModel) ? "Load Model" : "Download & Load"
        case .downloaded:
            return "Load Model"
        case .error:
            return "Retry"
        }
    }
    
    private var buttonIconName: String {
        switch whisperManager.modelStatus {
        case .ready:
            return "checkmark.circle"
        case .loading, .downloading:
            return "arrow.clockwise"
        case .notDownloaded:
            return whisperManager.isModelDownloaded(whisperManager.selectedModel) ? "play.circle" : "arrow.down.circle"
        case .downloaded:
            return "play.circle"
        case .error:
            return "arrow.clockwise"
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: WhisperManager.ModelStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .notDownloaded:
            return .gray
        case .downloading, .loading:
            return .orange
        case .downloaded:
            return .blue
        case .ready:
            return .green
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .notDownloaded:
            return "Not Downloaded"
        case .downloading(let progress):
            return "Downloading \(Int(progress * 100))%"
        case .downloaded:
            return "Downloaded"
        case .loading:
            return "Loading"
        case .ready:
            return "Ready"
        case .error:
            return "Error"
        }
    }
}

// MARK: - Text Cleanup Settings

struct TextCleanupSettingsView: View {
    @ObservedObject var textCleanupManager: TextCleanupManager
    @Binding var isLoadingModel: Bool
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Cleanup toggle
                    Toggle("Enable Text Cleanup", isOn: Binding(
                        get: { textCleanupManager.isCleanupEnabled },
                        set: { textCleanupManager.isCleanupEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    
                    Text("When enabled, transcribed text will be cleaned up to remove filler words, fix grammar, and improve formatting.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Mode selection
                    Text("Cleanup Mode")
                        .font(.headline)
                    
                    Text("Select a cleanup mode. More thorough modes apply additional corrections.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Cleanup Mode", selection: $textCleanupManager.selectedMode) {
                        ForEach(TextCleanupManager.CleanupMode.allCases) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .disabled(!textCleanupManager.isCleanupEnabled)
                    
                    // Mode description
                    Text(textCleanupManager.selectedMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // Status display
                    HStack {
                        Text("Status:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        CleanupStatusBadge(status: textCleanupManager.modelStatus)
                    }
                    
                    Text(textCleanupManager.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What Text Cleanup Does")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        CleanupFeatureRow(icon: "minus.circle", text: "Removes filler words (um, uh, like, you know)")
                        CleanupFeatureRow(icon: "checkmark.circle", text: "Fixes grammar and punctuation")
                        CleanupFeatureRow(icon: "textformat", text: "Proper capitalization")
                        CleanupFeatureRow(icon: "text.alignleft", text: "Natural text formatting")
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Cleanup Status Badge

struct CleanupStatusBadge: View {
    let status: TextCleanupManager.ModelStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .notDownloaded:
            return .gray
        case .downloading, .loading:
            return .orange
        case .downloaded:
            return .blue
        case .ready:
            return .green
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .notDownloaded:
            return "Not Downloaded"
        case .downloading(let progress):
            return "Downloading \(Int(progress * 100))%"
        case .downloaded:
            return "Downloaded"
        case .loading:
            return "Loading"
        case .ready:
            return "Ready"
        case .error:
            return "Error"
        }
    }
}

// MARK: - Cleanup Feature Row

struct CleanupFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Text Insertion Settings

struct TextInsertionSettingsView: View {
    @ObservedObject var textInserter: TextInserter
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Accessibility permission status
                    Text("Accessibility Permission")
                        .font(.headline)
                    
                    HStack {
                        Circle()
                            .fill(textInserter.hasAccessibilityPermission ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(textInserter.hasAccessibilityPermission ? "Granted" : "Not Granted")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((textInserter.hasAccessibilityPermission ? Color.green : Color.orange).opacity(0.15))
                    .cornerRadius(8)
                    
                    if !textInserter.hasAccessibilityPermission {
                        Text("WispFlow needs accessibility permission to insert text into other applications. Click the button below to grant permission.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            _ = textInserter.requestAccessibilityPermission(showPrompt: true)
                        }) {
                            HStack {
                                Image(systemName: "hand.raised")
                                Text("Grant Permission")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text("Text insertion is enabled. Transcribed text will be automatically inserted into the active text field.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Clipboard preservation toggle
                    Text("Clipboard Options")
                        .font(.headline)
                    
                    Toggle("Preserve Clipboard Contents", isOn: $textInserter.preserveClipboard)
                        .toggleStyle(.switch)
                    
                    Text("When enabled, the original clipboard contents will be restored after text insertion.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if textInserter.preserveClipboard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Restore Delay: \(String(format: "%.1f", textInserter.clipboardRestoreDelay))s")
                                .font(.caption)
                            
                            Slider(value: $textInserter.clipboardRestoreDelay, in: 0.2...2.0, step: 0.1)
                                .frame(width: 200)
                            
                            Text("Time to wait before restoring the clipboard. Increase if the inserted text is getting cut off.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How Text Insertion Works")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        InsertionFeatureRow(icon: "doc.on.clipboard", text: "Text is copied to the clipboard")
                        InsertionFeatureRow(icon: "command", text: "Cmd+V is simulated to paste")
                        InsertionFeatureRow(icon: "arrow.uturn.backward", text: "Original clipboard is restored (optional)")
                        InsertionFeatureRow(icon: "checkmark.circle", text: "Works in any text field")
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Insertion Feature Row

struct InsertionFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @State private var isRecordingHotkey = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Hotkey configuration
                    Text("Global Hotkey")
                        .font(.headline)
                    
                    Text("Press this keyboard shortcut from any app to start/stop voice recording.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        // Current hotkey display
                        HotkeyRecorderView(
                            hotkeyManager: hotkeyManager,
                            isRecording: $isRecordingHotkey
                        )
                        
                        // Reset to default button
                        Button(action: {
                            hotkeyManager.resetToDefault()
                        }) {
                            Text("Reset")
                        }
                        .disabled(hotkeyManager.configuration == .defaultHotkey)
                    }
                    
                    if isRecordingHotkey {
                        Text("Press your desired key combination...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Launch at Login
                    Text("Startup")
                        .font(.headline)
                    
                    Toggle("Launch WispFlow at Login", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, newValue in
                            setLaunchAtLogin(enabled: newValue)
                        }
                    
                    Text("Automatically start WispFlow when you log in to your Mac.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About WispFlow")
                        .font(.headline)
                    
                    Text("Version 0.1 (MVP)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Voice-to-text dictation with AI-powered transcription and auto-editing. All processing happens locally on your device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .onAppear {
            // Refresh launch at login status
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                print("Launch at login enabled")
            } else {
                try SMAppService.mainApp.unregister()
                print("Launch at login disabled")
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            // Revert the toggle on failure
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Hotkey Recorder View

struct HotkeyRecorderView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @Binding var isRecording: Bool
    @State private var localEventMonitor: Any?
    
    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            HStack {
                if isRecording {
                    Image(systemName: "keyboard")
                        .foregroundColor(.orange)
                    Text("Recording...")
                        .foregroundColor(.orange)
                } else {
                    Text(hotkeyManager.hotkeyDisplayString)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .frame(minWidth: 120)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .onDisappear {
            stopRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        
        // Install a local event monitor to capture key presses
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            // Ignore modifier-only key presses (flagsChanged)
            if event.type == .keyDown {
                handleKeyEvent(event)
                return nil // Consume the event
            }
            return event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Get modifiers (excluding caps lock, function, etc.)
        let relevantFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let modifiers = event.modifierFlags.intersection(relevantFlags)
        
        // Require at least one modifier key
        guard !modifiers.isEmpty else {
            print("HotkeyRecorder: Hotkey must include at least one modifier (Cmd, Shift, Option, or Control)")
            return
        }
        
        // Ignore Escape key (cancel)
        if event.keyCode == 53 { // kVK_Escape
            stopRecording()
            return
        }
        
        // Create new configuration
        let newConfig = HotkeyManager.HotkeyConfiguration(
            keyCode: event.keyCode,
            modifierFlags: modifiers
        )
        
        // Update the hotkey manager (this persists automatically)
        hotkeyManager.updateConfiguration(newConfig)
        
        // Stop recording
        stopRecording()
        
        print("HotkeyRecorder: New hotkey set to \(newConfig.displayString)")
    }
}

import ServiceManagement

// MARK: - Settings Window Controller

final class SettingsWindowController: NSObject {
    private var settingsWindow: NSWindow?
    private let whisperManager: WhisperManager
    private let textCleanupManager: TextCleanupManager
    private let textInserter: TextInserter
    private let hotkeyManager: HotkeyManager
    
    init(whisperManager: WhisperManager, textCleanupManager: TextCleanupManager, textInserter: TextInserter, hotkeyManager: HotkeyManager) {
        self.whisperManager = whisperManager
        self.textCleanupManager = textCleanupManager
        self.textInserter = textInserter
        self.hotkeyManager = hotkeyManager
        super.init()
    }
    
    func showSettings() {
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(
            whisperManager: whisperManager,
            textCleanupManager: textCleanupManager,
            textInserter: textInserter,
            hotkeyManager: hotkeyManager
        )
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "WispFlow Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        
        // Handle window close
        window.delegate = self
        
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
    }
}

// Import SwiftUI hosting controller
import AppKit
