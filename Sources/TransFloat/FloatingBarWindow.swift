import AppKit
import SwiftUI

class FloatingBarWindow {
    private var panel: FloatingPanel?
    private var hostingView: NSHostingView<FloatingBarView>?
    private var viewModel = FloatingBarViewModel()
    private var dismissTimer: Timer?
    private var closeButton: NSButton?

    private let barWidthRatio: CGFloat = 0.75
    private let maxBarHeight: CGFloat = 200
    private let bottomMargin: CGFloat = 40
    private let autoDismissDelay: TimeInterval = 3.0
    private let padding: CGFloat = 32 + 30 // horizontal padding (24) + trailing extra (30) + some buffer

    /// Measure actual text height using NSAttributedString
    private func measureHeight(translation: String, original: String, width: CGFloat) -> CGFloat {
        let textWidth = width - 24 - 24 - 30 // left pad + right pad + close button room

        // Measure translation text
        let transAttr = NSAttributedString(
            string: translation,
            attributes: [.font: NSFont.systemFont(ofSize: 18, weight: .semibold)]
        )
        let transRect = transAttr.boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        // Measure original text
        let origAttr = NSAttributedString(
            string: original,
            attributes: [.font: NSFont.systemFont(ofSize: 13)]
        )
        let origRect = origAttr.boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        // Total: text heights + spacing(6) + top padding(16) + bottom padding(16)
        return ceil(transRect.height + origRect.height + 6 + 16 + 16)
    }

    func show(original: String, translation: String) {
        viewModel.original = original
        viewModel.translation = translation
        viewModel.isVisible = true

        if panel == nil {
            createPanel()
        }

        guard let panel = panel, let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelWidth = screenFrame.width * barWidthRatio

        // Measure real content height, cap at 200px
        let contentHeight = measureHeight(translation: translation, original: original, width: panelWidth)
        let height = min(contentHeight, maxBarHeight)

        let panelX = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let panelY = screenFrame.origin.y + bottomMargin
        panel.setFrame(NSRect(x: panelX, y: panelY, width: panelWidth, height: height), display: true)

        // Position close button top-right
        if let closeButton = closeButton, let contentView = panel.contentView {
            closeButton.frame.origin = CGPoint(
                x: contentView.bounds.width - closeButton.frame.width - 12,
                y: contentView.bounds.height - closeButton.frame.height - 12
            )
        }

        panel.orderFrontRegardless()

        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        resetDismissTimer()
    }

    @objc func dismiss() {
        guard let panel = panel else { return }
        dismissTimer?.invalidate()
        dismissTimer = nil

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            self.viewModel.isVisible = false
        })
    }

    // MARK: - Private

    private func createPanel() {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 120),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.onDismiss = { [weak self] in self?.dismiss() }
        panel.onHoverChanged = { [weak self] isHovered in
            guard let self = self else { return }
            if isHovered {
                // Mouse entered — pause auto-dismiss
                self.dismissTimer?.invalidate()
                self.dismissTimer = nil
            } else {
                // Mouse left — dismiss after 1s delay
                self.resetDismissTimer(delay: 0.5)
            }
        }

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true

        let barView = FloatingBarView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: barView)
        hostingView.frame = panel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostingView)

        // Native AppKit close button on top
        let btn = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        btn.bezelStyle = .circular
        btn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        btn.imageScaling = .scaleProportionallyUpOrDown
        btn.isBordered = false
        btn.contentTintColor = NSColor.white.withAlphaComponent(0.5)
        btn.target = self
        btn.action = #selector(dismiss)
        panel.contentView?.addSubview(btn)
        closeButton = btn

        self.panel = panel
        self.hostingView = hostingView
    }

    private func resetDismissTimer(delay: TimeInterval? = nil) {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: delay ?? autoDismissDelay, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }
}

// MARK: - Floating Panel (handles ESC, hover tracking via NSTrackingArea)

private class FloatingPanel: NSPanel {
    var onDismiss: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onDismiss?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        makeKey()
        super.mouseDown(with: event)
    }

    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool) {
        super.setFrame(frameRect, display: displayFlag)
        updateHoverTracking()
    }

    private func updateHoverTracking() {
        guard let contentView = contentView else { return }
        if let existing = hoverTrackingArea {
            contentView.removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }
}
