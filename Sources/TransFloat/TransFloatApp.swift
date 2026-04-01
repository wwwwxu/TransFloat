import AppKit
import SwiftUI

// MARK: - Supported Languages

struct Language {
    let code: String
    let name: String
}

let supportedLanguages: [Language] = [
    Language(code: "zh-CN", name: "简体中文"),
    Language(code: "zh-TW", name: "繁體中文"),
    Language(code: "en", name: "English"),
    Language(code: "ja", name: "日本語"),
    Language(code: "ko", name: "한국어"),
    Language(code: "fr", name: "Français"),
    Language(code: "de", name: "Deutsch"),
    Language(code: "es", name: "Español"),
    Language(code: "ru", name: "Русский"),
    Language(code: "nl", name: "Nederlands"),
]

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var selectionMonitor: SelectionMonitor?
    var floatingBar: FloatingBarWindow?
    var isEnabled = true
    var targetLanguage = "zh-CN"
    var languageMenuItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[TransFloat] applicationDidFinishLaunching called")

        // Load saved language preference
        if let saved = UserDefaults.standard.string(forKey: "targetLanguage") {
            targetLanguage = saved
        }

        setupStatusBar()
        floatingBar = FloatingBarWindow()

        selectionMonitor = SelectionMonitor { [weak self] text in
            self?.handleSelectedText(text)
        }
        selectionMonitor?.start()
        checkAccessibilityPermission()
    }

    // MARK: - Menu Bar

    func setupStatusBar() {
        NSLog("[TransFloat] setting up status bar")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else {
            NSLog("[TransFloat] ERROR: could not get status item button")
            return
        }

        if let img = NSImage(systemSymbolName: "globe", accessibilityDescription: "TransFloat") {
            img.size = NSSize(width: 18, height: 18)
            button.image = img
            button.imagePosition = .imageOnly
        } else {
            button.title = "译"
            button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        }

        let menu = NSMenu()

        // Toggle
        let toggleItem = NSMenuItem(title: "启用翻译", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = .on
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Target language submenu
        let langItem = NSMenuItem(title: "翻译目标语言", action: nil, keyEquivalent: "")
        let langSubmenu = NSMenu()

        for lang in supportedLanguages {
            let item = NSMenuItem(title: "\(lang.name) (\(lang.code))", action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang.code
            item.state = lang.code == targetLanguage ? .on : .off
            langSubmenu.addItem(item)
            languageMenuItems.append(item)
        }

        langItem.submenu = langSubmenu
        menu.addItem(langItem)

        menu.addItem(NSMenuItem.separator())

        // Hotkey hint
        let hotkeyItem = NSMenuItem(title: "快捷键: ⌃⌥D", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)

        menu.addItem(NSMenuItem.separator())

        // Test
        let testItem = NSMenuItem(title: "测试翻译", action: #selector(testTranslation), keyEquivalent: "")
        testItem.target = self
        menu.addItem(testItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "退出 TransFloat", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        NSLog("[TransFloat] status bar setup complete")
    }

    @objc func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off
        NSLog("[TransFloat] enabled: \(isEnabled)")
    }

    @objc func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        targetLanguage = code
        UserDefaults.standard.set(code, forKey: "targetLanguage")

        // Update checkmarks
        for item in languageMenuItems {
            item.state = (item.representedObject as? String) == code ? .on : .off
        }

        let langName = supportedLanguages.first(where: { $0.code == code })?.name ?? code
        NSLog("[TransFloat] target language: \(langName) (\(code))")
    }

    @objc func testTranslation() {
        NSLog("[TransFloat] test translation triggered")
        handleSelectedText("The quick brown fox jumps over the lazy dog")
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Translation Flow

    func handleSelectedText(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let lang = targetLanguage
        NSLog("[TransFloat] translating to \(lang): \(trimmed.prefix(50))")

        DispatchQueue.main.async {
            self.floatingBar?.show(original: trimmed, translation: "翻译中...")
        }

        Task {
            do {
                let translation = try await GoogleTranslator.translate(trimmed, targetLang: lang)
                NSLog("[TransFloat] result: \(translation.prefix(50))")
                await MainActor.run {
                    self.floatingBar?.show(original: trimmed, translation: translation)
                }
            } catch {
                NSLog("[TransFloat] error: \(error)")
                await MainActor.run {
                    self.floatingBar?.show(original: trimmed, translation: "翻译失败: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Accessibility

    func checkAccessibilityPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        NSLog("[TransFloat] accessibility: \(trusted ? "✅ granted" : "⚠️ NOT granted")")
    }
}

// MARK: - Main Entry

private var _appDelegate: AppDelegate?

@main
enum TransFloatMain {
    static func main() {
        NSLog("[TransFloat] main() starting")
        let app = NSApplication.shared

        let delegate = AppDelegate()
        _appDelegate = delegate
        app.delegate = delegate

        NSLog("[TransFloat] calling app.run()")
        app.run()
    }
}
