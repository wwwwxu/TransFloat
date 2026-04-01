import AppKit
import Carbon.HIToolbox

private let kHotKeyID = EventHotKeyID(signature: OSType(0x5446_4C54), // "TFLT"
                                       id: 1)

// Global C callback for Carbon hot key events
private func hotKeyHandler(nextHandler: EventHandlerCallRef?,
                           event: EventRef?,
                           userData: UnsafeMutableRawPointer?) -> OSStatus {
    NSLog("[TransFloat] Carbon hotkey fired!")
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    let monitor = Unmanaged<SelectionMonitor>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        monitor.captureSelectedText()
    }
    return noErr
}

class SelectionMonitor {
    private let onTextSelected: (String) -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(onTextSelected: @escaping (String) -> Void) {
        self.onTextSelected = onTextSelected
    }

    func start() {
        registerCarbonHotKey()
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = handlerRef {
            RemoveEventHandler(ref)
            handlerRef = nil
        }
    }

    deinit { stop() }

    // MARK: - Carbon Global Hot Key

    private func registerCarbonHotKey() {
        // Register for kEventHotKeyPressed
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            selfPtr,
            &handler
        )

        guard status == noErr else {
            NSLog("[TransFloat] ERROR: InstallEventHandler failed: \(status)")
            return
        }
        handlerRef = handler

        // Register ⌃⌥D: Control + Option + D
        let modifiers: UInt32 = UInt32(controlKey | optionKey)
        var hotKeyID = kHotKeyID
        var ref: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard regStatus == noErr else {
            NSLog("[TransFloat] ERROR: RegisterEventHotKey failed: \(regStatus)")
            return
        }
        hotKeyRef = ref

        NSLog("[TransFloat] ✅ Carbon hotkey registered: ⌃⌥D (Control+Option+D)")
    }

    // MARK: - Capture Selected Text

    func captureSelectedText() {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount
        let savedString = pasteboard.string(forType: .string)

        NSLog("[TransFloat] simulating ⌘C...")
        simulateCopy()

        // Wait for copy (Electron apps need 0.3s+)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }

            if pasteboard.changeCount == previousChangeCount {
                NSLog("[TransFloat] clipboard unchanged — no text selected")
                return
            }

            guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
                NSLog("[TransFloat] clipboard empty after copy")
                return
            }

            NSLog("[TransFloat] captured: \(text.prefix(80))")
            self.onTextSelected(text)

            // Restore previous clipboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pasteboard.clearContents()
                if let saved = savedString {
                    pasteboard.setString(saved, forType: .string)
                }
            }
        }
    }

    // MARK: - Simulate ⌘C

    private func simulateCopy() {
        let source = CGEventSource(stateID: .combinedSessionState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else {
            NSLog("[TransFloat] ERROR: failed to create ⌘C events")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        NSLog("[TransFloat] ⌘C posted")
    }
}
