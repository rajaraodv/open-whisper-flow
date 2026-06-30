import Cocoa
import Carbon.HIToolbox
import ApplicationServices
import AVFoundation

final class ListeningOverlayView: NSView {
    private var levels: [CGFloat] = [0.30, 0.55, 0.80, 0.45, 0.65]
    private var phase: CGFloat = 0

    // Permission state, refreshed each time the overlay is shown.
    var pasteEnabled = true
    var micEnabled = true

    let capsuleHeight: CGFloat = 60
    let bannerGap: CGFloat = 8
    let bannerHeight: CGFloat = 30

    // The overlay grows upward to make room for the warning banner when paste is unavailable.
    var preferredHeight: CGFloat {
        pasteEnabled ? capsuleHeight : capsuleHeight + bannerGap + bannerHeight
    }

    func updateLevels() {
        levels = levels.map { _ in CGFloat.random(in: 0.25...1.0) }
        phase = phase >= 1 ? 0 : phase + 0.08
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // The capsule always sits at the bottom; the warning banner (if any) stacks above it.
        let capsuleRect = NSRect(x: 0, y: 0, width: bounds.width, height: capsuleHeight)
        drawCapsule(in: capsuleRect)

        if !pasteEnabled {
            let bannerRect = NSRect(x: 0, y: capsuleHeight + bannerGap, width: bounds.width, height: bannerHeight)
            drawWarningBanner(in: bannerRect)
        }
    }

    private func drawCapsule(in rect: NSRect) {
        let capsule = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
        NSColor(calibratedWhite: 0.06, alpha: 0.90).setFill()
        capsule.fill()

        NSColor(calibratedWhite: 1.0, alpha: 0.14).setStroke()
        capsule.lineWidth = 1
        capsule.stroke()

        drawParakeetMark(in: NSRect(x: 16, y: 11, width: 42, height: 38))

        let label = "Parakeet"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        label.draw(at: NSPoint(x: 66, y: 27), withAttributes: attributes)

        let status = pasteEnabled ? "listening" : "paste off · copying"
        let statusAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.58)
        ]
        status.draw(at: NSPoint(x: 66, y: 14), withAttributes: statusAttributes)

        let barStartX: CGFloat = 150
        let barWidth: CGFloat = 5
        let barGap: CGFloat = 6
        let maxHeight: CGFloat = 30
        NSColor(calibratedRed: 0.24, green: 0.78, blue: 1.0, alpha: 1.0).setFill()
        for (index, level) in levels.enumerated() {
            let height = max(8, maxHeight * level)
            let x = barStartX + CGFloat(index) * (barWidth + barGap)
            let y = rect.minY + (rect.height - height) / 2
            let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barWidth, height: height), xRadius: 2.5, yRadius: 2.5)
            path.fill()
        }

        // Permission status dots so the current state is always visible at a glance.
        drawPermissionDot(label: "Mic", enabled: micEnabled, dotCenter: NSPoint(x: 248, y: rect.minY + 40), labelEnd: 240)
        drawPermissionDot(label: "Paste", enabled: pasteEnabled, dotCenter: NSPoint(x: 248, y: rect.minY + 18), labelEnd: 240)
    }

    private func drawPermissionDot(label: String, enabled: Bool, dotCenter: NSPoint, labelEnd: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.72)
        ]
        let size = label.size(withAttributes: attributes)
        label.draw(at: NSPoint(x: labelEnd - size.width, y: dotCenter.y - size.height / 2), withAttributes: attributes)

        let color = enabled
            ? NSColor(calibratedRed: 0.20, green: 0.80, blue: 0.45, alpha: 1.0)
            : NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.32, alpha: 1.0)
        color.setFill()
        let radius: CGFloat = 5
        NSBezierPath(ovalIn: NSRect(x: dotCenter.x - radius, y: dotCenter.y - radius, width: radius * 2, height: radius * 2)).fill()
    }

    private func drawWarningBanner(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
        NSColor(calibratedRed: 0.40, green: 0.14, blue: 0.10, alpha: 0.96).setFill()
        path.fill()
        NSColor(calibratedRed: 1.0, green: 0.52, blue: 0.34, alpha: 0.65).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = "⚠︎ Can’t paste — enable Accessibility to auto-paste"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: rect.minX + 16, y: rect.midY - size.height / 2), withAttributes: attributes)
    }

    private func drawParakeetMark(in rect: NSRect) {
        let bob = sin(phase * .pi * 2) * 1.4
        let bodyRect = rect.offsetBy(dx: 0, dy: bob)

        NSColor(calibratedRed: 0.15, green: 0.79, blue: 0.44, alpha: 1.0).setFill()
        NSBezierPath(ovalIn: NSRect(x: bodyRect.minX + 2, y: bodyRect.minY + 4, width: 30, height: 30)).fill()

        NSColor(calibratedRed: 0.09, green: 0.52, blue: 0.94, alpha: 1.0).setFill()
        let wing = NSBezierPath()
        wing.move(to: NSPoint(x: bodyRect.minX + 10, y: bodyRect.minY + 16))
        wing.curve(
            to: NSPoint(x: bodyRect.minX + 29, y: bodyRect.minY + 12),
            controlPoint1: NSPoint(x: bodyRect.minX + 18, y: bodyRect.minY + 4),
            controlPoint2: NSPoint(x: bodyRect.minX + 28, y: bodyRect.minY + 5)
        )
        wing.curve(
            to: NSPoint(x: bodyRect.minX + 10, y: bodyRect.minY + 16),
            controlPoint1: NSPoint(x: bodyRect.minX + 25, y: bodyRect.minY + 22),
            controlPoint2: NSPoint(x: bodyRect.minX + 17, y: bodyRect.minY + 22)
        )
        wing.fill()

        NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.20, alpha: 1.0).setFill()
        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: bodyRect.minX + 31, y: bodyRect.minY + 23))
        beak.line(to: NSPoint(x: bodyRect.minX + 41, y: bodyRect.minY + 20))
        beak.line(to: NSPoint(x: bodyRect.minX + 31, y: bodyRect.minY + 17))
        beak.close()
        beak.fill()

        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: bodyRect.minX + 20, y: bodyRect.minY + 24, width: 7, height: 7)).fill()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: bodyRect.minX + 23, y: bodyRect.minY + 26, width: 3, height: 3)).fill()

        NSColor(calibratedWhite: 1.0, alpha: 0.18).setStroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: rect.minX, y: rect.minY + 2, width: 36, height: 36))
        ring.lineWidth = 1
        ring.stroke()
    }
}

final class ListeningOverlay {
    private let panel: NSPanel
    private let overlayView: ListeningOverlayView
    private var timer: Timer?

    init() {
        overlayView = ListeningOverlayView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        overlayView.wantsLayer = true

        panel = NSPanel(
            contentRect: overlayView.bounds,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = overlayView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
    }

    func show(pasteEnabled: Bool, micEnabled: Bool) {
        overlayView.pasteEnabled = pasteEnabled
        overlayView.micEnabled = micEnabled

        // Resize for the warning banner (grows upward) before positioning.
        let newSize = NSSize(width: 300, height: overlayView.preferredHeight)
        panel.setContentSize(newSize)
        overlayView.frame = NSRect(origin: .zero, size: newSize)
        overlayView.needsDisplay = true

        position()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.overlayView.updateLevels()
        }
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            panel.animator().alphaValue = 0
        } completionHandler: {
            self.panel.orderOut(nil)
        }
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let frame = panel.frame
        let x = visible.midX - frame.width / 2
        let y = visible.minY + 92
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

final class OnboardingHeroView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = self.bounds
        let background = NSBezierPath(roundedRect: bounds, xRadius: 22, yRadius: 22)
        NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.13, alpha: 1.0).setFill()
        background.fill()

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        "ParaFlow".draw(at: NSPoint(x: 28, y: bounds.height - 58), withAttributes: titleAttributes)

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.68)
        ]
        "Private local dictation powered by Parakeet.".draw(
            at: NSPoint(x: 30, y: bounds.height - 84),
            withAttributes: subtitleAttributes
        )

        let anchorX = bounds.maxX - 158
        let glow = NSBezierPath(ovalIn: NSRect(x: anchorX - 44, y: bounds.midY - 68, width: 148, height: 136))
        NSColor(calibratedRed: 0.12, green: 0.72, blue: 0.50, alpha: 0.20).setFill()
        glow.fill()

        let body = NSRect(x: anchorX - 14, y: bounds.midY - 28, width: 78, height: 78)
        NSColor(calibratedRed: 0.14, green: 0.80, blue: 0.45, alpha: 1.0).setFill()
        NSBezierPath(ovalIn: body).fill()

        NSColor(calibratedRed: 0.08, green: 0.50, blue: 0.92, alpha: 1.0).setFill()
        let wing = NSBezierPath()
        wing.move(to: NSPoint(x: body.minX + 24, y: body.midY + 2))
        wing.curve(
            to: NSPoint(x: body.maxX - 4, y: body.midY - 14),
            controlPoint1: NSPoint(x: body.minX + 36, y: body.minY - 4),
            controlPoint2: NSPoint(x: body.maxX - 6, y: body.minY + 8)
        )
        wing.curve(
            to: NSPoint(x: body.minX + 24, y: body.midY + 2),
            controlPoint1: NSPoint(x: body.maxX - 12, y: body.midY + 18),
            controlPoint2: NSPoint(x: body.minX + 44, y: body.midY + 22)
        )
        wing.fill()

        NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.18, alpha: 1.0).setFill()
        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: body.maxX - 4, y: body.midY + 24))
        beak.line(to: NSPoint(x: body.maxX + 24, y: body.midY + 12))
        beak.line(to: NSPoint(x: body.maxX - 4, y: body.midY + 2))
        beak.close()
        beak.fill()

        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: body.midX + 10, y: body.midY + 28, width: 16, height: 16)).fill()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: body.midX + 17, y: body.midY + 34, width: 6, height: 6)).fill()

        let waveColor = NSColor(calibratedRed: 0.30, green: 0.82, blue: 1.0, alpha: 0.75)
        waveColor.setStroke()
        for index in 0..<3 {
            let path = NSBezierPath()
            path.lineWidth = 3
            let x = anchorX - 80 + CGFloat(index * 16)
            path.move(to: NSPoint(x: x, y: bounds.midY - 48))
            path.curve(
                to: NSPoint(x: x + 42, y: bounds.midY - 48),
                controlPoint1: NSPoint(x: x + 10, y: bounds.midY - 24),
                controlPoint2: NSPoint(x: x + 32, y: bounds.midY - 72)
            )
            path.stroke()
        }
    }
}

final class OnboardingCardView: NSView {
    var fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.80)
    var borderColor = NSColor.separatorColor.withAlphaComponent(0.50)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
        fillColor.setFill()
        path.fill()
        borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

struct SelectedTextTarget {
    let pid: pid_t
    let appName: String
    let element: AXUIElement?
    let selectedRange: CFRange?
    let text: String
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var statusLabel: NSTextField!
    private var logView: NSTextView!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    private var toggleButton: NSButton!
    private var process: Process?
    private var logHandle: FileHandle?
    private var inputPipe: Pipe?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var processOutputBuffer = ""
    private var pasteTargetPID: pid_t?
    private var pasteTargetName = "Unknown"
    private var pasteTargetContext = ""
    private var pastePrefix = ""
    private let overlay = ListeningOverlay()
    private var isRecording = false
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingStartedAt: Date?
    private var isTranscribing = false
    private var pendingAudioURL: URL?
    private var transcriptionStartedAt: Date?
    private var accessibilityTimer: Timer?
    private var lastAccessibilityTrusted: Bool?
    private var activeSounds: [NSSound] = []
    private var onboardingWindow: NSWindow?
    private var onboardingStep = 0
    private var onboardingContent: NSStackView?
    private var onboardingBackButton: NSButton?
    private var onboardingNextButton: NSButton?
    private var micStatusLabel: NSTextField?
    private var accessibilityStatusLabel: NSTextField?
    private var hotkeyStatusLabel: NSTextField?
    private var hotkeyTestArmed = false
    private var hotkeyTested = false
    private var selectedTextTarget: SelectedTextTarget?
    private var transformPanel: NSPanel?
    private var transformButtons: [NSButton] = []
    private var transformProgress: NSProgressIndicator?
    private var transformHintLabel: NSTextField?
    private let transformModel = "llama3.2:1b"

    private let rootDir = Bundle.main.bundleURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .path
    private let resourcesURL = Bundle.main.resourceURL!
    private let onboardingCompletedKey = "LocalFlowOnboardingCompleted"
    private let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/ParaFlow.log")

    func applicationDidFinishLaunching(_ notification: Notification) {
        openLogFile()
        buildWindow()
        setStatus("Running")
        startButton.isEnabled = false
        stopButton.isEnabled = false
        toggleButton.isEnabled = true
        startTranscriberWorker()
        registerHotKey()
        appendLog("ParaFlow launched from \(rootDir)\n")
        startAccessibilityMonitor()
        if !UserDefaults.standard.bool(forKey: onboardingCompletedKey) {
            showOnboarding()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        unregisterHotKey()
        accessibilityTimer?.invalidate()
        stopNativeRecording()
        stopBackend(nil)
        return .terminateNow
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "ParaFlow"

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = root

        let title = NSTextField(labelWithString: "ParaFlow")
        title.font = .systemFont(ofSize: 24, weight: .semibold)

        let subtitle = NSTextField(labelWithString: "Local Parakeet dictation. Hold Ctrl+Option+Space to dictate.")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.maximumNumberOfLines = 2

        statusLabel = NSTextField(labelWithString: "Starting...")
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        startButton = NSButton(title: "Start", target: self, action: #selector(startBackend(_:)))
        stopButton = NSButton(title: "Stop App", target: self, action: #selector(stopBackend(_:)))
        toggleButton = NSButton(title: "Test Hold", target: self, action: #selector(toggleRecording(_:)))
        let logsButton = NSButton(title: "Open Logs", target: self, action: #selector(openLogs(_:)))
        let privacyButton = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openAccessibilitySettings(_:)))
        buttonRow.addArrangedSubview(startButton)
        buttonRow.addArrangedSubview(stopButton)
        buttonRow.addArrangedSubview(toggleButton)
        buttonRow.addArrangedSubview(logsButton)
        buttonRow.addArrangedSubview(privacyButton)

        let logLabel = NSTextField(labelWithString: "Recent log")
        logLabel.font = .systemFont(ofSize: 12, weight: .medium)
        logLabel.textColor = .secondaryLabelColor

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        logView = NSTextView()
        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.string = ""
        scrollView.documentView = logView

        root.addArrangedSubview(title)
        root.addArrangedSubview(subtitle)
        root.addArrangedSubview(statusLabel)
        root.addArrangedSubview(buttonRow)
        root.addArrangedSubview(logLabel)
        root.addArrangedSubview(scrollView)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            root.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            subtitle.widthAnchor.constraint(equalToConstant: 470),
            scrollView.widthAnchor.constraint(equalToConstant: 480),
            scrollView.heightAnchor.constraint(equalToConstant: 150),
        ])
    }

    private func showOnboarding() {
        if onboardingWindow != nil {
            onboardingWindow?.makeKeyAndOrderFront(nil)
            return
        }

        onboardingStep = 0
        hotkeyTestArmed = false
        hotkeyTested = false

        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 620),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Set Up ParaFlow"
        panel.center()
        onboardingWindow = panel

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 18
        root.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 20, right: 24)
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root

        let hero = OnboardingHeroView(frame: NSRect(x: 0, y: 0, width: 672, height: 164))
        hero.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(hero)

        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        onboardingContent = content
        root.addArrangedSubview(content)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(spacer)

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.spacing = 10
        footer.alignment = .centerY
        footer.translatesAutoresizingMaskIntoConstraints = false

        let footerSpacer = NSView()
        footerSpacer.translatesAutoresizingMaskIntoConstraints = false
        let back = NSButton(title: "Back", target: self, action: #selector(onboardingBack(_:)))
        let next = NSButton(title: "Continue", target: self, action: #selector(onboardingNext(_:)))
        next.keyEquivalent = "\r"
        onboardingBackButton = back
        onboardingNextButton = next

        footer.addArrangedSubview(footerSpacer)
        footer.addArrangedSubview(back)
        footer.addArrangedSubview(next)
        root.addArrangedSubview(footer)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
            root.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
            root.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor),
            hero.widthAnchor.constraint(equalToConstant: 672),
            hero.heightAnchor.constraint(equalToConstant: 164),
            content.widthAnchor.constraint(equalToConstant: 672),
            spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 1),
            footer.widthAnchor.constraint(equalToConstant: 672),
            footerSpacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 1),
        ])

        renderOnboardingStep()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func renderOnboardingStep() {
        guard let content = onboardingContent else { return }
        content.arrangedSubviews.forEach { view in
            content.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        switch onboardingStep {
        case 0:
            addOnboardingText(
                title: "Set up ParaFlow.app",
                body: "This setup will prepare ParaFlow.app to record your voice, listen for its global trigger, and paste text into the app you are using."
            )
            addSetupCard(
                title: "How it works",
                body: "Hold Ctrl + Option + Space, speak, then release. ParaFlow transcribes locally with Parakeet and pastes the text into the active text field.",
                accent: .systemBlue
            )
            addSetupCard(
                title: "App name to look for",
                body: "In macOS permission screens, enable the item named ParaFlow. If Finder shows the full filename, it may appear as ParaFlow.app.",
                accent: .systemGreen
            )
        case 1:
            addOnboardingText(
                title: "Enable required permissions",
                body: "ParaFlow needs exactly two macOS permissions. Both must show Ready before paste and dictation can work reliably."
            )
            micStatusLabel = permissionCard(
                title: "1. Microphone",
                path: "System Settings > Privacy & Security > Microphone",
                body: "Enable ParaFlow or ParaFlow.app so the app can record your voice.",
                buttonTitle: "Allow Microphone",
                action: #selector(requestMicrophoneFromOnboarding(_:)),
                accent: .systemTeal
            )
            accessibilityStatusLabel = permissionCard(
                title: "2. Accessibility",
                path: "System Settings > Privacy & Security > Accessibility",
                body: "Enable ParaFlow or ParaFlow.app so it can paste the transcript with Cmd+V.",
                buttonTitle: "Open Settings",
                action: #selector(openAccessibilitySettings(_:)),
                accent: .systemBlue
            )
            let refresh = NSButton(title: "Refresh Permission Status", target: self, action: #selector(refreshOnboardingStatus(_:)))
            content.addArrangedSubview(refresh)
        case 2:
            addOnboardingText(
                title: "Test the trigger",
                body: "This confirms the global hotkey is registered and that ParaFlow can hear the key press while another app is active."
            )
            addSetupCard(
                title: "Current trigger",
                body: "Hold Ctrl + Option + Space to start recording. Release the keys to stop recording and paste the result.",
                accent: .systemPurple
            )
            let keys = NSTextField(labelWithString: "Control  +  Option  +  Space")
            keys.font = .monospacedSystemFont(ofSize: 22, weight: .semibold)
            content.addArrangedSubview(keys)
            hotkeyStatusLabel = NSTextField(labelWithString: "Not tested yet")
            hotkeyStatusLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            hotkeyStatusLabel?.textColor = .secondaryLabelColor
            if let hotkeyStatusLabel {
                content.addArrangedSubview(hotkeyStatusLabel)
            }
            let test = NSButton(title: "Test Hotkey", target: self, action: #selector(testHotkeyFromOnboarding(_:)))
            content.addArrangedSubview(test)
        default:
            addOnboardingText(
                title: "Ready to dictate",
                body: "ParaFlow.app can now run in the background. Keep it open, then use the trigger anywhere you can type."
            )
            addSetupCard(
                title: "Daily use",
                body: "Click into Slack, Terminal, Cursor, a browser form, or any text field. Hold Ctrl + Option + Space, speak, then release.",
                accent: .systemGreen
            )
            addSetupCard(
                title: "If paste stops working",
                body: "Go back to System Settings > Privacy & Security > Accessibility and make sure ParaFlow.app is still enabled.",
                accent: .systemBlue
            )
        }

        onboardingBackButton?.isEnabled = onboardingStep > 0
        onboardingNextButton?.title = onboardingStep == 3 ? "Finish" : "Continue"
        updateOnboardingStatus()
    }

    private func addOnboardingText(title: String, body: String) {
        guard let content = onboardingContent else { return }
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        content.addArrangedSubview(titleLabel)

        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 14)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.maximumNumberOfLines = 3
        bodyLabel.preferredMaxLayoutWidth = 540
        content.addArrangedSubview(bodyLabel)
    }

    private func addOnboardingNote(_ text: String) {
        guard let content = onboardingContent else { return }
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.preferredMaxLayoutWidth = 540
        content.addArrangedSubview(label)
    }

    private func addSetupCard(title: String, body: String, accent: NSColor) {
        guard let content = onboardingContent else { return }

        let card = OnboardingCardView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 14
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let dot = OnboardingCardView()
        dot.fillColor = accent
        dot.borderColor = accent
        dot.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor

        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.preferredMaxLayoutWidth = 590

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(bodyLabel)
        row.addArrangedSubview(dot)
        row.addArrangedSubview(textStack)
        content.addArrangedSubview(card)

        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: 672),
            card.heightAnchor.constraint(equalToConstant: 82),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            dot.widthAnchor.constraint(equalToConstant: 12),
            dot.heightAnchor.constraint(equalToConstant: 12),
        ])
    }

    private func permissionCard(
        title: String,
        path: String,
        body: String,
        buttonTitle: String,
        action: Selector,
        accent: NSColor
    ) -> NSTextField {
        guard let content = onboardingContent else {
            return NSTextField(labelWithString: "")
        }

        let card = OnboardingCardView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let dot = OnboardingCardView()
        dot.fillColor = accent
        dot.borderColor = accent
        dot.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let pathLabel = NSTextField(labelWithString: path)
        pathLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        pathLabel.textColor = .labelColor

        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.preferredMaxLayoutWidth = 430

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(pathLabel)
        textStack.addArrangedSubview(bodyLabel)

        let status = NSTextField(labelWithString: "Checking...")
        status.font = .systemFont(ofSize: 13, weight: .semibold)
        status.alignment = .right
        status.textColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false

        let button = NSButton(title: buttonTitle, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(dot)
        card.addSubview(textStack)
        card.addSubview(status)
        card.addSubview(button)
        content.addArrangedSubview(card)

        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: 672),
            card.heightAnchor.constraint(equalToConstant: 106),
            dot.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            dot.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            dot.widthAnchor.constraint(equalToConstant: 12),
            dot.heightAnchor.constraint(equalToConstant: 12),
            textStack.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 14),
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            textStack.widthAnchor.constraint(equalToConstant: 430),
            status.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            status.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            status.widthAnchor.constraint(equalToConstant: 130),
            button.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            button.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return status
    }

    private func permissionRow(title: String, buttonTitle: String, action: Selector) -> NSTextField {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 10
        box.borderWidth = 1
        box.borderColor = NSColor.separatorColor.withAlphaComponent(0.45)
        box.fillColor = NSColor.windowBackgroundColor.withAlphaComponent(0.60)
        box.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        row.translatesAutoresizingMaskIntoConstraints = false
        box.contentView = row

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        let status = NSTextField(labelWithString: "Checking...")
        status.font = .systemFont(ofSize: 13, weight: .medium)
        status.textColor = .secondaryLabelColor
        let button = NSButton(title: buttonTitle, target: self, action: action)

        row.addArrangedSubview(label)
        row.addArrangedSubview(status)
        row.addArrangedSubview(button)
        onboardingContent?.addArrangedSubview(box)

        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: 672),
            label.widthAnchor.constraint(equalToConstant: 110),
            status.widthAnchor.constraint(equalToConstant: 180),
        ])
        return status
    }

    @objc private func onboardingBack(_ sender: Any?) {
        onboardingStep = max(0, onboardingStep - 1)
        renderOnboardingStep()
    }

    @objc private func onboardingNext(_ sender: Any?) {
        if onboardingStep == 3 {
            UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
            onboardingWindow?.close()
            onboardingWindow = nil
            window.orderOut(nil)
            NSApp.hide(nil)
            return
        }

        onboardingStep = min(3, onboardingStep + 1)
        renderOnboardingStep()
    }

    @objc private func requestMicrophoneFromOnboarding(_ sender: Any?) {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateOnboardingStatus()
            }
        }
    }

    @objc private func refreshOnboardingStatus(_ sender: Any?) {
        updateOnboardingStatus()
    }

    @objc private func testHotkeyFromOnboarding(_ sender: Any?) {
        hotkeyTestArmed = true
        hotkeyStatusLabel?.stringValue = "Waiting for Ctrl + Option + Space..."
        hotkeyStatusLabel?.textColor = .systemBlue
    }

    private func updateOnboardingStatus() {
        let micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let accessibilityGranted = AXIsProcessTrusted()

        micStatusLabel?.stringValue = micGranted ? "Ready" : "Needs permission"
        micStatusLabel?.textColor = micGranted ? .systemGreen : .systemYellow
        accessibilityStatusLabel?.stringValue = accessibilityGranted ? "Ready" : "Needs permission"
        accessibilityStatusLabel?.textColor = accessibilityGranted ? .systemGreen : .systemYellow

        if hotkeyTested {
            hotkeyStatusLabel?.stringValue = "Hotkey works"
            hotkeyStatusLabel?.textColor = .systemGreen
        } else if hotkeyTestArmed {
            hotkeyStatusLabel?.stringValue = "Waiting for Ctrl + Option + Space..."
            hotkeyStatusLabel?.textColor = .systemBlue
        }

        if onboardingStep == 1 {
            onboardingNextButton?.isEnabled = micGranted && accessibilityGranted
        } else if onboardingStep == 2 {
            onboardingNextButton?.isEnabled = hotkeyTested
        } else {
            onboardingNextButton?.isEnabled = true
        }
    }

    @objc private func startBackend(_ sender: Any?) {
        startTranscriberWorker()
    }

    private func startTranscriberWorker() {
        if process?.isRunning == true {
            setStatus("Running")
            return
        }

        openLogFile()

        let proc = Process()
        let bundledWorkerURL = resourcesURL.appendingPathComponent("backend/local-flow-worker")
        if FileManager.default.isExecutableFile(atPath: bundledWorkerURL.path) {
            proc.currentDirectoryURL = resourcesURL
            proc.executableURL = bundledWorkerURL
            proc.arguments = [
                "--model-dir",
                resourcesURL.appendingPathComponent("models/parakeet").path
            ]
        } else {
            proc.currentDirectoryURL = URL(fileURLWithPath: rootDir)
            proc.executableURL = URL(fileURLWithPath: "\(rootDir)/.venv/bin/python")
            proc.arguments = ["-m", "flow_clone.transcribe_worker"]
        }
        var backendEnvironment = ProcessInfo.processInfo.environment
        backendEnvironment.removeValue(forKey: "__CFBundleIdentifier")
        backendEnvironment.removeValue(forKey: "XPC_SERVICE_NAME")
        backendEnvironment.removeValue(forKey: "XPC_FLAGS")
        proc.environment = backendEnvironment

        let backendInput = Pipe()
        proc.standardInput = backendInput

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.handleProcessOutput(data)
        }

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.setStatus("Stopped")
                self?.startButton.isEnabled = true
                self?.stopButton.isEnabled = false
                self?.toggleButton.isEnabled = false
                self?.inputPipe = nil
                self?.process = nil
            }
        }

        do {
            try proc.run()
            process = proc
            inputPipe = backendInput
            setStatus("Running")
            startButton.isEnabled = false
            stopButton.isEnabled = true
            toggleButton.isEnabled = true
            appendLog("Starting warm Parakeet worker...\n")
        } catch {
            setStatus("Failed to start: \(error.localizedDescription)")
        }
    }

    @objc private func stopBackend(_ sender: Any?) {
        guard let proc = process else {
            setStatus("Stopped")
            startButton.isEnabled = true
            stopButton.isEnabled = false
            return
        }
        if proc.isRunning {
            sendBackendCommand("quit")
            proc.terminate()
        }
        process = nil
        inputPipe = nil
        logHandle?.closeFile()
        logHandle = nil
        setStatus("Stopped")
        startButton.isEnabled = true
        stopButton.isEnabled = false
        toggleButton.isEnabled = false
    }

    @objc private func toggleRecording(_ sender: Any?) {
        if isRecording {
            stopDictation()
        } else {
            startDictation()
        }
    }

    @objc private func openLogs(_ sender: Any?) {
        NSWorkspace.shared.open(logURL)
    }

    @objc private func openAccessibilitySettings(_ sender: Any?) {
        requestAccessibilityTrustIfNeeded()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func appendLog(_ data: Data) {
        logHandle?.write(data)
        guard let text = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async {
            self.logView.string += text
            self.logView.scrollToEndOfDocument(nil)
        }
    }

    private func setStatus(_ value: String) {
        statusLabel.stringValue = "Status: \(value)"
    }

    private func openLogFile() {
        guard logHandle == nil else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            logHandle = try FileHandle(forWritingTo: logURL)
            logHandle?.seekToEndOfFile()
        } catch {
            setStatus("Could not open log file: \(error.localizedDescription)")
        }
    }

    private func handleProcessOutput(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else {
            appendLog(data)
            return
        }

        processOutputBuffer += text

        while let newlineRange = processOutputBuffer.range(of: "\n") {
            let line = String(processOutputBuffer[..<newlineRange.lowerBound])
            processOutputBuffer.removeSubrange(...newlineRange.lowerBound)
            handleProcessLine(line)
        }
    }

    private func handleProcessLine(_ line: String) {
        let readyPrefix = "__LOCAL_FLOW_WORKER_READY__:"
        if line.hasPrefix(readyPrefix) {
            let elapsed = String(line.dropFirst(readyPrefix.count))
            appendLog("Parakeet worker ready in \(elapsed)s.\n")
            setStatus("Running")
            return
        }

        let cleanupReadyPrefix = "__LOCAL_FLOW_CLEANUP_READY__:"
        if line.hasPrefix(cleanupReadyPrefix) {
            let detail = String(line.dropFirst(cleanupReadyPrefix.count))
            appendLog("Cleanup worker: \(detail)\n")
            return
        }

        let cleanupUsedPrefix = "__LOCAL_FLOW_CLEANUP_USED__:"
        if line.hasPrefix(cleanupUsedPrefix) {
            let detail = String(line.dropFirst(cleanupUsedPrefix.count))
            appendLog("Cleanup used: \(detail)\n")
            return
        }

        let contextTermsPrefix = "__LOCAL_FLOW_CONTEXT_TERMS__:"
        if line.hasPrefix(contextTermsPrefix) {
            let payload = String(line.dropFirst(contextTermsPrefix.count))
            let parts = payload.split(separator: ":", maxSplits: 2).map(String.init)
            if parts.count == 3,
               let data = Data(base64Encoded: parts[2]),
               let preview = String(data: data, encoding: .utf8) {
                appendLog("Context spelling terms: \(parts[0]):\(parts[1]) -> \(preview)\n")
            } else {
                appendLog("Context spelling terms: \(payload)\n")
            }
            return
        }

        let contextTermsErrorPrefix = "__LOCAL_FLOW_CONTEXT_TERMS_ERROR__:"
        if line.hasPrefix(contextTermsErrorPrefix) {
            let message = String(line.dropFirst(contextTermsErrorPrefix.count))
            appendLog("Context spelling error: \(message)\n")
            return
        }

        let prefix = "__LOCAL_FLOW_TRANSCRIPT__:"
        if line.hasPrefix(prefix) {
            let payload = String(line.dropFirst(prefix.count))
            let parts = payload.split(separator: ":", maxSplits: 1).map(String.init)
            let elapsed = parts.count == 2 ? parts[0] : "?"
            let encoded = parts.count == 2 ? parts[1] : payload
            guard
                let data = Data(base64Encoded: encoded),
                let transcript = String(data: data, encoding: .utf8)
            else {
                appendLog("Could not decode transcript.\n")
                finishTranscription()
                return
            }

            appendLog("Transcription completed in \(elapsed)s.\n")
            pasteTranscript(transcript)
            appendLog("Native pasted into \(pasteTargetName): \(transcript)\n")
            finishTranscription()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.setStatus("Running")
            }
            return
        }

        let errorPrefix = "__LOCAL_FLOW_TRANSCRIBE_ERROR__:"
        if line.hasPrefix(errorPrefix) {
            let encoded = String(line.dropFirst(errorPrefix.count))
            let message = Data(base64Encoded: encoded).flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
            appendLog("Transcription failed: \(message)\n")
            finishTranscription()
            setStatus("Running")
            return
        }

        if line.contains("Recording too short") || line.contains("No speech detected") || line.hasPrefix("Pasted:") {
            setStatus("Running")
        } else if line.contains("Transcribing locally") {
            setStatus("Transcribing")
        }

        appendLog("\(line)\n")
    }

    private func finishTranscription() {
        if let pendingAudioURL {
            try? FileManager.default.removeItem(at: pendingAudioURL)
        }
        pendingAudioURL = nil
        transcriptionStartedAt = nil
        isTranscribing = false
    }

    private func sendBackendCommand(_ command: String) {
        guard process?.isRunning == true, let data = "\(command)\n".data(using: .utf8) else {
            return
        }
        inputPipe?.fileHandleForWriting.write(data)
    }

    private func pasteTranscript(_ text: String) {
        let finalText = applyPastePrefix(to: text)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(finalText, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            self.activatePasteTarget()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            self.sendCommandVPaste()
        }
    }

    private func applyPastePrefix(to text: String) -> String {
        guard !pastePrefix.isEmpty,
              let first = text.first,
              !first.isWhitespace,
              !",.;:?!)]}".contains(first)
        else {
            return text
        }

        return pastePrefix + text
    }

    private func activatePasteTarget() {
        guard let pasteTargetPID,
              let targetApp = NSRunningApplication(processIdentifier: pasteTargetPID),
              !targetApp.isTerminated
        else {
            appendLog("No paste target to activate.\n")
            return
        }

        targetApp.activate(options: [.activateIgnoringOtherApps])
    }

    private func sendCommandVPaste() {
        if !AXIsProcessTrusted() {
            appendLog("Accessibility is not trusted; direct Cmd+V may be blocked.\n")
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false)

        commandDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        commandUp?.flags = []

        commandDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        commandUp?.post(tap: .cghidEventTap)
        appendLog("Sent direct Cmd+V to \(pasteTargetName).\n")
    }

    private func capturePasteTarget() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            pasteTargetPID = nil
            pasteTargetName = "Unknown"
            pasteTargetContext = ""
            pastePrefix = ""
            return
        }

        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return
        }

        pasteTargetPID = app.processIdentifier
        pasteTargetName = app.localizedName ?? app.bundleIdentifier ?? "pid \(app.processIdentifier)"
        appendLog("Paste target: \(pasteTargetName) (\(app.processIdentifier))\n")
        pasteTargetContext = ""
        pastePrefix = ""
    }

    private func capturePasteTargetDetailsAsync(for pid: pid_t) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let context = self.captureAccessibilityContext(for: pid)
            let prefix = self.capturePastePrefix(for: pid)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.pasteTargetPID == pid else { return }
                self.pasteTargetContext = context
                self.pastePrefix = prefix
                if !prefix.isEmpty {
                    self.appendLog("Paste prefix: space\n")
                }
                if !context.isEmpty {
                    self.appendLog("Captured context for spelling: \(context.prefix(180))\n")
                }
            }
        }
    }

    private func captureSelectedTextTarget() -> SelectedTextTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return nil
        }

        guard AXIsProcessTrusted() else {
            appendLog("Selection commands unavailable: Accessibility is not trusted.\n")
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedValue: CFTypeRef?
        let appName = app.localizedName ?? app.bundleIdentifier ?? "pid \(app.processIdentifier)"
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
           let focusedValue,
           CFGetTypeID(focusedValue) == AXUIElementGetTypeID() {
            let focusedElement = focusedValue as! AXUIElement
            if let selectedText = copySelectedText(from: focusedElement), !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appendLog("Selected text detected via Accessibility (\(selectedText.count) chars).\n")
                return SelectedTextTarget(
                    pid: app.processIdentifier,
                    appName: appName,
                    element: focusedElement,
                    selectedRange: copySelectedTextRange(from: focusedElement),
                    text: selectedText
                )
            }
        }

        if let selectedText = copySelectedTextViaPasteboardFallback(), !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendLog("Selected text detected via Cmd+C fallback (\(selectedText.count) chars).\n")
            return SelectedTextTarget(pid: app.processIdentifier, appName: appName, element: nil, selectedRange: nil, text: selectedText)
        }

        appendLog("No selected text detected; starting dictation.\n")
        return nil
    }

    private func copySelectedText(from element: AXUIElement) -> String? {
        var selectedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedRef) == .success,
           let selected = selectedRef as? String,
           !selected.isEmpty {
            return selected
        }

        var valueRef: CFTypeRef?
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let value = valueRef as? String,
              AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef,
              CFGetTypeID(rangeRef) == AXValueGetTypeID()
        else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &range),
              range.location >= 0,
              range.length > 0
        else {
            return nil
        }

        let startOffset = min(range.location, value.count)
        let endOffset = min(range.location + range.length, value.count)
        guard startOffset < endOffset else {
            return nil
        }

        let start = value.index(value.startIndex, offsetBy: startOffset)
        let end = value.index(value.startIndex, offsetBy: endOffset)
        return String(value[start..<end])
    }

    private func copySelectedTextRange(from element: AXUIElement) -> CFRange? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef,
              CFGetTypeID(rangeRef) == AXValueGetTypeID()
        else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &range),
              range.location >= 0,
              range.length > 0
        else {
            return nil
        }
        return range
    }

    private func copySelectedTextViaPasteboardFallback() -> String? {
        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount
        pasteboard.clearContents()

        sendCommandC()
        Thread.sleep(forTimeInterval: 0.16)

        let copied = pasteboard.string(forType: .string)
        if let copied, !copied.isEmpty, pasteboard.changeCount != previousChangeCount {
            return copied
        }

        pasteboard.clearContents()
        if let previousString {
            pasteboard.setString(previousString, forType: .string)
        }
        return nil
    }

    private func sendCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false)

        commandDown?.flags = .maskCommand
        cDown?.flags = .maskCommand
        cUp?.flags = .maskCommand
        commandUp?.flags = []

        commandDown?.post(tap: .cghidEventTap)
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
        commandUp?.post(tap: .cghidEventTap)
    }

    private func showTransformPanel(for selection: SelectedTextTarget) {
        transformPanel?.close()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 178),
            styleMask: [.titled, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Edit Selection"
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 12
        container.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        container.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Selected text in \(selection.appName)")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .labelColor

        let preview = selection.text.replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
        let subtitle = NSTextField(labelWithString: String(preview.prefix(150)))
        subtitle.font = .systemFont(ofSize: 12, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail

        let hint = NSTextField(labelWithString: "Choose a local edit. Ollama runs on this Mac and replaces the selected text.")
        hint.font = .systemFont(ofSize: 11, weight: .regular)
        hint.textColor = .tertiaryLabelColor
        transformHintLabel = hint

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.distribution = .fillEqually

        let grammar = transformButton("Fix grammar", action: #selector(transformFixGrammar(_:)))
        let bullets = transformButton("Bullets", action: #selector(transformBullets(_:)))
        let numbered = transformButton("Numbered", action: #selector(transformNumbered(_:)))
        let concise = transformButton("Concise", action: #selector(transformConcise(_:)))
        transformButtons = [grammar, bullets, numbered, concise]
        transformButtons.forEach { buttonRow.addArrangedSubview($0) }

        let progress = NSProgressIndicator()
        progress.style = .spinning
        progress.controlSize = .small
        progress.isIndeterminate = true
        progress.isDisplayedWhenStopped = false
        progress.translatesAutoresizingMaskIntoConstraints = false
        transformProgress = progress

        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.spacing = 8
        statusRow.addArrangedSubview(progress)
        statusRow.addArrangedSubview(hint)

        container.addArrangedSubview(title)
        container.addArrangedSubview(subtitle)
        container.addArrangedSubview(buttonRow)
        container.addArrangedSubview(statusRow)
        panel.contentView = container

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
            container.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
            container.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor),
        ])

        positionTransformPanel(panel)
        transformPanel = panel
        panel.orderFrontRegardless()
        appendLog("Selected text command palette opened for \(selection.appName).\n")
    }

    private func transformButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .large
        return button
    }

    private func positionTransformPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let frame = panel.frame
        let x = visible.midX - frame.width / 2
        let y = visible.minY + 170
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func transformFixGrammar(_ sender: Any?) {
        runSelectedTextTransform(.grammar)
    }

    @objc private func transformBullets(_ sender: Any?) {
        runSelectedTextTransform(.bullets)
    }

    @objc private func transformNumbered(_ sender: Any?) {
        runSelectedTextTransform(.numbered)
    }

    @objc private func transformConcise(_ sender: Any?) {
        runSelectedTextTransform(.concise)
    }

    private enum TransformKind {
        case grammar
        case bullets
        case numbered
        case concise
    }

    private func runSelectedTextTransform(_ kind: TransformKind) {
        guard let target = selectedTextTarget else { return }
        setTransformPanelBusy(true, message: "Editing selected text...")
        setStatus("Editing selection")
        appendLog("Transforming selected text with \(transformModel).\n")

        rewriteSelectedText(target.text, kind: kind) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let rewritten):
                    self.replaceSelectedText(rewritten, target: target) {
                        self.transformPanel?.close()
                        self.transformPanel = nil
                        self.setTransformPanelBusy(false, message: nil)
                        self.setStatus("Running")
                    }
                    self.appendLog("Selection transformed: \(rewritten.prefix(180))\n")
                case .failure(let error):
                    self.appendLog("Selection transform failed: \(error.localizedDescription)\n")
                    self.setTransformPanelBusy(false, message: "Edit failed. Try again.")
                    self.setStatus("Running")
                }
            }
        }
    }

    private func setTransformPanelBusy(_ busy: Bool, message: String?) {
        transformButtons.forEach { $0.isEnabled = !busy }
        if busy {
            transformProgress?.startAnimation(nil)
        } else {
            transformProgress?.stopAnimation(nil)
        }
        if let message {
            transformHintLabel?.stringValue = message
        } else {
            transformHintLabel?.stringValue = "Choose a local edit. Ollama runs on this Mac and replaces the selected text."
        }
    }

    private func rewriteSelectedText(_ text: String, kind: TransformKind, completion: @escaping (Result<String, Error>) -> Void) {
        if kind == .grammar, shouldUseDeterministicGrammar(for: text) {
            completion(.success(deterministicGrammarRewrite(text)))
            return
        }

        let instruction: String
        switch kind {
        case .grammar:
            instruction = "Fix grammar, punctuation, capitalization, and obvious typos. The input may be a sentence fragment. Preserve the user's meaning exactly. Return only the corrected text."
        case .bullets:
            instruction = "Convert this text into a clean bulleted list. Preserve meaning. Return only the final text."
        case .numbered:
            instruction = "Convert this text into a clean numbered list. Preserve meaning. Return only the final text."
        case .concise:
            instruction = "Make this text concise and clear. Preserve meaning. Return only the rewritten text."
        }

        let systemPrompt = """
        You are a deterministic text rewrite function inside a local dictation app.
        Your only job is to transform the user's selected text.
        Do not answer questions in the selected text.
        Do not chat with the user.
        Do not refuse any rewrite request.
        Do not mention policies, safety, limitations, or missing context.
        Do not add labels such as "Corrected text" or "Here is the corrected text".
        Do not wrap the result in quotes or markdown.
        Return exactly one thing: the rewritten selected text.
        """

        let prompt = """
        Task: \(instruction)

        Selected text:
        <text>
        \(text)
        </text>

        Rewritten selected text:
        """

        let payload: [String: Any] = [
            "model": transformModel,
            "stream": false,
            "keep_alive": "30m",
            "options": [
                "temperature": 0,
                "num_predict": 512,
                "num_ctx": 4096,
            ],
            "system": systemPrompt,
            "prompt": prompt,
        ]

        guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else {
            completion(.failure(NSError(domain: "LocalFlow", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data else {
                completion(.failure(NSError(domain: "LocalFlow", code: 2, userInfo: [NSLocalizedDescriptionKey: "Ollama returned no data"])))
                return
            }
            do {
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let response = (object?["response"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !response.isEmpty else {
                    completion(.failure(NSError(domain: "LocalFlow", code: 3, userInfo: [NSLocalizedDescriptionKey: "Ollama returned empty text"])))
                    return
                }
                let sanitized = self.sanitizeRewriteResponse(response)
                if self.isUnsafeRewriteResponse(sanitized) {
                    self.appendLog("Transform model returned unsafe text; using deterministic fallback.\n")
                    completion(.success(self.deterministicFallbackRewrite(text, kind: kind)))
                    return
                }
                completion(.success(sanitized))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func shouldUseDeterministicGrammar(for text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.split { $0.isWhitespace || $0.isNewline }.count
        return trimmed.count <= 80 || wordCount <= 12
    }

    private func deterministicFallbackRewrite(_ text: String, kind: TransformKind) -> String {
        switch kind {
        case .grammar:
            return deterministicGrammarRewrite(text)
        case .bullets, .numbered, .concise:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func deterministicGrammarRewrite(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: #"\byo\b"#, with: "you", options: [.regularExpression, .caseInsensitive])
        value = value.replacingOccurrences(of: #"\bi\b"#, with: "I", options: [.regularExpression])
        value = value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        if let first = value.first, first.isLowercase {
            value = first.uppercased() + value.dropFirst()
        }

        let lower = value.lowercased()
        if !value.hasSuffix(".") && !value.hasSuffix("?") && !value.hasSuffix("!") {
            let questionStarters = ["who ", "what ", "when ", "where ", "why ", "how ", "is ", "are ", "do ", "does ", "did ", "can ", "could ", "would ", "should "]
            value += questionStarters.contains(where: { lower.hasPrefix($0) }) ? "?" : "."
        }
        return value
    }

    private func sanitizeRewriteResponse(_ text: String) -> String {
        var lines = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)

        while let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              first.range(of: #"^(here'?s|here is|corrected|rewritten|final|output)(\s+(the\s+)?(corrected|rewritten|final)\s+text)?\s*[:：]\s*$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            lines.removeFirst()
        }

        let value = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return stripWrappingQuotes(value)
    }

    private func isUnsafeRewriteResponse(_ text: String) -> Bool {
        let lower = text.lowercased()
        let unsafePhrases = [
            "i'm sorry",
            "i am sorry",
            "i can't fulfill",
            "i cannot fulfill",
            "i can't assist",
            "i cannot assist",
            "i'm here to help",
            "please provide",
            "no question provided",
            "as an ai",
        ]
        return unsafePhrases.contains { lower.contains($0) }
    }

    private func stripWrappingQuotes(_ text: String) -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2,
              let first = value.first,
              let last = value.last,
              first == last,
              first == "\"" || first == "'"
        else {
            return value
        }
        return String(value.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func replaceSelectedText(_ text: String, target: SelectedTextTarget, completion: @escaping () -> Void) {
        pasteTargetPID = target.pid
        pasteTargetName = target.appName
        pastePrefix = ""

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.activatePasteTarget()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            self.restoreSelectedTextRange(target)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            self.sendCommandVPaste()
            completion()
        }

        selectedTextTarget = nil
        appendLog("Replacing selected text via keyboard paste.\n")
    }

    private func restoreSelectedTextRange(_ target: SelectedTextTarget) {
        guard let element = target.element,
              var range = target.selectedRange,
              let rangeValue = AXValueCreate(.cfRange, &range)
        else {
            return
        }

        let status = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
        if status == .success {
            appendLog("Restored selected text range before paste.\n")
        } else {
            appendLog("Could not restore selected range before paste: \(status.rawValue).\n")
        }
    }

    private func capturePastePrefix(for pid: pid_t) -> String {
        guard AXIsProcessTrusted() else {
            return ""
        }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
        else {
            return ""
        }

        let focusedElement = focusedValue as! AXUIElement
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &valueRef) == .success,
              let value = valueRef as? String,
              !value.isEmpty
        else {
            return ""
        }

        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef,
              CFGetTypeID(rangeRef) == AXValueGetTypeID()
        else {
            return ""
        }

        var range = CFRange()
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &range),
              range.location > 0,
              range.length == 0
        else {
            return ""
        }

        let safeLocation = min(range.location, value.count)
        let beforeIndex = value.index(value.startIndex, offsetBy: safeLocation - 1)
        let previous = value[beforeIndex]
        return previous.isWhitespace ? "" : " "
    }

    private func captureAccessibilityContext(for pid: pid_t) -> String {
        guard AXIsProcessTrusted() else {
            return ""
        }

        let appElement = AXUIElementCreateApplication(pid)
        var chunks: [String] = []
        collectFocusedAXStrings(appElement, chunks: &chunks)
        collectAXStrings(appElement, depth: 0, maxDepth: 7, chunks: &chunks)

        var seen = Set<String>()
        let unique = chunks.compactMap { chunk -> String? in
            let normalized = chunk.replacingOccurrences(of: "\n", with: " ")
                .split(separator: " ")
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.count >= 2 else { return nil }
            let key = normalized.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return normalized
        }

        return unique.prefix(180).joined(separator: "\n")
    }

    private func collectFocusedAXStrings(_ appElement: AXUIElement, chunks: inout [String]) {
        let focusedAttributes: [CFString] = [
            kAXFocusedUIElementAttribute as CFString,
            kAXFocusedWindowAttribute as CFString,
            kAXMainWindowAttribute as CFString,
        ]

        for attribute in focusedAttributes {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, attribute, &value) == .success,
               let value,
               CFGetTypeID(value) == AXUIElementGetTypeID() {
                collectAXStrings(value as! AXUIElement, depth: 0, maxDepth: 8, chunks: &chunks)
            }
        }
    }

    private func collectAXStrings(_ element: AXUIElement, depth: Int, maxDepth: Int, chunks: inout [String]) {
        guard depth <= maxDepth, chunks.count < 520 else {
            return
        }

        let attributes: [CFString] = [
            kAXTitleAttribute as CFString,
            kAXValueAttribute as CFString,
            kAXDescriptionAttribute as CFString,
            kAXPlaceholderValueAttribute as CFString,
            kAXHelpAttribute as CFString,
            kAXRoleDescriptionAttribute as CFString,
        ]

        for attribute in attributes {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
               let string = value as? String,
               !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                chunks.append(string)
            }
        }

        let childAttributes: [CFString] = [
            kAXFocusedWindowAttribute as CFString,
            kAXFocusedUIElementAttribute as CFString,
            kAXChildrenAttribute as CFString,
        ]

        for attribute in childAttributes {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
                  let value
            else {
                continue
            }

            if CFGetTypeID(value) == AXUIElementGetTypeID() {
                collectAXStrings(value as! AXUIElement, depth: depth + 1, maxDepth: maxDepth, chunks: &chunks)
            } else if let children = value as? [AXUIElement] {
                for child in children.prefix(180) {
                    collectAXStrings(child, depth: depth + 1, maxDepth: maxDepth, chunks: &chunks)
                    if chunks.count >= 520 {
                        return
                    }
                }
            }
        }
    }

    private func startDictation() {
        if hotkeyTestArmed {
            hotkeyTestArmed = false
            hotkeyTested = true
            playStartSound()
            updateOnboardingStatus()
            return
        }

        guard !isRecording else {
            return
        }
        guard !isTranscribing else {
            appendLog("Still transcribing previous recording; ignoring key press.\n")
            return
        }

        capturePasteTarget()
        if let selection = captureSelectedTextTarget(), !selection.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            selectedTextTarget = selection
            showTransformPanel(for: selection)
            return
        }
        startNativeRecording()
    }

    private func stopDictation() {
        guard isRecording else {
            return
        }

        stopNativeRecording()
    }

    private func startNativeRecording() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.appendLog("Microphone access denied.\n")
                    self.setStatus("Microphone access denied")
                    return
                }

                do {
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("local-flow-\(UUID().uuidString).wav")
                    let settings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: 16000,
                        AVNumberOfChannelsKey: 1,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsFloatKey: false,
                        AVLinearPCMIsBigEndianKey: false,
                    ]
                    let recorder = try AVAudioRecorder(url: url, settings: settings)
                    recorder.isMeteringEnabled = true
                    recorder.prepareToRecord()
                    recorder.record()

                    self.audioRecorder = recorder
                    self.recordingURL = url
                    self.recordingStartedAt = Date()
                    self.isRecording = true
                    self.overlay.show(pasteEnabled: AXIsProcessTrusted(), micEnabled: granted)
                    self.playStartSound()
                    self.setStatus("Listening")
                    self.appendLog("Recording natively to \(url.path)\n")
                    if let pasteTargetPID = self.pasteTargetPID {
                        self.capturePasteTargetDetailsAsync(for: pasteTargetPID)
                    }
                } catch {
                    self.appendLog("Native recording failed: \(error.localizedDescription)\n")
                    self.setStatus("Recording failed")
                }
            }
        }
    }

    private func stopNativeRecording() {
        guard let recorder = audioRecorder, let url = recordingURL else {
            isRecording = false
            overlay.hide()
            setStatus("Running")
            return
        }

        recorder.stop()
        audioRecorder = nil
        recordingURL = nil
        isRecording = false
        overlay.hide()
        playStopSound()

        let duration = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartedAt = nil
        guard duration >= 0.35 else {
            appendLog("Recording too short; skipped.\n")
            setStatus("Running")
            try? FileManager.default.removeItem(at: url)
            return
        }

        setStatus("Transcribing")
        transcribeAndPaste(url)
    }

    private func transcribeAndPaste(_ audioURL: URL) {
        guard process?.isRunning == true else {
            appendLog("Transcriber worker is not running; restarting.\n")
            startTranscriberWorker()
            setStatus("Running")
            try? FileManager.default.removeItem(at: audioURL)
            return
        }

        appendLog("Transcribing native recording with warm Parakeet worker...\n")
        isTranscribing = true
        pendingAudioURL = audioURL
        transcriptionStartedAt = Date()
        sendContextToWorker(pasteTargetContext)
        sendBackendCommand(audioURL.path)
    }

    private func sendContextToWorker(_ context: String) {
        guard !context.isEmpty,
              let data = context.data(using: .utf8)
        else {
            return
        }

        let encoded = data.base64EncodedString()
        sendBackendCommand("__LOCAL_FLOW_CONTEXT__:\(encoded)")
    }

    private func playStartSound() {
        playCueSound()
    }

    private func playStopSound() {
        playCueSound()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.playCueSound()
        }
    }

    private func playCueSound() {
        guard let soundURL = Bundle.main.url(forResource: "deep-tuck", withExtension: "wav"),
              let sound = NSSound(contentsOf: soundURL, byReference: false) else {
            NSSound.beep()
            return
        }

        sound.volume = 1.0
        activeSounds.append(sound)
        sound.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self, weak sound] in
            guard let self, let sound else { return }
            self.activeSounds.removeAll { $0 === sound }
        }
    }

    private func registerHotKey() {
        guard hotKeyRef == nil else {
            return
        }

        let appPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event = event, let userData = userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let error = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard error == noErr, hotKeyID.id == 1 else {
                    return noErr
                }

                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                let eventKind = GetEventKind(event)
                DispatchQueue.main.async {
                    if eventKind == UInt32(kEventHotKeyPressed) {
                        delegate.startDictation()
                    } else if eventKind == UInt32(kEventHotKeyReleased) {
                        delegate.stopDictation()
                    }
                }
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            appPointer,
            &eventHandlerRef
        )

        guard status == noErr else {
            appendLog("Could not install hotkey handler: \(status)\n")
            return
        }

        let signature = OSType(
            UInt32(Character("L").asciiValue!) << 24
                | UInt32(Character("F").asciiValue!) << 16
                | UInt32(Character("L").asciiValue!) << 8
                | UInt32(Character("W").asciiValue!)
        )
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if hotKeyStatus == noErr {
            appendLog("Registered hold-to-dictate hotkey Ctrl+Option+Space.\n")
            appendLog("Accessibility trusted: \(AXIsProcessTrusted() ? "yes" : "no")\n")
        } else {
            appendLog("Could not register native hotkey Ctrl+Option+Space: \(hotKeyStatus)\n")
        }
    }

    private func requestAccessibilityTrustIfNeeded() {
        guard !AXIsProcessTrusted() else {
            return
        }

        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func startAccessibilityMonitor() {
        logAccessibilityTrust(force: true)
        accessibilityTimer?.invalidate()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.logAccessibilityTrust(force: false)
        }
    }

    private func logAccessibilityTrust(force: Bool) {
        let trusted = AXIsProcessTrusted()
        guard force || lastAccessibilityTrusted != trusted else {
            return
        }

        lastAccessibilityTrusted = trusted
        appendLog("Accessibility trusted refresh: \(trusted ? "yes" : "no")\n")
        updateOnboardingStatus()
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        hotKeyRef = nil
        eventHandlerRef = nil
    }

    private func appendLog(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        appendLog(data)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
