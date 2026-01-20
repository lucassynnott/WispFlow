import SwiftUI
import AppKit

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                     VOXA ACCESSIBILITY SUPPORT                                ║
// ║                                                                               ║
// ║  US-037: Accessibility Support                                                ║
// ║  - All UI elements have proper accessibility labels                           ║
// ║  - VoiceOver can navigate the entire interface                                ║
// ║  - Full keyboard navigation is supported                                      ║
// ║  - Focus states are clearly visible                                           ║
// ║                                                                               ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

// MARK: - Accessibility Labels for Navigation Items

extension NavigationItem {
    /// Accessibility label for VoiceOver
    var accessibilityLabel: String {
        switch self {
        case .home:
            return "Home, dashboard view"
        case .history:
            return "History, view past transcriptions"
        case .snippets:
            return "Snippets, manage saved text snippets"
        case .dictionary:
            return "Dictionary, manage custom words"
        case .settings:
            return "Settings, configure app preferences"
        }
    }

    /// Accessibility hint describing what happens on activation
    var accessibilityHint: String {
        "Double tap to navigate to \(displayName)"
    }
}

// MARK: - Accessibility Labels for Quick Actions

extension QuickAction {
    /// Accessibility label for VoiceOver
    var accessibilityLabel: String {
        "\(title), \(description)"
    }

    /// Accessibility hint for VoiceOver
    var accessibilityHint: String {
        "Double tap to \(description.lowercased())"
    }
}

// MARK: - Accessibility Labels for Quick Tool Actions

extension QuickToolAction {
    /// Accessibility label for VoiceOver
    var accessibilityLabel: String {
        "\(title), \(description)"
    }

    /// Accessibility hint for VoiceOver
    var accessibilityHint: String {
        "Double tap to \(description.lowercased())"
    }
}

// MARK: - Focus Ring Style

/// Custom focus ring style for consistent visual feedback
/// US-037: Focus states are clearly visible
struct VoxaFocusRingStyle: ViewModifier {
    @Environment(\.isFocused) private var isFocused
    var cornerRadius: CGFloat = CornerRadius.small

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isFocused ? Color.Voxa.accent : Color.clear,
                        lineWidth: 2
                    )
                    .padding(-2)
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

extension View {
    /// Apply Voxa focus ring style for keyboard navigation visibility
    /// US-037: Focus states are clearly visible
    func voxaFocusRing(cornerRadius: CGFloat = CornerRadius.small) -> some View {
        self.modifier(VoxaFocusRingStyle(cornerRadius: cornerRadius))
    }
}

// MARK: - Accessible Button Style

/// Button style that adds accessibility support and visible focus states
/// US-037: Accessibility Support
struct AccessibleButtonStyle: ButtonStyle {
    var label: String
    var hint: String?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Accessibility View Modifiers

/// View modifier to add comprehensive accessibility support
/// US-037: All UI elements have proper accessibility labels
struct AccessibleElement: ViewModifier {
    let label: String
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits

    init(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) {
        self.label = label
        self.hint = hint
        self.value = value
        self.traits = traits
    }

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
}

extension View {
    /// Add comprehensive accessibility support to any view
    /// US-037: All UI elements have proper accessibility labels
    func accessible(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self.modifier(AccessibleElement(
            label: label,
            hint: hint,
            value: value,
            traits: traits
        ))
    }

    /// Mark a view as a button with accessibility label
    func accessibleButton(_ label: String, hint: String? = nil) -> some View {
        self.accessible(label: label, hint: hint, traits: .isButton)
    }

    /// Mark a view as a header for VoiceOver navigation
    func accessibleHeader(_ label: String) -> some View {
        self.accessible(label: label, traits: .isHeader)
    }

    /// Mark a view as containing static text
    func accessibleStaticText(_ label: String) -> some View {
        self.accessible(label: label, traits: .isStaticText)
    }

    /// Mark a view as an image with description
    func accessibleImage(_ description: String) -> some View {
        self.accessible(label: description, traits: .isImage)
    }

    /// Mark a decorative element that should be hidden from VoiceOver
    func accessibilityDecorative() -> some View {
        self.accessibilityHidden(true)
    }
}

// MARK: - Keyboard Navigation Support

/// View modifier that enables keyboard focus and navigation
/// US-037: Full keyboard navigation is supported
struct KeyboardNavigable: ViewModifier {
    @FocusState private var isFocused: Bool
    var onActivate: () -> Void

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(isFocused ? Color.Voxa.accent : Color.clear, lineWidth: 2)
                    .padding(-2)
            )
            .onKeyPress(.return) {
                onActivate()
                return .handled
            }
            .onKeyPress(.space) {
                onActivate()
                return .handled
            }
    }
}

extension View {
    /// Make a view keyboard navigable with Return/Space activation
    /// US-037: Full keyboard navigation is supported
    func keyboardNavigable(onActivate: @escaping () -> Void) -> some View {
        self.modifier(KeyboardNavigable(onActivate: onActivate))
    }
}

// MARK: - Accessible Stat Card

/// Accessibility wrapper for stat cards that provides proper VoiceOver support
/// US-037: VoiceOver can navigate the entire interface
struct AccessibleStatCard: ViewModifier {
    let icon: String
    let value: String
    let label: String

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label): \(value)")
            .accessibilityHint("Statistic showing your \(label.lowercased())")
    }
}

extension View {
    /// Add stat card accessibility
    func accessibleStatCard(icon: String, value: String, label: String) -> some View {
        self.modifier(AccessibleStatCard(icon: icon, value: value, label: label))
    }
}

// MARK: - Accessible Toggle

/// View modifier to enhance toggle accessibility
/// US-037: All UI elements have proper accessibility labels
struct AccessibleToggle: ViewModifier {
    let label: String
    let isOn: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityHint("Double tap to toggle")
            .accessibilityAddTraits(.isButton)
    }
}

extension View {
    /// Add toggle accessibility with on/off state
    func accessibleToggle(_ label: String, isOn: Bool) -> some View {
        self.modifier(AccessibleToggle(label: label, isOn: isOn))
    }
}

// MARK: - Accessible List Item

/// View modifier for accessible list items with position information
/// US-037: VoiceOver can navigate the entire interface
struct AccessibleListItem: ViewModifier {
    let label: String
    let index: Int
    let total: Int

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint("Item \(index + 1) of \(total)")
    }
}

extension View {
    /// Add list item accessibility with position
    func accessibleListItem(_ label: String, index: Int, total: Int) -> some View {
        self.modifier(AccessibleListItem(label: label, index: index, total: total))
    }
}

// MARK: - Accessible Section

/// View modifier for accessible sections with header
/// US-037: VoiceOver can navigate the entire interface
struct AccessibleSection: ViewModifier {
    let title: String
    let itemCount: Int?

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityLabelText)
    }

    private var accessibilityLabelText: String {
        if let count = itemCount {
            return "\(title) section, \(count) item\(count == 1 ? "" : "s")"
        }
        return "\(title) section"
    }
}

extension View {
    /// Add section accessibility with optional item count
    func accessibleSection(_ title: String, itemCount: Int? = nil) -> some View {
        self.modifier(AccessibleSection(title: title, itemCount: itemCount))
    }
}

// MARK: - Focus Management

/// Focus scope identifier for main window navigation
enum MainWindowFocus: Hashable {
    case sidebar
    case content
    case search
    case primaryAction
}

/// Focus scope identifier for settings navigation
enum SettingsFocus: Hashable {
    case section(String)
    case control(String)
}

// MARK: - Accessibility Announcements

/// Priority levels for VoiceOver announcements
enum AnnouncementPriority: Int {
    case low = 0
    case medium = 50
    case high = 100
}

/// Helper for making VoiceOver announcements
enum AccessibilityAnnouncer {
    /// Announce a message to VoiceOver users
    static func announce(_ message: String, priority: AnnouncementPriority = .medium) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSNumber(value: priority.rawValue)
            ]
        )
    }

    /// Announce recording state change
    static func announceRecordingState(_ state: RecordingState) {
        let message: String
        switch state {
        case .idle:
            message = "Recording stopped"
        case .recording:
            message = "Recording started"
        case .processing:
            message = "Processing transcription"
        case .error:
            message = "An error occurred"
        }
        announce(message, priority: .high)
    }

    /// Announce navigation change
    static func announceNavigation(to item: NavigationItem) {
        announce("Navigated to \(item.displayName)", priority: .medium)
    }

    /// Announce completion of an action
    static func announceCompletion(_ action: String) {
        announce("\(action) completed", priority: .medium)
    }
}

// MARK: - Accessibility Testing Helpers

#if DEBUG
/// Debug view modifier to highlight focusable elements
struct AccessibilityDebugOverlay: ViewModifier {
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    if accessibilityEnabled {
                        Rectangle()
                            .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                }
            )
    }
}

extension View {
    /// Debug overlay showing accessibility boundaries
    func accessibilityDebug() -> some View {
        self.modifier(AccessibilityDebugOverlay())
    }
}
#endif

// MARK: - VoiceOver Rotor Support

/// Custom rotor actions for Voxa
enum VoxaRotorAction: String, CaseIterable {
    case navigateToHome = "Navigate to Home"
    case navigateToHistory = "Navigate to History"
    case navigateToSnippets = "Navigate to Snippets"
    case navigateToDictionary = "Navigate to Dictionary"
    case navigateToSettings = "Navigate to Settings"
    case toggleRecording = "Toggle Recording"

    var accessibilityCustomContentLabel: String {
        rawValue
    }
}

// MARK: - Accessible Navigation Item Row Extension

/// Extension to add accessibility support to navigation items
extension View {
    /// Add navigation item accessibility
    func accessibleNavigationItem(_ item: NavigationItem, isSelected: Bool) -> some View {
        self
            .accessibilityLabel(item.accessibilityLabel)
            .accessibilityHint(item.accessibilityHint)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityValue(isSelected ? "Selected" : "")
    }
}

// MARK: - Accessible Recording Button

/// Extension for recording button accessibility
extension View {
    /// Add recording button accessibility
    func accessibleRecordingButton(isRecording: Bool) -> some View {
        self
            .accessibilityLabel(isRecording ? "Stop Recording" : "Start Recording")
            .accessibilityHint(isRecording ? "Double tap to stop recording" : "Double tap to start recording, or press Option Command R")
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isRecording ? "Recording in progress" : "Ready to record")
    }
}

// MARK: - Transcription Item Accessibility

extension View {
    /// Add transcription item accessibility
    func accessibleTranscriptionItem(
        title: String,
        wordCount: Int,
        duration: String,
        timestamp: String
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), \(wordCount) words, \(duration), \(timestamp)")
            .accessibilityHint("Double tap to copy to clipboard")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Insight Card Accessibility

extension View {
    /// Add insight card accessibility
    func accessibleInsightCard(
        title: String,
        value: String,
        percentageChange: Double?,
        subtitle: String
    ) -> some View {
        var label = "\(title): \(value)"
        if let change = percentageChange {
            let direction = change > 0 ? "up" : (change < 0 ? "down" : "unchanged")
            label += ", \(direction) \(abs(Int(change))) percent"
        }
        label += ", \(subtitle)"

        return self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
    }
}
