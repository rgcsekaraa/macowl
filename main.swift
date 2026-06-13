// macowl - a tiny menu bar app that keeps your Mac awake.
//
// It lives only in the menu bar (no Dock icon) and uses IOKit power
// assertions instead of spawning the `caffeinate` tool. Build with build.sh.

import AppKit
import IOKit.pwr_mgt

// MARK: - Awake mode

enum AwakeMode {
    case off
    case system
    case systemAndDisplay

    var title: String {
        switch self {
        case .off:              return "Off"
        case .system:           return "On - System"
        case .systemAndDisplay: return "On - System + Display"
        }
    }

    var isActive: Bool { self != .off }
}

// MARK: - Power assertion manager

/// Holds at most one IOKit power assertion at a time.
final class AssertionManager {
    private var assertionID = IOPMAssertionID(0)
    private(set) var mode: AwakeMode = .off

    func apply(_ newMode: AwakeMode) {
        release()

        switch newMode {
        case .off:
            break
        case .system:
            create(type: kIOPMAssertPreventUserIdleSystemSleep,
                   reason: "macowl: keeping the system awake")
        case .systemAndDisplay:
            create(type: kIOPMAssertPreventUserIdleDisplaySleep,
                   reason: "macowl: keeping the system and display awake")
        }

        mode = newMode
    }

    private func create(type: String, reason: String) {
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id)
        if result == kIOReturnSuccess {
            assertionID = id
        }
    }

    private func release() {
        if assertionID != IOPMAssertionID(0) {
            IOPMAssertionRelease(assertionID)
            assertionID = IOPMAssertionID(0)
        }
    }

    deinit { release() }
}

// MARK: - App delegate / menu bar controller

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let assertions = AssertionManager()

    private let statusHeader = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let systemItem   = NSMenuItem(title: "Keep System Awake", action: nil, keyEquivalent: "")
    private let displayItem  = NSMenuItem(title: "Keep System + Display Awake", action: nil, keyEquivalent: "")
    private let offItem      = NSMenuItem(title: "Turn Off - Allow Sleep", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "macowl"

        let menu = NSMenu()
        menu.delegate = self

        statusHeader.isEnabled = false
        menu.addItem(statusHeader)
        menu.addItem(.separator())

        systemItem.target = self
        systemItem.action = #selector(toggleSystem)
        menu.addItem(systemItem)

        displayItem.target = self
        displayItem.action = #selector(toggleDisplay)
        menu.addItem(displayItem)

        offItem.target = self
        offItem.action = #selector(turnOff)
        menu.addItem(offItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit macowl", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu

        refreshMenu()
    }

    // MARK: Actions

    @objc private func toggleSystem() {
        set(mode: assertions.mode == .system ? .off : .system)
    }

    @objc private func toggleDisplay() {
        set(mode: assertions.mode == .systemAndDisplay ? .off : .systemAndDisplay)
    }

    @objc private func turnOff() {
        set(mode: .off)
    }

    private func set(mode: AwakeMode) {
        assertions.apply(mode)
        refreshMenu()
    }

    @objc private func quit() {
        assertions.apply(.off)
        NSApp.terminate(nil)
    }

    // MARK: UI updates

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenu()
    }

    private func refreshMenu() {
        statusHeader.title = "Status: \(assertions.mode.title)"
        systemItem.state  = assertions.mode == .system ? .on : .off
        displayItem.state = assertions.mode == .systemAndDisplay ? .on : .off
        offItem.isEnabled = assertions.mode.isActive
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)     // menu bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
