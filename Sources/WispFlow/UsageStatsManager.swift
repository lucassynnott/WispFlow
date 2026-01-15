import Foundation

// MARK: - Usage Statistics Manager
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ US-633: Dashboard Home View - Usage Statistics Tracking                      ║
// ║                                                                              ║
// ║ Tracks and persists user activity statistics:                                ║
// ║ - Streak days (consecutive days of transcription)                            ║
// ║ - Total words transcribed                                                    ║
// ║ - Average words per minute (WPM)                                             ║
// ║ - Recent transcription entries for activity timeline                         ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// Data model for a transcription entry in activity history
struct TranscriptionEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let textPreview: String
    let wordCount: Int
    let durationSeconds: Double // Recording duration
    
    init(text: String, durationSeconds: Double) {
        self.id = UUID()
        self.timestamp = Date()
        self.textPreview = String(text.prefix(200)) // Limit preview length
        self.wordCount = Self.countWords(in: text)
        self.durationSeconds = durationSeconds
    }
    
    /// Calculate words per minute for this transcription
    var wordsPerMinute: Double {
        guard durationSeconds > 0 else { return 0 }
        return Double(wordCount) / (durationSeconds / 60.0)
    }
    
    /// Count words in text (simple whitespace split)
    private static func countWords(in text: String) -> Int {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return words.count
    }
}

/// Manager for tracking usage statistics
/// Thread-safe singleton pattern with UserDefaults persistence
@MainActor
final class UsageStatsManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = UsageStatsManager()
    
    // MARK: - Constants
    
    private enum Constants {
        static let statsDataKey = "usageStatsData"
        static let historyDataKey = "transcriptionHistoryData"
        static let lastActiveDate = "lastActiveDate"
        static let currentStreakKey = "currentStreak"
        static let maxHistoryEntries = 50 // Keep last 50 transcriptions
    }
    
    // MARK: - Published Properties
    
    /// Current streak in days
    @Published private(set) var streakDays: Int = 0
    
    /// Total words transcribed
    @Published private(set) var totalWordsTranscribed: Int = 0
    
    /// Total transcriptions count
    @Published private(set) var totalTranscriptions: Int = 0
    
    /// Total recording duration in seconds
    @Published private(set) var totalRecordingDuration: Double = 0
    
    /// Recent transcription entries (newest first)
    @Published private(set) var recentEntries: [TranscriptionEntry] = []
    
    // MARK: - Computed Properties
    
    /// Average words per minute across all transcriptions
    var averageWPM: Double {
        guard totalRecordingDuration > 0 else { return 0 }
        return Double(totalWordsTranscribed) / (totalRecordingDuration / 60.0)
    }
    
    /// Check if user has any activity
    var hasActivity: Bool {
        return totalTranscriptions > 0
    }
    
    // MARK: - Initialization
    
    private init() {
        loadStats()
        loadHistory()
        updateStreakIfNeeded()
        
        print("UsageStatsManager: [US-633] Initialized - Streak: \(streakDays) days, Total words: \(totalWordsTranscribed), Transcriptions: \(totalTranscriptions)")
    }
    
    // MARK: - Public Methods
    
    /// Record a new transcription
    /// - Parameters:
    ///   - text: The transcribed text
    ///   - durationSeconds: Recording duration in seconds
    func recordTranscription(text: String, durationSeconds: Double) {
        let entry = TranscriptionEntry(text: text, durationSeconds: durationSeconds)
        
        // Update totals
        totalWordsTranscribed += entry.wordCount
        totalTranscriptions += 1
        totalRecordingDuration += durationSeconds
        
        // Add to history (newest first)
        recentEntries.insert(entry, at: 0)
        
        // Trim history if needed
        if recentEntries.count > Constants.maxHistoryEntries {
            recentEntries = Array(recentEntries.prefix(Constants.maxHistoryEntries))
        }
        
        // Update streak
        updateStreakForActivity()
        
        // Persist
        saveStats()
        saveHistory()
        
        print("UsageStatsManager: [US-633] Recorded transcription - Words: \(entry.wordCount), WPM: \(String(format: "%.1f", entry.wordsPerMinute)), Total words: \(totalWordsTranscribed)")
    }
    
    /// Clear a specific entry from history
    func removeEntry(_ entry: TranscriptionEntry) {
        recentEntries.removeAll { $0.id == entry.id }
        saveHistory()
    }
    
    /// Clear all history and stats (for testing/reset)
    func resetAllStats() {
        streakDays = 0
        totalWordsTranscribed = 0
        totalTranscriptions = 0
        totalRecordingDuration = 0
        recentEntries = []
        
        UserDefaults.standard.removeObject(forKey: Constants.statsDataKey)
        UserDefaults.standard.removeObject(forKey: Constants.historyDataKey)
        UserDefaults.standard.removeObject(forKey: Constants.lastActiveDate)
        UserDefaults.standard.removeObject(forKey: Constants.currentStreakKey)
        
        print("UsageStatsManager: [US-633] All stats reset")
    }
    
    // MARK: - Persistence
    
    /// Codable structure for stats persistence
    private struct PersistedStats: Codable {
        let totalWordsTranscribed: Int
        let totalTranscriptions: Int
        let totalRecordingDuration: Double
    }
    
    private func loadStats() {
        guard let data = UserDefaults.standard.data(forKey: Constants.statsDataKey) else {
            return
        }
        
        do {
            let stats = try JSONDecoder().decode(PersistedStats.self, from: data)
            totalWordsTranscribed = stats.totalWordsTranscribed
            totalTranscriptions = stats.totalTranscriptions
            totalRecordingDuration = stats.totalRecordingDuration
        } catch {
            print("UsageStatsManager: [US-633] Failed to load stats: \(error)")
        }
        
        // Load streak separately for easier management
        streakDays = UserDefaults.standard.integer(forKey: Constants.currentStreakKey)
    }
    
    private func saveStats() {
        let stats = PersistedStats(
            totalWordsTranscribed: totalWordsTranscribed,
            totalTranscriptions: totalTranscriptions,
            totalRecordingDuration: totalRecordingDuration
        )
        
        do {
            let encoded = try JSONEncoder().encode(stats)
            UserDefaults.standard.set(encoded, forKey: Constants.statsDataKey)
        } catch {
            print("UsageStatsManager: [US-633] Failed to save stats: \(error)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Constants.historyDataKey) else {
            return
        }
        
        do {
            recentEntries = try JSONDecoder().decode([TranscriptionEntry].self, from: data)
        } catch {
            print("UsageStatsManager: [US-633] Failed to load history: \(error)")
        }
    }
    
    private func saveHistory() {
        do {
            let encoded = try JSONEncoder().encode(recentEntries)
            UserDefaults.standard.set(encoded, forKey: Constants.historyDataKey)
        } catch {
            print("UsageStatsManager: [US-633] Failed to save history: \(error)")
        }
    }
    
    // MARK: - Streak Management
    
    /// Update streak count for current activity
    private func updateStreakForActivity() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastActiveData = UserDefaults.standard.object(forKey: Constants.lastActiveDate) as? Date {
            let lastActive = calendar.startOfDay(for: lastActiveData)
            let daysDiff = calendar.dateComponents([.day], from: lastActive, to: today).day ?? 0
            
            if daysDiff == 0 {
                // Same day, streak continues
            } else if daysDiff == 1 {
                // Next day, increment streak
                streakDays += 1
            } else {
                // Gap in days, reset streak
                streakDays = 1
            }
        } else {
            // First activity ever
            streakDays = 1
        }
        
        // Update last active date
        UserDefaults.standard.set(today, forKey: Constants.lastActiveDate)
        UserDefaults.standard.set(streakDays, forKey: Constants.currentStreakKey)
    }
    
    /// Check and update streak on app launch (might have missed days)
    private func updateStreakIfNeeded() {
        guard let lastActiveData = UserDefaults.standard.object(forKey: Constants.lastActiveDate) as? Date else {
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastActive = calendar.startOfDay(for: lastActiveData)
        let daysDiff = calendar.dateComponents([.day], from: lastActive, to: today).day ?? 0
        
        // If more than 1 day has passed without activity, reset streak
        if daysDiff > 1 {
            streakDays = 0
            UserDefaults.standard.set(streakDays, forKey: Constants.currentStreakKey)
            print("UsageStatsManager: [US-633] Streak reset due to inactivity (gap of \(daysDiff) days)")
        }
    }
}

// MARK: - Date Formatting Extensions

extension TranscriptionEntry {
    /// Relative date string for display (e.g., "Today", "Yesterday", "2 days ago")
    var relativeDateString: String {
        let calendar = Calendar.current
        let now = Date()
        let entryDate = calendar.startOfDay(for: timestamp)
        let today = calendar.startOfDay(for: now)
        
        let daysDiff = calendar.dateComponents([.day], from: entryDate, to: today).day ?? 0
        
        switch daysDiff {
        case 0:
            return "Today"
        case 1:
            return "Yesterday"
        case 2...6:
            return "\(daysDiff) days ago"
        default:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: timestamp)
        }
    }
    
    /// Time string for display (e.g., "2:30 PM")
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Full timestamp string
    var fullTimestampString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
