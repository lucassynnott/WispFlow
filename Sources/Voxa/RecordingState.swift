import Foundation

/// Represents the current recording state of the application
/// US-034: Extended to include processing and error states for menu bar icon display
enum RecordingState: String {
    case idle
    case recording
    case processing
    case error

    /// Toggle between idle and recording states
    mutating func toggle() {
        switch self {
        case .idle:
            self = .recording
        case .recording:
            self = .idle
        case .processing, .error:
            // Cannot toggle from processing or error states
            break
        }
    }

    /// Returns the SF Symbol name for the current state
    var iconName: String {
        switch self {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .processing:
            return "waveform.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    /// Returns the accessibility label for the current state
    var accessibilityLabel: String {
        switch self {
        case .idle:
            return "Voxa - Click to start recording"
        case .recording:
            return "Voxa - Recording... Click to stop"
        case .processing:
            return "Voxa - Processing transcription..."
        case .error:
            return "Voxa - Error occurred"
        }
    }
}
