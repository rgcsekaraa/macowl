// macowl - a tiny menu bar app that keeps your Mac awake.
//
// It lives only in the menu bar (no Dock icon) and uses IOKit power
// assertions instead of spawning the `caffeinate` tool. There are four
// states:
//
//   Off                  - normal sleep is allowed.
//   On - System          - the Mac will not idle sleep, the display may dim.
//   On - System+Display  - the whole machine and the screen stay awake.
//   On - Lid Closed      - the Mac keeps running even when the lid is shut.
//
// The lid-closed state is special. No IOKit assertion can stop the sleep
// that happens when you close the lid, so it uses the system wide
// `pmset disablesleep` setting, which needs an admin password. Because that
// setting survives a crash, macowl keeps a small marker file and reconciles
// the state on the next launch so your Mac never gets stuck awake by mistake.
//
// Build with build.sh.

import AppKit
import IOKit.pwr_mgt
import ServiceManagement

// MARK: - Awake mode

enum AwakeMode {
    case off
    case system
    case systemAndDisplay
    case lidClosed

    var title: String {
        switch self {
        case .off:              return "Off"
        case .system:           return "On - System"
        case .systemAndDisplay: return "On - System + Display"
        case .lidClosed:        return "On - Even with Lid Closed"
        }
    }

    var isActive: Bool { self != .off }

    /// Whether this mode needs the system wide lid-close setting turned on.
    var needsLidSleepDisabled: Bool { self == .lidClosed }
}

// MARK: - Lid sleep control

/// Controls whether the Mac is allowed to sleep when the lid is shut.
///
/// macOS has no power assertion for this, so the only reliable lever is the
/// system wide `pmset disablesleep` flag. Changing it needs admin rights, so
/// every change shows an authorization prompt. A marker file records when
/// macowl was the one that turned it on, which lets the app detect a leftover
/// after a crash and offer to undo it.
enum LidSleep {

    /// The outcome of trying to change the setting.
    enum ChangeResult {
        case changed
        case cancelled          // the user dismissed the password prompt
        case failed(String)     // anything else went wrong
    }

    /// Location of the marker file under Application Support.
    private static let markerURL: URL = {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = support.appendingPathComponent("macowl", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("lid-sleep-disabled.marker")
    }()

    /// True when macowl's marker file is present.
    static var markerExists: Bool {
        FileManager.default.fileExists(atPath: markerURL.path)
    }

    /// Reads the live system setting. No admin rights are needed for this.
    /// Returns nil only if `pmset` could not be run at all.
    static func isDisabledSystemWide() -> Bool? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        for line in output.split(separator: "\n") where line.contains("SleepDisabled") {
            // The line looks like " SleepDisabled  1". When the value is 0 the
            // line is usually absent, which we treat as "not disabled" below.
            return line.contains("1")
        }
        return false
    }

    /// True when macowl believes it is the owner of an active lid setting,
    /// that is the marker is present and the system setting is really on.
    static func isOwnedAndActive() -> Bool {
        markerExists && (isDisabledSystemWide() ?? false)
    }

    /// Turns the system wide setting on or off through an admin prompt and
    /// keeps the marker file in sync with the request.
    @discardableResult
    static func set(_ disabled: Bool) -> ChangeResult {
        let value = disabled ? "1" : "0"
        let command = "/usr/bin/pmset -a disablesleep \(value)"
        let source = "do shell script \"\(command)\" with administrator privileges"

        guard let script = NSAppleScript(source: source) else {
            return .failed("Could not build the authorization request.")
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        if let errorInfo = errorInfo {
            let code = (errorInfo["NSAppleScriptErrorNumber"] as? Int) ?? 0
            if code == -128 {
                return .cancelled        // user cancelled the prompt
            }
            let message = (errorInfo["NSAppleScriptErrorMessage"] as? String)
                ?? "The system did not allow the change."
            return .failed(message)
        }

        if disabled {
            try? Data().write(to: markerURL)
        } else {
            clearMarker()
        }
        return .changed
    }

    /// Removes the marker file without touching the system setting.
    static func clearMarker() {
        try? FileManager.default.removeItem(at: markerURL)
    }
}

// MARK: - Power assertion manager

/// Holds at most one IOKit power assertion at a time and, for the lid-closed
/// mode, drives the system wide lid setting through `LidSleep`.
final class AssertionManager {

    /// The outcome of applying a mode.
    enum ApplyResult {
        case ok
        case cancelled
        case failed(String)
    }

    private var assertionID = IOPMAssertionID(0)
    private(set) var mode: AwakeMode = .off

    /// Applies a mode. The lid setting is handled first because it is the only
    /// step that can be refused, and we do not want to half apply a mode.
    @discardableResult
    func apply(_ newMode: AwakeMode) -> ApplyResult {
        let wantLid = newMode.needsLidSleepDisabled
        let haveLid = LidSleep.isOwnedAndActive()

        if wantLid != haveLid {
            switch LidSleep.set(wantLid) {
            case .changed:
                break
            case .cancelled:
                return .cancelled          // leave the current mode untouched
            case .failed(let message):
                return .failed(message)
            }
        }

        release()

        switch newMode {
        case .off:
            break
        case .system, .lidClosed:
            // For lidClosed the pmset flag already blocks every kind of sleep,
            // so this assertion simply makes the intent explicit and survives
            // if the flag is ever cleared from under us.
            create(type: kIOPMAssertPreventUserIdleSystemSleep,
                   reason: "macowl: keeping the system awake")
        case .systemAndDisplay:
            create(type: kIOPMAssertPreventUserIdleDisplaySleep,
                   reason: "macowl: keeping the system and display awake")
        }

        mode = newMode
        return .ok
    }

    /// Adopts an already active lid setting that was found at launch, without
    /// prompting for a password again.
    func adoptLidMode() {
        release()
        create(type: kIOPMAssertPreventUserIdleSystemSleep,
               reason: "macowl: keeping the system awake")
        mode = .lidClosed
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
    private var signalSources: [DispatchSourceSignal] = []

    // Menu items we keep around so we can update their state.
    private let statusHeader = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let systemItem   = NSMenuItem(title: "Keep System Awake", action: nil, keyEquivalent: "")
    private let displayItem  = NSMenuItem(title: "Keep System + Display Awake", action: nil, keyEquivalent: "")
    private let lidItem      = NSMenuItem(title: "Keep Awake with Lid Closed", action: nil, keyEquivalent: "")
    private let offItem      = NSMenuItem(title: "Turn Off - Allow Sleep", action: nil, keyEquivalent: "")
    private let loginItem    = NSMenuItem(title: "Start at Login", action: nil, keyEquivalent: "")

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

        lidItem.target = self
        lidItem.action = #selector(toggleLid)
        menu.addItem(lidItem)

        offItem.target = self
        offItem.action = #selector(turnOff)
        menu.addItem(offItem)

        menu.addItem(.separator())

        // "Start at Login" relies on SMAppService, which only exists on
        // macOS 13+. On older systems we hide the item rather than show a
        // control that can't work.
        if #available(macOS 13.0, *) {
            loginItem.target = self
            loginItem.action = #selector(toggleLoginItem)
            menu.addItem(loginItem)
        }

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit macowl", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu

        installSignalHandlers()
        reconcileLeftoverLidState()

        refreshIcon()
        refreshMenu()
    }

    // MARK: Signals

    /// Restore normal sleep on a graceful termination signal. A hard kill
    /// (SIGKILL) cannot be caught, but the launch reconciliation above covers
    /// that case.
    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                self?.assertions.apply(.off)
                NSApp.terminate(nil)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    // MARK: Startup safety net

    /// If a previous run left the lid setting on (for example after a crash or
    /// a force quit), ask the user whether to keep the Mac awake or restore
    /// normal sleep. This is what stops the Mac from being stuck awake forever.
    private func reconcileLeftoverLidState() {
        guard LidSleep.markerExists else { return }

        // The marker is here, so a past run turned the setting on. Check if it
        // is still really on.
        guard LidSleep.isDisabledSystemWide() ?? false else {
            // Something already cleared it, so just drop the stale marker.
            LidSleep.clearMarker()
            return
        }

        let alert = NSAlert()
        alert.messageText = "macowl did not quit cleanly last time"
        alert.informativeText = """
        Your Mac is still set to stay awake even with the lid closed. \
        Do you want to keep it awake, or restore normal sleep?
        """
        alert.addButton(withTitle: "Restore Normal Sleep")
        alert.addButton(withTitle: "Keep Awake")

        if alert.runModal() == .alertFirstButtonReturn {
            // Restore normal sleep. This needs the admin prompt once more.
            switch assertions.apply(.off) {
            case .ok, .cancelled:
                break
            case .failed(let message):
                showError("Couldn't restore normal sleep", message)
            }
        } else {
            // Keep the Mac awake and show the matching state in the menu,
            // without asking for the password again.
            assertions.adoptLidMode()
        }
    }

    // MARK: Actions

    @objc private func toggleSystem() {
        set(mode: assertions.mode == .system ? .off : .system)
    }

    @objc private func toggleDisplay() {
        set(mode: assertions.mode == .systemAndDisplay ? .off : .systemAndDisplay)
    }

    @objc private func toggleLid() {
        set(mode: assertions.mode == .lidClosed ? .off : .lidClosed)
    }

    @objc private func turnOff() {
        set(mode: .off)
    }

    private func set(mode: AwakeMode) {
        switch assertions.apply(mode) {
        case .ok, .cancelled:
            // On cancel the mode is unchanged, the refresh below just keeps the
            // menu honest.
            break
        case .failed(let message):
            showError("Couldn't change the lid setting", message)
        }
        refreshIcon()
        refreshMenu()
    }

    @objc private func toggleLoginItem() {
        guard #available(macOS 13.0, *) else { return }
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            showError("Couldn't update Login Items", error.localizedDescription)
        }
        refreshMenu()
    }

    @objc private func quit() {
        // Make sure we never leave the Mac stuck awake.
        assertions.apply(.off)
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Last line of defence for terminations that did not go through quit().
        if assertions.mode.needsLidSleepDisabled || LidSleep.isOwnedAndActive() {
            assertions.apply(.off)
        }
    }

    // MARK: UI updates

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenu()
    }

    private func showError(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
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
        lidItem.state     = assertions.mode == .lidClosed ? .on : .off
        offItem.isEnabled = assertions.mode.isActive
        if #available(macOS 13.0, *) {
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)     // menu bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
