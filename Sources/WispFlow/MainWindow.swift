import SwiftUI
import AppKit

// MARK: - Navigation Item Enum

/// Navigation items for the main window sidebar
/// US-632: Main Window with Sidebar Navigation
enum NavigationItem: String, CaseIterable, Identifiable {
    case home = "home"
    case history = "history"
    case snippets = "snippets"
    case dictionary = "dictionary"
    case settings = "settings"
    
    var id: String { rawValue }
    
    /// Display name for the navigation item
    var displayName: String {
        switch self {
        case .home:
            return "Home"
        case .history:
            return "History"
        case .snippets:
            return "Snippets"
        case .dictionary:
            return "Dictionary"
        case .settings:
            return "Settings"
        }
    }
    
    /// SF Symbol icon name for the navigation item
    /// Each icon is distinctive and represents the feature clearly
    var iconName: String {
        switch self {
        case .home:
            return "house.fill"
        case .history:
            return "clock.fill"
        case .snippets:
            return "doc.on.clipboard.fill"
        case .dictionary:
            return "character.book.closed.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
    
    /// Icon name for inactive/outline state
    var iconNameInactive: String {
        switch self {
        case .home:
            return "house"
        case .history:
            return "clock"
        case .snippets:
            return "doc.on.clipboard"
        case .dictionary:
            return "character.book.closed"
        case .settings:
            return "gearshape"
        }
    }
}

// MARK: - Main Window View

/// Main application window with sidebar navigation
/// US-632: Main Window with Sidebar Navigation
struct MainWindowView: View {
    /// Currently selected navigation item
    @State private var selectedItem: NavigationItem = .home
    
    /// Whether the sidebar is collapsed (icon-only mode)
    @State private var isSidebarCollapsed: Bool = false
    
    /// Track window width for auto-collapse
    @State private var windowWidth: CGFloat = 900
    
    /// Animation namespace for shared transitions
    @Namespace private var animationNamespace
    
    /// Sidebar width constants
    private let sidebarExpandedWidth: CGFloat = 220
    private let sidebarCollapsedWidth: CGFloat = 70
    private let collapseThreshold: CGFloat = 700
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // MARK: - Sidebar
                sidebarView
                    .frame(width: isSidebarCollapsed ? sidebarCollapsedWidth : sidebarExpandedWidth)
                
                // MARK: - Subtle Separator
                Rectangle()
                    .fill(Color.Wispflow.border.opacity(0.5))
                    .frame(width: 1)
                    .wispflowShadow(.subtle)
                
                // MARK: - Main Content Area
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                windowWidth = newWidth
                // Auto-collapse sidebar when window too small
                withAnimation(WispflowAnimation.smooth) {
                    isSidebarCollapsed = newWidth < collapseThreshold
                }
            }
            .onAppear {
                windowWidth = geometry.size.width
                isSidebarCollapsed = geometry.size.width < collapseThreshold
            }
        }
        .background(Color.Wispflow.background)
    }
    
    // MARK: - Sidebar View
    
    /// Fixed left sidebar with navigation items
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App branding area
            sidebarHeader
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // Navigation items
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(NavigationItem.allCases) { item in
                    NavigationItemRow(
                        item: item,
                        isSelected: selectedItem == item,
                        isCollapsed: isSidebarCollapsed,
                        animationNamespace: animationNamespace,
                        onSelect: {
                            withAnimation(WispflowAnimation.smooth) {
                                selectedItem = item
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
            
            Spacer()
            
            // Collapse toggle button
            collapseToggleButton
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.lg)
        }
        .frame(maxHeight: .infinity)
        .background(Color.Wispflow.surface)
    }
    
    // MARK: - Sidebar Header
    
    /// App branding/logo area at top of sidebar
    private var sidebarHeader: some View {
        HStack(spacing: Spacing.md) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(
                        LinearGradient(
                            colors: [Color.Wispflow.accent.opacity(0.9), Color.Wispflow.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            
            if !isSidebarCollapsed {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WispFlow")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    Text("Voice to Text")
                        .font(Font.Wispflow.small)
                        .foregroundColor(Color.Wispflow.textSecondary)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            
            Spacer()
        }
        .padding(Spacing.lg)
        .animation(WispflowAnimation.smooth, value: isSidebarCollapsed)
    }
    
    // MARK: - Collapse Toggle Button
    
    /// Button to manually toggle sidebar collapse state
    private var collapseToggleButton: some View {
        Button(action: {
            withAnimation(WispflowAnimation.smooth) {
                isSidebarCollapsed.toggle()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isSidebarCollapsed ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Wispflow.textSecondary)
                
                if !isSidebarCollapsed {
                    Text("Collapse")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .transition(.opacity)
                }
            }
            .padding(Spacing.sm)
            .frame(maxWidth: isSidebarCollapsed ? 44 : .infinity, alignment: isSidebarCollapsed ? .center : .leading)
            .background(Color.Wispflow.border.opacity(0.3))
            .cornerRadius(CornerRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
        .help(isSidebarCollapsed ? "Expand sidebar" : "Collapse sidebar")
    }
    
    // MARK: - Content View
    
    /// Main content area that displays the selected view
    private var contentView: some View {
        Group {
            switch selectedItem {
            case .home:
                HomeContentView()
            case .history:
                HistoryContentView()
            case .snippets:
                SnippetsContentView()
            case .dictionary:
                DictionaryContentView()
            case .settings:
                SettingsContentView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(WispflowAnimation.tabTransition, value: selectedItem)
    }
}

// MARK: - Navigation Item Row

/// Single navigation item in the sidebar
struct NavigationItemRow: View {
    let item: NavigationItem
    let isSelected: Bool
    let isCollapsed: Bool
    let animationNamespace: Namespace.ID
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                // Icon
                Image(systemName: isSelected ? item.iconName : item.iconNameInactive)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color.Wispflow.accent : Color.Wispflow.textSecondary)
                    .frame(width: 24, height: 24)
                
                // Label (hidden when collapsed)
                if !isCollapsed {
                    Text(item.displayName)
                        .font(Font.Wispflow.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? Color.Wispflow.textPrimary : Color.Wispflow.textSecondary)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
                
                if !isCollapsed {
                    Spacer()
                }
            }
            .padding(.horizontal, isCollapsed ? Spacing.md : Spacing.md)
            .padding(.vertical, Spacing.sm + 2)
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .background(
                ZStack {
                    // Selected indicator - left accent bar
                    if isSelected {
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(Color.Wispflow.accentLight)
                            .matchedGeometryEffect(id: "selectedBackground", in: animationNamespace)
                    }
                    
                    // Hover highlight
                    if isHovering && !isSelected {
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(Color.Wispflow.border.opacity(0.4))
                    }
                }
            )
            .overlay(
                // Left accent indicator for selected item
                HStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.Wispflow.accent)
                            .frame(width: 3)
                            .transition(.opacity)
                    }
                    Spacer()
                }
            )
            .cornerRadius(CornerRadius.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(WispflowAnimation.quick) {
                isHovering = hovering
            }
        }
        .help(item.displayName)
    }
}

// MARK: - Dashboard Home View (US-633)

/// Dashboard home view showing activity and quick actions
/// US-633: Dashboard Home View
struct HomeContentView: View {
    @StateObject private var statsManager = UsageStatsManager.shared
    @State private var hoveredQuickAction: QuickAction?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // MARK: - Welcome Message
                welcomeSection
                
                // MARK: - Usage Statistics Row
                if statsManager.hasActivity {
                    statsSection
                } else {
                    emptyStatsSection
                }
                
                // MARK: - Feature Banner (optional promotional area)
                featureBannerSection
                
                // MARK: - Quick Actions
                quickActionsSection
                
                // MARK: - Recent Activity Timeline
                recentActivitySection
                
                Spacer(minLength: Spacing.xxl)
            }
            .padding(Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Wispflow.background)
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                // Greeting based on time of day
                Text(greetingMessage)
                    .font(Font.Wispflow.largeTitle)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Spacer()
                
                // Current date
                Text(currentDateString)
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textSecondary)
            }
            
            Text("Ready to capture your thoughts")
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
    }
    
    /// Time-based greeting message
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }
    
    /// Current date string
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Your Activity")
                .font(Font.Wispflow.headline)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            HStack(spacing: Spacing.lg) {
                // Streak Days
                StatCard(
                    icon: "flame.fill",
                    value: "\(statsManager.streakDays)",
                    label: "Day Streak",
                    iconColor: .orange
                )
                
                // Total Words
                StatCard(
                    icon: "text.word.spacing",
                    value: formatNumber(statsManager.totalWordsTranscribed),
                    label: "Words",
                    iconColor: Color.Wispflow.accent
                )
                
                // Average WPM
                StatCard(
                    icon: "speedometer",
                    value: String(format: "%.0f", statsManager.averageWPM),
                    label: "Avg WPM",
                    iconColor: Color.Wispflow.info
                )
                
                // Total Transcriptions
                StatCard(
                    icon: "waveform",
                    value: "\(statsManager.totalTranscriptions)",
                    label: "Recordings",
                    iconColor: Color.Wispflow.success
                )
            }
        }
    }
    
    /// Empty state for stats section showing onboarding prompt
    private var emptyStatsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Get Started")
                .font(Font.Wispflow.headline)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            HStack(spacing: Spacing.lg) {
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Wispflow.accent)
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Record your first transcription")
                        .font(Font.Wispflow.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    Text("Press ⌘⇧Space anywhere to start recording")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                }
                
                Spacer()
            }
            .padding(Spacing.lg)
            .background(Color.Wispflow.accentLight)
            .cornerRadius(CornerRadius.medium)
        }
    }
    
    // MARK: - Feature Banner Section
    
    private var featureBannerSection: some View {
        HStack(spacing: Spacing.lg) {
            // Banner icon
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(
                        LinearGradient(
                            colors: [Color.Wispflow.accent.opacity(0.8), Color.Wispflow.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("AI-Powered Text Cleanup")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Text("Enable intelligent formatting and punctuation in Settings → Text Cleanup")
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textSecondary)
            }
            
            Spacer()
            
            Button(action: {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }) {
                Text("Settings")
                    .font(Font.Wispflow.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.Wispflow.accent)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.Wispflow.accentLight)
                    .cornerRadius(CornerRadius.small)
            }
            .buttonStyle(InteractiveScaleStyle())
        }
        .padding(Spacing.lg)
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .wispflowShadow(.subtle)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Quick Actions")
                .font(Font.Wispflow.headline)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            HStack(spacing: Spacing.lg) {
                ForEach(QuickAction.allCases) { action in
                    QuickActionCard(
                        action: action,
                        isHovered: hoveredQuickAction == action,
                        onHover: { isHovering in
                            withAnimation(WispflowAnimation.quick) {
                                hoveredQuickAction = isHovering ? action : nil
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Recent Activity")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Spacer()
                
                if !statsManager.recentEntries.isEmpty {
                    Text("\(statsManager.recentEntries.count) entries")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                }
            }
            
            if statsManager.recentEntries.isEmpty {
                // Empty state
                emptyActivityState
            } else {
                // Activity timeline
                activityTimeline
            }
        }
    }
    
    /// Empty state for activity section
    private var emptyActivityState: some View {
        HStack {
            Spacer()
            VStack(spacing: Spacing.md) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Wispflow.textTertiary)
                
                Text("No transcriptions yet")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
                
                Text("Your recent activity will appear here")
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textTertiary)
            }
            .padding(.vertical, Spacing.xxl)
            Spacer()
        }
        .background(Color.Wispflow.surfaceSecondary.opacity(0.5))
        .cornerRadius(CornerRadius.medium)
    }
    
    /// Activity timeline with dated entries
    private var activityTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group entries by date
            ForEach(groupedEntries.keys.sorted(by: >), id: \.self) { date in
                if let entries = groupedEntries[date] {
                    // Date header
                    dateHeader(for: date)
                    
                    // Entries for this date
                    ForEach(entries) { entry in
                        ActivityTimelineEntry(entry: entry)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .wispflowShadow(.subtle)
    }
    
    /// Group entries by date
    private var groupedEntries: [Date: [TranscriptionEntry]] {
        let calendar = Calendar.current
        var groups: [Date: [TranscriptionEntry]] = [:]
        
        for entry in statsManager.recentEntries {
            let dateKey = calendar.startOfDay(for: entry.timestamp)
            if groups[dateKey] == nil {
                groups[dateKey] = []
            }
            groups[dateKey]?.append(entry)
        }
        
        return groups
    }
    
    /// Date header for activity timeline
    private func dateHeader(for date: Date) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let label: String
        if calendar.isDate(date, inSameDayAs: today) {
            label = "Today"
        } else if calendar.isDate(date, inSameDayAs: yesterday) {
            label = "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            label = formatter.string(from: date)
        }
        
        return Text(label)
            .font(Font.Wispflow.caption)
            .fontWeight(.semibold)
            .foregroundColor(Color.Wispflow.textSecondary)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.xs)
    }
    
    // MARK: - Helpers
    
    /// Format large numbers with K/M suffix
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        }
        return "\(number)"
    }
}

// MARK: - Stat Card Component

/// Individual stat card with icon and value
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: Color
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            // Value
            Text(value)
                .font(Font.Wispflow.title)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            // Label
            Text(label)
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .wispflowShadow(.subtle)
    }
}

// MARK: - Quick Action Model

/// Quick action types for dashboard
enum QuickAction: String, CaseIterable, Identifiable {
    case newRecording = "new_recording"
    case viewHistory = "view_history"
    case openSnippets = "open_snippets"
    case openSettings = "open_settings"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .newRecording:
            return "New Recording"
        case .viewHistory:
            return "View History"
        case .openSnippets:
            return "Snippets"
        case .openSettings:
            return "Settings"
        }
    }
    
    var description: String {
        switch self {
        case .newRecording:
            return "Start a new voice transcription"
        case .viewHistory:
            return "Browse past transcriptions"
        case .openSnippets:
            return "Save and reuse text snippets"
        case .openSettings:
            return "Configure WispFlow preferences"
        }
    }
    
    var icon: String {
        switch self {
        case .newRecording:
            return "mic.fill"
        case .viewHistory:
            return "clock.fill"
        case .openSnippets:
            return "doc.on.clipboard.fill"
        case .openSettings:
            return "gearshape.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .newRecording:
            return Color.Wispflow.accent
        case .viewHistory:
            return Color.Wispflow.info
        case .openSnippets:
            return Color.Wispflow.success
        case .openSettings:
            return Color.Wispflow.textSecondary
        }
    }
}

// MARK: - Quick Action Card Component

/// Quick action card with hover lift effect
struct QuickActionCard: View {
    let action: QuickAction
    let isHovered: Bool
    var onHover: (Bool) -> Void
    
    var body: some View {
        Button(action: performAction) {
            VStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(action.iconColor.opacity(isHovered ? 0.2 : 0.12))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: action.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(action.iconColor)
                }
                
                // Label
                Text(action.title)
                    .font(Font.Wispflow.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                // Description
                Text(action.description)
                    .font(Font.Wispflow.small)
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.md)
            .background(Color.Wispflow.surface)
            .cornerRadius(CornerRadius.medium)
            // Hover lift effect: shadow and slight scale
            .wispflowShadow(isHovered ? .card : .subtle)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .offset(y: isHovered ? -2 : 0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            onHover(hovering)
        }
        .animation(WispflowAnimation.quick, value: isHovered)
    }
    
    private func performAction() {
        switch action {
        case .newRecording:
            // Note: Recording is triggered via hotkey, show hint
            // Could post notification to show recording hint
            print("QuickAction: New Recording tapped - use hotkey ⌘⇧Space")
        case .viewHistory:
            // Navigate to history tab (would require coordination with parent)
            print("QuickAction: View History tapped")
        case .openSnippets:
            // Navigate to snippets tab
            print("QuickAction: Open Snippets tapped")
        case .openSettings:
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }
    }
}

// MARK: - Activity Timeline Entry Component

/// Single entry in the activity timeline
struct ActivityTimelineEntry: View {
    let entry: TranscriptionEntry
    @State private var isHovered = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.md) {
                // Timeline dot and line
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.Wispflow.accent)
                        .frame(width: 8, height: 8)
                    
                    Rectangle()
                        .fill(Color.Wispflow.border)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 20)
                
                // Entry content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        // Timestamp
                        Text(entry.timeString)
                            .font(Font.Wispflow.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        // Word count badge
                        Text("\(entry.wordCount) words")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textTertiary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                        
                        Spacer()
                        
                        // Expand/collapse button
                        Button(action: { 
                            withAnimation(WispflowAnimation.quick) {
                                isExpanded.toggle() 
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.Wispflow.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(isHovered || isExpanded ? 1 : 0)
                    }
                    
                    // Text preview
                    Text(entry.textPreview)
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textPrimary)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // WPM info when expanded
                    if isExpanded {
                        HStack(spacing: Spacing.md) {
                            Label(String(format: "%.0f WPM", entry.wordsPerMinute), systemImage: "speedometer")
                            Label(String(format: "%.1fs", entry.durationSeconds), systemImage: "clock")
                        }
                        .font(Font.Wispflow.small)
                        .foregroundColor(Color.Wispflow.textTertiary)
                        .padding(.top, Spacing.xs)
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
            .padding(.horizontal, Spacing.sm)
            .background(isHovered ? Color.Wispflow.surfaceSecondary.opacity(0.5) : Color.clear)
            .cornerRadius(CornerRadius.small)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(WispflowAnimation.quick) {
                    isHovered = hovering
                }
            }
        }
    }
}

// MARK: - Placeholder Content Views

/// History view placeholder (to be implemented in US-634)
struct HistoryContentView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "clock.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.Wispflow.accent.opacity(0.5))
            
            Text("History")
                .font(Font.Wispflow.largeTitle)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            Text("Transcription history will appear here")
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Wispflow.background)
    }
}

/// Snippets view placeholder (to be implemented in US-635)
struct SnippetsContentView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.Wispflow.accent.opacity(0.5))
            
            Text("Snippets")
                .font(Font.Wispflow.largeTitle)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            Text("Save and reuse text snippets")
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Wispflow.background)
    }
}

/// Dictionary view placeholder (to be implemented in US-636)
struct DictionaryContentView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.Wispflow.accent.opacity(0.5))
            
            Text("Dictionary")
                .font(Font.Wispflow.largeTitle)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            Text("Custom words and phrases for better transcription")
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Wispflow.background)
    }
}

/// Settings view placeholder (redirects to Settings window)
struct SettingsContentView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.Wispflow.accent.opacity(0.5))
            
            Text("Settings")
                .font(Font.Wispflow.largeTitle)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            Text("Configure WispFlow preferences")
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
            
            Button(action: {
                // Post notification to open settings
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .medium))
                    Text("Open Settings Window")
                }
                .font(Font.Wispflow.body)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color.Wispflow.accent)
                .cornerRadius(CornerRadius.small)
            }
            .buttonStyle(InteractiveScaleStyle())
            .padding(.top, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Wispflow.background)
    }
}

// MARK: - Main Window Controller

/// Controller for the main application window
/// Handles window state persistence and lifecycle
final class MainWindowController: NSObject {
    private var mainWindow: NSWindow?
    
    /// UserDefaults keys for window state persistence
    private enum WindowStateKeys {
        static let frameKey = "MainWindowFrame"
        static let wasOpen = "MainWindowWasOpen"
    }
    
    /// Minimum window size (800x600 as specified)
    private let minimumSize = NSSize(width: 800, height: 600)
    
    /// Default window size
    private let defaultSize = NSSize(width: 1000, height: 700)
    
    override init() {
        super.init()
    }
    
    /// Show the main window
    func showMainWindow() {
        if let existingWindow = mainWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let mainView = MainWindowView()
        let hostingController = NSHostingController(rootView: mainView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "WispFlow"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = minimumSize
        window.delegate = self
        
        // Restore saved window frame or use default
        if let savedFrame = loadWindowFrame() {
            window.setFrame(savedFrame, display: true)
        } else {
            window.setContentSize(defaultSize)
            window.center()
        }
        
        // Use autosave for window position
        window.setFrameAutosaveName("MainWindow")
        
        mainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Mark window as open
        UserDefaults.standard.set(true, forKey: WindowStateKeys.wasOpen)
    }
    
    /// Close the main window
    func closeMainWindow() {
        mainWindow?.close()
    }
    
    /// Check if main window is currently open
    var isWindowOpen: Bool {
        return mainWindow != nil && mainWindow!.isVisible
    }
    
    // MARK: - Window State Persistence
    
    /// Save window frame to UserDefaults
    private func saveWindowFrame() {
        guard let window = mainWindow else { return }
        let frameString = NSStringFromRect(window.frame)
        UserDefaults.standard.set(frameString, forKey: WindowStateKeys.frameKey)
    }
    
    /// Load saved window frame from UserDefaults
    private func loadWindowFrame() -> NSRect? {
        guard let frameString = UserDefaults.standard.string(forKey: WindowStateKeys.frameKey) else {
            return nil
        }
        let frame = NSRectFromString(frameString)
        // Validate frame is reasonable
        if frame.width >= minimumSize.width && frame.height >= minimumSize.height {
            return frame
        }
        return nil
    }
}

// MARK: - NSWindowDelegate

extension MainWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        saveWindowFrame()
        UserDefaults.standard.set(false, forKey: "MainWindowWasOpen")
        mainWindow = nil
    }
    
    func windowDidResize(_ notification: Notification) {
        // Save frame on resize for persistence
        saveWindowFrame()
    }
    
    func windowDidMove(_ notification: Notification) {
        // Save frame when window is moved
        saveWindowFrame()
    }
}

// Note: openSettings notification is already defined in ToastView.swift
// We use the existing Notification.Name.openSettings from there

// MARK: - Preview Provider

#if DEBUG
struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView()
            .frame(width: 1000, height: 700)
    }
}
#endif
