// macowl - a tiny menu bar app that keeps your Mac awake.
//
// It lives only in the menu bar (no Dock icon). Build with build.sh.

import AppKit

// MARK: - App delegate / menu bar controller

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "macowl"

        let menu = NSMenu()

        let quit = NSMenuItem(title: "Quit macowl", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)     // menu bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
