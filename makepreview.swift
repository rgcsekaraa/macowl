// Renders a UI preview image of the macowl menu for the README.
//   swift makepreview.swift <output.png>
// This is a faithful illustration of the menu (same items and states the app
// shows), drawn in code so it can be regenerated. It is not a photographic
// screenshot.

import AppKit

// The owl mark, identical to the one main.swift draws in the menu bar.
func drawOwlMark(in rect: NSRect, awake: Bool) {
    let w = rect.width, h = rect.height
    let ctx = NSGraphicsContext.current!
    ctx.saveGraphicsState()
    ctx.shouldAntialias = true
    let t = NSAffineTransform()
    t.translateX(by: rect.minX, yBy: rect.minY)
    t.concat()

    let amber     = NSColor(red: 0.86, green: 0.60, blue: 0.24, alpha: 1)
    let amberDark = NSColor(red: 0.55, green: 0.35, blue: 0.12, alpha: 1)
    let belly     = NSColor(red: 0.95, green: 0.78, blue: 0.46, alpha: 1)

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

    let body = NSBezierPath(roundedRect: NSRect(x: w*0.12, y: h*0.06, width: w*0.76, height: h*0.74),
                            xRadius: w*0.36, yRadius: w*0.36)
    amber.setFill(); body.fill()
    belly.setFill()
    NSBezierPath(ovalIn: NSRect(x: w*0.27, y: h*0.08, width: w*0.46, height: h*0.46)).fill()

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
    }

    let beak = NSBezierPath()
    let bx = w*0.5, by = h*0.48
    beak.move(to: NSPoint(x: bx-w*0.06, y: by))
    beak.line(to: NSPoint(x: bx+w*0.06, y: by))
    beak.line(to: NSPoint(x: bx, y: by-h*0.13))
    beak.close()
    NSColor(red: 0.95, green: 0.62, blue: 0.16, alpha: 1).setFill(); beak.fill()

    ctx.restoreGraphicsState()
}

enum Row {
    case header(String)
    case item(String, checked: Bool, selected: Bool, enabled: Bool)
    case separator
}

let rows: [Row] = [
    .header("Status: On - Even with Lid Closed"),
    .separator,
    .item("Keep System Awake", checked: false, selected: false, enabled: true),
    .item("Keep System + Display Awake", checked: false, selected: false, enabled: true),
    .item("Keep Awake with Lid Closed", checked: true, selected: true, enabled: true),
    .item("Turn Off - Allow Sleep", checked: false, selected: false, enabled: true),
    .separator,
    .item("Start at Login", checked: true, selected: false, enabled: true),
    .separator,
    .item("Quit macowl", checked: false, selected: false, enabled: true),
]

let W: CGFloat = 760, H: CGFloat = 560
let barH: CGFloat = 30
let rowH: CGFloat = 26
let sepH: CGFloat = 11
let padV: CGFloat = 6
let panelW: CGFloat = 320

func heightOf(_ r: Row) -> CGFloat {
    if case .separator = r { return sepH }
    return rowH
}
let contentH = rows.reduce(0) { $0 + heightOf($1) }
let panelH = contentH + padV*2

let img = NSImage(size: NSSize(width: W, height: H), flipped: false) { _ in
    let ctx = NSGraphicsContext.current!
    ctx.shouldAntialias = true

    // Desktop backdrop.
    NSGradient(colors: [
        NSColor(calibratedRed: 0.36, green: 0.45, blue: 0.62, alpha: 1),
        NSColor(calibratedRed: 0.20, green: 0.26, blue: 0.40, alpha: 1)])!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

    // Menu bar.
    NSColor(calibratedWhite: 0.97, alpha: 0.95).setFill()
    NSRect(x: 0, y: H-barH, width: W, height: barH).fill()
    NSColor(calibratedWhite: 0.75, alpha: 1).setFill()
    NSRect(x: 0, y: H-barH, width: W, height: 0.75).fill()

    // Clock on the far right of the bar.
    let clock = "Fri 9:41"
    let clockAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13),
        .foregroundColor: NSColor(calibratedWhite: 0.2, alpha: 1)]
    let clockSize = (clock as NSString).size(withAttributes: clockAttrs)
    (clock as NSString).draw(at: NSPoint(x: W-clockSize.width-16, y: H-barH+(barH-clockSize.height)/2),
                             withAttributes: clockAttrs)

    // Owl in the menu bar (with an open-menu highlight behind it).
    let owlSize: CGFloat = 20
    let owlX = W - 150
    let owlY = H - barH + (barH-owlSize)/2
    NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 0.18).setFill()
    NSRect(x: owlX-8, y: H-barH, width: owlSize+16, height: barH).fill()
    drawOwlMark(in: NSRect(x: owlX, y: owlY, width: owlSize, height: owlSize), awake: true)

    // Menu panel, right edge roughly under the owl.
    let panelRight = owlX + owlSize + 8
    let pX = panelRight - panelW
    let panelTopY = H - barH - 4
    let panelBottomY = panelTopY - panelH

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 16
    shadow.shadowOffset = NSSize(width: 0, height: -6)
    ctx.saveGraphicsState()
    shadow.set()
    NSColor(calibratedWhite: 0.99, alpha: 1).setFill()
    let panel = NSBezierPath(roundedRect: NSRect(x: pX, y: panelBottomY, width: panelW, height: panelH),
                             xRadius: 10, yRadius: 10)
    panel.fill()
    ctx.restoreGraphicsState()

    // Rows from the top down.
    var y = panelTopY - padV
    for r in rows {
        switch r {
        case .separator:
            NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
            NSRect(x: pX+12, y: y - sepH/2, width: panelW-24, height: 1).fill()
            y -= sepH
        case .header(let title):
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor(calibratedWhite: 0.5, alpha: 1)]
            let sz = (title as NSString).size(withAttributes: attrs)
            (title as NSString).draw(at: NSPoint(x: pX+16, y: y - rowH/2 - sz.height/2),
                                     withAttributes: attrs)
            y -= rowH
        case .item(let title, let checked, let selected, let enabled):
            if selected {
                NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(x: pX+5, y: y-rowH+2, width: panelW-10, height: rowH-4),
                             xRadius: 5, yRadius: 5).fill()
            }
            let textColor: NSColor = selected ? .white
                : (enabled ? NSColor(calibratedWhite: 0.1, alpha: 1) : NSColor(calibratedWhite: 0.6, alpha: 1))
            if checked {
                let chk = "✓"
                let ca: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                    .foregroundColor: textColor]
                let cs = (chk as NSString).size(withAttributes: ca)
                (chk as NSString).draw(at: NSPoint(x: pX+14, y: y - rowH/2 - cs.height/2), withAttributes: ca)
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13.5),
                .foregroundColor: textColor]
            let sz = (title as NSString).size(withAttributes: attrs)
            (title as NSString).draw(at: NSPoint(x: pX+34, y: y - rowH/2 - sz.height/2), withAttributes: attrs)
            y -= rowH
        }
    }

    // Caption.
    let cap = "macowl menu - the owl is awake, lid-closed mode is on"
    let capAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.9)]
    (cap as NSString).draw(at: NSPoint(x: 30, y: 28), withAttributes: capAttrs)

    return true
}

// Write a 2x PNG.
let outPath = CommandLine.arguments.dropFirst().first ?? "./menu-preview.png"
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(W*2), pixelsHigh: Int(H*2),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
img.draw(in: NSRect(x: 0, y: 0, width: W, height: H))
NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
