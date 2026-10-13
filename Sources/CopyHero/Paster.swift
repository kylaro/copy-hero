import AppKit
import ApplicationServices
import Carbon.HIToolbox

enum Paster {
    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// Shows the system Accessibility prompt if we aren't trusted yet (no-op otherwise).
    static func requestAccessibility() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func copyToPasteboard(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.content {
        case .text(let s): pb.setString(s, forType: .string)
        case .image(_, let data, let type): pb.setData(data, forType: type)
        }
    }

    /// Sends ⌘V to whatever app is frontmost. Needs Accessibility permission;
    /// without it the item is still on the clipboard for a manual ⌘V.
    static func pasteIntoFrontApp() {
        guard hasAccessibility else { return }
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
