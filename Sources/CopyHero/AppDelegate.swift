import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let history = ClipboardHistory()
    private var monitor: ClipboardMonitor!
    private var panel: HistoryPanelController!
    private var hotKey: HotKey!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor = ClipboardMonitor { [weak self] in self?.history.add($0) }
        monitor.start()

        panel = HistoryPanelController(history: history)
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | shiftKey)) { [weak self] in
            self?.panel.toggle()
        }

        setUpStatusItem()
        registerLoginItem()
        Paster.requestAccessibility()
    }

    /// Always start at login. Remove via scripts/uninstall.sh or System Settings › Login Items.
    private func registerLoginItem() {
        guard SMAppService.mainApp.status != .enabled else { return }
        do {
            try SMAppService.mainApp.register()
        } catch {
            NSLog("CopyHero: could not register login item: \(error)")
        }
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CopyHero")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let show = NSMenuItem(title: "Show History", action: #selector(showHistory), keyEquivalent: "v")
        show.keyEquivalentModifierMask = [.control, .shift]
        menu.addItem(show)
        menu.addItem(NSMenuItem(title: "Clear History (\(history.items.count))", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        if Paster.hasAccessibility {
            menu.addItem(NSMenuItem(title: "Auto-paste: enabled", action: nil, keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Enable Auto-paste (Accessibility)…", action: #selector(openAccessibility), keyEquivalent: ""))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit CopyHero", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
    }

    @objc private func showHistory() {
        // Let the status menu finish closing first.
        DispatchQueue.main.async { self.panel.show() }
    }

    @objc private func clearHistory() {
        history.clear()
    }

    @objc private func openAccessibility() {
        Paster.requestAccessibility()
        Paster.openAccessibilitySettings()
    }
}
