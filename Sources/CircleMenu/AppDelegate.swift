import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, MouseChordDelegate {
    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let store = ConfigStore.shared
    private let monitor = MouseChordMonitor()
    private lazy var panel = RadialMenuPanel()
    private lazy var settings = SettingsWindowController(store: store)
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        monitor.delegate = self
        startMonitoring(prompt: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "CircleMenu")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Hold Left + Right click to open", action: nil, keyEquivalent: ""))
        menu.addItem(statusLine)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit CircleMenu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func startMonitoring(prompt: Bool) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            statusLine.title = "⚠️ Waiting for Accessibility permission…"
            permissionTimer?.invalidate()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard AXIsProcessTrusted() else { return }
                timer.invalidate()
                self?.startMonitoring(prompt: false)
            }
            return
        }
        statusLine.title = monitor.start() ? "✅ Active" : "❌ Could not create mouse event tap"
    }

    @objc private func openSettings() {
        settings.present()
    }

    // MARK: MouseChordDelegate

    func chordBegan(at point: CGPoint) {
        panel.show(at: point, options: store.config.options)
    }

    func chordMoved(to point: CGPoint) {
        panel.updateSelection(for: point)
    }

    func chordEnded(at point: CGPoint) {
        let option = panel.updateSelection(for: point)
        panel.hide()
        guard let option else { return }
        // Run outside the event-tap callback: AppleScript calls can be slow and would time out the tap.
        DispatchQueue.main.async {
            let urls = FinderSelection.current()
            guard !urls.isEmpty else { NSSound.beep(); return }
            ActionRunner.run(option, on: urls)
        }
    }
}
