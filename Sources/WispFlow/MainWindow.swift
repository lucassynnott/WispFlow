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

// MARK: - Placeholder Content Views

/// Home view placeholder (to be implemented in US-633)
struct HomeContentView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "house.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.Wispflow.accent.opacity(0.5))
            
            Text("Home")
                .font(Font.Wispflow.largeTitle)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            Text("Dashboard and quick actions coming soon")
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Wispflow.background)
    }
}

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
