import AppKit

/// Floating recording indicator window that shows when recording is active
/// Displays a pill-shaped overlay with recording status and cancel button
final class RecordingIndicatorWindow: NSPanel {
    
    // MARK: - UI Components
    
    private let containerView = NSView()
    private let recordingIcon = NSImageView()
    private let statusLabel = NSTextField()
    private let cancelButton = NSButton()
    
    /// Callback when cancel button is clicked
    var onCancel: (() -> Void)?
    
    // MARK: - Configuration
    
    private struct Constants {
        static let windowWidth: CGFloat = 160
        static let windowHeight: CGFloat = 44
        static let cornerRadius: CGFloat = 22
        static let padding: CGFloat = 12
        static let iconSize: CGFloat = 20
        static let animationDuration: TimeInterval = 0.2
    }
    
    // MARK: - Initialization
    
    init() {
        // Create a borderless, floating window
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Constants.windowWidth, height: Constants.windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        // Window behavior
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        
        // Appearance
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        
        // Don't show in mission control or expose
        collectionBehavior.insert(.stationary)
        
        // Position window at top center of main screen
        positionWindow()
    }
    
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        // Container view with pill shape
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = Constants.cornerRadius
        containerView.layer?.masksToBounds = true
        
        // Use visual effect view for blur background
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = Constants.cornerRadius
        visualEffect.layer?.masksToBounds = true
        
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(visualEffect)
        
        // Container inside visual effect
        containerView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(containerView)
        
        // Recording icon (pulsing red circle)
        let recordingImage = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
        recordingIcon.image = recordingImage
        recordingIcon.contentTintColor = .systemRed
        recordingIcon.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(recordingIcon)
        
        // Status label
        statusLabel.stringValue = "Recording..."
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .labelColor
        statusLabel.backgroundColor = .clear
        statusLabel.isBordered = false
        statusLabel.isEditable = false
        statusLabel.isSelectable = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        // Cancel button
        let cancelImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Cancel recording")
        cancelButton.image = cancelImage
        cancelButton.imagePosition = .imageOnly
        cancelButton.isBordered = false
        cancelButton.contentTintColor = .secondaryLabelColor
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonClicked)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cancelButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Visual effect fills content view
            visualEffect.topAnchor.constraint(equalTo: contentView.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Container fills visual effect
            containerView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            
            // Recording icon on the left
            recordingIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Constants.padding),
            recordingIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            recordingIcon.widthAnchor.constraint(equalToConstant: Constants.iconSize),
            recordingIcon.heightAnchor.constraint(equalToConstant: Constants.iconSize),
            
            // Status label in the middle
            statusLabel.leadingAnchor.constraint(equalTo: recordingIcon.trailingAnchor, constant: 8),
            statusLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // Cancel button on the right
            cancelButton.leadingAnchor.constraint(greaterThanOrEqualTo: statusLabel.trailingAnchor, constant: 8),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Constants.padding),
            cancelButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: Constants.iconSize),
            cancelButton.heightAnchor.constraint(equalToConstant: Constants.iconSize)
        ])
        
        // Start pulsing animation
        startPulsingAnimation()
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowX = screenFrame.midX - (Constants.windowWidth / 2)
        let windowY = screenFrame.maxY - Constants.windowHeight - 20 // 20px from top
        
        setFrameOrigin(NSPoint(x: windowX, y: windowY))
    }
    
    // MARK: - Animations
    
    private func startPulsingAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 0.4
        pulseAnimation.duration = 0.8
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        recordingIcon.layer?.add(pulseAnimation, forKey: "pulse")
    }
    
    private func stopPulsingAnimation() {
        recordingIcon.layer?.removeAnimation(forKey: "pulse")
    }
    
    // MARK: - Actions
    
    @objc private func cancelButtonClicked() {
        print("Cancel button clicked on recording indicator")
        onCancel?()
    }
    
    // MARK: - Public API
    
    /// Show the indicator with animation
    func showWithAnimation() {
        alphaValue = 0
        orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.animationDuration
            self.animator().alphaValue = 1
        }
        
        startPulsingAnimation()
        print("Recording indicator shown")
    }
    
    /// Hide the indicator with animation
    func hideWithAnimation(completion: (() -> Void)? = nil) {
        stopPulsingAnimation()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Constants.animationDuration
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            completion?()
        })
        
        print("Recording indicator hidden")
    }
    
    /// Update the status text
    func updateStatus(_ text: String) {
        statusLabel.stringValue = text
    }
    
    // MARK: - Window Behavior Overrides
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}
