import AppKit
import ServiceManagement

// Used by scripts/uninstall.sh to remove the login item before deleting the app.
if CommandLine.arguments.contains("--unregister-login") {
    try? SMAppService.mainApp.unregister()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
