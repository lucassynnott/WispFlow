import AppKit
import Combine

/// Minimal floating recording indicator - black pill with orange dot and waveform bars
/// Shows recording state and processing state with loading animation
final class RecordingIndicatorWindow: NSPanel {

    // MARK: - UI Components

    private let containerView = NSView()
    private let backgroundLayer = CALayer()
    private let recordingDot = NSView()
    private let waveformView = BarWaveformView()
    private let loadingView = LoadingDotsView()

    /// Callback when indicator is clicked
    var onCancel: (() -> Void)?

    /// Audio level subscription
    private var audioLevelCancellable: AnyCancellable?

    /// Pulse animation for recording dot
    private var pulseTimer: Timer?
    private var pulsePhase: CGFloat = 0

    /// Current state
    private var isProcessing = false

    // MARK: - Configuration

    private struct Constants {
        static let windowWidth: CGFloat = 100
        static let windowHeight: CGFloat = 32
        static let cornerRadius: CGFloat = 16  // Half of height for perfect pill
        static let horizontalPadding: CGFloat = 12
        static let dotSize: CGFloat = 8
        static let animationDuration: TimeInterval = 0.3
        static let slideOffset: CGFloat = 50
    }

    // MARK: - Initialization

    init() {
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
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Make content view fully transparent
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        positionWindow(withSlideOffset: true)
    }

    private func setupUI() {
        guard let contentView = self.contentView else { return }

        // Ensure content view is fully transparent with no border
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.layer?.borderWidth = 0
        contentView.layer?.shadowOpacity = 0

        // Container view - transparent, holds subviews
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.layer?.borderWidth = 0
        containerView.layer?.shadowOpacity = 0
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        // Background layer - simple dark pill, no shadow for clean look
        backgroundLayer.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0).cgColor
        backgroundLayer.cornerRadius = Constants.cornerRadius
        backgroundLayer.masksToBounds = true
        backgroundLayer.borderWidth = 0
        containerView.layer?.addSublayer(backgroundLayer)

        // Recording dot - orange circle
        recordingDot.wantsLayer = true
        recordingDot.layer?.cornerRadius = Constants.dotSize / 2
        recordingDot.layer?.backgroundColor = NSColor(red: 0.92, green: 0.35, blue: 0.2, alpha: 1.0).cgColor
        recordingDot.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(recordingDot)

        // Waveform bars (visible during recording)
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(waveformView)

        // Loading dots (visible during processing)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.isHidden = true
        containerView.addSubview(loadingView)

        // Layout
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            recordingDot.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Constants.horizontalPadding),
            recordingDot.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            recordingDot.widthAnchor.constraint(equalToConstant: Constants.dotSize),
            recordingDot.heightAnchor.constraint(equalToConstant: Constants.dotSize),

            waveformView.leadingAnchor.constraint(equalTo: recordingDot.trailingAnchor, constant: 8),
            waveformView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Constants.horizontalPadding),
            waveformView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            waveformView.heightAnchor.constraint(equalToConstant: 16),

            loadingView.leadingAnchor.constraint(equalTo: recordingDot.trailingAnchor, constant: 8),
            loadingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Constants.horizontalPadding),
            loadingView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            loadingView.heightAnchor.constraint(equalToConstant: 16),
        ])

        // Update background layer frame when container resizes
        containerView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: containerView,
            queue: .main
        ) { [weak self] _ in
            self?.backgroundLayer.frame = self?.containerView.bounds ?? .zero
        }
    }

    private func updateBackgroundFrame() {
        backgroundLayer.frame = containerView.bounds
        // Update shadow path to match rounded rect
        backgroundLayer.shadowPath = CGPath(roundedRect: containerView.bounds, cornerWidth: Constants.cornerRadius, cornerHeight: Constants.cornerRadius, transform: nil)
    }

    private func positionWindow(withSlideOffset: Bool = false) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowX = screenFrame.midX - (Constants.windowWidth / 2)
        let baseY = screenFrame.maxY - Constants.windowHeight - 20
        let windowY = withSlideOffset ? baseY + Constants.slideOffset : baseY

        setFrameOrigin(NSPoint(x: windowX, y: windowY))
    }

    // MARK: - Animations

    private func startPulsingAnimation() {
        stopPulsingAnimation()

        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.pulsePhase += 0.1
            if self.pulsePhase > CGFloat.pi * 2 {
                self.pulsePhase -= CGFloat.pi * 2
            }

            let opacity = 0.6 + 0.4 * sin(self.pulsePhase)

            DispatchQueue.main.async {
                self.recordingDot.layer?.opacity = Float(opacity)
            }
        }
        pulseTimer?.tolerance = 0.01
    }

    private func stopPulsingAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        recordingDot.layer?.opacity = 1.0
    }

    // MARK: - Public API

    func showWithAnimation() {
        isProcessing = false
        waveformView.isHidden = false
        loadingView.isHidden = true
        loadingView.stopAnimating()

        positionWindow(withSlideOffset: true)
        alphaValue = 0
        orderFrontRegardless()

        // Force layout update
        containerView.needsLayout = true
        containerView.layoutSubtreeIfNeeded()
        updateBackgroundFrame()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let targetY = screenFrame.maxY - Constants.windowHeight - 20

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            let currentFrame = self.frame
            self.animator().setFrameOrigin(NSPoint(x: currentFrame.origin.x, y: targetY))
        }

        startPulsingAnimation()
        waveformView.startAnimating()
    }

    /// Switch to processing/loading state
    func showProcessing() {
        isProcessing = true
        stopPulsingAnimation()
        recordingDot.layer?.opacity = 1.0

        // Fade transition between waveform and loading
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.waveformView.animator().alphaValue = 0
        }, completionHandler: {
            self.waveformView.isHidden = true
            self.waveformView.stopAnimating()
            self.loadingView.isHidden = false
            self.loadingView.alphaValue = 0
            self.loadingView.startAnimating()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.loadingView.animator().alphaValue = 1
            }
        })
    }

    func hideWithAnimation(completion: (() -> Void)? = nil) {
        stopPulsingAnimation()
        waveformView.stopAnimating()
        loadingView.stopAnimating()

        guard let screen = NSScreen.main else {
            orderOut(nil)
            completion?()
            return
        }
        let screenFrame = screen.visibleFrame
        let targetY = screenFrame.maxY + Constants.slideOffset

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Constants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
            let currentFrame = self.frame
            self.animator().setFrameOrigin(NSPoint(x: currentFrame.origin.x, y: targetY))
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.positionWindow(withSlideOffset: true)
            self?.resetState()
            completion?()
        })
    }

    private func resetState() {
        isProcessing = false
        waveformView.isHidden = false
        waveformView.alphaValue = 1
        loadingView.isHidden = true
        loadingView.alphaValue = 1
    }

    func updateStatus(_ text: String) {
        // No status label in minimal design
    }

    func updateAudioLevel(_ level: Float) {
        if !isProcessing {
            waveformView.updateLevel(level)
        }
    }

    func connectAudioManager(_ audioManager: AudioManager) {
        audioLevelCancellable = audioManager.$currentAudioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.waveformView.updateLevel(level)
            }
    }

    func disconnectAudioManager() {
        audioLevelCancellable?.cancel()
        audioLevelCancellable = nil
        waveformView.updateLevel(-60.0)
    }

    deinit {
        stopPulsingAnimation()
        audioLevelCancellable?.cancel()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Bar Waveform View

/// Simple vertical bar waveform that responds to audio levels
final class BarWaveformView: NSView {

    private let barCount = 7
    private var barLayers: [CALayer] = []
    private var currentLevel: CGFloat = 0
    private var animationTimer: Timer?
    private var barHeights: [CGFloat] = []

    private struct Constants {
        static let barWidth: CGFloat = 2
        static let barSpacing: CGFloat = 2
        static let minBarHeight: CGFloat = 3
        static let maxBarHeight: CGFloat = 14
        static let minDB: Float = -60.0
        static let maxDB: Float = 0.0
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true

        barHeights = Array(repeating: Constants.minBarHeight, count: barCount)

        for _ in 0..<barCount {
            let bar = CALayer()
            bar.backgroundColor = NSColor.white.cgColor
            bar.cornerRadius = Constants.barWidth / 2
            layer?.addSublayer(bar)
            barLayers.append(bar)
        }
    }

    func startAnimating() {
        stopAnimating()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            self?.updateBars()
        }
        animationTimer?.tolerance = 0.005
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func updateBars() {
        let centerIndex = barCount / 2

        for i in 0..<barCount {
            let distanceFromCenter = abs(i - centerIndex)
            let centerFactor = 1.0 - (CGFloat(distanceFromCenter) / CGFloat(centerIndex + 1)) * 0.4

            let baseHeight = Constants.minBarHeight + (Constants.maxBarHeight - Constants.minBarHeight) * currentLevel * centerFactor
            let randomFactor = CGFloat.random(in: 0.75...1.0)
            let targetHeight = max(Constants.minBarHeight, baseHeight * randomFactor)

            barHeights[i] = barHeights[i] * 0.65 + targetHeight * 0.35
        }

        layoutBars()
    }

    private func layoutBars() {
        let totalWidth = CGFloat(barCount) * Constants.barWidth + CGFloat(barCount - 1) * Constants.barSpacing
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (i, bar) in barLayers.enumerated() {
            let x = startX + CGFloat(i) * (Constants.barWidth + Constants.barSpacing)
            let height = barHeights[i]
            let y = centerY - height / 2

            bar.frame = CGRect(x: x, y: y, width: Constants.barWidth, height: height)
        }

        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        layoutBars()
    }

    func updateLevel(_ level: Float) {
        let clampedLevel = max(Constants.minDB, min(Constants.maxDB, level))
        let percentage = (clampedLevel - Constants.minDB) / (Constants.maxDB - Constants.minDB)
        let curved = pow(CGFloat(percentage), 0.6)
        currentLevel = currentLevel * 0.4 + curved * 0.6
    }

    deinit {
        stopAnimating()
    }
}

// MARK: - Loading Dots View

/// Animated loading dots for processing state
final class LoadingDotsView: NSView {

    private let dotCount = 3
    private var dotLayers: [CALayer] = []
    private var animationTimer: Timer?
    private var phase: CGFloat = 0

    private struct Constants {
        static let dotSize: CGFloat = 4
        static let dotSpacing: CGFloat = 5
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true

        for _ in 0..<dotCount {
            let dot = CALayer()
            dot.backgroundColor = NSColor.white.cgColor
            dot.cornerRadius = Constants.dotSize / 2
            layer?.addSublayer(dot)
            dotLayers.append(dot)
        }

        layoutDots()
    }

    func startAnimating() {
        stopAnimating()
        phase = 0

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
        animationTimer?.tolerance = 0.01
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil

        // Reset dots to default state
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for dot in dotLayers {
            dot.opacity = 0.4
            dot.transform = CATransform3DIdentity
        }
        CATransaction.commit()
    }

    private func updateAnimation() {
        phase += 0.15

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (i, dot) in dotLayers.enumerated() {
            // Staggered wave animation
            let offset = CGFloat(i) * 0.8
            let wave = sin(phase - offset)

            // Opacity pulses between 0.3 and 1.0
            let opacity = 0.3 + 0.7 * max(0, wave)
            dot.opacity = Float(opacity)

            // Scale pulses between 0.8 and 1.2
            let scale = 0.8 + 0.4 * max(0, wave)
            dot.transform = CATransform3DMakeScale(scale, scale, 1)
        }

        CATransaction.commit()
    }

    private func layoutDots() {
        let totalWidth = CGFloat(dotCount) * Constants.dotSize + CGFloat(dotCount - 1) * Constants.dotSpacing
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (i, dot) in dotLayers.enumerated() {
            let x = startX + CGFloat(i) * (Constants.dotSize + Constants.dotSpacing)
            let y = centerY - Constants.dotSize / 2
            dot.frame = CGRect(x: x, y: y, width: Constants.dotSize, height: Constants.dotSize)
        }

        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        layoutDots()
    }

    deinit {
        stopAnimating()
    }
}
