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

        refreshIcon()
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
        refreshIcon()
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

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        let image = AppDelegate.owlImage(size: 18, awake: assertions.mode.isActive)
        image.isTemplate = false        // colour icon, not a monochrome template
        button.image = image
        button.toolTip = "macowl - \(assertions.mode.title)"
    }

    /// Custom colour owl mark, the eponymous macowl. Eyes open and alert when
    /// awake, closed (sleeping) when off. Transparent background so it sits
    /// cleanly in the menu bar.
    static func owlImage(size: CGFloat, awake: Bool) -> NSImage {
        let s = NSSize(width: size, height: size)
        return NSImage(size: s, flipped: false) { rect in
            let w = rect.width, h = rect.height
            NSGraphicsContext.current!.shouldAntialias = true
            let amber     = NSColor(red: 0.86, green: 0.60, blue: 0.24, alpha: 1)
            let amberDark = NSColor(red: 0.55, green: 0.35, blue: 0.12, alpha: 1)
            let belly     = NSColor(red: 0.95, green: 0.78, blue: 0.46, alpha: 1)

            // Ear tufts.
            func ear(cx: CGFloat, tipX: CGFloat) {
                let base = h*0.70, tip = h*0.97, half = w*0.10
                let p = NSBezierPath()
                p.move(to: NSPoint(x: cx-half, y: base))
                p.line(to: NSPoint(x: cx+half, y: base))
                p.line(to: NSPoint(x: tipX, y: tip))
                p.close()
                amberDark.setFill(); p.fill()
            }
            ear(cx: w*0.30, tipX: w*0.20)
            ear(cx: w*0.70, tipX: w*0.80)

            // Body + belly highlight.
            let body = NSBezierPath(roundedRect: NSRect(x: w*0.12, y: h*0.06, width: w*0.76, height: h*0.74),
                                    xRadius: w*0.36, yRadius: w*0.36)
            amber.setFill(); body.fill()
            belly.setFill()
            NSBezierPath(ovalIn: NSRect(x: w*0.27, y: h*0.08, width: w*0.46, height: h*0.46)).fill()

            // Eyes.
            let eyeR = w*0.17, eyeY = h*0.55, lx = w*0.35, rx = w*0.65
            if awake {
                for cx in [lx, rx] {
                    NSColor(red: 0.99, green: 0.98, blue: 0.93, alpha: 1).setFill()
                    NSBezierPath(ovalIn: NSRect(x: cx-eyeR, y: eyeY-eyeR, width: eyeR*2, height: eyeR*2)).fill()
                    let pr = eyeR*0.5
                    NSColor.black.setFill()
                    NSBezierPath(ovalIn: NSRect(x: cx-pr, y: eyeY-pr, width: pr*2, height: pr*2)).fill()
                    let gl = pr*0.4
                    NSColor.white.setFill()
                    NSBezierPath(ovalIn: NSRect(x: cx-pr*0.3, y: eyeY+pr*0.15, width: gl*2, height: gl*2)).fill()
                }
            } else {
                // Closed / sleeping eyes: downward arcs.
                for cx in [lx, rx] {
                    let p = NSBezierPath()
                    p.move(to: NSPoint(x: cx-eyeR, y: eyeY))
                    p.curve(to: NSPoint(x: cx+eyeR, y: eyeY),
                            controlPoint1: NSPoint(x: cx-eyeR*0.4, y: eyeY-eyeR),
                            controlPoint2: NSPoint(x: cx+eyeR*0.4, y: eyeY-eyeR))
                    p.lineWidth = w*0.05; p.lineCapStyle = .round
                    amberDark.setStroke(); p.stroke()
                }
            }

            // Beak.
            let beak = NSBezierPath()
            let bx = w*0.5, by = h*0.48
            beak.move(to: NSPoint(x: bx-w*0.06, y: by))
            beak.line(to: NSPoint(x: bx+w*0.06, y: by))
            beak.line(to: NSPoint(x: bx, y: by-h*0.13))
            beak.close()
            NSColor(red: 0.95, green: 0.62, blue: 0.16, alpha: 1).setFill(); beak.fill()

            return true
        }
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
