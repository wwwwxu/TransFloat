import AppKit
import Carbon.HIToolbox
import CoreGraphics

// MARK: - CGEventTap callback (global C function)

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<SelectionMonitor>.fromOpaque(refcon).takeUnretainedValue()

    // Tap was disabled (timeout or user input) — re-enable it
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        NSLog("[TransFloat] event tap disabled (type=\(type.rawValue)) — re-enabling")
        if let tap = monitor.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else { return Unmanaged.passUnretained(event) }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    // ⌃⌥D — Control + Option + D, no Cmd/Shift
    if keyCode == Int64(kVK_ANSI_D)
        && flags.contains(.maskControl)
        && flags.contains(.maskAlternate)
        && !flags.contains(.maskCommand)
        && !flags.contains(.maskShift) {
        NSLog("[TransFloat] ⌃⌥D detected via CGEventTap")
        DispatchQueue.main.async { monitor.captureSelectedText() }
    }

    return Unmanaged.passUnretained(event)
}

// MARK: - SelectionMonitor

class SelectionMonitor {
    private let onTextSelected: (String) -> Void
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(onTextSelected: @escaping (String) -> Void) {
        self.onTextSelected = onTextSelected
    }

    func start() {
        setupEventTap()
        observeSleepWake()
    }

    func stop() {
        teardownEventTap()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func reregister() {
        NSLog("[TransFloat] reregister() called")
        teardownEventTap()
        setupEventTap()
    }

    deinit { stop() }

    // MARK: - CGEventTap

    private func setupEventTap() {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // Listen for keyDown + tap-disabled events
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            NSLog("[TransFloat] ⚠️ CGEventTap failed (no Accessibility?) — falling back to Carbon")
            setupCarbonHotKey()
            return
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = src
        NSLog("[TransFloat] ✅ CGEventTap registered for ⌃⌥D")
    }

    private func teardownEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            runLoopSource = nil
        }
    }

    // MARK: - Carbon fallback

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private func setupCarbonHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var handler: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), carbonHotKeyCallback,
                            1, &eventType, selfPtr, &handler)
        handlerRef = handler

        let modifiers: UInt32 = UInt32(controlKey | optionKey)
        var hotKeyID = EventHotKeyID(signature: OSType(0x5446_4C54), id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_D), modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRef = ref
            NSLog("[TransFloat] ✅ Carbon hotkey registered (fallback): ⌃⌥D")
        } else {
            NSLog("[TransFloat] ❌ Carbon hotkey also failed: \(status)")
        }
    }

    // MARK: - Sleep/wake

    private func observeSleepWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            NSLog("[TransFloat] system woke — reregistering")
            self?.reregister()
        }
    }

    // MARK: - Capture selected text

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
              let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else {
            NSLog("[TransFloat] ERROR: failed to create ⌘C events")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags   = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        NSLog("[TransFloat] ⌘C posted")
    }
}

// MARK: - Carbon callback (fallback)

private func carbonHotKeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    NSLog("[TransFloat] Carbon hotkey fired (fallback)!")
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    let monitor = Unmanaged<SelectionMonitor>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { monitor.captureSelectedText() }
    return noErr
}
