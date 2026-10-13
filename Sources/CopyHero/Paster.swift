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

    /// Brings `target` back to the front, then sends ⌘V to it. Needs Accessibility
    /// permission; without it the item is still on the clipboard for a manual ⌘V.
    static func paste(into target: NSRunningApplication?) {
        guard hasAccessibility else {
            NSLog("CopyHero: Accessibility not granted, skipping auto-paste")
            return
        }
        if let target, !target.isActive {
            target.activate()
        }
        waitForFocus(of: target, attemptsLeft: 20) { sendCommandV() }
    }

    /// Polls until `target` is frontmost (or we give up), then a short settle delay so
    /// its key window is ready to receive the keystroke.
    private static func waitForFocus(of target: NSRunningApplication?, attemptsLeft: Int, then action: @escaping () -> Void) {
        let ready = target == nil || NSWorkspace.shared.frontmostApplication == target
        if ready || attemptsLeft == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: action)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            waitForFocus(of: target, attemptsLeft: attemptsLeft - 1, then: action)
        }
    }

    private static func sendCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        // Don't let the just-finished mouse click suppress our synthetic keystroke.
        src?.setLocalEventsFilterDuringSuppressionState([.permitLocalMouseEvents, .permitSystemDefinedEvents],
                                                        state: .eventSuppressionStateSuppressionInterval)
        let vKey = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}
