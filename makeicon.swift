// Generates the coloured owl app icon as an .iconset directory.
//   swift makeicon.swift <output-iconset-dir>
// build.sh then runs `iconutil` to turn it into macowl.icns.
//
// The app icon uses the awake (open-eyed, alert) owl as macowl's identity.

import AppKit

func drawOwl(into rect: NSRect, awake: Bool) {
    let w = rect.width, h = rect.height
    NSGraphicsContext.current!.shouldAntialias = true

    // Background squircle with night-sky gradient.
    let pad = w * 0.06
    let bgRect = NSRect(x: pad, y: pad, width: w - pad*2, height: h - pad*2)
    let bg = NSBezierPath(roundedRect: bgRect, xRadius: w*0.225, yRadius: w*0.225)
    NSGradient(colors: [
        NSColor(red: 0.20, green: 0.22, blue: 0.50, alpha: 1),
        NSColor(red: 0.08, green: 0.09, blue: 0.22, alpha: 1)])!.draw(in: bg, angle: -90)

    // Crescent moon (top-right). Drawn as a clip of (moon disc) minus (cut
    // disc) so the gap is genuinely the sky showing through. The earlier
    // version painted the gap with a fixed colour, which did not match the
    // gradient and left an ugly dark dot instead of a crescent.
    let moonColor = NSColor(red: 0.98, green: 0.95, blue: 0.78, alpha: 1)
    let mc = NSPoint(x: w*0.79, y: h*0.79), mr = w*0.078
    let moonRect = NSRect(x: mc.x-mr, y: mc.y-mr, width: mr*2, height: mr*2)
    let cutRect = NSRect(x: mc.x-mr+mr*0.62, y: mc.y-mr+mr*0.10, width: mr*2, height: mr*2)
    let ctx = NSGraphicsContext.current!
    ctx.saveGraphicsState()
    NSBezierPath(ovalIn: moonRect).addClip()
    let mask = NSBezierPath(rect: bgRect)
    mask.appendOval(in: cutRect)
    mask.windingRule = .evenOdd
    mask.addClip()
    moonColor.setFill(); NSBezierPath(rect: moonRect).fill()
    ctx.restoreGraphicsState()

    // A few small stars to balance the night sky.
    moonColor.setFill()
    func star(_ fx: CGFloat, _ fy: CGFloat, _ r: CGFloat) {
        NSBezierPath(ovalIn: NSRect(x: w*fx-r, y: h*fy-r, width: r*2, height: r*2)).fill()
    }
    star(0.20, 0.84, w*0.011)
    star(0.30, 0.72, w*0.008)
    star(0.86, 0.62, w*0.009)
    star(0.66, 0.86, w*0.007)

    let amber = NSColor(red: 0.86, green: 0.60, blue: 0.24, alpha: 1)
    let amberDark = NSColor(red: 0.62, green: 0.40, blue: 0.15, alpha: 1)

    // Ear tufts.
    func ear(cx: CGFloat, tipX: CGFloat) {
        let base = h*0.72, tip = h*0.86, half = w*0.075
        let p = NSBezierPath()
        p.move(to: NSPoint(x: cx-half, y: base))
        p.line(to: NSPoint(x: cx+half, y: base))
        p.line(to: NSPoint(x: tipX, y: tip))
        p.close()
        amberDark.setFill(); p.fill()
    }
    ear(cx: w*0.38, tipX: w*0.31)
    ear(cx: w*0.62, tipX: w*0.69)

    // Head/body + belly highlight.
    let body = NSBezierPath(roundedRect: NSRect(x: w*0.24, y: h*0.20, width: w*0.52, height: h*0.55),
                            xRadius: w*0.26, yRadius: w*0.26)
    amber.setFill(); body.fill()
    NSColor(red: 0.93, green: 0.74, blue: 0.42, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: w*0.34, y: h*0.22, width: w*0.32, height: h*0.36)).fill()

    // Eyes.
    let eyeR = w*0.115, eyeY = h*0.56
    let lx = w*0.41, rx = w*0.59
    if awake {
        for cx in [lx, rx] {
            NSColor(red: 0.98, green: 0.97, blue: 0.92, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: cx-eyeR, y: eyeY-eyeR, width: eyeR*2, height: eyeR*2)).fill()
            let ring = NSBezierPath(ovalIn: NSRect(x: cx-eyeR, y: eyeY-eyeR, width: eyeR*2, height: eyeR*2))
            ring.lineWidth = w*0.018; amberDark.setStroke(); ring.stroke()
            let pr = eyeR*0.5
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: cx-pr, y: eyeY-pr, width: pr*2, height: pr*2)).fill()
            let gl = pr*0.32
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: cx-pr*0.3, y: eyeY+pr*0.2, width: gl*2, height: gl*2)).fill()
        }
    } else {
        for cx in [lx, rx] {
            let p = NSBezierPath()
            p.move(to: NSPoint(x: cx-eyeR, y: eyeY))
            p.curve(to: NSPoint(x: cx+eyeR, y: eyeY),
                    controlPoint1: NSPoint(x: cx-eyeR*0.4, y: eyeY-eyeR*1.0),
                    controlPoint2: NSPoint(x: cx+eyeR*0.4, y: eyeY-eyeR*1.0))
            p.lineWidth = w*0.025; p.lineCapStyle = .round
            amberDark.setStroke(); p.stroke()
        }
    }

    // Beak.
    let beak = NSBezierPath()
    let bx = w*0.5, by = h*0.50
    beak.move(to: NSPoint(x: bx-w*0.035, y: by))
    beak.line(to: NSPoint(x: bx+w*0.035, y: by))
    beak.line(to: NSPoint(x: bx, y: by-h*0.075))
    beak.close()
    NSColor(red: 0.95, green: 0.66, blue: 0.20, alpha: 1).setFill(); beak.fill()
}

func render(size: CGFloat, to path: String) {
    let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { r in
        drawOwl(into: r, awake: true); return true
    }
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
}

let dir = CommandLine.arguments.dropFirst().first ?? "./macowl.iconset"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
let specs: [(Int, String)] = [
    (16,"icon_16x16"),(32,"icon_16x16@2x"),(32,"icon_32x32"),(64,"icon_32x32@2x"),
    (128,"icon_128x128"),(256,"icon_128x128@2x"),(256,"icon_256x256"),(512,"icon_256x256@2x"),
    (512,"icon_512x512"),(1024,"icon_512x512@2x")]
for (px, name) in specs { render(size: CGFloat(px), to: "\(dir)/\(name).png") }
print("wrote iconset to \(dir)")
